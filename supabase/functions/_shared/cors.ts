// Shared CORS helper.
//
// Replaces the previous wildcard `Access-Control-Allow-Origin: *` on every
// Edge Function. Mobile clients do not send Origin headers, so they are
// unaffected; web callers must match the allowlist.
//
// Configure via the `ALLOWED_ORIGINS` Function secret (comma-separated). If
// the secret is empty or unset we fall back to a wildcard for backwards
// compatibility — set it explicitly in prod.
//
//   supabase secrets set ALLOWED_ORIGINS="https://app.dolpin.example,https://admin.dolpin.example"
//
// The reply mirrors the request Origin only when it appears in the
// allowlist, preventing reflection of arbitrary origins.

const RAW = Deno.env.get('ALLOWED_ORIGINS') ?? ''
const ALLOWED = new Set(
  RAW.split(',').map((s) => s.trim()).filter((s) => s.length > 0),
)

const BASE_HEADERS: Record<string, string> = {
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Vary': 'Origin',
}

export function corsHeaders(req: Request): Record<string, string> {
  const origin = req.headers.get('Origin') ?? ''
  // No Origin (native mobile, server-to-server) — return base headers.
  if (!origin) return { ...BASE_HEADERS }
  // Wildcard fallback when no allowlist configured.
  if (ALLOWED.size === 0) {
    return { ...BASE_HEADERS, 'Access-Control-Allow-Origin': '*' }
  }
  // Reflect only allowlisted origins.
  if (ALLOWED.has(origin)) {
    return { ...BASE_HEADERS, 'Access-Control-Allow-Origin': origin }
  }
  // Disallowed origin — omit ACAO so the browser blocks the response.
  return { ...BASE_HEADERS }
}

export function jsonResponse(
  req: Request,
  status: number,
  body: unknown,
): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders(req), 'Content-Type': 'application/json' },
  })
}

export function preflightResponse(req: Request): Response {
  return new Response('ok', { headers: corsHeaders(req) })
}
