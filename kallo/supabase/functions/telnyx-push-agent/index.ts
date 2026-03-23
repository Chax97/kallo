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

    // Fetch agent from DB
    console.log("[push-agent] fetching agent:", agent_id)
    const { data: agent, error: dbError } = await supabase
      .from("ai_agents")
      .select("*")
      .eq("id", agent_id)
      .single()

    if (dbError) throw new Error(`DB error: ${dbError.message}`)
    if (!agent) throw new Error(`Agent not found: ${agent_id}`)
    console.log("[push-agent] agent:", agent.name, "telnyx_agent_id:", agent.telnyx_agent_id)

    // Build payload per https://developers.telnyx.com/api-reference/assistants/create-an-assistant
    const payload: Record<string, unknown> = {
      name: agent.name,
      model: (agent.llm_model === "openai/gpt-4o-mini" ? "openai/gpt-4o" : agent.llm_model) ?? "openai/gpt-4o",
      instructions: agent.instructions ?? "You are a helpful AI receptionist.",
      enabled_features: ["telephony"],
    }

    if (agent.greeting) payload.greeting = agent.greeting
    if (agent.description) payload.description = agent.description

    // Only send voice_settings if a voice is explicitly configured
    // (the DB may hold voices from a different Telnyx product — omit to use Telnyx default)
    if (agent.tts_voice && !agent.tts_voice.includes(".")) {
      payload.voice_settings = { voice: agent.tts_voice }
    }

    payload.transcription_settings = {
      model: agent.stt_model
        ? `${agent.stt_provider ?? "deepgram"}/${agent.stt_model}`
        : "deepgram/nova-3",
    }

    payload.telephony_settings = {
      ...(agent.record_conversations ? {
        recording_settings: { enabled: true },
      } : {}),
    }

    let telnyxAssistantId: string = agent.telnyx_agent_id

    if (telnyxAssistantId) {
      console.log("[push-agent] updating assistant:", telnyxAssistantId)
      await telnyxRequest("PATCH", `/ai/assistants/${telnyxAssistantId}`, payload)
    } else {
      console.log("[push-agent] creating new assistant")
      const result = await telnyxRequest("POST", `/ai/assistants`, payload)
      const data = result.data as Record<string, unknown> | undefined
      telnyxAssistantId = (data?.id ?? result.id) as string
      if (!telnyxAssistantId) throw new Error("Telnyx did not return an assistant ID")

      console.log("[push-agent] storing telnyx_agent_id:", telnyxAssistantId)
      const { error: updateError } = await supabase
        .from("ai_agents")
        .update({ telnyx_agent_id: telnyxAssistantId })
        .eq("id", agent_id)
      if (updateError) {
        console.error("[push-agent] failed to store telnyx_agent_id:", updateError.message)
      }
    }

    console.log("[push-agent] success:", telnyxAssistantId)
    return new Response(
      JSON.stringify({ success: true, telnyx_agent_id: telnyxAssistantId }),
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
