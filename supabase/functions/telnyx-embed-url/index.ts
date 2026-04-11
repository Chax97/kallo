import { createClient } from "jsr:@supabase/supabase-js@2"
import { CreateBucketCommand, S3Client } from "npm:@aws-sdk/client-s3"

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
)

const TELNYX_API_KEY = Deno.env.get("TELNYX_API_KEY")!
const TELNYX_API_BASE = "https://api.telnyx.com/v2"
const TELNYX_S3_ENDPOINT = "https://us-central-1.telnyxcloudstorage.com"

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
}

function getS3Client(): S3Client {
  return new S3Client({
    endpoint: TELNYX_S3_ENDPOINT,
    region: "us-central-1",
    credentials: {
      accessKeyId: TELNYX_API_KEY,
      secretAccessKey: TELNYX_API_KEY,
    },
    forcePathStyle: true,
  })
}

async function createBucket(bucketName: string): Promise<void> {
  const s3 = getS3Client()
  try {
    await s3.send(new CreateBucketCommand({ Bucket: bucketName }))
    console.log(`[embed-url] bucket created: ${bucketName}`)
  } catch (err: unknown) {
    const name = (err as { name?: string }).name ?? ""
    if (name === "BucketAlreadyExists" || name === "BucketAlreadyOwnedByYou") {
      console.log(`[embed-url] bucket already exists: ${bucketName}`)
      return
    }
    throw err
  }
}

async function telnyxRequest(
  method: string,
  path: string,
  body?: unknown,
): Promise<Record<string, unknown>> {
  const url = `${TELNYX_API_BASE}${path}`
  const res = await fetch(url, {
    method,
    headers: {
      Authorization: `Bearer ${TELNYX_API_KEY}`,
      "Content-Type": "application/json",
    },
    body: body ? JSON.stringify(body) : undefined,
  })
  const json = await res.json()
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
    if (!TELNYX_API_KEY) throw new Error("TELNYX_API_KEY env var is not set")

    const { agent_id, url } = await req.json() as { agent_id?: string; url?: string }
    if (!agent_id) throw new Error("agent_id is required")
    if (!url) throw new Error("url is required")

    // 1. Fetch agent to get company_id
    const { data: agent, error: agentErr } = await supabase
      .from("agent_settings")
      .select("company_id")
      .eq("id", agent_id)
      .single()

    if (agentErr) throw new Error(`DB error: ${agentErr.message}`)
    if (!agent) throw new Error(`Agent not found: ${agent_id}`)

    const companyId = agent.company_id as string

    // 2. Each URL gets its own bucket to avoid Telnyx overwriting depth-X-Y.txt files
    //    across different crawls. Bucket name derived from a fresh UUID.
    const bucketId = crypto.randomUUID().replace(/-/g, "").slice(0, 16)
    const bucketName = `kallo-url-${bucketId}`
    await createBucket(bucketName)

    // 3. Submit URL to Telnyx REST API for embedding
    console.log(`[embed-url] embedding url: ${url} into bucket: ${bucketName}`)
    const embedRes = await telnyxRequest("POST", "/ai/embeddings/url", {
      url,
      bucket_name: bucketName,
    })

    const taskId = (embedRes.task_id ?? (embedRes.data as Record<string, unknown>)?.task_id) as string | null
    console.log(`[embed-url] task_id: ${taskId}`)

    // 4. Insert knowledge item — store bucket name in `content` for use by telnyx-push-agent
    const { count } = await supabase
      .from("agent_knowledge_items")
      .select("*", { count: "exact", head: true })
      .eq("agent_id", agent_id)
      .eq("item_type", "url")
    const { error: insertErr } = await supabase
      .from("agent_knowledge_items")
      .insert({
        agent_id,
        company_id: companyId,
        item_type: "url",
        url,
        content: bucketName,
        telnyx_task_id: taskId ?? null,
        status: "ready",
        sort_order: count ?? 0,
      })

    if (insertErr) throw new Error(`Failed to save knowledge item: ${insertErr.message}`)

    // 5. Auto-sync agent so all bucket_ids stay up to date
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    const syncRes = await fetch(`${supabaseUrl}/functions/v1/telnyx-push-agent`, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${serviceKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ agent_id }),
    })
    console.log(`[embed-url] agent sync status: ${syncRes.status}`)

    return new Response(
      JSON.stringify({ success: true, task_id: taskId, bucket_name: bucketName }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } },
    )
  } catch (e) {
    const message = e instanceof Error ? e.message : String(e)
    console.error("[embed-url] error:", message)
    return new Response(JSON.stringify({ error: message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    })
  }
})
