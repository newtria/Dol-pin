// Supabase Edge Function for server-side Gemini VLM analysis
// Deploy with: supabase functions deploy gemini-analyze
// Set secret: supabase secrets set GEMINI_API_KEY=<your-key>

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY")!;
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;
const GEMINI_TIMEOUT_MS = 15_000;
const MAX_IMAGE_BASE64_BYTES = 8 * 1024 * 1024;
const MAX_PROMPT_CHARS = 1200;
const ALLOWED_MIME_TYPES = new Set(["image/jpeg", "image/png", "image/webp"]);

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

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
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    if (req.method !== "POST") {
      return new Response(
        JSON.stringify({ error: "Method not allowed" }),
        {
          status: 405,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    const authHeader = req.headers.get("Authorization") ?? "";
    if (!authHeader.toLowerCase().startsWith("bearer ")) {
      return new Response(
        JSON.stringify({ error: "Missing bearer token" }),
        {
          status: 401,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }
    const callerJwt = authHeader.slice("Bearer ".length).trim();
    if (!callerJwt) {
      return new Response(
        JSON.stringify({ error: "Empty bearer token" }),
        {
          status: 401,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      global: { headers: { Authorization: `Bearer ${callerJwt}` } },
    });
    const { data: userData, error: userError } = await supabase.auth.getUser(
      callerJwt,
    );
    if (userError || !userData?.user) {
      return new Response(
        JSON.stringify({ error: "Invalid token" }),
        {
          status: 401,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    const { image, mimeType, prompt } = (await req.json()) as AnalyzeRequest;

    if (!image || !prompt) {
      return new Response(
        JSON.stringify({ error: "Missing required fields: image, prompt" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }
    if (
      typeof image !== "string" || byteLength(image) > MAX_IMAGE_BASE64_BYTES
    ) {
      return new Response(
        JSON.stringify({ error: "Image payload is too large" }),
        {
          status: 413,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }
    if (typeof prompt !== "string" || prompt.length > MAX_PROMPT_CHARS) {
      return new Response(
        JSON.stringify({ error: "Prompt is too long" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }
    const safeMimeType = mimeType || "image/jpeg";
    if (!ALLOWED_MIME_TYPES.has(safeMimeType)) {
      return new Response(
        JSON.stringify({ error: "Unsupported image MIME type" }),
        {
          status: 415,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
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
      return new Response(
        JSON.stringify({
          error: "Gemini API request failed",
          status: geminiResponse.status,
        }),
        {
          status: 502,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    const geminiData = await geminiResponse.json();
    const text =
      geminiData?.candidates?.[0]?.content?.parts?.[0]?.text?.trim() ?? "";

    return new Response(
      JSON.stringify({ result: text }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  } catch (error) {
    console.error("Edge function error:", error);
    return new Response(
      JSON.stringify({ error: "Internal server error" }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  }
});
