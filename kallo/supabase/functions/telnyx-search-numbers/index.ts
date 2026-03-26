const TELNYX_API_KEY = Deno.env.get("TELNYX_API_KEY")
const TELNYX_API_BASE = "https://api.telnyx.com/v2"

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders })

  try {
    if (!TELNYX_API_KEY) throw new Error("TELNYX_API_KEY not set")

    const body = await req.json()

    const {
      country_code,
      features,
      phone_number_type,
      national_destination_code,
      locality,
      phone_number_starts_with,
      phone_number_ends_with,
      phone_number_contains,
      limit = 20,
    } = body

    if (!country_code) throw new Error("country_code is required")

    const params = new URLSearchParams()
    params.set("filter[country_code]", country_code)

    if (Array.isArray(features) && features.length > 0) {
      for (const f of features) params.append("filter[features][]", f)
    }
    if (phone_number_type) params.set("filter[phone_number_type]", phone_number_type)
    if (national_destination_code) params.set("filter[national_destination_code]", String(national_destination_code))
    if (locality) params.set("filter[locality]", String(locality))
    if (phone_number_starts_with) params.set("filter[phone_number][starts_with]", String(phone_number_starts_with))
    if (phone_number_ends_with)   params.set("filter[phone_number][ends_with]",   String(phone_number_ends_with))
    if (phone_number_contains)    params.set("filter[phone_number][contains]",    String(phone_number_contains))
    params.set("filter[limit]", String(Math.min(Number(limit) || 20, 100)))

    const url = `${TELNYX_API_BASE}/available_phone_numbers?${params.toString()}`
    console.log(`[telnyx-search-numbers] GET ${url}`)

    const res = await fetch(url, {
      headers: {
        Authorization: `Bearer ${TELNYX_API_KEY}`,
        "Content-Type": "application/json",
      },
    })

    const json = await res.json()
    console.log(`[telnyx-search-numbers] response ${res.status}: total=${json?.meta?.total_results}`)
    if (json?.data?.[0]) {
      console.log(`[telnyx-search-numbers] sample region_information:`, JSON.stringify(json.data[0].region_information))
    }

    if (!res.ok) throw new Error(`Telnyx API error ${res.status}: ${JSON.stringify(json)}`)

    return new Response(JSON.stringify(json), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    })
  } catch (e) {
    const message = e instanceof Error ? e.message : String(e)
    console.error("[telnyx-search-numbers] error:", message)
    return new Response(JSON.stringify({ error: message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    })
  }
})
