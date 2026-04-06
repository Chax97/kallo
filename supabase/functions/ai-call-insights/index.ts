import { createClient } from "jsr:@supabase/supabase-js@2"

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
)

const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY")
const RESEND_FROM_EMAIL = Deno.env.get("RESEND_FROM_EMAIL") ?? "noreply@speekit.com.au"

interface InsightPayload {
  conversation_id?: string
  call_id?: string
  assistant_id?: string
  insights?: Array<{
    insight_id?: string
    insight_name?: string
    result?: string | Record<string, unknown>
  }>
  conversation_channel?: string
  agent_target?: string
  end_user_target?: string
  started_at?: string
  ended_at?: string
}

function buildEmailHtml(opts: {
  businessName: string
  callerNumber: string
  agentNumber: string
  summary: string
  transcript: string | null
  startedAt: string
  endedAt: string
}): string {
  const start = new Date(opts.startedAt)
  const end = new Date(opts.endedAt)
  const durationSecs = Math.round((end.getTime() - start.getTime()) / 1000)
  const mins = Math.floor(durationSecs / 60)
  const secs = durationSecs % 60
  const duration = mins > 0 ? `${mins}m ${secs}s` : `${secs}s`
  const dateStr = start.toLocaleDateString("en-AU", {
    weekday: "short", year: "numeric", month: "short", day: "numeric",
  })
  const timeStr = start.toLocaleTimeString("en-AU", {
    hour: "2-digit", minute: "2-digit", hour12: true,
  })

  const transcriptBlock = opts.transcript ? `
  <div style="background: white; border: 1px solid #e8e8f0; border-radius: 12px; padding: 24px; margin-bottom: 24px;">
    <p style="margin: 0 0 12px 0; font-size: 11px; font-weight: 700; text-transform: uppercase; letter-spacing: 0.05em; color: #9ca3af;">Transcript</p>
    <p style="margin: 0; font-size: 13px; line-height: 1.7; color: #4a4a6a;">${opts.transcript.replace(/\n/g, "<br>")}</p>
  </div>` : ""

  return `
<!DOCTYPE html>
<html>
<head><meta charset="utf-8"></head>
<body style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; color: #1a1a2e;">
  <div style="background: #f8f9fb; border-radius: 12px; padding: 24px; margin-bottom: 16px;">
    <h2 style="margin: 0 0 16px 0; font-size: 18px; color: #0d0d1a;">Call Summary</h2>
    <table style="width: 100%; font-size: 14px; color: #4a4a6a;">
      <tr><td style="padding: 4px 12px 4px 0; font-weight: 600; width: 120px;">Caller</td><td>${opts.callerNumber}</td></tr>
      <tr><td style="padding: 4px 12px 4px 0; font-weight: 600;">Business Line</td><td>${opts.agentNumber}</td></tr>
      <tr><td style="padding: 4px 12px 4px 0; font-weight: 600;">Date</td><td>${dateStr} at ${timeStr}</td></tr>
      <tr><td style="padding: 4px 12px 4px 0; font-weight: 600;">Duration</td><td>${duration}</td></tr>
    </table>
  </div>
  <div style="background: white; border: 1px solid #e8e8f0; border-radius: 12px; padding: 24px; margin-bottom: 16px;">
    <p style="margin: 0; font-size: 14px; line-height: 1.6; color: #2a2a4a;">${opts.summary.replace(/\n/g, "<br>")}</p>
  </div>
  ${transcriptBlock}
  <div style="text-align: center; font-size: 11px; color: #9ca3af;">
    <p>Powered by Kallo AI &middot; ${opts.businessName}</p>
  </div>
</body>
</html>`
}

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 })
  }

  try {
    const raw = await req.json()
    console.log("[insights] received:", JSON.stringify(raw).substring(0, 500))

    let payload: InsightPayload

    // Telnyx native insight webhook format:
    // { record_type: "event", event_type: "conversation_insight_result", payload: { conversation_id, results: [...] } }
    if (raw?.event_type === "conversation_insight_result" && raw?.payload?.results) {
      const p = raw.payload as Record<string, unknown>
      const conversationId = p.conversation_id as string | undefined
      const results = p.results as Array<Record<string, unknown>>

      // Look up the call record by conversation_id to get agent info
      let assistantId: string | null = null
      let callId: string | null = null
      let agentTarget: string | null = null
      let endUserTarget: string | null = null
      let startedAt: string | null = null
      let endedAt: string | null = null

      if (conversationId) {
        const { data: callRow } = await supabase
          .from("calls")
          .select("id, to_number, from_number, started_at, ended_at")
          .eq("call_session_id", conversationId)
          .maybeSingle()

        if (callRow) {
          callId = callRow.id
          agentTarget = callRow.to_number
          endUserTarget = callRow.from_number
          startedAt = callRow.started_at
          endedAt = callRow.ended_at

          // Look up assistant_id from the phone number
          if (callRow.to_number) {
            const { data: phoneRow } = await supabase
              .from("phone_numbers")
              .select("assigned_agent_id")
              .eq("number", callRow.to_number)
              .maybeSingle()
            if (phoneRow?.assigned_agent_id) {
              const { data: agentRow } = await supabase
                .from("agent_settings")
                .select("telnyx_assistant_id")
                .eq("id", phoneRow.assigned_agent_id)
                .maybeSingle()
              assistantId = agentRow?.telnyx_assistant_id ?? null
            }
          }
        }
      }

      // Map results to our insight format
      // Each result may have a name field; fall back to detecting by content
      const TRANSCRIPT_TEMPLATE_ID = Deno.env.get("TELNYX_TRANSCRIPT_TEMPLATE_ID")
      const insights: InsightPayload["insights"] = results.map((r) => {
        const resultText = String(r.result ?? "")
        const insightId = r.insight_id as string | undefined
        let insightName = r.name as string | undefined
        // If no name, identify by template ID or content pattern
        if (!insightName) {
          if (insightId && TRANSCRIPT_TEMPLATE_ID && insightId === TRANSCRIPT_TEMPLATE_ID) {
            insightName = "Transcript"
          } else if (/^(Agent:|Caller:)/m.test(resultText)) {
            insightName = "Transcript"
          } else {
            insightName = "Call Summary"
          }
        }
        return { insight_name: insightName, result: resultText }
      })

      payload = {
        conversation_id: conversationId,
        call_id: callId ?? undefined,
        assistant_id: assistantId ?? undefined,
        insights,
        agent_target: agentTarget ?? undefined,
        end_user_target: endUserTarget ?? undefined,
        started_at: startedAt ?? undefined,
        ended_at: endedAt ?? undefined,
      }
      console.log("[insights] normalised from Telnyx format, assistant:", assistantId, "insights:", insights.map(i => i.insight_name))
    } else {
      // Our own self-call format (already normalised)
      payload = raw as InsightPayload
    }

    const { conversation_id, call_id: payloadCallId, assistant_id, insights, agent_target, end_user_target, started_at, ended_at } = payload

    if (!assistant_id || !insights || insights.length === 0) {
      console.log("[insights] no assistant_id or insights — skipping")
      return new Response(JSON.stringify({ received: true }), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      })
    }

    // Look up agent_settings by telnyx_assistant_id
    const { data: agent, error: agentErr } = await supabase
      .from("agent_settings")
      .select("id, company_id, business_name, voicemail_email")
      .eq("telnyx_assistant_id", assistant_id)
      .maybeSingle()

    if (agentErr) {
      console.error("[insights] agent lookup error:", agentErr.message)
    }

    const companyId = agent?.company_id ?? null
    const agentSettingsId = agent?.id ?? null
    const businessName = (agent?.business_name as string) ?? "Business"
    const voicemailEmail = agent?.voicemail_email as string | null
    const callerNumber = end_user_target ?? "Unknown"
    const agentNumber = agent_target ?? "Unknown"

    console.log("[insights] company:", companyId, "agent:", agentSettingsId, "email:", voicemailEmail)

    // Try to find matching call record — prefer call_id passed directly, then fall back to conversation_id lookup
    let callId: string | null = payloadCallId ?? null
    if (!callId && conversation_id) {
      const { data: callRow } = await supabase
        .from("calls")
        .select("id")
        .eq("call_session_id", conversation_id)
        .maybeSingle()
      callId = callRow?.id ?? null
    }
    console.log("[insights] linked call_id:", callId)

    // Store each insight and collect Call Summary + Transcript for the email
    let callSummary: string | null = null
    let callTranscript: string | null = null
    for (const insight of insights) {
      const isStructured = typeof insight.result === "object" && insight.result !== null
      const resultJson = isStructured
        ? insight.result
        : { text: String(insight.result ?? "") }

      const resultText = isStructured ? JSON.stringify(insight.result) : String(insight.result ?? "")
      if (insight.insight_name === "Call Summary") callSummary = resultText
      if (insight.insight_name === "Transcript") callTranscript = resultText

      if (companyId) {
        const { error: insertErr } = await supabase.from("call_insights").insert({
          company_id: companyId,
          conversation_id: conversation_id ?? "",
          call_id: callId,
          agent_settings_id: agentSettingsId,
          insight_name: insight.insight_name ?? "Unknown",
          insight_type: isStructured ? "structured" : "unstructured",
          result: resultJson,
          caller_number: callerNumber,
          agent_number: agentNumber,
        })
        if (insertErr) {
          console.error("[insights] insert error:", insertErr.message)
        } else {
          console.log("[insights] stored insight:", insight.insight_name)
        }
      }
    }

    // Send email via Resend if we have a call summary and email
    if (callSummary && voicemailEmail && RESEND_API_KEY) {
      try {
        const startTime = new Date(started_at ?? Date.now())
        const formattedDateTime = startTime.toLocaleDateString("en-AU", {
          day: "numeric", month: "short", year: "numeric",
        }) + " " + startTime.toLocaleTimeString("en-AU", {
          hour: "2-digit", minute: "2-digit", hour12: true,
        })

        const htmlContent = buildEmailHtml({
          businessName,
          callerNumber,
          agentNumber,
          summary: callSummary,
          transcript: callTranscript,
          startedAt: started_at ?? new Date().toISOString(),
          endedAt: ended_at ?? new Date().toISOString(),
        })

        console.log("[insights] sending email to:", voicemailEmail)
        const emailRes = await fetch("https://api.resend.com/emails", {
          method: "POST",
          headers: {
            Authorization: `Bearer ${RESEND_API_KEY}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            from: `${businessName} (Kallo AI) <${RESEND_FROM_EMAIL}>`,
            to: voicemailEmail,
            subject: `Call Summary: ${callerNumber} ${formattedDateTime}`,
            html: htmlContent,
          }),
        })
        const emailJson = await emailRes.json()
        console.log("[insights] Resend response:", emailRes.status, JSON.stringify(emailJson))
      } catch (emailErr) {
        console.error("[insights] email error:", emailErr)
      }
    } else {
      if (!callSummary) console.log("[insights] no Call Summary insight to email")
      if (!voicemailEmail) console.log("[insights] no voicemail_email configured")
      if (!RESEND_API_KEY) console.log("[insights] RESEND_API_KEY not set")
    }

    return new Response(JSON.stringify({ received: true }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    })
  } catch (e) {
    const message = e instanceof Error ? e.message : String(e)
    console.error("[insights] error:", message)
    // Always return 200 so Telnyx doesn't retry
    return new Response(JSON.stringify({ received: true, error: message }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    })
  }
})
