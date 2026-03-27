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

    const { phone_number, company_id, label, regulatory_requirements } = await req.json()
    if (!phone_number) throw new Error("phone_number is required")
    if (!company_id)   throw new Error("company_id is required")

    // Fetch company's telnyx_connection_id
    const { data: company, error: companyError } = await supabase
      .from("companies")
      .select("telnyx_connection_id")
      .eq("id", company_id)
      .single()

    if (companyError) throw new Error(`Failed to fetch company: ${companyError.message}`)

    // Place order with Telnyx
    const orderBody: Record<string, unknown> = {
      phone_numbers: [{ phone_number }],
    }
    if (company?.telnyx_connection_id) {
      orderBody.connection_id = company.telnyx_connection_id
    }
    if (Array.isArray(regulatory_requirements) && regulatory_requirements.length > 0) {
      orderBody.regulatory_requirements = regulatory_requirements
    }

    console.log(`[telnyx-buy-number] ordering ${phone_number} for company ${company_id}`)

    const res = await fetch(`${TELNYX_API_BASE}/number_orders`, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${TELNYX_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(orderBody),
    })

    const json = await res.json()
    console.log(`[telnyx-buy-number] response ${res.status}:`, JSON.stringify(json))

    if (!res.ok) throw new Error(`Telnyx API error ${res.status}: ${JSON.stringify(json)}`)

    const orderedNumber = json.data?.phone_numbers?.[0]
    if (!orderedNumber) throw new Error("No phone number in order response")

    // Insert into phone_numbers table
    const { data: inserted, error: insertError } = await supabase
      .from("phone_numbers")
      .insert({
        company_id,
        number: phone_number,
        telnyx_number_id: orderedNumber.id ?? null,
        label: label ?? null,
        status: orderedNumber.status ?? 'purchase_pending',
      })
      .select()
      .single()

    if (insertError) throw new Error(`Failed to save phone number: ${insertError.message}`)

    console.log(`[telnyx-buy-number] saved to DB:`, inserted.id)

    return new Response(JSON.stringify({ success: true, data: inserted }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    })
  } catch (e) {
    const message = e instanceof Error ? e.message : String(e)
    console.error("[telnyx-buy-number] error:", message)
    return new Response(JSON.stringify({ error: message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    })
  }
})
