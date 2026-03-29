import { createClient } from "jsr:@supabase/supabase-js@2"

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
)

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

    const { company_id } = await req.json()
    if (!company_id) throw new Error("company_id is required")

    // Fetch all phone numbers from Telnyx
    const res = await fetch(`${TELNYX_API_BASE}/phone_numbers?page[size]=100`, {
      headers: {
        Authorization: `Bearer ${TELNYX_API_KEY}`,
        "Content-Type": "application/json",
      },
    })

    const json = await res.json()
    console.log(`[telnyx-sync-numbers] response ${res.status}: total=${json?.meta?.total_results}`)

    if (!res.ok) throw new Error(`Telnyx API error ${res.status}: ${JSON.stringify(json)}`)

    const numbers = (json.data ?? []) as Array<Record<string, unknown>>

    if (numbers.length === 0) {
      return new Response(JSON.stringify({ synced: 0 }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      })
    }

    // Fetch numbers already in DB for this company to avoid duplicates
    const { data: existing, error: fetchError } = await supabase
      .from("phone_numbers")
      .select("number")
      .eq("company_id", company_id)

    if (fetchError) throw new Error(`DB fetch failed: ${fetchError.message}`)

    const existingSet = new Set((existing ?? []).map((r: { number: string }) => r.number))

    const rows = numbers
      .map((n) => ({
        company_id,
        number:            n.phone_number as string,
        telnyx_number_id:  n.id as string ?? null,
        label:             (n.tags as string[] | undefined)?.[0] ?? null,
        status:            n.status as string ?? null,
      }))
      .filter((r) => !existingSet.has(r.number))

    if (rows.length === 0) {
      console.log(`[telnyx-sync-numbers] all numbers already in DB for company ${company_id}`)
      return new Response(JSON.stringify({ synced: 0 }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      })
    }

    const { error: insertError } = await supabase
      .from("phone_numbers")
      .insert(rows)

    if (insertError) throw new Error(`DB insert failed: ${insertError.message}`)

    console.log(`[telnyx-sync-numbers] synced ${rows.length} numbers for company ${company_id}`)

    return new Response(JSON.stringify({ synced: rows.length }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    })
  } catch (e) {
    const message = e instanceof Error ? e.message : String(e)
    console.error("[telnyx-sync-numbers] error:", message)
    return new Response(JSON.stringify({ error: message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    })
  }
})
