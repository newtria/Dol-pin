import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { requireAuthenticatedUser } from "../_shared/auth.ts";
import {
  errorResponse,
  jsonResponse,
  optionsResponse,
  parseJsonBody,
} from "../_shared/http.ts";
import { reconcileMoney, rpc } from "../_shared/rental-finance.ts";
import {
  paymentProvider,
  type ProviderFactory,
} from "../_shared/payment-provider.ts";
export function createHandler(providers: ProviderFactory = paymentProvider) {
  return async (req: Request): Promise<Response> => {
    if (req.method === "OPTIONS") return optionsResponse();
    if (req.method !== "POST") {
      return jsonResponse(405, { error: "Method not allowed" });
    }
    try {
      const url = Deno.env.get("SUPABASE_URL")!;
      const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
      const caller = await requireAuthenticatedUser(req, url, key);
      if (caller instanceof Response) return caller;
      const body = await parseJsonBody<Record<string, unknown>>(req);
      if (body instanceof Response) return body;
      if (
        !body || typeof body.reservationId !== "string" ||
        !["refund", "settle"].includes(String(body.action))
      ) return jsonResponse(400, { error: "잘못된 거래 요청입니다." });
      const admin = createClient(url, key);
      const op = await rpc<{ id: string; status: string }>(
        admin,
        "begin_rental_money_operation",
        {
          p_reservation_id: body.reservationId,
          p_actor: caller.id,
          p_kind: body.action,
        },
      );
      if (op.status === "complete") {
        return jsonResponse(200, {
          status: body.action === "refund" ? "cancelled" : "settled",
        });
      }
      return jsonResponse(200, await reconcileMoney(admin, op.id, providers));
    } catch (e) {
      return errorResponse(e);
    }
  };
}
if (import.meta.main) Deno.serve(createHandler());
