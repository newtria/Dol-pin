// Supabase Edge Function for server-side Gemini VLM analysis.
//
// Deploy with: supabase functions deploy gemini-analyze
//
// Required secrets:
//   GEMINI_API_KEY               — Google Generative Language API key.
//   SUPABASE_URL                 — provided by the platform.
//   SUPABASE_SERVICE_ROLE_KEY    — provided by the platform.
// Optional:
//   ALLOWED_ORIGINS              — comma-separated CORS allowlist.
//   GEMINI_DAILY_QUOTA           — per-user daily call cap (default: 50).
//
// Authorization model:
//   * Caller must present a valid Supabase JWT.
//   * Each call increments a per-user counter in `function_usage_quota`
//     (migration 017); requests beyond the daily cap are rejected with
//     429 + a `Retry-After` hint pointing at the next UTC midnight.
//   * No CORS wildcard once `ALLOWED_ORIGINS` is configured.
//
// Inputs are validated for type + size before they reach Gemini — base64
// payloads above 4 MB are rejected up front to match the
// `lib/data/datasources/gemini_service.dart` client guard.

import { requireUser } from '../_shared/auth.ts'
import { checkAndIncrementQuota } from '../_shared/quota.ts'
import {
  corsHeaders,
  jsonResponse,
  preflightResponse,
} from '../_shared/cors.ts'

// Keyed under this name in `function_usage_quota`. Renaming the function
// without renaming this string silently forks the per-user counter.
const FUNCTION_NAME = 'gemini-analyze'
const GEMINI_API_KEY = Deno.env.get('GEMINI_API_KEY')!

// Misconfigured env (`"abc"`, blank, "0") otherwise produces NaN / 0 and
// either every request fails 500 or the limit collapses to 1.
const DAILY_QUOTA_DEFAULT = 50
const parsedQuota = Number(Deno.env.get('GEMINI_DAILY_QUOTA') ?? '')
const DAILY_QUOTA = Number.isFinite(parsedQuota) && parsedQuota >= 1
  ? Math.floor(parsedQuota)
  : DAILY_QUOTA_DEFAULT

// Soft cap before we even attempt to hit Gemini. The mobile client trims
// images to <= 4 MB base64 before calling us; anything larger is a sign of
// a misbehaving caller and we cut it off here to protect billing.
const MAX_IMAGE_BASE64_BYTES = 4 * 1024 * 1024
const MAX_PROMPT_CHARS = 2_000

interface AnalyzeRequest {
  image: string // base64-encoded image data
  mimeType: string // e.g. "image/jpeg"
  prompt: string // the analysis prompt
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return preflightResponse(req)
  if (req.method !== 'POST') {
    return jsonResponse(req, 405, { error: 'Method not allowed' })
  }
  const json = (status: number, body: unknown) => jsonResponse(req, status, body)

  const auth = await requireUser(req)
  if (!auth.ok) return json(auth.status, { error: auth.error })

  // Validate body BEFORE touching the quota counter — malformed or oversized
  // requests must not burn a quota slot.
  let body: AnalyzeRequest
  try {
    body = (await req.json()) as AnalyzeRequest
  } catch {
    return json(400, { error: 'Invalid JSON body' })
  }

  const { image, mimeType, prompt } = body
  if (typeof image !== 'string' || image.length === 0) {
    return json(400, { error: 'Missing or invalid image' })
  }
  if (image.length > MAX_IMAGE_BASE64_BYTES) {
    return json(413, { error: 'Image too large' })
  }
  if (typeof prompt !== 'string' || prompt.length === 0) {
    return json(400, { error: 'Missing or invalid prompt' })
  }
  if (prompt.length > MAX_PROMPT_CHARS) {
    return json(413, { error: 'Prompt too long' })
  }

  const quota = await checkAndIncrementQuota(
    auth.userId,
    FUNCTION_NAME,
    DAILY_QUOTA,
  )
  if (!quota.ok) {
    // 429 needs an extra `Retry-After` header that `jsonResponse` doesn't
    // emit; build the response by hand for this branch only.
    const headers = {
      ...corsHeaders(req),
      'Content-Type': 'application/json',
      ...(quota.status === 429
        ? { 'Retry-After': String(quota.retryAfterSeconds) }
        : {}),
    }
    return new Response(JSON.stringify({ error: quota.error }), {
      status: quota.status,
      headers,
    })
  }

  // Pass the API key in the header instead of the URL — `?key=…` ends up
  // in Supabase Function fetch logs, exposing the production Gemini key to
  // anyone with log-read access on the project.
  const geminiUrl =
    'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent'

  try {
    const geminiResponse = await fetch(geminiUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-goog-api-key': GEMINI_API_KEY,
      },
      body: JSON.stringify({
        contents: [
          {
            parts: [
              { text: prompt },
              {
                inline_data: {
                  mime_type: mimeType || 'image/jpeg',
                  data: image,
                },
              },
            ],
          },
        ],
      }),
    })

    if (!geminiResponse.ok) {
      const errorBody = await geminiResponse.text()
      console.error(
        'Gemini API error',
        { status: geminiResponse.status, userId: auth.userId },
        errorBody,
      )
      return json(502, {
        error: 'Gemini API request failed',
        status: geminiResponse.status,
      })
    }

    const geminiData = await geminiResponse.json()
    const text =
      geminiData?.candidates?.[0]?.content?.parts?.[0]?.text?.trim() ?? ''

    return json(200, {
      result: text,
      quota: { count: quota.count, limit: quota.limit },
    })
  } catch (error) {
    console.error('Edge function error', { userId: auth.userId }, error)
    return json(500, { error: 'Internal server error' })
  }
})
