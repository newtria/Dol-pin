#!/usr/bin/env node
import { execFileSync } from 'node:child_process'
import { existsSync, readFileSync } from 'node:fs'
import { dirname, join, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

const scriptDir = dirname(fileURLToPath(import.meta.url))
const repoRoot = resolve(scriptDir, '..')
const args = new Set(process.argv.slice(2))
const structureOnly = args.has('--structure-only')

const failures = []
const warnings = []

function readRepo(path) {
  return readFileSync(join(repoRoot, path), 'utf8')
}

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

function hasCommand(name) {
  try {
    execFileSync('command', ['-v', name], {
      shell: true,
      stdio: 'ignore',
    })
    return true
  } catch {
    return false
  }
}

function runCommand(label, command, args) {
  try {
    execFileSync(command, args, {
      cwd: repoRoot,
      stdio: 'pipe',
    })
  } catch {
    failures.push(`${label} failed`)
  }
}

function checkFile(path) {
  if (!existsSync(join(repoRoot, path))) {
    failures.push(`missing file: ${path}`)
  }
}

function checkContains(path, needle, label = needle) {
  if (!existsSync(join(repoRoot, path))) {
    failures.push(`missing file: ${path}`)
    return
  }
  const text = readRepo(path)
  if (!text.includes(needle)) {
    failures.push(`${path} is missing ${label}`)
  }
}

function isPlaceholder(key, value) {
  const normalized = String(value ?? '').trim()
  if (!normalized) return true
  const badFragments = [
    'your-',
    'placeholder',
    'changeme',
    'imp00000000',
    'example.com',
  ]
  if (badFragments.some((fragment) => normalized.includes(fragment))) {
    return true
  }
  if (key === 'DOLPIN_ADMIN_ACTION_KEY' && normalized.length < 32) {
    return true
  }
  return false
}

const env = {
  ...parseEnvFile('.env'),
  ...process.env,
}

const requiredAppEnv = [
  'SUPABASE_URL',
  'SUPABASE_ANON_KEY',
  'PORTONE_IMP_CODE',
  'SENTRY_DSN',
]
const requiredEdgeEnv = [
  'SUPABASE_SERVICE_ROLE_KEY',
  'PORTONE_IMP_KEY',
  'PORTONE_IMP_SECRET',
  'DOLPIN_ADMIN_ACTION_KEY',
  'GEMINI_API_KEY',
  'FCM_PROJECT_ID',
  'FCM_SERVICE_ACCOUNT_JSON',
]

const edgeFunctionFiles = [
  'supabase/functions/gemini-analyze/index.ts',
  'supabase/functions/push-notification/index.ts',
  'supabase/functions/verify-payment/index.ts',
  'supabase/functions/refund-payment/index.ts',
  'supabase/functions/settle-reservation/index.ts',
  'supabase/functions/resolve-dispute/index.ts',
]

const requiredFiles = [
  '.env.example',
  'supabase/config.toml',
  'supabase/migrations/017_reservation_state_machine.sql',
  'supabase/functions/_shared/reservation-actions.ts',
  'scripts/resolve-dispute.mjs',
  ...edgeFunctionFiles,
]

for (const file of requiredFiles) {
  checkFile(file)
}

for (const key of [...requiredAppEnv, ...requiredEdgeEnv]) {
  checkContains('.env.example', `${key}=`, `${key} placeholder`)
}

checkContains(
  'supabase/migrations/017_reservation_state_machine.sql',
  'reservation_dispute_resolutions',
)
checkContains(
  'supabase/migrations/017_reservation_state_machine.sql',
  'dispute_pending',
)
checkContains('supabase/config.toml', '[functions.resolve-dispute]')
checkContains('supabase/config.toml', 'verify_jwt = false')
checkContains(
  'supabase/functions/resolve-dispute/index.ts',
  'DOLPIN_ADMIN_ACTION_KEY',
)
checkContains(
  'supabase/functions/resolve-dispute/index.ts',
  'beginReservationPaymentAction',
)
checkContains(
  'supabase/functions/resolve-dispute/index.ts',
  'action: "dispute_pending"',
)
checkContains(
  'supabase/functions/_shared/reservation-actions.ts',
  '"begin_reservation_payment_action"',
)
checkContains(
  'supabase/functions/_shared/reservation-actions.ts',
  '"clear_reservation_payment_action"',
)
checkContains(
  'supabase/functions/resolve-dispute/index.ts',
  'retried_transition',
)
checkContains(
  'supabase/functions/refund-payment/index.ts',
  'Retry will reconcile provider state before another cancel.',
)
checkContains(
  'supabase/functions/settle-reservation/index.ts',
  'Retry will reconcile provider state before another cancel.',
)
checkContains(
  'supabase/functions/resolve-dispute/index.ts',
  'Retry will reconcile provider state before another cancel.',
)

runCommand('node syntax check for release-preflight', process.execPath, [
  '--check',
  join(repoRoot, 'scripts/release-preflight.mjs'),
])
runCommand('node syntax check for resolve-dispute CLI', process.execPath, [
  '--check',
  join(repoRoot, 'scripts/resolve-dispute.mjs'),
])

if (!structureOnly) {
  for (const key of requiredAppEnv) {
    if (isPlaceholder(key, env[key])) {
      failures.push(`missing release app env: ${key}`)
    }
  }
  for (const key of requiredEdgeEnv) {
    if (isPlaceholder(key, env[key])) {
      failures.push(`missing release edge secret: ${key}`)
    }
  }

  for (const command of ['mise', 'supabase', 'deno']) {
    if (!hasCommand(command)) {
      failures.push(`missing required release CLI: ${command}`)
    }
  }

  if (hasCommand('deno')) {
    for (const fn of edgeFunctionFiles) {
      runCommand(`deno check ${fn}`, 'deno', ['check', fn])
    }
  }

  if (hasCommand('xcrun')) {
    try {
      const devices = execFileSync('xcrun', ['simctl', 'list', 'devices'], {
        encoding: 'utf8',
      })
      if (devices.includes('Booted')) {
        failures.push('iOS Simulator cleanup failed: Booted simulator remains')
      }
    } catch {
      warnings.push('could not inspect iOS Simulator state with xcrun')
    }
  } else {
    warnings.push('xcrun is unavailable; skipping simulator cleanup check')
  }
} else {
  warnings.push('structure-only mode skipped env, CLI, and simulator checks')
}

for (const warning of warnings) {
  console.warn(`[warn] ${warning}`)
}

if (failures.length > 0) {
  console.error('release preflight: failed')
  for (const failure of failures) {
    console.error(`- ${failure}`)
  }
  process.exit(1)
}

console.log('release preflight: ok')
