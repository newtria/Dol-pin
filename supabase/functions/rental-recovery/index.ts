import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { errorResponse, jsonResponse } from "../_shared/http.ts";
import { errorCode } from "../_shared/errors.ts";
import {
  reconcileCheckout,
  reconcileMoney,
} from "../_shared/rental-finance.ts";
import {
  paymentProvider,
  type ProviderFactory,
} from "../_shared/payment-provider.ts";

export function createHandler(
  providers: ProviderFactory = paymentProvider,
  fixtureScope?: () => Promise<string[]>,
) {
  return async (req: Request): Promise<Response> => {
    if (req.method !== "POST") return jsonResponse(405, {});
    const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (!key || req.headers.get("Authorization") !== `Bearer ${key}`) {
      return jsonResponse(401, {});
    }
    const started = Date.now();
    try {
      const admin = createClient(Deno.env.get("SUPABASE_URL")!, key);
      // Due-time ordering plus persisted backoff prevents one broken payment
      // consuming the entire queue. Reviewed work is resumed only by an operator.
      let checkoutQuery = admin.from("rental_recovery_due").select(
        "key,reservation_id",
      )
        .eq("kind", "checkout").order("next_attempt_at").limit(4);
      let operationQuery = admin.from("rental_recovery_due").select(
        "key,reservation_id",
      )
        .eq("kind", "money").order("next_attempt_at").limit(4);
      if (fixtureScope) {
        const ids = await fixtureScope();
        checkoutQuery = checkoutQuery.in("reservation_id", ids);
        operationQuery = operationQuery.in("reservation_id", ids);
      }
      const [checkouts, operations] = await Promise.all([
        checkoutQuery,
        operationQuery,
      ]);
      if (checkouts.error) throw checkouts.error;
      if (operations.error) throw operations.error;
      const work = [
        ...(checkouts.data ?? []).map((c) => ({
          kind: "checkout",
          key: c.key,
          run: () => reconcileCheckout(admin, c.key, undefined, providers),
        })),
        ...(operations.data ?? []).map((op) => ({
          kind: "money",
          key: op.key,
          run: () => reconcileMoney(admin, op.key, providers),
        })),
      ];
      let completed = 0, failed = 0, needsReview = 0, checked = 0;
      for (let i = 0; i < work.length; i += 8) {
        const batch = work.slice(i, i + 8);
        // At most eight jobs, one concurrent wave; no serial HTTP waves can
        // accumulate past the scheduler timeout. Providers cap each fetch at 15s.
        const results = await Promise.allSettled(
          batch.map((task) => task.run()),
        );
        checked += batch.length;
        results.forEach((result, j) => {
          if (result.status === "fulfilled") {
            if (result.value.status !== "processing") {
              completed++;
            }
          } else {
            const code = errorCode(result.reason);
            if (code === "PAYMENT_REVIEW_REQUIRED") needsReview++;
            else failed++;
            console.error(
              JSON.stringify({
                event: "rental_recovery_failed",
                kind: batch[j].kind,
                key: batch[j].key,
                code,
              }),
            );
          }
        });
      }
      console.info(
        JSON.stringify({
          event: "rental_recovery_run",
          checked,
          completed,
          failed,
          needsReview,
          durationMs: Date.now() - started,
        }),
      );
      return jsonResponse(failed ? 503 : 200, {
        checked,
        completed,
        failed,
        needsReview,
      });
    } catch (error) {
      return errorResponse(error);
    }
  };
}
if (import.meta.main) Deno.serve(createHandler());
