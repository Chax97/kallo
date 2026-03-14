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

  switch (eventType) {
    case "call.initiated": {
      const { error } = await supabase.from("call_logs").upsert({
        call_control_id: callData.call_control_id,
        call_leg_id: callData.call_leg_id,
        call_session_id: callData.call_session_id,
        direction: callData.direction,
        from_number: callData.from,
        to_number: callData.to,
        state: "initiated",
        started_at: new Date().toISOString(),
      }, { onConflict: "call_control_id" })
      if (error) console.error("call.initiated DB error:", error.message)
      break
    }

    case "call.answered": {
      const { error } = await supabase
        .from("call_logs")
        .update({ state: "answered", answered_at: new Date().toISOString() })
        .eq("call_control_id", callData.call_control_id)
      if (error) console.error("call.answered DB error:", error.message)
      break
    }

    case "call.hangup": {
      const durationSeconds = callData.start_time
        ? Math.floor((Date.now() - new Date(callData.start_time).getTime()) / 1000)
        : null

      const isMissed =
        callData.hangup_cause !== "normal_clearing" &&
        callData.hangup_cause !== "originator_cancel"

      const { error } = await supabase.from("call_logs").upsert(
        {
          call_control_id: callData.call_control_id,
          call_leg_id: callData.call_leg_id,
          call_session_id: callData.call_session_id,
          direction: callData.direction,
          from_number: callData.from,
          to_number: callData.to,
          state: isMissed ? "missed" : "completed",
          ended_at: new Date().toISOString(),
          hangup_cause: callData.hangup_cause,
          duration_seconds: durationSeconds,
        },
        { onConflict: "call_control_id" },
      )
      if (error) console.error("call.hangup DB error:", error.message)
      break
    }

    case "call.recording.saved": {
      const { error } = await supabase
        .from("call_logs")
        .update({
          recording_url: callData.recording_urls?.mp3 ?? callData.recording_urls?.wav,
        })
        .eq("call_control_id", callData.call_control_id)
      if (error) console.error("call.recording.saved DB error:", error.message)
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
