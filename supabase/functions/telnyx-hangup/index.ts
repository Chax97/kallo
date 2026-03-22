Deno.serve(async (req) => {
  const { call_control_id } = await req.json()

  const apiKey = Deno.env.get("TELNYX_API_KEY")!

  const res = await fetch(
    `https://api.telnyx.com/v2/calls/${call_control_id}/actions/hangup`,
    {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({}),
    },
  )

  if (!res.ok) {
    const data = await res.json()
    console.error("Telnyx hangup error:", JSON.stringify(data))
    return new Response(JSON.stringify({ error: data }), {
      status: res.status,
      headers: { "Content-Type": "application/json" },
    })
  }

  return new Response(JSON.stringify({ ok: true }), {
    headers: { "Content-Type": "application/json" },
  })
})
