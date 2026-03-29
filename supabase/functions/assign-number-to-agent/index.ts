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

    const body = await req.json()
    const { phone_number_id, agent_settings_id, action } = body

    // action: "assign" or "unassign"
    if (!phone_number_id) throw new Error("phone_number_id is required")
    if (action !== "assign" && action !== "unassign") {
      throw new Error("action must be 'assign' or 'unassign'")
    }

    let connectionId: string | null = null

    if (action === "assign") {
      if (!agent_settings_id) throw new Error("agent_settings_id is required for assign")

      // Look up the agent's Telnyx assistant ID
      const { data: agent, error: agentErr } = await supabase
        .from("agent_settings")
        .select("telnyx_texml_app_id, telnyx_assistant_id")
        .eq("id", agent_settings_id)
        .single()

      if (agentErr || !agent) throw new Error(`Agent not found: ${agentErr?.message}`)
      if (!agent.telnyx_assistant_id) {
        throw new Error("Agent is not deployed to Telnyx yet.")
      }

      // If we already have the TeXML app ID, use it
      if (agent.telnyx_texml_app_id) {
        connectionId = agent.telnyx_texml_app_id
      } else {
        // GET the assistant from Telnyx to find the TeXML app ID
        console.log(`[assign] fetching assistant ${agent.telnyx_assistant_id} to get TeXML app ID`)
        const getRes = await fetch(`${TELNYX_API_BASE}/ai/assistants/${agent.telnyx_assistant_id}`, {
          headers: { Authorization: `Bearer ${TELNYX_API_KEY}` },
        })
        const getJson = await getRes.json()
        console.log(`[assign] GET assistant response:`, JSON.stringify(getJson))

        // Search for TeXML app ID in the response
        const data = getJson.data ?? getJson
        const telSettings = data?.telephony_settings ?? data?.telephony ?? {}
        connectionId = telSettings?.default_texml_app_id
          ?? telSettings?.texml_app_id
          ?? data?.default_texml_app_id
          ?? null

        // If still not found, log the full structure so we can debug
        if (!connectionId) {
          console.log(`[assign] full response data keys:`, JSON.stringify(Object.keys(data ?? {})))
          console.log(`[assign] telephony_settings:`, JSON.stringify(telSettings))
          throw new Error(`Could not find TeXML app ID in assistant response. Keys: ${JSON.stringify(Object.keys(data ?? {}))}`)
        }

        // Cache it for next time
        await supabase
          .from("agent_settings")
          .update({ telnyx_texml_app_id: connectionId })
          .eq("id", agent_settings_id)
      }

      // Before assigning, GET the current connection_id so we can restore it on unassign
      console.log(`[assign] fetching current voice settings for number ${phone_number_id}`)
      const currentRes = await fetch(`${TELNYX_API_BASE}/phone_numbers/${phone_number_id}/voice`, {
        headers: { Authorization: `Bearer ${TELNYX_API_KEY}` },
      })
      const currentJson = await currentRes.json()
      const currentConnectionId = currentJson?.data?.connection_id ?? null
      // Only save as "original" if it's NOT already the AI assistant's connection
      const originalConnectionId = (currentConnectionId && currentConnectionId !== connectionId)
        ? currentConnectionId
        : null
      console.log(`[assign] current connection_id: ${currentConnectionId}, saving original: ${originalConnectionId}`)

      console.log(`[assign] assigning number ${phone_number_id} to TeXML app ${connectionId}`)

      // PATCH the number to point to the AI assistant's TeXML app
      const res = await fetch(`${TELNYX_API_BASE}/phone_numbers/${phone_number_id}/voice`, {
        method: "PATCH",
        headers: {
          Authorization: `Bearer ${TELNYX_API_KEY}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({ connection_id: connectionId }),
      })
      const resJson = await res.json()
      console.log(`[assign] Telnyx PATCH response ${res.status}:`, JSON.stringify(resJson))
      if (!res.ok) throw new Error(`Telnyx error ${res.status}: ${JSON.stringify(resJson)}`)

      // Save assignment + original connection_id in DB
      await supabase
        .from("phone_numbers")
        .update({
          assigned_agent_id: agent_settings_id,
          original_connection_id: originalConnectionId,
        })
        .eq("telnyx_number_id", phone_number_id)

    } else {
      // Unassign: restore the original connection_id
      const { data: phoneRow } = await supabase
        .from("phone_numbers")
        .select("original_connection_id")
        .eq("telnyx_number_id", phone_number_id)
        .single()

      const restoreConnectionId = phoneRow?.original_connection_id ?? null
      console.log(`[assign] unassigning number ${phone_number_id}, restoring connection: ${restoreConnectionId}`)

      if (restoreConnectionId) {
        // Restore original connection
        const res = await fetch(`${TELNYX_API_BASE}/phone_numbers/${phone_number_id}/voice`, {
          method: "PATCH",
          headers: {
            Authorization: `Bearer ${TELNYX_API_KEY}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({ connection_id: restoreConnectionId }),
        })
        const resJson = await res.json()
        console.log(`[assign] Telnyx restore PATCH response ${res.status}:`, JSON.stringify(resJson))
        if (!res.ok) throw new Error(`Telnyx error ${res.status}: ${JSON.stringify(resJson)}`)
      } else {
        // No original connection — remove from AI assistant via the assistant's phone number list
        // Look up which agent this number is assigned to
        const { data: phoneData } = await supabase
          .from("phone_numbers")
          .select("assigned_agent_id, number")
          .eq("telnyx_number_id", phone_number_id)
          .single()

        if (phoneData?.assigned_agent_id) {
          const { data: agentData } = await supabase
            .from("agent_settings")
            .select("telnyx_assistant_id")
            .eq("id", phoneData.assigned_agent_id)
            .single()

          if (agentData?.telnyx_assistant_id) {
            // Use the Telnyx AI assistant API to remove the phone number
            console.log(`[assign] removing ${phoneData.number} from assistant ${agentData.telnyx_assistant_id}`)
            const removeRes = await fetch(
              `${TELNYX_API_BASE}/ai/assistants/${agentData.telnyx_assistant_id}/phone_numbers/${phoneData.number}`,
              {
                method: "DELETE",
                headers: { Authorization: `Bearer ${TELNYX_API_KEY}` },
              },
            )
            console.log(`[assign] assistant phone number DELETE response ${removeRes.status}`)

            // If DELETE on assistant didn't work, try setting connection to empty string
            if (!removeRes.ok) {
              console.log(`[assign] DELETE failed, trying PATCH with empty connection`)
              const res = await fetch(`${TELNYX_API_BASE}/phone_numbers/${phone_number_id}/voice`, {
                method: "PATCH",
                headers: {
                  Authorization: `Bearer ${TELNYX_API_KEY}`,
                  "Content-Type": "application/json",
                },
                body: JSON.stringify({ connection_id: "" }),
              })
              const resJson = await res.json()
              console.log(`[assign] Telnyx empty PATCH response ${res.status}:`, JSON.stringify(resJson))
            }
          }
        }
      }

      await supabase
        .from("phone_numbers")
        .update({ assigned_agent_id: null, original_connection_id: null })
        .eq("telnyx_number_id", phone_number_id)
    }

    return new Response(
      JSON.stringify({ success: true, action, connection_id: connectionId }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } },
    )
  } catch (e) {
    const message = e instanceof Error ? e.message : String(e)
    console.error("[assign] error:", message)
    return new Response(
      JSON.stringify({ error: message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    )
  }
})
