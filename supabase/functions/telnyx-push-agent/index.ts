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

async function telnyxRequest(
  method: string,
  path: string,
  body?: unknown,
): Promise<Record<string, unknown>> {
  const url = `${TELNYX_API_BASE}${path}`
  console.log(`[telnyx] ${method} ${url}`, body ? JSON.stringify(body) : "")
  const res = await fetch(url, {
    method,
    headers: {
      Authorization: `Bearer ${TELNYX_API_KEY}`,
      "Content-Type": "application/json",
    },
    body: body ? JSON.stringify(body) : undefined,
  })
  const json = await res.json()
  console.log(`[telnyx] response ${res.status}:`, JSON.stringify(json))
  if (!res.ok) {
    throw new Error(`Telnyx API error ${res.status}: ${JSON.stringify(json)}`)
  }
  return json
}

// ── Build system instructions from agent_settings fields ──────────────────────

function buildInstructions(agent: Record<string, unknown>): string {
  const lines: string[] = []

  // Identity
  lines.push(`You are ${agent.agent_name || "an AI receptionist"} at ${agent.business_name || "our company"}.`)
  if (agent.business_description) {
    lines.push(`About the business: ${agent.business_description}`)
  }
  lines.push(`Business hours: ${agent.business_hours || "Mon–Fri 9am–5pm"}.`)
  lines.push(`Speak in ${agent.language || "English (AU)"}.`)
  lines.push(`Your personality style is: ${agent.persona || "Professional"}.`)

  if (agent.announce_ai_disclosure) {
    lines.push("At the start of each call, disclose that the caller is speaking with an AI agent.")
  }

  if (agent.custom_instructions) {
    lines.push(`\nAdditional instructions: ${agent.custom_instructions}`)
  }

  // Call qualification
  const questions = agent.qualification_questions as Array<Record<string, string>> | null
  if (questions && questions.length > 0) {
    lines.push("\n## Call Qualification")
    lines.push("Ask these questions in order to qualify the caller:")
    for (let i = 0; i < questions.length; i++) {
      const q = questions[i]
      lines.push(`${i + 1}. "${q.question}"`)
      lines.push(`   - If YES → ${q.yes_dest}${q.yes_custom_number ? ` (${q.yes_custom_number})` : ""}`)
      lines.push(`   - If NO → ${q.no_dest}${q.no_custom_number ? ` (${q.no_custom_number})` : ""}`)
      lines.push(`   - If UNCLEAR → ${q.unclear_dest}${q.unclear_custom_number ? ` (${q.unclear_custom_number})` : ""}`)
    }
    lines.push(`Default destination for callers who pass all questions: ${agent.default_destination || "Take a message"}.`)
    if (agent.default_transfer_number) {
      lines.push(`Default transfer number: ${agent.default_transfer_number}`)
    }
  }

  // Routing & Escalation
  lines.push("\n## Routing & Escalation Rules")
  if (agent.transfer_on_human_request) lines.push("- If the caller asks to speak to a human, transfer immediately.")
  if (agent.transfer_on_repeat) lines.push("- If the caller repeats themselves 3 times, escalate to a human.")
  if (agent.transfer_on_failed_attempts) lines.push("- If you cannot answer after 2 attempts, escalate to a human.")
  if (agent.transfer_on_duration_exceeded) {
    lines.push(`- If the call exceeds ${agent.max_duration_minutes || 10} minutes, escalate.`)
  }
  if (agent.escalation_transfer_number) {
    lines.push(`Escalation transfer number: ${agent.escalation_transfer_number}`)
  }

  // Out of hours
  lines.push(`\nOut of hours behaviour: ${agent.out_of_hours_behaviour || "Take a message and email to team"}.`)
  if (agent.out_of_hours_message) {
    lines.push(`Out of hours message: "${agent.out_of_hours_message}"`)
  }
  if (agent.emergency_override) {
    lines.push("Emergency override is enabled — allow urgent calls to escalate even outside hours.")
    if (agent.emergency_transfer_number) {
      lines.push(`Emergency transfer number: ${agent.emergency_transfer_number}`)
    }
  }

  // Keywords
  const termKeys = agent.termination_keywords as string[] | null
  if (termKeys && termKeys.length > 0) {
    lines.push(`\n## Safety Keywords`)
    lines.push(`Termination keywords (end call immediately): ${termKeys.join(", ")}`)
    lines.push(`Action: ${agent.termination_action || "End call immediately, log incident"}`)
  }

  const escalKeys = agent.escalation_keywords as string[] | null
  if (escalKeys && escalKeys.length > 0) {
    lines.push(`Escalation keywords (transfer to human): ${escalKeys.join(", ")}`)
    if (agent.keyword_escalation_number) {
      lines.push(`Keyword escalation number: ${agent.keyword_escalation_number}`)
    }
  }

  const priorityKeys = agent.priority_keywords as string[] | null
  if (priorityKeys && priorityKeys.length > 0) {
    lines.push(`Priority keywords (high-value callers): ${priorityKeys.join(", ")}`)
  }

  const offLimits = agent.off_limits_keywords as string[] | null
  if (offLimits && offLimits.length > 0) {
    lines.push(`Off-limits topics (do not discuss): ${offLimits.join(", ")}`)
    if (agent.deflection_message) {
      lines.push(`When asked about off-limits topics, say: "${agent.deflection_message}"`)
    }
  }

  // Behaviour
  lines.push("\n## Behaviour")
  lines.push(`Keep responses ${agent.max_response_length || "Medium (2–4 sentences)"}.`)
  lines.push(`Speaking pace: ${agent.speaking_pace || "Normal"}.`)
  if (agent.use_filler_words) lines.push("Use natural filler words like 'Sure', 'Of course', 'Absolutely'.")
  if (agent.confirm_caller_details) lines.push("Before transferring, confirm the caller's name and reason for calling.")
  if (agent.ask_callback_if_busy) lines.push("If the line is busy, ask for a callback number.")
  lines.push(`If the caller is silent for ${agent.silence_timeout || 8} seconds: ${agent.silence_action || "Prompt caller to respond"}.`)
  if (agent.silence_prompt) {
    lines.push(`Silence prompt: "${agent.silence_prompt}"`)
  }
  if (agent.allow_barge_in) lines.push("Allow the caller to interrupt you mid-sentence.")
  if (agent.announce_recording) lines.push("Announce at the start that the call may be recorded.")

  return lines.join("\n")
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }

  try {
    console.log("[push-agent] function invoked")

    if (!TELNYX_API_KEY) throw new Error("TELNYX_API_KEY env var is not set")

    const rawText = await req.text()
    console.log("[push-agent] raw body:", rawText)

    if (!rawText?.trim()) throw new Error("Request body is empty")

    const body = JSON.parse(rawText)
    const agent_id = body.agent_id as string | undefined
    if (!agent_id) throw new Error("agent_id is required")

    // Fetch agent settings from DB
    console.log("[push-agent] fetching agent_settings:", agent_id)
    const { data: agent, error: dbError } = await supabase
      .from("agent_settings")
      .select("*")
      .eq("id", agent_id)
      .single()

    if (dbError) throw new Error(`DB error: ${dbError.message}`)
    if (!agent) throw new Error(`Agent not found: ${agent_id}`)
    console.log("[push-agent] agent:", agent.agent_name, "telnyx_assistant_id:", agent.telnyx_assistant_id)

    // Build Telnyx assistant payload from agent_settings
    const instructions = buildInstructions(agent)
    console.log("[push-agent] instructions length:", instructions.length)

    // Map language to determine if English-only (enables faster STT model)
    const lang = (agent.language ?? "English (AU)") as string
    const isEnglish = lang.startsWith("English")

    const payload: Record<string, unknown> = {
      name: `${agent.agent_name || "Agent"} - ${agent.business_name || "Business"}`,
      // moonshotai/Kimi-K2.5: Telnyx recommended, no external API key required
      model: "moonshotai/Kimi-K2.5",
      instructions,
      enabled_features: ["telephony"],
    }

    if (agent.greeting) payload.greeting = agent.greeting
    if (agent.business_description) payload.description = agent.business_description

    // Telnyx Ultra: sub-100ms TTFB, built for real-time AI assistants
    // Falls back to KokoroTTS for non-English
    payload.voice_settings = isEnglish
      ? { voice: "Telnyx.Ultra.002622d8-19d0-4567-a16a-f99c7397c062" }
      : { voice: "Telnyx.KokoroTTS.af" }

    // deepgram/flux: optimised for turn-taking (English)
    // deepgram/nova-3: recommended for multi-lingual
    payload.transcription = {
      model: isEnglish ? "deepgram/flux" : "deepgram/nova-3",
    }

    // Set webhook URL so AI assistant call events flow to our edge function
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!
    const webhookUrl = `${supabaseUrl}/functions/v1/telnyx-webhook`

    payload.telephony = {
      // status_callback_url ensures Telnyx sends call events even if the TeXML app PATCH below fails
      status_callback_url: webhookUrl,
      status_callback_method: "POST",
      ...(agent.record_calls ? {
        recording_settings: { enabled: true },
      } : {}),
    }

    // Set the webhook at the assistant level (receives call.analyzed and other AI events)
    payload.webhook_url = webhookUrl

    let telnyxAssistantId: string = agent.telnyx_assistant_id
    let texmlAppId: string | null = agent.telnyx_texml_app_id ?? null

    if (telnyxAssistantId) {
      console.log("[push-agent] updating assistant:", telnyxAssistantId)
      await telnyxRequest("PATCH", `/ai/assistants/${telnyxAssistantId}`, payload)
    } else {
      console.log("[push-agent] creating new assistant")
      const result = await telnyxRequest("POST", `/ai/assistants`, payload)
      const data = result.data as Record<string, unknown> | undefined
      telnyxAssistantId = (data?.id ?? result.id) as string
      if (!telnyxAssistantId) throw new Error("Telnyx did not return an assistant ID")
    }

    // Always GET the assistant to reliably extract the TeXML app ID
    if (!texmlAppId) {
      console.log("[push-agent] fetching assistant to get texml_app_id")
      const getResult = await telnyxRequest("GET", `/ai/assistants/${telnyxAssistantId}`)
      console.log("[push-agent] GET response keys:", JSON.stringify(Object.keys(getResult)))
      const getData = getResult.data as Record<string, unknown> | undefined
      console.log("[push-agent] assistant data keys:", getData ? JSON.stringify(Object.keys(getData)) : "null")

      // Try multiple paths to find the TeXML app ID
      const telSettings = (getData?.telephony_settings ?? getData?.telephony) as Record<string, unknown> | undefined
      console.log("[push-agent] telephony_settings:", JSON.stringify(telSettings))
      texmlAppId = (telSettings?.default_texml_app_id as string)
        ?? (telSettings?.texml_app_id as string)
        ?? (getData?.default_texml_app_id as string)
        ?? null
      console.log("[push-agent] extracted texml_app_id:", texmlAppId)
    }

    // Configure the TeXML app's webhook so call events reach our edge function
    if (texmlAppId) {
      console.log("[push-agent] configuring TeXML app webhook:", texmlAppId)
      try {
        // Try TeXML Applications API
        const texmlPatchRes = await fetch(`${TELNYX_API_BASE}/texml_applications/${texmlAppId}`, {
          method: "PATCH",
          headers: {
            Authorization: `Bearer ${TELNYX_API_KEY}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            // IMPORTANT: voice_url must stay as the AI assistant's TeXML handler
            voice_url: `${TELNYX_API_BASE}/ai/assistants/${telnyxAssistantId}/texml`,
            voice_method: "POST",
            // status_callback receives call events (initiated, answered, hangup, etc.)
            status_callback: webhookUrl,
            status_callback_method: "POST",
          }),
        })
        const texmlPatchJson = await texmlPatchRes.json()
        console.log(`[push-agent] TeXML app PATCH response ${texmlPatchRes.status}:`, JSON.stringify(texmlPatchJson))

        if (!texmlPatchRes.ok) {
          // Fallback: try Call Control Applications API
          console.log("[push-agent] TeXML PATCH failed, trying call_control_applications")
          const ccPatchRes = await fetch(`${TELNYX_API_BASE}/call_control_applications/${texmlAppId}`, {
            method: "PATCH",
            headers: {
              Authorization: `Bearer ${TELNYX_API_KEY}`,
              "Content-Type": "application/json",
            },
            body: JSON.stringify({
              webhook_event_url: webhookUrl,
              webhook_event_failover_url: webhookUrl,
            }),
          })
          const ccPatchJson = await ccPatchRes.json()
          console.log(`[push-agent] call_control_applications PATCH response ${ccPatchRes.status}:`, JSON.stringify(ccPatchJson))
        }
      } catch (e) {
        console.error("[push-agent] failed to configure TeXML webhook:", e)
      }
    }

    // Save both IDs
    const updatePayload: Record<string, unknown> = {
      telnyx_assistant_id: telnyxAssistantId,
      status: "active",
    }
    if (texmlAppId) {
      updatePayload.telnyx_texml_app_id = texmlAppId
    }
    const { error: updateError } = await supabase
      .from("agent_settings")
      .update(updatePayload)
      .eq("id", agent_id)
    if (updateError) {
      console.error("[push-agent] failed to store IDs:", updateError.message)
    }

    console.log("[push-agent] success:", telnyxAssistantId, "texml:", texmlAppId)
    return new Response(
      JSON.stringify({ success: true, telnyx_assistant_id: telnyxAssistantId, telnyx_texml_app_id: texmlAppId }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } },
    )
  } catch (e) {
    const message = e instanceof Error ? e.message : String(e)
    console.error("[push-agent] error:", message)
    return new Response(JSON.stringify({ error: message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    })
  }
})
