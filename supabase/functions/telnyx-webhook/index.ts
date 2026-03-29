import { createClient } from "jsr:@supabase/supabase-js@2"

interface TelnyxCallPayload {
  call_control_id?: string
  call_leg_id?: string
  call_session_id?: string
  direction?: string
  from?: string
  to?: string
  hangup_cause?: string
  start_time?: string
  recording_urls?: { mp3?: string; wav?: string }
  public_recording_urls?: { mp3?: string; wav?: string }
  duration_millis?: number
  recording_duration_secs?: number
  recording_started_at?: string
  recording_ended_at?: string
  client_state?: string
  // TeXML analyzed event fields (raw strings from form data)
  _recordings?: string
  _conversation_insights?: string
  _conversation_id?: string
  _answered_time?: string
  _call_duration?: string
}

interface TelnyxEvent {
  data?: {
    event_type?: string
    payload?: TelnyxCallPayload
  }
}

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
)

const TELNYX_API_KEY = Deno.env.get("TELNYX_API_KEY")!
const TELNYX_CONNECTION_ID = Deno.env.get("TELNYX_CONNECTION_ID")!

async function callControlAction(
  callControlId: string,
  action: string,
  params: Record<string, unknown> = {},
) {
  const res = await fetch(
    `https://api.telnyx.com/v2/calls/${callControlId}/actions/${action}`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${TELNYX_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(params),
    },
  )
  const data = await res.json()
  if (!res.ok) console.error(`${action} error:`, JSON.stringify(data))
  return data
}

function decodeClientState(encoded?: string): Record<string, unknown> {
  try {
    if (!encoded) return {}
    return JSON.parse(atob(encoded))
  } catch {
    return {}
  }
}

Deno.serve(async (req) => {
  const contentType = req.headers.get("content-type") ?? ""
  let payload: TelnyxEvent

  // TeXML status_callback sends form-urlencoded; normal webhooks send JSON
  if (contentType.includes("application/x-www-form-urlencoded")) {
    const formData = await req.formData()
    const formObj: Record<string, string> = {}
    formData.forEach((value, key) => { formObj[key] = value.toString() })
    console.log("TeXML status_callback form data:", JSON.stringify(formObj))

    // Map TeXML status_callback fields to our standard format
    const callStatus = formObj["CallStatus"] ?? formObj["callstatus"] ?? ""
    const eventMap: Record<string, string> = {
      "ringing": "call.initiated",
      "in-progress": "call.answered",
      "completed": "call.hangup",
      "busy": "call.hangup",
      "no-answer": "call.hangup",
      "failed": "call.hangup",
      "canceled": "call.hangup",
      "analyzed": "call.analyzed",
    }
    // If no CallStatus but has CallInitiatedAt, this is the initial call event
    let mappedEvent = eventMap[callStatus.toLowerCase()] ?? ""
    if (!mappedEvent && (formObj["CallInitiatedAt"] || formObj["CallerId"])) {
      mappedEvent = "call.initiated"
    }

    const hangupCause = callStatus.toLowerCase() === "completed" ? "normal_clearing"
      : callStatus.toLowerCase() === "no-answer" ? "no_answer"
      : callStatus.toLowerCase() === "busy" ? "busy"
      : callStatus.toLowerCase() === "canceled" ? "originator_cancel"
      : callStatus || undefined

    payload = {
      data: {
        event_type: mappedEvent || undefined,
        payload: {
          call_control_id: formObj["CallSid"] ?? formObj["callsid"] ?? undefined,
          call_leg_id: formObj["CallLegId"] ?? formObj["CallControlId"] ?? undefined,
          call_session_id: formObj["CallSessionId"] ?? formObj["CallSid"] ?? undefined,
          direction: "incoming", // TeXML status_callback is always inbound to the AI assistant
          from: formObj["From"] ?? formObj["Caller"] ?? formObj["CallerId"] ?? undefined,
          to: formObj["To"] ?? formObj["Called"] ?? undefined,
          start_time: formObj["StartTime"] ?? formObj["CallInitiatedAt"] ?? undefined,
          hangup_cause: hangupCause,
          duration_millis: formObj["CallDuration"] ? parseInt(formObj["CallDuration"]) * 1000 : undefined,
          // Mark as AI assistant call so we skip SIP dial logic
          client_state: btoa(JSON.stringify({ stage: "ai_assistant" })),
          // Pass analyzed event fields
          _recordings: formObj["Recordings"] ?? undefined,
          _conversation_insights: formObj["ConversationInsights"] ?? undefined,
          _conversation_id: formObj["ConversationId"] ?? undefined,
          _answered_time: formObj["AnsweredTime"] ?? undefined,
          _call_duration: formObj["CallDuration"] ?? undefined,
        },
      },
    }
  } else {
    try {
      payload = await req.json()
    } catch {
      const rawBody = await req.text()
      console.log("Failed to parse request body:", rawBody.substring(0, 500))
      return new Response("Bad Request", { status: 400 })
    }
  }

  const eventType = payload?.data?.event_type
  const callData = payload?.data?.payload

  console.log("Telnyx event:", eventType, callData?.call_control_id)

  if (!eventType || !callData) {
    return new Response(JSON.stringify({ received: true }), {
      headers: { "Content-Type": "application/json" },
      status: 200,
    })
  }

  const cs = decodeClientState(callData.client_state)

  switch (eventType) {
    case "call.initiated": {
      const sipUser = Deno.env.get("TELNYX_SIP_USER") ?? ""
      const isToSipUser = callData.to?.includes(sipUser) ?? false

      // Skip SIP b-leg records — they are internal routing legs and should
      // not appear in the call history.
      if (!isToSipUser) {
        const callRecord = {
          call_control_id: callData.call_control_id,
          call_leg_id: callData.call_leg_id,
          call_session_id: callData.call_session_id,
          direction: callData.direction,
          from_number: callData.from,
          to_number: callData.to,
          state: "initiated",
          started_at: new Date().toISOString(),
        }
        await supabase.from("call_logs").upsert(callRecord, { onConflict: "call_control_id" })

        // Also write to `calls` table (used by the admin portal)
        // Look up company_id from the phone number (to_number for inbound, from_number for outbound)
        const didNumber = callData.direction === "incoming" ? callData.to : callData.from
        let companyId: string | null = null
        if (didNumber) {
          const { data: phoneRow } = await supabase
            .from("phone_numbers")
            .select("company_id")
            .eq("number", didNumber)
            .maybeSingle()
          companyId = phoneRow?.company_id ?? null
        }

        await supabase.from("calls").upsert({
          telnyx_call_id: callData.call_control_id,
          call_leg_id: callData.call_leg_id,
          call_session_id: callData.call_session_id,
          direction: callData.direction === "incoming" ? "inbound" : "outbound",
          from_number: callData.from,
          to_number: callData.to,
          status: "initiated",
          started_at: new Date().toISOString(),
          ...(companyId ? { company_id: companyId } : {}),
        }, { onConflict: "telnyx_call_id" })
      }

      // Dial the SIP user only for fresh inbound calls on the DID.
      // Guard against the dial loop: isToSipUser catches the SIP credentials
      // connection re-firing call.initiated when it receives our b-leg dial.
      if (callData.direction === "incoming" && !cs?.stage && !isToSipUser) {
        const res = await fetch("https://api.telnyx.com/v2/calls", {
          method: "POST",
          headers: {
            Authorization: `Bearer ${TELNYX_API_KEY}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            connection_id: TELNYX_CONNECTION_ID,
            to: `sip:${Deno.env.get("TELNYX_SIP_USER")}@sip.telnyx.com`,
            from: callData.from,
            timeout_secs: 20,
            client_state: btoa(JSON.stringify({
              stage: "dial",
              inbound_call_control_id: callData.call_control_id,
              original_from: callData.from,
              original_to: callData.to,
            })),
          }),
        })
        const dialData = await res.json()
        console.log("Dialed SIP user:", dialData?.data?.call_control_id)
      }
      break
    }

    case "call.answered": {
      const answeredAt = new Date().toISOString()
      await supabase
        .from("call_logs")
        .update({ state: "answered", answered_at: answeredAt })
        .eq("call_control_id", callData.call_control_id)

      await supabase
        .from("calls")
        .update({ status: "answered", answered_at: answeredAt })
        .eq("telnyx_call_id", callData.call_control_id)

      if (cs?.stage === "dial" && cs?.inbound_call_control_id) {
        // App answered the SIP b-leg — bridge it to the original inbound a-leg
        console.log("SIP user answered — bridging to inbound call", cs.inbound_call_control_id)
        await supabase
          .from("call_logs")
          .update({ state: "answered", answered_by: "app", answered_at: new Date().toISOString() })
          .eq("call_control_id", cs.inbound_call_control_id as string)
        await callControlAction(callData.call_control_id!, "bridge", {
          call_control_id: cs.inbound_call_control_id,
        })
        // Start recording the inbound (a-leg) — captures both sides after bridge
        await callControlAction(cs.inbound_call_control_id as string, "record_start", {
          format: "mp3",
          channels: "dual",
          play_beep: false,
        })
        console.log("Recording started on inbound leg", cs.inbound_call_control_id)
      } else if (cs?.stage === "voicemail") {
        // Voicemail a-leg answered — play greeting
        console.log("Voicemail call answered — playing greeting")
        await callControlAction(callData.call_control_id!, "speak", {
          payload:
            "Hi, you have reached Kallo. We are unable to take your call right now. Please leave a message after the beep and we will get back to you as soon as possible.",
          voice: "female",
          language: "en-AU",
        })
      }
      break
    }

    case "call.speak.ended": {
      if (cs?.stage === "voicemail") {
        console.log("Voicemail greeting finished — starting recording")
        await callControlAction(callData.call_control_id!, "record_start", {
          format: "mp3",
          channels: "single",
          play_beep: true,
          time_limit_secs: 120,
          silence_duration_secs: 5,
        })
      }
      break
    }

    case "call.hangup": {
      const hangupCause = callData.hangup_cause ?? ""
      const isCompleted = hangupCause === "normal_clearing"

      console.log(`Hangup: stage=${cs?.stage}, cause=${hangupCause}, id=${callData.call_control_id}`)

      // ── B-leg (SIP forwarding leg) ────────────────────────────────────────
      // All b-leg hangups carry cs.stage === "dial". Trigger voicemail if
      // eligible, then break — b-leg records are never written to call_logs.
      if (cs?.stage === "dial") {
        if (hangupCause !== "originator_cancel" && cs?.inbound_call_control_id) {
          const { data: aLeg } = await supabase
            .from("call_logs")
            .select("state")
            .eq("call_control_id", cs.inbound_call_control_id as string)
            .maybeSingle()

          if (aLeg?.state === "initiated") {
            console.log(`SIP b-leg ended (${hangupCause}) — answering inbound call for voicemail`)
            await callControlAction(cs.inbound_call_control_id as string, "answer", {
              client_state: btoa(JSON.stringify({
                stage: "voicemail",
                original_from: cs.original_from,
                original_to: cs.original_to,
              })),
            })
          } else {
            console.log(`SIP b-leg ended (${hangupCause}) but a-leg state=${aLeg?.state} — skipping voicemail`)
          }
        }
        break // Never log b-leg records regardless of hangup cause
      }

      // ── A-leg / outbound calls ────────────────────────────────────────────
      // Look up the existing record — direction is often missing from the
      // hangup payload. If no record exists this is an unknown internal event;
      // skip it rather than ghost-creating a new row.
      const { data: callLog } = await supabase
        .from("call_logs")
        .select("direction, answered_by, state")
        .eq("call_control_id", callData.call_control_id)
        .maybeSingle()

      if (!callLog) {
        // Check if it exists in the calls table (AI assistant calls write there directly)
        const { data: callRow } = await supabase
          .from("calls")
          .select("direction, status")
          .eq("telnyx_call_id", callData.call_control_id)
          .maybeSingle()

        if (callRow) {
          console.log(`Hangup: found in calls table, updating`)
          const durationSecs = callData.start_time
            ? Math.floor((Date.now() - new Date(callData.start_time).getTime()) / 1000)
            : null
          await supabase
            .from("calls")
            .update({
              status: isCompleted ? "completed" : "missed",
              state: isCompleted ? "completed" : "missed",
              ended_at: new Date().toISOString(),
              hangup_cause: hangupCause,
              duration_seconds: durationSecs,
            })
            .eq("telnyx_call_id", callData.call_control_id)
          break
        }

        console.log(`Hangup: no record found for ${callData.call_control_id} — skipping`)
        break
      }

      const direction = callLog.direction ?? callData.direction
      const durationSeconds = callData.start_time
        ? Math.floor((Date.now() - new Date(callData.start_time).getTime()) / 1000)
        : null

      // Preserve "voicemail" state already written by call.recording.saved.
      const finalState = callLog.state === "voicemail" || cs?.stage === "voicemail"
        ? "voicemail"
        : isCompleted ? "completed" : "missed"

      console.log(`Hangup DB update: direction=${direction}, cause=${hangupCause}, finalState=${finalState}`)

      const endedAt = new Date().toISOString()
      await supabase
        .from("call_logs")
        .update({
          state: finalState,
          ended_at: endedAt,
          hangup_cause: hangupCause,
          duration_seconds: durationSeconds,
        })
        .eq("call_control_id", callData.call_control_id)

      await supabase
        .from("calls")
        .update({
          status: finalState,
          state: finalState,
          ended_at: endedAt,
          hangup_cause: hangupCause,
          duration_seconds: durationSeconds,
        })
        .eq("telnyx_call_id", callData.call_control_id)
      break
    }

    case "call.recording.saved": {
      const recordingUrl =
        callData.public_recording_urls?.mp3 ??
        callData.recording_urls?.mp3 ??
        callData.recording_urls?.wav

      const durationSecs = callData.recording_duration_secs
        ?? (callData.recording_started_at && callData.recording_ended_at
          ? Math.round((new Date(callData.recording_ended_at).getTime() - new Date(callData.recording_started_at).getTime()) / 1000)
          : Math.floor((callData.duration_millis ?? 0) / 1000))

      console.log("call.recording.saved: stage=", cs?.stage, "durationSecs=", durationSecs, "url=", recordingUrl)

      const isVoicemail = cs?.stage === "voicemail"
      let savedStoragePath: string | null = null

      if (recordingUrl) {
        try {
          console.log("Downloading recording:", recordingUrl, "stage=", cs?.stage)
          const audioRes = await fetch(recordingUrl)
          const audioBlob = await audioRes.blob()
          const safeId = (callData.call_control_id ?? "unknown").replace(/[^a-zA-Z0-9\-_]/g, "_")
          const fileName = `${safeId}-${Date.now()}.mp3`
          const bucket = isVoicemail ? "voicemails" : "call_recordings"
          const storagePath = isVoicemail ? `recordings/${fileName}` : fileName

          const { error: storageError } = await supabase.storage
            .from(bucket)
            .upload(storagePath, audioBlob, {
              contentType: "audio/mpeg",
              upsert: true,
            })

          if (storageError) {
            console.error("Storage error:", storageError.message)
          } else {
            savedStoragePath = storagePath
            if (isVoicemail) {
              await supabase.from("voicemails").insert({
                call_control_id: callData.call_control_id,
                from_number: (cs.original_from as string) ?? callData.from,
                to_number: (cs.original_to as string) ?? callData.to,
                recording_url: recordingUrl,
                storage_path: storagePath,
                duration_seconds: durationSecs,
              })
            }
            console.log("Recording saved to storage:", storagePath)
          }
        } catch (e) {
          console.error("Recording error:", e)
        }
      }

      await supabase
        .from("call_logs")
        .update({
          recording_url: recordingUrl,
          ...(savedStoragePath ? { storage_path: savedStoragePath } : {}),
          ...(isVoicemail ? { state: "voicemail" } : {}),
        })
        .eq("call_control_id", callData.call_control_id)

      await supabase
        .from("calls")
        .update({
          recording_url: recordingUrl,
          ...(savedStoragePath ? { storage_path: savedStoragePath } : {}),
          ...(isVoicemail ? { status: "voicemail" } : {}),
        })
        .eq("telnyx_call_id", callData.call_control_id)
      break
    }

    case "call.analyzed": {
      // Post-call analysis from AI assistant — contains recordings, insights, transcript
      console.log("[analyzed] Processing AI assistant post-call data for", callData.call_control_id)

      let recordingUrl: string | null = null
      let durationSeconds: number | null = null
      let storagePath: string | null = null

      // Parse recordings
      try {
        const recordings = JSON.parse(callData._recordings ?? "[]")
        if (Array.isArray(recordings) && recordings.length > 0) {
          const rec = recordings[0]
          recordingUrl = rec.download_urls?.mp3 ?? null
          if (rec.start_time && rec.end_time) {
            durationSeconds = Math.round(
              (new Date(rec.end_time).getTime() - new Date(rec.start_time).getTime()) / 1000
            )
          }
          console.log("[analyzed] recording URL:", recordingUrl, "duration:", durationSeconds)
        }
      } catch (e) {
        console.error("[analyzed] failed to parse recordings:", e)
      }

      // Parse conversation insights
      let insightSummary: string | null = null
      try {
        const insights = JSON.parse(callData._conversation_insights ?? "[]")
        if (Array.isArray(insights) && insights.length > 0) {
          const results = insights[0]?.conversation_insights
          if (Array.isArray(results) && results.length > 0) {
            insightSummary = results[0]?.result ?? null
          }
        }
        console.log("[analyzed] insight summary:", insightSummary?.substring(0, 100))
      } catch (e) {
        console.error("[analyzed] failed to parse insights:", e)
      }

      // Download and store the recording
      if (recordingUrl) {
        try {
          const audioRes = await fetch(recordingUrl)
          const audioBlob = await audioRes.blob()
          const safeId = (callData.call_control_id ?? "unknown").replace(/[^a-zA-Z0-9\-_]/g, "_")
          const fileName = `${safeId}-${Date.now()}.mp3`

          const { error: storageError } = await supabase.storage
            .from("call_recordings")
            .upload(fileName, audioBlob, { contentType: "audio/mpeg", upsert: true })

          if (storageError) {
            console.error("[analyzed] storage error:", storageError.message)
          } else {
            storagePath = fileName
            console.log("[analyzed] recording saved:", storagePath)
          }
        } catch (e) {
          console.error("[analyzed] recording download error:", e)
        }
      }

      // Look up the phone number to get company_id
      const didNumber = callData.to
      let companyId: string | null = null
      if (didNumber) {
        const { data: phoneRow } = await supabase
          .from("phone_numbers")
          .select("company_id")
          .eq("number", didNumber)
          .maybeSingle()
        companyId = phoneRow?.company_id ?? null
      }

      // Upsert into calls table with all the AI assistant data
      const callDurationSecs = callData._call_duration ? parseInt(callData._call_duration) : durationSeconds
      const { error: upsertError } = await supabase.from("calls").upsert({
        telnyx_call_id: callData.call_control_id,
        call_session_id: callData.call_session_id,
        direction: "inbound",
        from_number: callData.from,
        to_number: callData.to,
        status: "completed",
        state: "completed",
        started_at: callData.start_time ?? callData._answered_time,
        answered_at: callData._answered_time,
        ended_at: new Date().toISOString(),
        duration_seconds: callDurationSecs,
        recording_url: recordingUrl,
        storage_path: storagePath,
        hangup_cause: "normal_clearing",
        answered_by: "ai_assistant",
        ...(companyId ? { company_id: companyId } : {}),
      }, { onConflict: "telnyx_call_id" })

      if (upsertError) {
        console.error("[analyzed] calls upsert error:", upsertError.message)
      } else {
        console.log("[analyzed] call record saved/updated")
      }

      break
    }

    default:
      console.log("Unhandled event type:", eventType)
  }

  return new Response(JSON.stringify({ received: true }), {
    headers: { "Content-Type": "application/json" },
    status: 200,
  })
})
