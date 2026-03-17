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
  let payload: TelnyxEvent
  try {
    payload = await req.json()
  } catch {
    return new Response("Bad Request", { status: 400 })
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
        await supabase.from("call_logs").upsert({
          call_control_id: callData.call_control_id,
          call_leg_id: callData.call_leg_id,
          call_session_id: callData.call_session_id,
          direction: callData.direction,
          from_number: callData.from,
          to_number: callData.to,
          state: "initiated",
          started_at: new Date().toISOString(),
        }, { onConflict: "call_control_id" })
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
      await supabase
        .from("call_logs")
        .update({ state: "answered", answered_at: new Date().toISOString() })
        .eq("call_control_id", callData.call_control_id)

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

      await supabase
        .from("call_logs")
        .update({
          state: finalState,
          ended_at: new Date().toISOString(),
          hangup_cause: hangupCause,
          duration_seconds: durationSeconds,
        })
        .eq("call_control_id", callData.call_control_id)
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

      if (recordingUrl && cs?.stage === "voicemail") {
        try {
          console.log("Downloading voicemail recording:", recordingUrl)
          const audioRes = await fetch(recordingUrl)
          const audioBlob = await audioRes.blob()
          // Sanitize call_control_id for use as a filename — colons and other
          // special characters cause path-encoding mismatches in Supabase Storage.
          const safeId = (callData.call_control_id ?? "unknown").replace(/[^a-zA-Z0-9\-_]/g, "_")
          const fileName = `${safeId}-${Date.now()}.mp3`
          const storagePath = `recordings/${fileName}`

          const { error: storageError } = await supabase.storage
            .from("voicemails")
            .upload(storagePath, audioBlob, {
              contentType: "audio/mpeg",
              upsert: true,
            })

          if (storageError) {
            console.error("Storage error:", storageError.message)
          } else {
            await supabase.from("voicemails").insert({
              call_control_id: callData.call_control_id,
              from_number: (cs.original_from as string) ?? callData.from,
              to_number: (cs.original_to as string) ?? callData.to,
              recording_url: recordingUrl,
              storage_path: storagePath,
              duration_seconds: durationSecs,
            })
            console.log("Voicemail saved to storage:", storagePath)
          }
        } catch (e) {
          console.error("Recording error:", e)
        }
      }

      await supabase
        .from("call_logs")
        .update({
          recording_url: recordingUrl,
          // Lock in "voicemail" state now so call.hangup can't overwrite it
          // with "missed" if the client_state is somehow unavailable later.
          ...(cs?.stage === "voicemail" ? { state: "voicemail" } : {}),
        })
        .eq("call_control_id", callData.call_control_id)
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
