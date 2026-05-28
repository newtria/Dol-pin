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
//   * Per-user counter in `function_usage_quota` (migration 018) gates the
//     call — requests beyond the daily cap return 429 + `Retry-After`.
//   * Upstream-failure paths (Gemini 5xx, fetch throw) call
//     `refundQuotaSlot` so a Gemini outage does not drain users' quotas.
//   * Inputs are validated for type, shape, and size before the quota
//     increment — malformed bodies do not burn a slot.

import { requireUser } from '../_shared/auth.ts'
import {
  checkAndIncrementQuota,
  refundQuotaSlot,
} from '../_shared/quota.ts'
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

// Soft cap before we even attempt to hit Gemini. Matches the client-side
// guard in `lib/data/datasources/gemini_service.dart`.
const MAX_IMAGE_BASE64_BYTES = 4 * 1024 * 1024
const MAX_PROMPT_CHARS = 2_000

// Mime allowlist matches what Gemini's inlineData accepts and what
// `_getMimeType` on the client can produce.
const ALLOWED_MIME_TYPES = new Set([
  'image/jpeg',
  'image/png',
  'image/webp',
  'image/heic',
  'image/heif',
])

interface AnalyzeRequest {
  image: string
  mimeType: string
  prompt: string
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return preflightResponse(req)
  const json = (status: number, body: unknown) => jsonResponse(req, status, body)

  // Top-level try/catch so a thrown helper (network reset, pool exhaustion,
  // unexpected runtime error) returns structured JSON + CORS headers
  // instead of Deno's default empty 500 — which a browser caller would
  // see as a CORS error masking the real cause.
  try {
    if (req.method !== 'POST') {
      return json(405, { error: 'Method not allowed' })
    }

    const auth = await requireUser(req)
    if (!auth.ok) return json(auth.status, { error: auth.error })

    // -----------------------------------------------------------------
    // Body validation — runs BEFORE the quota increment so a malformed
    // or oversized request does not burn a quota slot.
    // -----------------------------------------------------------------
    let rawBody: unknown
    try {
      rawBody = await req.json()
    } catch {
      return json(400, { error: 'Invalid JSON body' })
    }
    // Guard against valid JSON that isn't an object: `null`, numbers,
    // arrays. Destructuring `null` would throw a raw TypeError.
    if (!rawBody || typeof rawBody !== 'object' || Array.isArray(rawBody)) {
      return json(400, { error: 'Body must be a JSON object' })
    }
    const body = rawBody as Partial<AnalyzeRequest>
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
    const resolvedMime = typeof mimeType === 'string' && mimeType.length > 0
      ? mimeType
      : 'image/jpeg'
    if (!ALLOWED_MIME_TYPES.has(resolvedMime)) {
      return json(415, {
        error: 'Unsupported mimeType',
        accepted: [...ALLOWED_MIME_TYPES],
      })
    }

    // -----------------------------------------------------------------
    // Quota gate.
    // -----------------------------------------------------------------
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

    // -----------------------------------------------------------------
    // Gemini call. Any non-2xx or thrown error refunds the quota slot
    // before responding — a Gemini outage must not drain the user's cap.
    // -----------------------------------------------------------------
    // API key in header, not `?key=…`, to keep it out of Supabase fetch logs.
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
                { inline_data: { mime_type: resolvedMime, data: image } },
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
        await refundQuotaSlot(auth.userId, FUNCTION_NAME)
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
      console.error('Gemini fetch threw', { userId: auth.userId }, error)
      await refundQuotaSlot(auth.userId, FUNCTION_NAME)
      return json(502, { error: 'Gemini call failed' })
    }
  } catch (error) {
    // Catch-all: any uncaught throw from auth / quota / validation. We do
    // NOT refund the quota here — if the throw happened before the quota
    // call, there's nothing to refund; if after, the inner try/catch
    // already refunded.
    console.error('gemini-analyze handler error', error)
    return json(500, { error: 'Internal server error' })
  }
})
