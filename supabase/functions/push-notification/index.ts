// Supabase Edge Function for sending push notifications via FCM HTTP v1.
// Deploy with: supabase functions deploy push-notification
//
// Required secrets (set via `supabase secrets set`):
//   SUPABASE_URL                — already provided by the platform
//   SUPABASE_SERVICE_ROLE_KEY  — already provided
//   FCM_SERVICE_ACCOUNT_JSON   — full Google service account JSON, base64 or raw
//   FCM_PROJECT_ID             — Firebase project id (e.g. "dolpin-123abc")
//
// The legacy FCM HTTP API (`fcm.googleapis.com/fcm/send` + `key=...`) was shut
// down on 2024-07-22; this function uses HTTP v1 with an OAuth2 access token
// derived from the service account JSON.
//
// Authorization model:
//   * Caller must present a valid Supabase JWT (`Authorization: Bearer …`).
//   * The auth.uid() resolved from that JWT must be a participant of the
//     reservation that the notification is *about*. The caller cannot push to
//     an arbitrary user — they can only push to the counter-party of one of
//     their own reservations. This is the only legitimate use case in the
//     app and matches the chat-room access pattern.

import { createClient } from '@supabase/supabase-js'
import { create, getNumericDate } from 'djwt'
import { requireUser } from '../_shared/auth.ts'
import { jsonResponse, preflightResponse } from '../_shared/cors.ts'

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
const FCM_PROJECT_ID = Deno.env.get('FCM_PROJECT_ID')!
const FCM_SERVICE_ACCOUNT_JSON = Deno.env.get('FCM_SERVICE_ACCOUNT_JSON')!

interface PushPayload {
  reservationId: string
  receiverId: string
  title: string
  body: string
  data?: Record<string, string>
}

interface ServiceAccount {
  client_email: string
  private_key: string
  token_uri: string
}

// ---------------------------------------------------------------------------
// OAuth2 access token (cached in module scope while the worker is warm)
// ---------------------------------------------------------------------------

let cachedToken: { value: string; expiresAt: number } | null = null

function decodeServiceAccount(): ServiceAccount {
  // Allow either raw JSON or base64-wrapped JSON in the secret.
  const raw = FCM_SERVICE_ACCOUNT_JSON.trim()
  const json = raw.startsWith('{') ? raw : new TextDecoder().decode(
    Uint8Array.from(atob(raw), (c) => c.charCodeAt(0)),
  )
  return JSON.parse(json) as ServiceAccount
}

async function importPrivateKey(pem: string): Promise<CryptoKey> {
  const cleaned = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, '')
    .replace(/-----END PRIVATE KEY-----/, '')
    .replace(/\s+/g, '')
  const der = Uint8Array.from(atob(cleaned), (c) => c.charCodeAt(0))
  return crypto.subtle.importKey(
    'pkcs8',
    der,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  )
}

async function getAccessToken(): Promise<string> {
  const now = Date.now()
  if (cachedToken && cachedToken.expiresAt - 60_000 > now) {
    return cachedToken.value
  }

  const sa = decodeServiceAccount()
  const key = await importPrivateKey(sa.private_key)

  const jwt = await create(
    { alg: 'RS256', typ: 'JWT' },
    {
      iss: sa.client_email,
      scope: 'https://www.googleapis.com/auth/firebase.messaging',
      aud: sa.token_uri,
      iat: getNumericDate(0),
      exp: getNumericDate(60 * 60),
    },
    key,
  )

  const res = await fetch(sa.token_uri, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt,
    }),
  })

  if (!res.ok) {
    throw new Error(`token exchange failed: ${res.status}`)
  }

  const body = (await res.json()) as { access_token: string; expires_in: number }
  cachedToken = {
    value: body.access_token,
    expiresAt: Date.now() + body.expires_in * 1000,
  }
  return body.access_token
}

// ---------------------------------------------------------------------------
// Request handler
// ---------------------------------------------------------------------------

// Service-role client at module scope — Edge Function workers stay warm
// across requests, so we avoid reconstructing the client per call.
const adminClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return preflightResponse(req)
  const json = (status: number, body: unknown) => jsonResponse(req, status, body)

  try {
    if (req.method !== 'POST') {
      return json(405, { error: 'Method not allowed' })
    }

    const auth = await requireUser(req)
    if (!auth.ok) return json(auth.status, { error: auth.error })
    const callerId = auth.userId

    let rawBody: unknown
    try {
      rawBody = await req.json()
    } catch {
      return json(400, { error: 'Invalid JSON body' })
    }
    if (!rawBody || typeof rawBody !== 'object' || Array.isArray(rawBody)) {
      return json(400, { error: 'Body must be a JSON object' })
    }
    const payload = rawBody as PushPayload

    if (!payload.reservationId || !payload.receiverId || !payload.title || !payload.body) {
      return json(400, { error: 'Missing required fields' })
    }

    // Authorize: caller must be a participant of the reservation, and the
    // declared receiver must be the *other* participant of the same reservation.
    const { data: reservation, error: resError } = await adminClient
      .from('reservations')
      .select('id, lender_id, borrower_id')
      .eq('id', payload.reservationId)
      .single()

    if (resError || !reservation) {
      return json(404, { error: 'Reservation not found' })
    }

    const isCallerParticipant =
      reservation.lender_id === callerId || reservation.borrower_id === callerId
    if (!isCallerParticipant) {
      return json(403, { error: 'Not a participant of this reservation' })
    }

    const expectedReceiver =
      reservation.lender_id === callerId ? reservation.borrower_id : reservation.lender_id
    if (expectedReceiver !== payload.receiverId) {
      return json(403, { error: 'receiverId does not match the reservation counter-party' })
    }

    const { data: receiverRow } = await adminClient
      .from('users')
      .select('fcm_token')
      .eq('id', payload.receiverId)
      .single()

    if (!receiverRow?.fcm_token) {
      return json(404, { error: 'Receiver has no FCM token registered' })
    }

    const accessToken = await getAccessToken()
    const fcmRes = await fetch(
      `https://fcm.googleapis.com/v1/projects/${FCM_PROJECT_ID}/messages:send`,
      {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${accessToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          message: {
            token: receiverRow.fcm_token,
            notification: { title: payload.title, body: payload.body },
            data: payload.data ?? {},
          },
        }),
      },
    )

    if (!fcmRes.ok) {
      const text = await fcmRes.text()
      console.error('FCM send failed', fcmRes.status, text)
      return json(502, { error: 'FCM send failed', status: fcmRes.status })
    }

    const result = await fcmRes.json()
    return json(200, result)
  } catch (error) {
    console.error('push-notification handler error', error)
    return json(500, { error: 'Internal server error' })
  }
})
