Deno.serve(async (req) => {
  const { to, from } = await req.json()

  // Convert to E.164 format
  const formatE164 = (number: string) => {
  const cleaned = number.replace(/\s+/g, '').replace(/-/g, '')
  if (cleaned.startsWith('+')) return cleaned
  if (cleaned.startsWith('0')) {
    // UK mobile/landline: 07xxx, 01xxx, 02xxx
    if (cleaned.startsWith('07') || cleaned.startsWith('01') || cleaned.startsWith('02')) {
      return '+44' + cleaned.slice(1)
    }
    // Australian mobile/landline: 04xxx, 03xxx, 02xxx
    return '+61' + cleaned.slice(1)
  }
  return '+' + cleaned
}

  const toFormatted = formatE164(to)
  const fromFormatted = formatE164(from)

  const apiKey = Deno.env.get("TELNYX_API_KEY")!
  const connectionId = Deno.env.get("TELNYX_CONNECTION_ID")!

  const res = await fetch("https://api.telnyx.com/v2/calls", {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      connection_id: connectionId,
      to: toFormatted,
      from: fromFormatted,
      timeout_secs: 60,
    }),
  })

  const data = await res.json()

  if (!res.ok) {
    console.error("Telnyx call error:", JSON.stringify(data))
    return new Response(JSON.stringify({ error: data }), {
      status: res.status,
      headers: { "Content-Type": "application/json" },
    })
  }

  return new Response(
    JSON.stringify({ call_control_id: data.data?.call_control_id }),
    { headers: { "Content-Type": "application/json" } },
  )
})
