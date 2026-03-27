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

    const { file_base64, file_name, customer_reference } = await req.json()
    if (!file_base64) throw new Error("file_base64 is required")
    if (!file_name)   throw new Error("file_name is required")

    // Decode base64 → binary
    const binaryStr = atob(file_base64)
    const bytes     = new Uint8Array(binaryStr.length)
    for (let i = 0; i < binaryStr.length; i++) bytes[i] = binaryStr.charCodeAt(i)

    const blob     = new Blob([bytes], { type: "application/pdf" })
    const formData = new FormData()
    formData.append("file", blob, file_name)
    if (customer_reference) formData.append("customer_reference", customer_reference)

    console.log(`[telnyx-upload-document] uploading ${file_name} (${bytes.length} bytes)`)

    const res  = await fetch(`${TELNYX_API_BASE}/documents`, {
      method:  "POST",
      headers: { Authorization: `Bearer ${TELNYX_API_KEY}` },
      body:    formData,
    })

    const json = await res.json()
    console.log(`[telnyx-upload-document] response ${res.status}:`, JSON.stringify(json))

    if (!res.ok) throw new Error(`Telnyx API error ${res.status}: ${JSON.stringify(json)}`)

    const documentId = json.data?.id
    if (!documentId) throw new Error("No document ID in response")

    return new Response(
      JSON.stringify({ document_id: documentId }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } },
    )
  } catch (e) {
    const message = e instanceof Error ? e.message : String(e)
    console.error("[telnyx-upload-document] error:", message)
    return new Response(
      JSON.stringify({ error: message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    )
  }
})
