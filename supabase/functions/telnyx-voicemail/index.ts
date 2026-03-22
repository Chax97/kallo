import { createClient } from "jsr:@supabase/supabase-js@2"

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
)

const TELNYX_API_KEY = Deno.env.get("TELNYX_API_KEY")!

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

interface TelnyxCallPayload {
  call_control_id?: string
  call_session_id?: string
  hangup_cause?: string
}

interface TelnyxEvent {
  data?: {
    event_type?: string
    payload?: TelnyxCallPayload
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

  console.log("Voicemail webhook event:", eventType, callData?.call_control_id)

  if (!eventType || !callData) {
    return new Response(JSON.stringify({ received: true }), {
      headers: { "Content-Type": "application/json" },
      status: 200,
    })
  }

  switch (eventType) {
    case "call.initiated": {
      // This is the b-leg (SIP ringing leg) — it is outbound from Telnyx's perspective.
      // Cannot answer it. Just log and wait for call.hangup if it times out.
      console.log("Voicemail: b-leg initiated, session:", callData.call_session_id)
      break
    }

    case "call.bridged": {
      // B-leg bridged to a-leg (SIP is ringing the app). Nothing to do here.
      console.log("Voicemail: b-leg bridged, session:", callData.call_session_id)
      break
    }

    case "call.hangup": {
      // B-leg hung up. If the transfer timed out (app didn't answer), the original
      // caller (a-leg) is still alive. Find it by call_session_id and play voicemail.
      console.log("Voicemail: b-leg hung up, cause:", callData.hangup_cause, "session:", callData.call_session_id)

      // If the caller hung up, the a-leg is already gone — nothing to do
      if (callData.hangup_cause === "originator_cancel") {
        console.log("Voicemail: caller hung up, skipping voicemail")
        break
      }

      if (!callData.call_session_id) break

      // Find the a-leg — same session, different call_control_id
      const { data: aLeg } = await supabase
        .from("call_logs")
        .select("call_control_id, state, answered_by")
        .eq("call_session_id", callData.call_session_id)
        .neq("call_control_id", callData.call_control_id)
        .maybeSingle()

      console.log("Voicemail: a-leg lookup result:", aLeg)

      if (!aLeg?.call_control_id) {
        console.log("Voicemail: no a-leg found for session", callData.call_session_id)
        break
      }

      // Skip if app already answered, or call already ended/in voicemail
      if (
        aLeg.answered_by === "app" ||
        aLeg.state === "completed" ||
        aLeg.state === "voicemail"
      ) {
        console.log("Voicemail: a-leg not eligible, state:", aLeg.state, "answered_by:", aLeg.answered_by)
        break
      }

      console.log("Voicemail: speaking greeting on a-leg", aLeg.call_control_id)

      // Mark a-leg as voicemail so the main webhook handles speak.ended + recording
      await supabase
        .from("call_logs")
        .update({ state: "voicemail" })
        .eq("call_control_id", aLeg.call_control_id)

      await callControlAction(aLeg.call_control_id, "speak", {
        payload:
          "Hi, you have reached Kallo. We are unable to take your call right now. Please leave a message after the beep and we will get back to you as soon as possible.",
        voice: "female",
        language: "en-AU",
      })
      break
    }

    default:
      console.log("Voicemail: unhandled event type:", eventType)
  }

  return new Response(JSON.stringify({ received: true }), {
    headers: { "Content-Type": "application/json" },
    status: 200,
  })
})
