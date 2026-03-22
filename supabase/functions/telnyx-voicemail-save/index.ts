import { createClient } from "jsr:@supabase/supabase-js@2"

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
)

Deno.serve(async (req) => {
  const formData = await req.formData()

  const recordingUrl = formData.get("RecordingUrl")?.toString()
  const from = formData.get("From")?.toString()
  const to = formData.get("To")?.toString()
  const duration = parseInt(formData.get("RecordingDuration")?.toString() ?? "0")
  const callControlId = formData.get("CallControlId")?.toString()

  console.log("Voicemail recording received:", { recordingUrl, from, to, duration })

  if (recordingUrl) {
    try {
      const audioRes = await fetch(recordingUrl)
      const audioBlob = await audioRes.blob()
      const fileName = `${Date.now()}-${from}.mp3`
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
        const { error: dbError } = await supabase.from("voicemails").insert({
          call_control_id: callControlId,
          from_number: from,
          to_number: to,
          recording_url: recordingUrl,
          storage_path: storagePath,
          duration_seconds: duration,
        })
        if (dbError) console.error("DB error:", dbError.message)
        else console.log("Voicemail saved:", storagePath)
      }
    } catch (e) {
      console.error("Error saving voicemail:", e)
    }
  }

  return new Response(
    `<?xml version="1.0" encoding="UTF-8"?><Response><Hangup/></Response>`,
    { headers: { "Content-Type": "text/xml" } },
  )
})
