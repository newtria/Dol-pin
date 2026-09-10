import {
  codeForStatus,
  errorCode,
  isErrorCode,
  publicError,
} from "./errors.ts";

export const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-dolpin-admin-key",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Expose-Headers": "Retry-After, X-Request-Id",
};

export function jsonResponse(status: number, body: unknown): Response {
  const headers: Record<string, string> = {
    ...corsHeaders,
    "Content-Type": "application/json",
  };
  if (status >= 400) {
    const original = body && typeof body === "object"
      ? body as Record<string, unknown>
      : {};
    const detail = publicError(
      isErrorCode(original.code) ? original.code : codeForStatus(status),
    );
    const requestId = crypto.randomUUID();
    // Preserve legacy reconciliation flags, never arbitrary error/debug fields.
    const flags = Object.fromEntries(
      ["refunded", "retried_transition", "review_required"]
        .filter((key) => typeof original[key] === "boolean").map(
          (key) => [key, original[key]],
        ),
    );
    const retryAfter = typeof original.retryAfter === "number" &&
        Number.isFinite(original.retryAfter)
      ? Math.max(1, Math.ceil(original.retryAfter))
      : undefined;
    body = {
      ...flags,
      code: detail.code,
      error: detail.error,
      retryable: detail.retryable,
      requestId,
      ...(retryAfter ? { retryAfter } : {}),
    };
    status = detail.status;
    headers["X-Request-Id"] = requestId;
    if (retryAfter) headers["Retry-After"] = String(retryAfter);
    if (status >= 500) {
      console.error(
        JSON.stringify({ event: "api_error", requestId, code: detail.code }),
      );
    }
  }
  return new Response(JSON.stringify(body), {
    status,
    headers,
  });
}

export function errorResponse(error: unknown): Response {
  const detail = publicError(errorCode(error));
  return jsonResponse(detail.status, { code: detail.code });
}

export function optionsResponse(): Response {
  return new Response("ok", { headers: corsHeaders });
}

export async function parseJsonBody<T>(
  req: Request,
  maxBytes = 64 * 1024,
): Promise<T | Response> {
  try {
    if (Number(req.headers.get("content-length")) > maxBytes) {
      return jsonResponse(413, {});
    }
    if (!req.body) return jsonResponse(400, {});
    const reader = req.body.getReader();
    const chunks: Uint8Array[] = [];
    let length = 0;
    try {
      while (true) {
        const { done, value } = await reader.read();
        if (done) break;
        length += value.byteLength;
        if (length > maxBytes) {
          await reader.cancel();
          return jsonResponse(413, {});
        }
        chunks.push(value);
      }
    } finally {
      reader.releaseLock();
    }
    const bytes = new Uint8Array(length);
    let offset = 0;
    for (const chunk of chunks) {
      bytes.set(chunk, offset);
      offset += chunk.byteLength;
    }
    const body = JSON.parse(new TextDecoder().decode(bytes));
    if (!body || typeof body !== "object" || Array.isArray(body)) {
      return jsonResponse(400, {});
    }
    return body as T;
  } catch {
    return jsonResponse(400, { error: "Invalid JSON body" });
  }
}
