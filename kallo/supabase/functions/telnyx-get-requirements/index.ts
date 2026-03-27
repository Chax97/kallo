import { createClient } from "jsr:@supabase/supabase-js@2"

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
)

const TELNYX_API_KEY  = Deno.env.get("TELNYX_API_KEY")
const TELNYX_API_BASE = "https://api.telnyx.com/v2"

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders })

  try {
    if (!TELNYX_API_KEY) throw new Error("TELNYX_API_KEY not set")

    const { country_code, phone_number_type, action = "ordering" } = await req.json()
    if (!country_code)      throw new Error("country_code is required")
    if (!phone_number_type) throw new Error("phone_number_type is required")

    // Check cache first
    const { data: cached } = await supabase
      .from("telnyx_requirements_cache")
      .select("requirements_types, expires_at")
      .eq("country_code", country_code)
      .eq("phone_number_type", phone_number_type)
      .eq("action", action)
      .single()

    if (cached && new Date(cached.expires_at) > new Date()) {
      console.log(`[telnyx-get-requirements] cache hit: ${country_code}/${phone_number_type}/${action}`)
      return new Response(
        JSON.stringify({ data: cached.requirements_types, source: "cache" }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } },
      )
    }

    // Cache miss — fetch from Telnyx
    const params = new URLSearchParams({
      "filter[country_code]":      country_code,
      "filter[phone_number_type]": phone_number_type,
      "filter[action]":            action,
    })

    console.log(`[telnyx-get-requirements] fetching from Telnyx: ${country_code}/${phone_number_type}/${action}`)

    const res  = await fetch(`${TELNYX_API_BASE}/requirements?${params}`, {
      headers: {
        Authorization:  `Bearer ${TELNYX_API_KEY}`,
        "Content-Type": "application/json",
      },
    })

    const json   = await res.json()
    if (!res.ok) throw new Error(`Telnyx API error ${res.status}: ${JSON.stringify(json)}`)

    const record = json.data?.[0] ?? null

    const row = {
      country_code,
      phone_number_type,
      action,
      requirement_id:    record?.id ?? "none",
      requirements_types: record?.requirement_types ?? [],
      raw_response:       record ?? {},
      fetched_at:         new Date().toISOString(),
      expires_at:         new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString(),
    }

    await supabase
      .from("telnyx_requirements_cache")
      .upsert(row, { onConflict: "country_code,phone_number_type,action" })

    console.log(`[telnyx-get-requirements] cached ${row.requirements_types.length} requirement types`)

    return new Response(
      JSON.stringify({ data: row.requirements_types, source: "telnyx" }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } },
    )
  } catch (e) {
    const message = e instanceof Error ? e.message : String(e)
    console.error("[telnyx-get-requirements] error:", message)
    return new Response(
      JSON.stringify({ error: message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    )
  }
})
