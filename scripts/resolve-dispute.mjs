#!/usr/bin/env node
import { existsSync, readFileSync } from 'node:fs'
import { dirname, join, resolve } from 'node:path'
import { randomUUID } from 'node:crypto'
import { fileURLToPath } from 'node:url'

const scriptDir = dirname(fileURLToPath(import.meta.url))
const repoRoot = resolve(scriptDir, '..')

function parseEnvFile(path) {
  const fullPath = join(repoRoot, path)
  if (!existsSync(fullPath)) return {}
  const parsed = {}
  for (const rawLine of readFileSync(fullPath, 'utf8').split(/\r?\n/)) {
    const line = rawLine.trim()
    if (!line || line.startsWith('#')) continue
    const eq = line.indexOf('=')
    if (eq <= 0) continue
    const key = line.slice(0, eq).trim()
    let value = line.slice(eq + 1).trim()
    if (
      (value.startsWith('"') && value.endsWith('"')) ||
      (value.startsWith("'") && value.endsWith("'"))
    ) {
      value = value.slice(1, -1)
    }
    parsed[key] = value
  }
  return parsed
}

function parseArgs(argv) {
  const values = {}
  const booleans = new Set()
  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i]
    if (!arg.startsWith('--')) {
      throw new Error(`Unexpected argument: ${arg}`)
    }
    const [rawKey, rawValue] = arg.slice(2).split('=', 2)
    const key = rawKey.replace(/-([a-z])/g, (_, c) => c.toUpperCase())
    if (rawValue !== undefined) {
      values[key] = rawValue
    } else if (i + 1 < argv.length && !argv[i + 1].startsWith('--')) {
      values[key] = argv[i + 1]
      i += 1
    } else {
      booleans.add(key)
    }
  }
  return { values, booleans }
}

function usage() {
  console.log(`Usage:
  node scripts/resolve-dispute.mjs \\
    --reservation-id <uuid> \\
    --refund-amount <integer-krw> \\
    --reason <text> \\
    --idempotency-key <stable-key> \\
    [--confirm]

By default this is a dry run. Add --confirm to call the Edge Function.
Required env: SUPABASE_URL, DOLPIN_ADMIN_ACTION_KEY`)
}

function fail(message) {
  console.error(`resolve-dispute: ${message}`)
  process.exit(1)
}

const { values, booleans } = parseArgs(process.argv.slice(2))
if (booleans.has('help')) {
  usage()
  process.exit(0)
}

const env = {
  ...parseEnvFile('.env'),
  ...process.env,
}

const reservationId = values.reservationId
const refundAmount = Number(values.refundAmount)
const reason = values.reason
const idempotencyKey = values.idempotencyKey
const confirm = booleans.has('confirm')
const dryRun = booleans.has('dryRun') || !confirm

if (!reservationId) fail('missing --reservation-id')
if (!Number.isInteger(refundAmount) || refundAmount < 0) {
  fail('--refund-amount must be a non-negative integer')
}
if (!reason || reason.trim().length === 0) fail('missing --reason')
if (confirm && !idempotencyKey) {
  fail('real calls require --idempotency-key for provider-safe retries')
}
if (!env.SUPABASE_URL) fail('missing SUPABASE_URL')
if (confirm && !env.DOLPIN_ADMIN_ACTION_KEY) {
  fail('missing DOLPIN_ADMIN_ACTION_KEY')
}

const endpoint = `${env.SUPABASE_URL.replace(/\/$/, '')}/functions/v1/resolve-dispute`
const body = {
  reservation_id: reservationId,
  refund_amount: refundAmount,
  reason: reason.trim(),
  idempotency_key: idempotencyKey ?? `dry_run_${randomUUID()}`,
}

if (dryRun) {
  console.log(
    JSON.stringify(
      {
        dry_run: true,
        method: 'POST',
        endpoint,
        headers: ['content-type', 'x-dolpin-admin-key'],
        body,
        next: 'add --confirm with an explicit --idempotency-key to execute',
      },
      null,
      2,
    ),
  )
  process.exit(0)
}

const response = await fetch(endpoint, {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'x-dolpin-admin-key': env.DOLPIN_ADMIN_ACTION_KEY,
  },
  body: JSON.stringify(body),
})

const text = await response.text()
let parsed
try {
  parsed = JSON.parse(text)
} catch {
  parsed = { raw: text }
}

console.log(
  JSON.stringify(
    {
      ok: response.ok,
      status: response.status,
      body: parsed,
    },
    null,
    2,
  ),
)

if (!response.ok) {
  process.exit(1)
}
