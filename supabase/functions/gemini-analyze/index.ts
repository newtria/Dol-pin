// Supabase Edge Function for server-side Gemini VLM analysis
// Deploy with: supabase functions deploy gemini-analyze
// Set secret: supabase secrets set GEMINI_API_KEY=<your-key>

import { requireAuthenticatedUser } from "../_shared/auth.ts";
import {
  jsonResponse,
  optionsResponse,
  parseJsonBody,
} from "../_shared/http.ts";

const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY")!;
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;
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

Deno.serve(async (req) => {
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

    const body = await parseJsonBody<AnalyzeRequest>(req);
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

    // Call Gemini API
    const geminiUrl =
      `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=${GEMINI_API_KEY}`;

    const ctrl = new AbortController();
    const timer = setTimeout(() => ctrl.abort(), GEMINI_TIMEOUT_MS);
    let geminiResponse: Response;
    try {
      geminiResponse = await fetch(geminiUrl, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
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
      });
    } finally {
      clearTimeout(timer);
    }

    if (!geminiResponse.ok) {
      const errorBody = await geminiResponse.text();
      console.error("Gemini API error:", geminiResponse.status, errorBody);
      return jsonResponse(502, {
        error: "Gemini API request failed",
        status: geminiResponse.status,
      });
    }

    const geminiData = await geminiResponse.json();
    const text =
      geminiData?.candidates?.[0]?.content?.parts?.[0]?.text?.trim() ?? "";

    return jsonResponse(200, { result: text });
  } catch (error) {
    console.error("Edge function error:", error);
    return jsonResponse(500, { error: "Internal server error" });
  }
});
