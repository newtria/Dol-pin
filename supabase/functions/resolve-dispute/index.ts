// Compatibility route: operator JWT plus the same durable command as finance-ops.
import { createHandler as createFinanceHandler } from "../finance-ops/index.ts";
import { jsonResponse, optionsResponse, parseJsonBody } from "../_shared/http.ts";
import { type ProviderFactory, paymentProvider } from "../_shared/payment-provider.ts";

export function createHandler(providers: ProviderFactory = paymentProvider) {
  const finance = createFinanceHandler(providers);
  return async (req: Request): Promise<Response> => {
    if (req.method === "OPTIONS") return optionsResponse();
    if (req.method !== "POST") return jsonResponse(405, {});
    const body = await parseJsonBody<Record<string, unknown>>(req);
    if (body instanceof Response) return body;
    const headers = new Headers(req.headers);
    headers.delete("content-length");
    return finance(new Request(req.url, { method: "POST", headers, body: JSON.stringify({
      action: "resolveDispute", reservationId: body.reservation_id,
      refundAmount: body.refund_amount, reason: body.reason,
    }) }));
  };
}
if (import.meta.main) Deno.serve(createHandler());
