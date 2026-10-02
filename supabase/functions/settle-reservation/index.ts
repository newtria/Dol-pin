// Preserve the legacy request contract without a second financial authority.
import { createHandler as createRentalHandler } from "../rental-payment/index.ts";
import { jsonResponse, optionsResponse, parseJsonBody } from "../_shared/http.ts";
import { type ProviderFactory, paymentProvider } from "../_shared/payment-provider.ts";

export function createHandler(providers: ProviderFactory = paymentProvider) {
  const rental = createRentalHandler(providers);
  return async (req: Request): Promise<Response> => {
    if (req.method === "OPTIONS") return optionsResponse();
    if (req.method !== "POST") return jsonResponse(405, {});
    const body = await parseJsonBody<Record<string, unknown>>(req);
    if (body instanceof Response) return body;
    const headers = new Headers(req.headers);
    headers.delete("content-length");
    const response = await rental(new Request(req.url, { method: "POST", headers, body: JSON.stringify({
      action: "settle", reservationId: body.reservation_id,
    }) }));
    if (!response.ok) return response;
    const outcome = await response.json();
    // The legacy client treats every 2xx as final success.
    return outcome.status === "processing" ? jsonResponse(409, { code: "PAYMENT_REVIEW_REQUIRED" }) : jsonResponse(200, outcome);
  };
}
if (import.meta.main) Deno.serve(createHandler());
