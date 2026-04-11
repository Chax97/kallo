import { createClient } from "jsr:@supabase/supabase-js@2"
import { CreateBucketCommand, PutObjectCommand, S3Client } from "npm:@aws-sdk/client-s3"

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

/** Create the Telnyx S3 bucket (idempotent — BucketAlreadyExists is fine). */
async function ensureBucket(bucketName: string): Promise<void> {
  const s3 = getS3Client()
  try {
    await s3.send(new CreateBucketCommand({ Bucket: bucketName }))
    console.log(`[embed-doc] bucket created: ${bucketName}`)
  } catch (err: unknown) {
    const name = (err as { name?: string }).name ?? ""
    if (name === "BucketAlreadyExists" || name === "BucketAlreadyOwnedByYou") {
      console.log(`[embed-doc] bucket already exists: ${bucketName}`)
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

    const { agent_id, storage_path, file_name } = await req.json() as {
      agent_id?: string
      storage_path?: string
      file_name?: string
    }
    if (!agent_id) throw new Error("agent_id is required")
    if (!storage_path) throw new Error("storage_path is required")
    if (!file_name) throw new Error("file_name is required")

    // 1. Fetch agent to get company_id and existing bucket name
    const { data: agent, error: agentErr } = await supabase
      .from("agent_settings")
      .select("company_id, knowledge_bucket_name")
      .eq("id", agent_id)
      .single()

    if (agentErr) throw new Error(`DB error: ${agentErr.message}`)
    if (!agent) throw new Error(`Agent not found: ${agent_id}`)

    const companyId = agent.company_id as string
    let bucketName = agent.knowledge_bucket_name as string | null

    // 2. Create S3 bucket only on first use
    if (!bucketName) {
      bucketName = `kallo-kb-${agent_id}`
      await ensureBucket(bucketName)
      const { error: updateErr } = await supabase
        .from("agent_settings")
        .update({ knowledge_bucket_name: bucketName })
        .eq("id", agent_id)
      if (updateErr) {
        console.error("[embed-doc] failed to save bucket name:", updateErr.message)
      }
    }

    // 3. Download file from Supabase Storage
    console.log(`[embed-doc] downloading from Supabase Storage: ${storage_path}`)
    const { data: fileData, error: downloadErr } = await supabase.storage
      .from("Knowledge Base Documents")
      .download(storage_path)

    if (downloadErr) throw new Error(`Failed to download file: ${downloadErr.message}`)
    if (!fileData) throw new Error("Downloaded file is empty")

    const fileBytes = new Uint8Array(await fileData.arrayBuffer())

    // 4. Upload file to Telnyx S3 bucket
    console.log(`[embed-doc] uploading ${file_name} to Telnyx bucket: ${bucketName}`)
    const s3 = getS3Client()
    await s3.send(new PutObjectCommand({
      Bucket: bucketName,
      Key: file_name,
      Body: fileBytes,
      ContentType: fileData.type || "application/octet-stream",
    }))
    console.log(`[embed-doc] file uploaded to Telnyx S3: ${file_name}`)

    // 5. Trigger Telnyx embedding on the uploaded file
    console.log(`[embed-doc] triggering embedding for: ${file_name}`)
    const embedRes = await telnyxRequest("POST", "/ai/embeddings", {
      bucket_name: bucketName,
      file_key: file_name,
    })

    const taskId = (embedRes.task_id ?? (embedRes.data as Record<string, unknown>)?.task_id) as string | null
    console.log(`[embed-doc] task_id: ${taskId}`)

    // 6. Insert knowledge item into DB
    const { error: insertErr } = await supabase
      .from("agent_knowledge_items")
      .insert({
        agent_id,
        company_id: companyId,
        item_type: "document",
        content: file_name,
        telnyx_task_id: taskId ?? null,
        status: "ready",
        sort_order: 0,
      })

    if (insertErr) throw new Error(`Failed to save knowledge item: ${insertErr.message}`)

    // 7. Auto-sync agent to Telnyx so retrieval tool is up to date
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
    console.log(`[embed-doc] agent sync status: ${syncRes.status}`)

    return new Response(
      JSON.stringify({ success: true, task_id: taskId, bucket_name: bucketName }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } },
    )
  } catch (e) {
    const message = e instanceof Error ? e.message : String(e)
    console.error("[embed-doc] error:", message)
    return new Response(JSON.stringify({ error: message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    })
  }
})
