import { createClient } from "jsr:@supabase/supabase-js@2"

/**
 * telnyx-push-agent
 *
 * Reads the agent_settings rows for a company, builds a system prompt from
 * each active agent's configuration, and creates / updates a Telnyx AI
 * Assistant via the Telnyx v2 API.  The resulting assistant id is stored back
 * in the agent_settings row so the webhook can route inbound calls to it.
 */

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
)

const TELNYX_API_KEY = Deno.env.get("TELNYX_API_KEY")
console.log("[telnyx-push-agent] TELNYX_API_KEY present:", !!TELNYX_API_KEY)
console.log("[telnyx-push-agent] SUPABASE_URL:", Deno.env.get("SUPABASE_URL"))

// ── Helpers ──────────────────────────────────────────────────────────────────

interface AgentRow {
  id: string
  company_id: string
  status: string
  business_name: string
  agent_name: string
  business_description: string
  business_hours: string
  language: string
  persona: string
  custom_instructions: string
  greeting: string
  announce_ai_disclosure: boolean
  qualification_questions: Array<{
    question: string
    yes_dest: string
    no_dest: string
    unclear_dest: string
  }>
  default_destination: string
  default_transfer_number: string | null
  transfer_on_human_request: boolean
  transfer_on_repeat: boolean
  transfer_on_failed_attempts: boolean
  transfer_on_duration_exceeded: boolean
  max_duration_minutes: number
  escalation_transfer_number: string | null
  out_of_hours_behaviour: string
  out_of_hours_message: string
  emergency_override: boolean
  emergency_transfer_number: string | null
  voicemail_email: string | null
  voicemail_sms: string | null
  include_transcript_in_email: boolean
  termination_keywords: string[]
  termination_action: string
  escalation_keywords: string[]
  keyword_escalation_number: string | null
  priority_keywords: string[]
  off_limits_keywords: string[]
  deflection_message: string
  max_response_length: string
  speaking_pace: string
  use_filler_words: boolean
  confirm_caller_details: boolean
  ask_callback_if_busy: boolean
  silence_timeout: number
  silence_action: string
  silence_prompt: string
  allow_barge_in: boolean
  record_calls: boolean
  generate_transcript: boolean
  generate_ai_summary: boolean
  announce_recording: boolean
  telnyx_assistant_id: string | null
}

function buildSystemPrompt(agent: AgentRow): string {
  const lines: string[] = []

  // ── Identity ────────────────────────────────────────────────────────────
  lines.push(`You are ${agent.agent_name}, an AI phone receptionist for ${agent.business_name || "our company"}.`)

  if (agent.business_description) {
    lines.push(`About the business: ${agent.business_description}`)
  }

  lines.push(`Business hours: ${agent.business_hours}.`)
  lines.push(`Speak in ${agent.language}. Your tone should be ${agent.persona.toLowerCase()}.`)

  if (agent.announce_ai_disclosure) {
    lines.push("At the start of each call, inform the caller they are speaking with an AI assistant.")
  }

  if (agent.announce_recording) {
    lines.push("Inform the caller that the call may be recorded for quality and training purposes.")
  }

  // ── Greeting ────────────────────────────────────────────────────────────
  const greeting = agent.greeting.replace("{business_name}", agent.business_name || "our company")
  lines.push(`\nGreeting: "${greeting}"`)

  // ── Custom instructions ────────────────────────────────────────────────
  if (agent.custom_instructions) {
    lines.push(`\nAdditional instructions: ${agent.custom_instructions}`)
  }

  // ── Call qualification ─────────────────────────────────────────────────
  if (agent.qualification_questions.length > 0) {
    lines.push("\n## Call Qualification")
    lines.push("Ask the following questions to determine how to route the call:")
    for (const q of agent.qualification_questions) {
      lines.push(`- "${q.question}"`)
      lines.push(`  - If YES → ${q.yes_dest}`)
      lines.push(`  - If NO → ${q.no_dest}`)
      lines.push(`  - If UNCLEAR → ${q.unclear_dest}`)
    }
    lines.push(`If none of the above match, the default action is: ${agent.default_destination}.`)
    if (agent.default_transfer_number) {
      lines.push(`Default transfer number: ${agent.default_transfer_number}`)
    }
  }

  // ── Routing & escalation ───────────────────────────────────────────────
  lines.push("\n## Routing & Escalation Rules")

  if (agent.transfer_on_human_request) {
    lines.push("- If the caller explicitly asks to speak to a human, transfer immediately.")
  }
  if (agent.transfer_on_repeat) {
    lines.push("- If the caller repeats the same request multiple times without resolution, transfer to a human.")
  }
  if (agent.transfer_on_failed_attempts) {
    lines.push("- If you fail to resolve the query after several attempts, transfer to a human.")
  }
  if (agent.transfer_on_duration_exceeded) {
    lines.push(`- If the call exceeds ${agent.max_duration_minutes} minutes, transfer to a human.`)
  }
  if (agent.escalation_transfer_number) {
    lines.push(`Escalation transfer number: ${agent.escalation_transfer_number}`)
  }

  // ── Out of hours ───────────────────────────────────────────────────────
  lines.push(`\nOut-of-hours behaviour: ${agent.out_of_hours_behaviour}.`)
  if (agent.out_of_hours_message) {
    lines.push(`Out-of-hours message: "${agent.out_of_hours_message}"`)
  }

  // ── Emergency ──────────────────────────────────────────────────────────
  if (agent.emergency_override) {
    lines.push("\nEmergency override is enabled. If the caller has a genuine emergency, transfer immediately.")
    if (agent.emergency_transfer_number) {
      lines.push(`Emergency transfer number: ${agent.emergency_transfer_number}`)
    }
  }

  // ── Keywords ───────────────────────────────────────────────────────────
  if (agent.termination_keywords.length > 0) {
    lines.push(`\n## Safety Keywords`)
    lines.push(`If the caller uses any of these words: [${agent.termination_keywords.join(", ")}]`)
    lines.push(`Action: ${agent.termination_action}`)
  }

  if (agent.escalation_keywords.length > 0) {
    lines.push(`\nEscalation keywords: [${agent.escalation_keywords.join(", ")}]. If detected, escalate the call.`)
    if (agent.keyword_escalation_number) {
      lines.push(`Keyword escalation number: ${agent.keyword_escalation_number}`)
    }
  }

  if (agent.priority_keywords.length > 0) {
    lines.push(`Priority keywords: [${agent.priority_keywords.join(", ")}]. Treat these callers with extra care.`)
  }

  if (agent.off_limits_keywords.length > 0) {
    lines.push(`Off-limits topics: [${agent.off_limits_keywords.join(", ")}]. Do not discuss these topics.`)
    if (agent.deflection_message) {
      lines.push(`Instead say: "${agent.deflection_message}"`)
    }
  }

  // ── Behaviour ──────────────────────────────────────────────────────────
  lines.push("\n## Behaviour")
  lines.push(`Response length: ${agent.max_response_length}.`)
  lines.push(`Speaking pace: ${agent.speaking_pace}.`)

  if (agent.use_filler_words) {
    lines.push("Use natural filler words (um, well, let me see) to sound more human.")
  } else {
    lines.push("Avoid filler words. Be direct and concise.")
  }

  if (agent.confirm_caller_details) {
    lines.push("Always confirm the caller's name and details before proceeding.")
  }

  if (agent.ask_callback_if_busy) {
    lines.push("If the line is busy or no one is available, offer to arrange a callback.")
  }

  lines.push(`If the caller is silent for ${agent.silence_timeout} seconds, ${agent.silence_action.toLowerCase()}.`)
  if (agent.silence_prompt) {
    lines.push(`Silence prompt: "${agent.silence_prompt}"`)
  }

  if (agent.allow_barge_in) {
    lines.push("Allow the caller to interrupt you mid-sentence.")
  }

  return lines.join("\n")
}

/** Map our language setting to a Telnyx voice language code. */
function mapLanguage(lang: string): string {
  const map: Record<string, string> = {
    "English (UK)": "en-GB",
    "English (AU)": "en-AU",
    "English (US)": "en-US",
    "Spanish": "es-ES",
    "French": "fr-FR",
    "Arabic": "ar-SA",
    "Mandarin": "zh-CN",
  }
  return map[lang] ?? "en-AU"
}

/** Map persona to a Telnyx voice. */
function mapVoice(persona: string): string {
  // Telnyx supports "male" and "female" voices.
  // Default to female for most personas.
  const malePersonas = ["formal", "concise"]
  return malePersonas.includes(persona.toLowerCase()) ? "male" : "female"
}

// ── Telnyx AI Assistant API ──────────────────────────────────────────────────

async function telnyxRequest(
  method: string,
  path: string,
  body?: Record<string, unknown>,
): Promise<{ ok: boolean; status: number; data: Record<string, unknown> }> {
  const res = await fetch(`https://api.telnyx.com/v2${path}`, {
    method,
    headers: {
      Authorization: `Bearer ${TELNYX_API_KEY}`,
      "Content-Type": "application/json",
    },
    ...(body ? { body: JSON.stringify(body) } : {}),
  })
  const data = await res.json()
  console.log(`[telnyx-push-agent] Telnyx ${method} ${path} → ${res.status}`, JSON.stringify(data))
  return { ok: res.ok, status: res.status, data }
}

async function upsertAssistant(
  agent: AgentRow,
): Promise<{ assistantId: string }> {
  const systemPrompt = buildSystemPrompt(agent)
  const language = mapLanguage(agent.language)
  const voice = mapVoice(agent.persona)

  const assistantPayload = {
    name: `${agent.agent_name} - ${agent.business_name || "Kallo"}`,
    system_prompt: systemPrompt,
    language,
    voice,
    first_message: agent.greeting.replace("{business_name}", agent.business_name || "our company"),
    model: "telnyx_trained",
    enable_recording: agent.record_calls,
    enable_transcription: agent.generate_transcript,
  }

  // Update existing or create new
  if (agent.telnyx_assistant_id) {
    console.log(`Updating assistant ${agent.telnyx_assistant_id}`)
    const res = await telnyxRequest(
      "PATCH",
      `/ai/assistants/${agent.telnyx_assistant_id}`,
      assistantPayload,
    )

    if (res.ok) {
      return { assistantId: agent.telnyx_assistant_id }
    }

    // If the assistant was deleted on Telnyx side, create a new one
    if (res.status === 404) {
      console.log("Assistant not found on Telnyx, creating new one")
    } else {
      console.error("Failed to update assistant:", JSON.stringify(res.data))
      throw new Error(`Telnyx update failed: ${res.status}`)
    }
  }

  // Create new assistant
  console.log("[telnyx-push-agent] Creating new Telnyx AI assistant")
  console.log("[telnyx-push-agent] Assistant payload:", JSON.stringify(assistantPayload, null, 2))
  const res = await telnyxRequest("POST", "/ai/assistants", assistantPayload)

  if (!res.ok) {
    console.error("Failed to create assistant:", JSON.stringify(res.data))
    throw new Error(`Telnyx create failed: ${res.status} — ${JSON.stringify(res.data)}`)
  }

  const assistantId = (res.data as Record<string, unknown>)?.data
    ? ((res.data as Record<string, Record<string, string>>).data.id)
    : (res.data as Record<string, string>).id

  console.log("Created assistant:", assistantId)
  return { assistantId }
}

// ── Main handler ─────────────────────────────────────────────────────────────

Deno.serve(async (req) => {
  try {
    const body = await req.json()
    console.log("[telnyx-push-agent] Request body:", JSON.stringify(body))
    const { company_id } = body

    if (!company_id) {
      console.error("[telnyx-push-agent] Missing company_id in request body")
      return new Response(
        JSON.stringify({ error: "company_id is required" }),
        { status: 400, headers: { "Content-Type": "application/json" } },
      )
    }

    // Fetch all agents for this company
    const { data: agents, error: fetchError } = await supabase
      .from("agent_settings")
      .select("*")
      .eq("company_id", company_id)

    if (fetchError) {
      console.error("DB fetch error:", fetchError.message)
      return new Response(
        JSON.stringify({ error: fetchError.message }),
        { status: 500, headers: { "Content-Type": "application/json" } },
      )
    }

    console.log("[telnyx-push-agent] Fetched agents count:", agents?.length ?? 0)

    if (!agents || agents.length === 0) {
      console.warn("[telnyx-push-agent] No agents found for company_id:", company_id)
      return new Response(
        JSON.stringify({ message: "No agents found for company" }),
        { status: 200, headers: { "Content-Type": "application/json" } },
      )
    }

    const results: Array<{ agent_id: string; assistant_id: string; status: string }> = []

    for (const agent of agents as AgentRow[]) {
      try {
        const { assistantId } = await upsertAssistant(agent)

        // Store the assistant ID back in the database
        if (assistantId !== agent.telnyx_assistant_id) {
          console.log(`[telnyx-push-agent] Saving telnyx_assistant_id=${assistantId} for agent ${agent.id}`)
          const { error: updateError } = await supabase
            .from("agent_settings")
            .update({ telnyx_assistant_id: assistantId })
            .eq("id", agent.id)
          if (updateError) {
            console.error(`[telnyx-push-agent] Failed to save assistant ID back:`, updateError.message)
          }
        }

        results.push({
          agent_id: agent.id,
          assistant_id: assistantId,
          status: "synced",
        })
      } catch (err) {
        console.error(`Failed to sync agent ${agent.id}:`, err)
        results.push({
          agent_id: agent.id,
          assistant_id: agent.telnyx_assistant_id ?? "",
          status: `error: ${(err as Error).message}`,
        })
      }
    }

    return new Response(
      JSON.stringify({ results }),
      { status: 200, headers: { "Content-Type": "application/json" } },
    )
  } catch (err) {
    console.error("Unexpected error:", err)
    return new Response(
      JSON.stringify({ error: (err as Error).message }),
      { status: 500, headers: { "Content-Type": "application/json" } },
    )
  }
})
