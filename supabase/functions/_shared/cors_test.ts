// Run with: deno test --config ../deno.json cors_test.ts
//
// Pure-function tests for the ALLOWED_ORIGINS allowlist semantics in
// `_shared/cors.ts`. The env-coupled `corsHeaders` is wrapped over
// `parseAllowlist` + `resolveOrigin`, which carry the actual logic and
// are exported for direct testing.

import { assertEquals } from 'jsr:@std/assert@1'
import { parseAllowlist, resolveOrigin } from './cors.ts'

Deno.test('parseAllowlist: undefined → empty set', () => {
  assertEquals(parseAllowlist(undefined).size, 0)
})

Deno.test('parseAllowlist: empty / whitespace-only → empty set', () => {
  assertEquals(parseAllowlist('').size, 0)
  assertEquals(parseAllowlist('   ').size, 0)
  assertEquals(parseAllowlist(', ,').size, 0)
})

Deno.test('parseAllowlist: trims and splits', () => {
  const set = parseAllowlist(' https://a.test , https://b.test ,')
  assertEquals(set.size, 2)
  assertEquals(set.has('https://a.test'), true)
  assertEquals(set.has('https://b.test'), true)
})

Deno.test('resolveOrigin: no Origin → null (omit ACAO)', () => {
  assertEquals(resolveOrigin('', new Set()), null)
  assertEquals(resolveOrigin('', new Set(['https://a.test'])), null)
})

Deno.test('resolveOrigin: empty allowlist + any origin → wildcard', () => {
  assertEquals(resolveOrigin('https://anything.test', new Set()), '*')
})

Deno.test('resolveOrigin: allowlist hit reflects', () => {
  const allow = new Set(['https://a.test', 'https://b.test'])
  assertEquals(resolveOrigin('https://a.test', allow), 'https://a.test')
})

Deno.test('resolveOrigin: allowlist miss → null', () => {
  const allow = new Set(['https://a.test'])
  assertEquals(resolveOrigin('https://evil.test', allow), null)
})

Deno.test('resolveOrigin: case-sensitive comparison', () => {
  const allow = new Set(['https://a.test'])
  // Origin headers are technically case-sensitive in the path/query but
  // host-insensitive — we err on strict matching since allowlists in
  // practice are configured with the exact production host.
  assertEquals(resolveOrigin('https://A.test', allow), null)
})
