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

    const { kyc_document_id } = await req.json()
    if (!kyc_document_id) throw new Error("kyc_document_id is required")

    // 1. Fetch the DB row
    const { data: doc, error: docError } = await supabase
      .from("company_kyc_documents")
      .select("id, storage_path, telnyx_document_id, status, requirement_name")
      .eq("id", kyc_document_id)
      .single()

    if (docError || !doc) throw new Error(`Document not found: ${docError?.message}`)

    // Idempotent — already pushed successfully, just return the existing ID
    if (doc.telnyx_document_id) {
      console.log(`[telnyx-push-kyc-document] already submitted: ${doc.telnyx_document_id}`)
      return new Response(
        JSON.stringify({ telnyx_document_id: doc.telnyx_document_id }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } },
      )
    }

    if (!doc.storage_path) throw new Error("Document has no storage_path")

    // 2. Download from Supabase Storage (service role has full access to private buckets)
    console.log(`[telnyx-push-kyc-document] downloading from storage: ${doc.storage_path}`)

    const { data: fileData, error: storageError } = await supabase.storage
      .from("kyc-documents")
      .download(doc.storage_path)

    if (storageError || !fileData) {
      throw new Error(`Storage download failed: ${storageError?.message ?? "unknown"}`)
    }

    // 3. Push to Telnyx
    const fileName    = doc.storage_path.split("/").pop() ?? "document.pdf"
    const formData    = new FormData()
    formData.append("file", fileData, fileName)
    formData.append("customer_reference", doc.requirement_name ?? "kyc-document")

    console.log(`[telnyx-push-kyc-document] pushing ${fileName} to Telnyx`)

    const res  = await fetch(`${TELNYX_API_BASE}/documents`, {
      method:  "POST",
      headers: { Authorization: `Bearer ${TELNYX_API_KEY}` },
      body:    formData,
    })

    const json = await res.json()
    console.log(`[telnyx-push-kyc-document] Telnyx response ${res.status}`)

    if (!res.ok) throw new Error(`Telnyx error ${res.status}: ${JSON.stringify(json)}`)

    const telnyxDocumentId = json.data?.id
    if (!telnyxDocumentId) throw new Error("No document ID in Telnyx response")

    // 4. Update the DB row — status = submitted
    await supabase
      .from("company_kyc_documents")
      .update({ telnyx_document_id: telnyxDocumentId, status: "submitted" })
      .eq("id", kyc_document_id)

    console.log(`[telnyx-push-kyc-document] updated row ${kyc_document_id} with telnyx_document_id ${telnyxDocumentId}`)

    return new Response(
      JSON.stringify({ telnyx_document_id: telnyxDocumentId }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } },
    )
  } catch (e) {
    const message = e instanceof Error ? e.message : String(e)
    console.error("[telnyx-push-kyc-document] error:", message)
    // Mark as failed if we have the ID (allows operator to see what needs retry)
    try {
      const body = await new Request(req.url, { body: req.body }).json().catch(() => null)
      if (body?.kyc_document_id) {
        await supabase
          .from("company_kyc_documents")
          .update({ status: "failed" })
          .eq("id", body.kyc_document_id)
          .eq("status", "stored") // only update if still in 'stored' state
      }
    } catch { /* ignore secondary failure */ }
    return new Response(
      JSON.stringify({ error: message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    )
  }
})
