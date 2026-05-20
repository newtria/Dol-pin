// Shared PortOne (Iamport) REST client for the verify-payment and
// refund-payment functions.
//
// Holds the imp_key/imp_secret in module scope — never expose either to
// callers. The access token is cached per-worker; warm invocations skip
// the /users/getToken hop. Sharing this module across both functions
// halves the cache-miss rate on cold workers compared to per-function
// copies.

const PORTONE_API = 'https://api.iamport.kr'
const PORTONE_TIMEOUT_MS = 15_000

const PORTONE_IMP_KEY = Deno.env.get('PORTONE_IMP_KEY')!
const PORTONE_IMP_SECRET = Deno.env.get('PORTONE_IMP_SECRET')!

export interface PortOnePayment {
  imp_uid: string
  merchant_uid: string
  amount: number
  cancel_amount?: number
  status: string // 'ready' | 'paid' | 'failed' | 'cancelled'
  currency?: string
  pg_provider?: string
  pay_method?: string
}

export type AppPaymentStatus = 'success' | 'pending' | 'failed'

let cachedToken: { value: string; expiresAt: number } | null = null

async function getAccessToken(): Promise<string> {
  const now = Date.now()
  if (cachedToken && cachedToken.expiresAt - 60_000 > now) {
    return cachedToken.value
  }

  const ctrl = new AbortController()
  const timer = setTimeout(() => ctrl.abort(), PORTONE_TIMEOUT_MS)
  try {
    const res = await fetch(`${PORTONE_API}/users/getToken`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        imp_key: PORTONE_IMP_KEY,
        imp_secret: PORTONE_IMP_SECRET,
      }),
      signal: ctrl.signal,
    })
    if (!res.ok) throw new Error(`PortOne token HTTP ${res.status}`)
    const data = await res.json()
    if (data.code !== 0) {
      throw new Error(`PortOne token: ${data.message ?? 'unknown'}`)
    }
    const token = data.response.access_token as string
    // PortOne returns `expired_at` as unix seconds.
    const expiresAt = Number(data.response.expired_at) * 1000
    cachedToken = { value: token, expiresAt }
    return token
  } finally {
    clearTimeout(timer)
  }
}

export async function getPayment(impUid: string): Promise<PortOnePayment> {
  const token = await getAccessToken()
  const ctrl = new AbortController()
  const timer = setTimeout(() => ctrl.abort(), PORTONE_TIMEOUT_MS)
  try {
    const res = await fetch(
      `${PORTONE_API}/payments/${encodeURIComponent(impUid)}`,
      {
        method: 'GET',
        headers: { Authorization: token },
        signal: ctrl.signal,
      },
    )
    if (!res.ok) throw new Error(`PortOne payment HTTP ${res.status}`)
    const data = await res.json()
    if (data.code !== 0) {
      throw new Error(`PortOne payment: ${data.message ?? 'unknown'}`)
    }
    return data.response as PortOnePayment
  } finally {
    clearTimeout(timer)
  }
}

export async function cancelPayment(params: {
  imp_uid: string
  amount?: number
  reason: string
}): Promise<PortOnePayment> {
  const token = await getAccessToken()
  const ctrl = new AbortController()
  const timer = setTimeout(() => ctrl.abort(), PORTONE_TIMEOUT_MS)
  try {
    const res = await fetch(`${PORTONE_API}/payments/cancel`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: token },
      body: JSON.stringify(params),
      signal: ctrl.signal,
    })
    if (!res.ok) throw new Error(`PortOne cancel HTTP ${res.status}`)
    const data = await res.json()
    if (data.code !== 0) {
      throw new Error(`PortOne cancel: ${data.message ?? 'unknown'}`)
    }
    return data.response as PortOnePayment
  } finally {
    clearTimeout(timer)
  }
}

/// Parses our `dolpin_<uuid>_<epoch>` merchant_uid format
/// (generated client-side in `lib/data/datasources/payment_service.dart`)
/// back into the reservation id. Returns null if the input is malformed.
export function extractReservationId(merchantUid: string): string | null {
  if (!merchantUid.startsWith('dolpin_')) return null
  const parts = merchantUid.split('_')
  if (parts.length !== 3) return null
  return parts[1]
}

/// Maps PortOne's status vocabulary to the Flutter app's PaymentStatus enum.
export function normalizeStatus(portOneStatus: string): AppPaymentStatus {
  switch (portOneStatus) {
    case 'paid':
      return 'success'
    case 'ready':
      return 'pending'
    default:
      return 'failed'
  }
}
