import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { requireAuthenticatedUser } from "../_shared/auth.ts";
import {
  errorResponse,
  jsonResponse,
  optionsResponse,
  parseJsonBody,
} from "../_shared/http.ts";
import { reconcileCheckout, rpc } from "../_shared/rental-finance.ts";
import {
  paymentProvider,
  type ProviderFactory,
} from "../_shared/payment-provider.ts";
const hash = async (text: string) =>
  Array.from(
    new Uint8Array(
      await crypto.subtle.digest("SHA-256", new TextEncoder().encode(text)),
    ),
    (b) => b.toString(16).padStart(2, "0"),
  ).join("");

export function createHandler(providers: ProviderFactory = paymentProvider) {
  return async (req: Request): Promise<Response> => {
    if (req.method === "OPTIONS") return optionsResponse();
    if (req.method !== "POST") {
      return jsonResponse(405, { error: "Method not allowed" });
    }
    const body = await parseJsonBody<Record<string, unknown>>(req);
    if (body instanceof Response) return body;
    if (!body || typeof body !== "object") {
      return jsonResponse(400, { error: "잘못된 결제 요청입니다." });
    }
    const url = Deno.env.get("SUPABASE_URL")!;
    const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const admin = createClient(url, key);
    try {
      if (body.action === "prepare" || body.action === "recover") {
        const caller = await requireAuthenticatedUser(req, url, key);
        if (caller instanceof Response) return caller;
        if (typeof body.reservationId !== "string") {
          return jsonResponse(400, { error: "예약 번호가 필요합니다." });
        }
        if (body.action === "recover") {
          const { data: r, error } = await admin.from("reservations").select(
            "borrower_id,status",
          ).eq("id", body.reservationId).single();
          if (error || r.borrower_id !== caller.id) {
            return jsonResponse(403, { error: "거래에 접근할 수 없습니다." });
          }
          if (r.status !== "accepted") {
            return jsonResponse(200, {
              status: r.status,
              reservationId: body.reservationId,
            });
          }
          const { data: c } = await admin.from("toss_checkouts").select(
            "order_id",
          ).eq("reservation_id", body.reservationId).maybeSingle();
          return jsonResponse(
            200,
            c
              ? await reconcileCheckout(admin, c.order_id, undefined, providers)
              : { status: r.status, reservationId: body.reservationId },
          );
        }
        providers("toss"); // Validate provider configuration before opening a checkout.
        const origin = Deno.env.get("DOLPIN_WEB_URL");
        if (!origin) {
          return jsonResponse(503, {
            error: "결제 웹 주소 설정이 필요합니다.",
          });
        }
        const token = crypto.randomUUID() + crypto.randomUUID();
        const c = await rpc<{ order_id: string }>(
          admin,
          "prepare_toss_checkout",
          {
            p_reservation_id: body.reservationId,
            p_actor: caller.id,
            p_token_hash: await hash(token),
            p_mobile: body.mobile === true,
          },
        );
        return jsonResponse(200, {
          checkoutUrl: `${new URL(
            "/payments/checkout",
            origin,
          )}#token=${token}&orderId=${c.order_id}`,
        });
      }
      if (
        !["checkout", "confirm", "status"].includes(String(body.action)) ||
        typeof body.token !== "string" || typeof body.orderId !== "string"
      ) {
        return jsonResponse(400, { error: "잘못된 결제 요청입니다." });
      }
      const { data: session, error: sessionError } = await admin.from(
        "toss_checkout_sessions",
      ).select("mobile,expires_at").eq("order_id", body.orderId).eq(
        "token_hash",
        await hash(body.token),
      ).maybeSingle();
      if (
        sessionError || !session || Date.parse(session.expires_at) <= Date.now()
      ) {
        return jsonResponse(403, {
          error:
            "결제 링크가 유효하지 않습니다. 거래 상세에서 결과를 확인해 주세요.",
        });
      }
      const { data: c, error } = await admin.from("toss_checkouts").select("*")
        .eq("order_id", body.orderId).single();
      if (error) throw error;
      if (body.action === "checkout") {
        const { data: r, error } = await admin.from("reservations").select(
          "status,payment_attempt_merchant_uid",
        ).eq("id", c.reservation_id).single();
        if (error) throw error;
        return jsonResponse(200, {
          orderId: c.order_id,
          amount: c.amount,
          customerKey: c.customer_key,
          mobile: session.mobile,
          reservationId: c.reservation_id,
          status: r.status,
          recovering: r.status === "accepted" &&
            !!r.payment_attempt_merchant_uid,
          canPay: r.status === "accepted" && !r.payment_attempt_merchant_uid &&
            Date.parse(c.expires_at) > Date.now(),
        });
      }
      if (body.action === "status") {
        const { data: r, error } = await admin.from("reservations").select(
          "status",
        ).eq("id", c.reservation_id).single();
        if (error) throw error;
        return jsonResponse(200, {
          ...(r.status === "accepted"
            ? await reconcileCheckout(admin, c.order_id, undefined, providers)
            : { status: r.status, reservationId: c.reservation_id }),
          mobile: session.mobile,
        });
      }
      if (
        typeof body.paymentKey !== "string" || !body.paymentKey ||
        body.amount !== c.amount
      ) {
        return jsonResponse(400, {
          error: "결제 금액 또는 승인 정보가 일치하지 않습니다.",
        });
      }
      const result = await reconcileCheckout(
        admin,
        c.order_id,
        body.paymentKey,
        providers,
      );
      return jsonResponse(200, { ...result, mobile: session.mobile });
    } catch (e) {
      return errorResponse(e);
    }
  };
}
export const handleRequest = createHandler();
if (import.meta.main) Deno.serve(handleRequest);
