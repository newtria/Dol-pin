// Supabase Edge Function for server-side Gemini VLM analysis
// Deploy with: supabase functions deploy gemini-analyze
// Set secret: supabase secrets set GEMINI_API_KEY=<your-key>

const GEMINI_API_KEY = Deno.env.get('GEMINI_API_KEY')!

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface AnalyzeRequest {
  image: string       // base64-encoded image data
  mimeType: string    // e.g. "image/jpeg"
  prompt: string      // the analysis prompt
}

Deno.serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    if (req.method !== 'POST') {
      return new Response(
        JSON.stringify({ error: 'Method not allowed' }),
        { status: 405, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      )
    }

    const { image, mimeType, prompt } = (await req.json()) as AnalyzeRequest

    if (!image || !prompt) {
      return new Response(
        JSON.stringify({ error: 'Missing required fields: image, prompt' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      )
    }

    // Call Gemini API
    const geminiUrl =
      `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=${GEMINI_API_KEY}`

    const geminiResponse = await fetch(geminiUrl, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
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
      console.error('Gemini API error:', geminiResponse.status, errorBody)
      return new Response(
        JSON.stringify({ error: 'Gemini API request failed', status: geminiResponse.status }),
        { status: 502, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      )
    }

    const geminiData = await geminiResponse.json()
    const text =
      geminiData?.candidates?.[0]?.content?.parts?.[0]?.text?.trim() ?? ''

    return new Response(
      JSON.stringify({ result: text }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    )
  } catch (error) {
    console.error('Edge function error:', error)
    return new Response(
      JSON.stringify({ error: 'Internal server error' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    )
  }
})
