import { isErrorCode } from "./errors.ts";

const errorTypes = new Set([
  "Error", "TypeError", "RangeError", "SyntaxError", "ReferenceError",
  "URIError", "EvalError", "DOMException", "TimeoutError", "AbortError",
  "ApiError", "PostgrestError", "AuthApiError", "StorageApiError",
]);
const sourceFiles = new Set([
  "http.ts", "telemetry.ts", "errors.ts", "auth.ts", "portone.ts",
  "payment-provider.ts", "rental-finance.ts", "reservation-actions.ts",
  "account-closure.ts",
]);
const functionNames = new Set([
  "account-lifecycle", "finance-ops", "gemini-analyze", "push-notification",
  "refund-payment", "rental-payment", "rental-recovery", "resolve-dispute",
  "service-delivery", "service-ops", "settle-reservation", "toss-payment",
  "verify-payment",
]);

// Error messages, SQL details, URLs and complete stacks can contain customer
// data or credentials. Diagnostics use a bounded, explicit field allowlist.
export function errorDiagnostics(error: unknown): Record<string, unknown>[] {
  const diagnostics: Record<string, unknown>[] = [];
  const seen = new Set<unknown>();
  let current = error;
  while (current && typeof current === "object" && diagnostics.length < 3 && !seen.has(current)) {
    seen.add(current);
    const value = current as Record<string, unknown>;
    const name = typeof value.name === "string" && errorTypes.has(value.name)
      ? value.name
      : "UnknownError";
    const code = typeof value.code === "string" &&
        (isErrorCode(value.code) || /^[0-9A-Z]{5}$/.test(value.code) || /^PGRST\d{3}$/.test(value.code))
      ? value.code
      : undefined;
    const frames: string[] = [];
    if (typeof value.stack === "string") {
      for (const match of value.stack.slice(0, 12000).matchAll(/\/([a-z0-9_-]+)\/([a-z0-9_-]+\.ts):(\d{1,7}):(\d{1,5})/g)) {
        const [, directory, file, line, column] = match;
        if ((directory === "_shared" && sourceFiles.has(file)) || (file === "index.ts" && functionNames.has(directory))) {
          frames.push(`${directory}/${file}:${line}:${column}`);
          if (frames.length === 5) break;
        }
      }
    }
    diagnostics.push({ type: name, ...(code ? { code } : {}), ...(frames.length ? { frames } : {}) });
    current = value.cause;
  }
  return diagnostics;
}
