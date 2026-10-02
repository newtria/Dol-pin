// Legacy callers identify the payment; authorization and durable reconciliation
// happen before any provider HTTP, exactly as in rental-payment.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { requireAuthenticatedUser } from "../_shared/auth.ts";
import { errorResponse, jsonResponse, optionsResponse, parseJsonBody } from "../_shared/http.ts";
import { ApiError } from "../_shared/errors.ts";
import { reconcileMoney, rpc } from "../_shared/rental-finance.ts";
import { type ProviderFactory, paymentProvider } from "../_shared/payment-provider.ts";

export function createHandler(providers: ProviderFactory = paymentProvider) {
  return async (req: Request): Promise<Response> => {
    if (req.method === "OPTIONS") return optionsResponse();
    if (req.method !== "POST") return jsonResponse(405, {});
    try {
      const url = Deno.env.get("SUPABASE_URL");
      const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
      if (!url || !key) throw new ApiError("SERVICE_UNAVAILABLE");
      const caller = await requireAuthenticatedUser(req, url, key);
      if (caller instanceof Response) return caller;
      const body = await parseJsonBody<Record<string, unknown>>(req);
      if (body instanceof Response) return body;
      if (typeof body.imp_uid !== "string" || !body.imp_uid || body.imp_uid.length > 200) throw new ApiError("INVALID_REQUEST");
      const admin = createClient(url, key);
      const { data: rental, error } = await admin.from("reservations")
        .select("id,borrower_id,lender_id,total_paid").eq("payment_id", body.imp_uid).maybeSingle();
      if (error) throw error;
      if (!rental || ![rental.borrower_id, rental.lender_id].includes(caller.id)) throw new ApiError("NOT_FOUND");
      if (body.amount !== undefined && body.amount !== rental.total_paid) throw new ApiError("INVALID_REQUEST");
      const op = await rpc<{ id: string; status: string }>(admin, "begin_rental_money_operation", {
        p_reservation_id: rental.id, p_actor: caller.id, p_kind: "refund",
      });
      const result = op.status === "complete" ? { status: "cancelled" } : await reconcileMoney(admin, op.id, providers);
      if (result.status === "processing") return jsonResponse(409, { code: "PAYMENT_REVIEW_REQUIRED" });
      return jsonResponse(200, { ...result, reservation_status: result.status });
    } catch (error) {
      return errorResponse(error);
    }
  };
}
if (import.meta.main) Deno.serve(createHandler());
