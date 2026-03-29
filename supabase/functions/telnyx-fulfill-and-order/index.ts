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

    const { phone_number, company_id, kyc_id, verify_only } = await req.json()
    if (!phone_number) throw new Error("phone_number is required")
    if (!company_id)   throw new Error("company_id is required")
    if (!kyc_id)       throw new Error("kyc_id is required")

    // ── Load company_kyc ───────────────────────────────────────────────────
    const { data: kyc, error: kycError } = await supabase
      .from("company_kyc")
      .select("id, telnyx_requirement_group_id, country_code, phone_number_type")
      .eq("id", kyc_id)
      .single()
    if (kycError || !kyc) throw new Error(`company_kyc not found: ${kycError?.message}`)

    // ── Load company for address fields + connection_id ────────────────────
    const { data: company, error: companyError } = await supabase
      .from("companies")
      .select("name, address_line1, address_line2, city, state, postcode, country, telnyx_connection_id")
      .eq("id", company_id)
      .single()
    if (companyError || !company) throw new Error(`Company not found: ${companyError?.message}`)

    let requirementGroupId = kyc.telnyx_requirement_group_id as string | null

    // ── Steps 1–3: Always run (idempotent) ──────────────────────────────────

    // Load all non-superseded kyc_documents for this kyc record
    const { data: docs, error: docsError } = await supabase
      .from("company_kyc_documents")
      .select("id, document_type, storage_path, telnyx_document_id, telnyx_address_id, field_value, requirement_type_id, requirement_name")
      .eq("kyc_id", kyc_id)
      .eq("is_superseded", false)
    if (docsError) throw new Error(`Failed to load kyc documents: ${docsError.message}`)

    const allDocs = docs ?? []
    console.log(`[fulfill] loaded ${allDocs.length} kyc_documents:`, JSON.stringify(allDocs.map(d => ({
      id: d.id, type: d.document_type, req: d.requirement_type_id,
      has_telnyx_doc: !!d.telnyx_document_id, has_telnyx_addr: !!d.telnyx_address_id,
      has_storage: !!d.storage_path, has_value: !!d.field_value,
    }))))

    // Step 1–2: Upload any document files not yet pushed to Telnyx
    for (const doc of allDocs) {
      if (doc.document_type !== "document") continue
      if (doc.telnyx_document_id) continue  // already uploaded — idempotent

      if (!doc.storage_path) throw new Error(`Document ${doc.id} has no storage_path`)

      console.log(`[fulfill] downloading from storage: ${doc.storage_path}`)
      const { data: fileData, error: storageError } = await supabase.storage
        .from("kyc-documents")
        .download(doc.storage_path)
      if (storageError || !fileData) {
        throw new Error(`Storage download failed for ${doc.id}: ${storageError?.message ?? "unknown"}`)
      }

      const fileName = doc.storage_path.split("/").pop() ?? "document.pdf"
      const formData = new FormData()
      formData.append("file", fileData, fileName)
      formData.append("customer_reference", doc.requirement_name ?? "kyc-document")

      const telRes = await fetch(`${TELNYX_API_BASE}/documents`, {
        method:  "POST",
        headers: { Authorization: `Bearer ${TELNYX_API_KEY}` },
        body:    formData,
      })
      const telJson = await telRes.json()
      console.log(`[fulfill] document upload response ${telRes.status}`)
      if (!telRes.ok) throw new Error(`Telnyx document upload failed: ${JSON.stringify(telJson)}`)

      const telnyxDocId = telJson.data?.id
      if (!telnyxDocId) throw new Error("No document ID in Telnyx response")

      await supabase
        .from("company_kyc_documents")
        .update({ telnyx_document_id: telnyxDocId, status: "submitted" })
        .eq("id", doc.id)
      doc.telnyx_document_id = telnyxDocId
      console.log(`[fulfill] saved telnyx_document_id ${telnyxDocId} for doc ${doc.id}`)
    }

    // Step 3: Create Telnyx address record for address-type requirements
    for (const doc of allDocs) {
      if (doc.document_type !== "address") continue
      if (doc.telnyx_address_id) continue  // already created — idempotent

      console.log(`[fulfill] creating address for requirement ${doc.requirement_type_id}`)

      const addressBody = {
        customer_reference:  company.name ?? "business",
        first_name:          company.name ?? "Business",
        last_name:           "Address",
        street_address:      company.address_line1 ?? doc.field_value ?? "",
        extended_address:    company.address_line2 ?? "",
        locality:            company.city ?? "",
        postal_code:         company.postcode ?? "",
        country_code:        kyc.country_code ?? "GB",
        administrative_area: company.state ?? "",
      }

      let addrRes = await fetch(`${TELNYX_API_BASE}/addresses`, {
        method:  "POST",
        headers: {
          Authorization:  `Bearer ${TELNYX_API_KEY}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify(addressBody),
      })
      let addrJson = await addrRes.json()
      console.log(`[fulfill] address response ${addrRes.status}`)

      // If Telnyx returns 10015 suggestions, retry with the corrected values
      if (!addrRes.ok && Array.isArray(addrJson.errors) &&
          addrJson.errors.every((e: { code: string }) => e.code === "10015")) {
        console.log(`[fulfill] applying Telnyx address suggestions and retrying`)
        const corrected = { ...addressBody }
        for (const err of addrJson.errors) {
          const field = err.source?.pointer?.replace("/", "")
          if (field && field in corrected) {
            (corrected as Record<string, string>)[field] = err.detail ?? ""
          }
        }
        console.log(`[fulfill] corrected address: ${JSON.stringify(corrected)}`)
        addrRes = await fetch(`${TELNYX_API_BASE}/addresses`, {
          method:  "POST",
          headers: {
            Authorization:  `Bearer ${TELNYX_API_KEY}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify(corrected),
        })
        addrJson = await addrRes.json()
        console.log(`[fulfill] corrected address response ${addrRes.status}`)
      }
      if (!addrRes.ok) throw new Error(`Telnyx address creation failed: ${JSON.stringify(addrJson)}`)

      const telnyxAddressId = addrJson.data?.id
      if (!telnyxAddressId) throw new Error("No address ID in Telnyx response")

      await supabase
        .from("company_kyc_documents")
        .update({ telnyx_address_id: telnyxAddressId })
        .eq("id", doc.id)
      doc.telnyx_address_id = telnyxAddressId
      console.log(`[fulfill] saved telnyx_address_id ${telnyxAddressId} for doc ${doc.id}`)
    }

    // ── Step 4: Create requirement group (only if not already created) ─────
    if (!requirementGroupId) {
      console.log(`[fulfill] creating requirement group`)
      const groupRes = await fetch(`${TELNYX_API_BASE}/requirement_groups`, {
        method:  "POST",
        headers: {
          Authorization:  `Bearer ${TELNYX_API_KEY}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          name:              `kyc-${kyc_id}`,
          action:            "ordering",
          phone_number_type: kyc.phone_number_type,
          country_code:      kyc.country_code,
        }),
      })
      const groupJson = await groupRes.json()
      console.log(`[fulfill] requirement_group response ${groupRes.status}`)
      if (!groupRes.ok) throw new Error(`Telnyx requirement_group create failed: ${JSON.stringify(groupJson)}`)

      requirementGroupId = groupJson.data?.id
      if (!requirementGroupId) throw new Error("No requirement_group ID in Telnyx response")

      // Save immediately — if step 5 fails, step 4 won't re-run on retry
      await supabase
        .from("company_kyc")
        .update({ telnyx_requirement_group_id: requirementGroupId })
        .eq("id", kyc_id)
      console.log(`[fulfill] saved requirement_group_id ${requirementGroupId}`)
    } else {
      console.log(`[fulfill] reusing existing requirement_group ${requirementGroupId}`)
    }

    // ── Step 5: Inspect requirement group, then fulfill ──────────────────
    // GET the requirement group to see its actual requirements and their IDs
    const groupGetRes = await fetch(`${TELNYX_API_BASE}/requirement_groups/${requirementGroupId}`, {
      headers: { Authorization: `Bearer ${TELNYX_API_KEY}` },
    })
    const groupGetJson = await groupGetRes.json()
    console.log(`[fulfill] GET requirement_group ${groupGetRes.status}:`, JSON.stringify(groupGetJson))

    // Build a map from requirement_type_id → group requirement record_id
    // The group's requirements have their own IDs that differ from the type IDs
    const groupReqs = groupGetJson.data?.regulatory_requirements ?? []
    const typeToGroupReqId: Record<string, string> = {}
    for (const gr of groupReqs) {
      const typeId = gr.requirement_type?.id ?? gr.requirement_type_id ?? ""
      const recordId = gr.record_id ?? gr.id ?? ""
      if (typeId && recordId) {
        typeToGroupReqId[typeId] = recordId
      }
      console.log(`[fulfill] group req: id=${gr.id}, record_id=${gr.record_id}, type_id=${typeId}, field_type=${gr.field_type}, field_value=${gr.field_value}`)
    }

    // Build requirements array using the group's own requirement IDs
    const requirements: Array<{ requirement_id: string; field_value: string }> = []
    for (const doc of allDocs) {
      let value: string | null = null
      if (doc.document_type === "document") {
        value = doc.telnyx_document_id
      } else if (doc.document_type === "address") {
        value = doc.telnyx_address_id
      } else {
        value = doc.field_value
      }
      if (!doc.requirement_type_id || !value) continue

      // Use the group's requirement record_id if available, otherwise fall back to type ID
      const reqId = typeToGroupReqId[doc.requirement_type_id] ?? doc.requirement_type_id
      requirements.push({ requirement_id: reqId, field_value: value })
    }

    console.log(`[fulfill] requirements to submit (${requirements.length}):`, JSON.stringify(requirements))

    if (requirements.length > 0) {
      const patchRes = await fetch(`${TELNYX_API_BASE}/requirement_groups/${requirementGroupId}`, {
        method:  "PATCH",
        headers: {
          Authorization:  `Bearer ${TELNYX_API_KEY}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({ regulatory_requirements: requirements }),
      })
      const patchJson = await patchRes.json()
      console.log(`[fulfill] requirement_group fulfill response ${patchRes.status}:`, JSON.stringify(patchJson))
      if (!patchRes.ok) throw new Error(`Telnyx requirement_group fulfill failed: ${JSON.stringify(patchJson)}`)
      console.log(`[fulfill] fulfilled requirement group ${requirementGroupId}`)
    }

    // GET the group again to verify it's fulfilled
    const verifyRes = await fetch(`${TELNYX_API_BASE}/requirement_groups/${requirementGroupId}`, {
      headers: { Authorization: `Bearer ${TELNYX_API_KEY}` },
    })
    const verifyJson = await verifyRes.json()
    console.log(`[fulfill] requirement_group after fulfill:`, JSON.stringify(verifyJson.data?.regulatory_requirements?.map((r: Record<string, unknown>) => ({
      id: r.id, record_id: r.record_id, type: r.requirement_type_id, field_value: r.field_value, status: r.status,
    }))))

    if (verify_only) {
      // Verify-only mode: skip number ordering, associate requirement group with existing order
      console.log(`[fulfill] verify_only mode for ${phone_number}`)

      // Search for the pending number order by phone number
      console.log(`[fulfill] searching number_orders for ${phone_number}`)
      const searchRes = await fetch(`${TELNYX_API_BASE}/number_orders?filter[phone_number]=${encodeURIComponent(phone_number)}&filter[status]=pending`, {
        headers: { Authorization: `Bearer ${TELNYX_API_KEY}` },
      })
      const searchJson = await searchRes.json()
      console.log(`[fulfill] number_orders search response ${searchRes.status}:`, JSON.stringify(searchJson))

      if (Array.isArray(searchJson.data) && searchJson.data.length > 0) {
        const order = searchJson.data[0]
        const orderId = order.id
        console.log(`[fulfill] found number_order ${orderId}`)

        // Get the actual sub_number_order ID from the order response
        const subOrderIds = order.sub_number_orders_ids ?? []
        if (subOrderIds.length > 0) {
          const subOrderId = subOrderIds[0]
          console.log(`[fulfill] updating sub_number_order ${subOrderId} with requirement_group ${requirementGroupId}`)
          const subRes = await fetch(`${TELNYX_API_BASE}/sub_number_orders/${subOrderId}`, {
            method:  "PATCH",
            headers: {
              Authorization:  `Bearer ${TELNYX_API_KEY}`,
              "Content-Type": "application/json",
            },
            body: JSON.stringify({ requirement_group_id: requirementGroupId }),
          })
          const subJson = await subRes.json()
          console.log(`[fulfill] sub_number_order PATCH response ${subRes.status}:`, JSON.stringify(subJson))
        } else {
          // Fallback: update the number order directly
          console.log(`[fulfill] no sub_number_order IDs, updating number_order ${orderId} directly`)
          const orderPatchRes = await fetch(`${TELNYX_API_BASE}/number_orders/${orderId}`, {
            method:  "PATCH",
            headers: {
              Authorization:  `Bearer ${TELNYX_API_KEY}`,
              "Content-Type": "application/json",
            },
            body: JSON.stringify({
              phone_numbers: [{ phone_number, requirement_group_id: requirementGroupId }],
            }),
          })
          const orderPatchJson = await orderPatchRes.json()
          console.log(`[fulfill] number_order PATCH response ${orderPatchRes.status}:`, JSON.stringify(orderPatchJson))
        }
      } else {
        console.log(`[fulfill] no pending number_order found for ${phone_number}`)
      }

      console.log(`[fulfill] done (verify_only) for ${phone_number}`)
      return new Response(
        JSON.stringify({ success: true, verify_only: true }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } },
      )
    }

    // ── Step 6: Place number order ─────────────────────────────────────────
    const orderBody: Record<string, unknown> = {
      phone_numbers: [{ phone_number, requirement_group_id: requirementGroupId }],
    }
    if (company.telnyx_connection_id) {
      orderBody.connection_id = company.telnyx_connection_id
    }

    console.log(`[fulfill] ordering ${phone_number} with requirement_group ${requirementGroupId}`)
    const orderRes = await fetch(`${TELNYX_API_BASE}/number_orders`, {
      method:  "POST",
      headers: {
        Authorization:  `Bearer ${TELNYX_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(orderBody),
    })
    const orderJson = await orderRes.json()
    console.log(`[fulfill] number_order response ${orderRes.status}`)
    if (!orderRes.ok) throw new Error(`Telnyx number_order failed: ${JSON.stringify(orderJson)}`)

    const orderedNumber = orderJson.data?.phone_numbers?.[0]
    if (!orderedNumber) throw new Error("No phone number in order response")

    // Save to phone_numbers table
    const { data: inserted, error: insertError } = await supabase
      .from("phone_numbers")
      .insert({
        company_id,
        number:           phone_number,
        telnyx_number_id: orderedNumber.id ?? null,
        status:           orderedNumber.status ?? "purchase_pending",
      })
      .select()
      .single()
    if (insertError) throw new Error(`Failed to save phone number: ${insertError.message}`)

    console.log(`[fulfill] done, phone_numbers row: ${inserted.id}`)
    return new Response(
      JSON.stringify({ success: true, data: inserted }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } },
    )
  } catch (e) {
    const message = e instanceof Error ? e.message : String(e)
    console.error("[fulfill] error:", message)
    return new Response(
      JSON.stringify({ error: message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    )
  }
})
