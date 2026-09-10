// Supabase Edge Function for server-side Gemini VLM analysis
// Deploy with: supabase functions deploy gemini-analyze
// Set secret: supabase secrets set GEMINI_API_KEY=<your-key>

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { ApiError, providerCall } from "../_shared/errors.ts";
import { requireAuthenticatedUser } from "../_shared/auth.ts";
import {
  errorResponse,
  jsonResponse,
  optionsResponse,
  parseJsonBody,
} from "../_shared/http.ts";

const GEMINI_TIMEOUT_MS = 15_000;
const MAX_IMAGE_BASE64_BYTES = 8 * 1024 * 1024;
const MAX_PROMPT_CHARS = 1200;
const ALLOWED_MIME_TYPES = new Set(["image/jpeg", "image/png", "image/webp"]);

interface AnalyzeRequest {
  image: string; // base64-encoded image data
  mimeType: string; // e.g. "image/jpeg"
  prompt: string; // the analysis prompt
}

function byteLength(value: string): number {
  return new TextEncoder().encode(value).length;
}

export function createHandler() {
  return async (req: Request): Promise<Response> => {
    const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY");
    const model = Deno.env.get("GEMINI_MODEL") ?? "gemini-3.6-flash";
    const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
    const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;
    // Handle CORS preflight
    if (req.method === "OPTIONS") {
      return optionsResponse();
    }

    try {
      if (req.method !== "POST") {
        return jsonResponse(405, { error: "Method not allowed" });
      }

      const caller = await requireAuthenticatedUser(
        req,
        SUPABASE_URL,
        SUPABASE_ANON_KEY,
      );
      if (caller instanceof Response) return caller;

      const body = await parseJsonBody<AnalyzeRequest>(req, 9 * 1024 * 1024);
      if (body instanceof Response) return body;
      const { image, mimeType, prompt } = body;

      if (!image || !prompt) {
        return jsonResponse(400, {
          error: "Missing required fields: image, prompt",
        });
      }
      if (
        typeof image !== "string" || byteLength(image) > MAX_IMAGE_BASE64_BYTES
      ) {
        return jsonResponse(413, { error: "Image payload is too large" });
      }
      if (typeof prompt !== "string" || prompt.length > MAX_PROMPT_CHARS) {
        return jsonResponse(400, { error: "Prompt is too long" });
      }
      const safeMimeType = mimeType || "image/jpeg";
      if (!ALLOWED_MIME_TYPES.has(safeMimeType)) {
        return jsonResponse(415, { error: "Unsupported image MIME type" });
      }

      const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
      if (
        !GEMINI_API_KEY || !serviceKey || !/^gemini-[a-z0-9.-]+$/.test(model)
      ) {
        throw new ApiError("SERVICE_UNAVAILABLE");
      }
      const admin = createClient(SUPABASE_URL, serviceKey);
      const { data: quota, error: quotaError } = await admin.rpc(
        "consume_api_quota",
        { p_user_id: caller.id, p_feature: "gemini-analyze" },
      );
      if (quotaError || typeof quota?.allowed !== "boolean") {
        throw new ApiError("SERVICE_UNAVAILABLE");
      }
      if (!quota.allowed) {
        return jsonResponse(429, {
          code: "RATE_LIMITED",
          retryAfter: quota.retryAfter,
        });
      }

      // Reserve quota before incurring provider cost; upstream failures consume it.
      // Call Gemini API
      const geminiUrl =
        `https://generativelanguage.googleapis.com/v1beta/models/${
          encodeURIComponent(model)
        }:generateContent`;

      const ctrl = new AbortController();
      const timer = setTimeout(() => ctrl.abort(), GEMINI_TIMEOUT_MS);
      let geminiResponse: Response;
      let geminiData;
      try {
        geminiResponse = await providerCall(() =>
          fetch(geminiUrl, {
            method: "POST",
            headers: {
              "Content-Type": "application/json",
              "x-goog-api-key": GEMINI_API_KEY,
            },
            signal: ctrl.signal,
            body: JSON.stringify({
              contents: [
                {
                  parts: [
                    { text: prompt },
                    {
                      inline_data: {
                        mime_type: safeMimeType,
                        data: image,
                      },
                    },
                  ],
                },
              ],
            }),
          })
        );

        if (!geminiResponse.ok) {
          await geminiResponse.body?.cancel();
          return jsonResponse(502, {
            error: "Gemini API request failed",
            status: geminiResponse.status,
          });
        }

        geminiData = await providerCall(() => geminiResponse.json());
      } finally {
        clearTimeout(timer);
      }
      const text = geminiData?.candidates?.[0]?.content?.parts?.[0]?.text;
      if (typeof text !== "string" || !text.trim()) {
        throw new ApiError("UPSTREAM_UNAVAILABLE");
      }
      return jsonResponse(200, { result: text.trim() });
    } catch (error) {
      return errorResponse(error);
    }
  };
}
if (import.meta.main) Deno.serve(createHandler());
