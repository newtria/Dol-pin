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

const ALLOWED = parseAllowlist(Deno.env.get('ALLOWED_ORIGINS'))

const BASE_HEADERS: Record<string, string> = {
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Vary': 'Origin',
}

/// Pure — exported for unit tests. Empty / whitespace-only env → empty
/// set, which signals "no allowlist configured" and triggers the
/// wildcard fallback in [resolveOrigin].
export function parseAllowlist(raw: string | undefined): Set<string> {
  return new Set(
    (raw ?? '').split(',').map((s) => s.trim()).filter((s) => s.length > 0),
  )
}

/// Pure — exported for unit tests. Returns the value the response should
/// put in `Access-Control-Allow-Origin`, or `null` to omit the header.
export function resolveOrigin(
  origin: string,
  allowed: Set<string>,
): string | null {
  if (!origin) return null
  if (allowed.size === 0) return '*'
  if (allowed.has(origin)) return origin
  return null
}

export function corsHeaders(req: Request): Record<string, string> {
  const origin = req.headers.get('Origin') ?? ''
  const acao = resolveOrigin(origin, ALLOWED)
  return acao === null
    ? { ...BASE_HEADERS }
    : { ...BASE_HEADERS, 'Access-Control-Allow-Origin': acao }
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
