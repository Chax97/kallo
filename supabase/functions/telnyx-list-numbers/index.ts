const TELNYX_API_KEY = Deno.env.get("TELNYX_API_KEY")
const TELNYX_API_BASE = "https://api.telnyx.com/v2"

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }

  try {
    if (!TELNYX_API_KEY) throw new Error("TELNYX_API_KEY env var is not set")

    const url = `${TELNYX_API_BASE}/phone_numbers`
    console.log(`[telnyx-list-numbers] GET ${url}`)

    const res = await fetch(url, {
      method: "GET",
      headers: {
        Authorization: `Bearer ${TELNYX_API_KEY}`,
        "Content-Type": "application/json",
      },
    })

    const json = await res.json()
    console.log(`[telnyx-list-numbers] response ${res.status}:`, JSON.stringify(json))

    if (!res.ok) {
      throw new Error(`Telnyx API error ${res.status}: ${JSON.stringify(json)}`)
    }

    return new Response(JSON.stringify(json), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    })
  } catch (e) {
    const message = e instanceof Error ? e.message : String(e)
    console.error("[telnyx-list-numbers] error:", message)
    return new Response(JSON.stringify({ error: message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    })
  }
})
