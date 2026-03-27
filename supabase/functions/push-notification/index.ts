// Supabase Edge Function for sending push notifications
// Deploy with: supabase functions deploy push-notification

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SUPABASE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
const FCM_SERVER_KEY = Deno.env.get('FCM_SERVER_KEY')!

interface PushPayload {
  userId: string
  title: string
  body: string
  data?: Record<string, string>
}

Deno.serve(async (req) => {
  const payload: PushPayload = await req.json()

  const supabase = createClient(SUPABASE_URL, SUPABASE_KEY)

  // Get user's FCM token
  const { data: user } = await supabase
    .from('users')
    .select('fcm_token')
    .eq('id', payload.userId)
    .single()

  if (!user?.fcm_token) {
    return new Response(JSON.stringify({ error: 'No FCM token' }), { status: 404 })
  }

  // Send FCM push
  const fcmResponse = await fetch('https://fcm.googleapis.com/fcm/send', {
    method: 'POST',
    headers: {
      'Authorization': `key=${FCM_SERVER_KEY}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      to: user.fcm_token,
      notification: {
        title: payload.title,
        body: payload.body,
      },
      data: payload.data ?? {},
    }),
  })

  const result = await fcmResponse.json()
  return new Response(JSON.stringify(result), { status: 200 })
})
