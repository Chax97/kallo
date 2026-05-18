// POST /functions/v1/hubspot-push-call
// Auth: service role only (called from another Edge Function).
// Body: { call_id: string, summary?: string, transcript?: string, force?: boolean }
// Response: { status: 'success' | 'skipped' | 'error', ... }

import { createClient, SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.45.0";
import { corsHeaders } from "../_shared/cors.ts";
import {
  getValidHubSpotToken,
  HubSpotNotConnectedError,
} from "../_shared/hubspot_tokens.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const HUBSPOT_API_BASE = "https://api.hubapi.com";

// HubSpot defined association type IDs.
const ASSOCIATION_CALL_TO_CONTACT = 194;

// Supabase Storage signed URLs: one year. The recording link in HubSpot
// will keep working for this long; after that we'd need to either rotate
// the URL or move recordings to a public bucket.
const RECORDING_SIGNED_URL_TTL_SECONDS = 60 * 60 * 24 * 365;
const RECORDING_BUCKET = "call_recordings";

interface PushCallBody {
  call_id?: string;
  summary?: string;
  transcript?: string;
  force?: boolean;
}

interface CallRow {
  id: string;
  company_id: string | null;
  direction: string | null;
  from_number: string | null;
  to_number: string | null;
  started_at: string | null;
  ended_at: string | null;
  duration_seconds: number | null;
  recording_url: string | null;
  storage_path: string | null;
  ai_messages: unknown;
  user_id: string | null;
  crm_sync_status: string | null;
  hubspot_engagement_id: string | null;
}

interface PhonebookRow {
  id: string;
  name: string | null;
  phone_number: string | null;
  mobile_number: string | null;
  hubspot_contact_id: string | null;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  // Service role only. This function is internal to Kallo's backend.
  // We accept either the legacy JWT-format service role key or the new
  // `sb_secret_...` format by simply comparing against the env var. No
  // decoding needed; the caller proves it's authorised by knowing the key.
  const auth = req.headers.get("Authorization");
  if (!auth?.startsWith("Bearer ")) {
    return json({ error: "Missing Authorization" }, 401);
  }
  const token = auth.slice(7).trim();
  if (!token || token !== SUPABASE_SERVICE_ROLE_KEY) {
    return json({ error: "Unauthorized: service role key required" }, 401);
  }

  let body: PushCallBody;
  try {
    body = await req.json();
  } catch {
    return json({ error: "Invalid JSON body" }, 400);
  }

  const { call_id, summary } = body;
  let { transcript } = body;
  if (!call_id) {
    return json({ error: "call_id is required" }, 400);
  }

  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
  const startTime = Date.now();

  // Load the call once and keep it around for error handling too.
  const { data: call, error: callError } = await supabase
    .from("calls")
    .select(
      "id, company_id, direction, from_number, to_number, started_at, ended_at, duration_seconds, recording_url, storage_path, ai_messages, user_id, crm_sync_status, hubspot_engagement_id",
    )
    .eq("id", call_id)
    .maybeSingle();

  if (callError) {
    return json({ status: "error", error: `Failed to load call: ${callError.message}` }, 500);
  }
  if (!call) {
    return json({ status: "error", error: "Call not found" }, 404);
  }
  if (!call.company_id) {
    return await skip(supabase, call, null, "no_company_id");
  }

  // Idempotency: don't push the same call twice unless force=true.
  if (call.crm_sync_status === "synced" && !body.force) {
    return json({
      status: "skipped",
      reason: "already_synced",
      engagement_id: call.hubspot_engagement_id,
    });
  }

  // If the caller didn't pass a transcript, build one from ai_messages on
  // the calls row. This is the normal path for internal pushes triggered
  // by telnyx-webhook; explicit Postman tests can still pass transcript
  // directly to override.
  if (!transcript && Array.isArray(call.ai_messages) && call.ai_messages.length > 0) {
    transcript = (call.ai_messages as Array<{ role?: string; content?: string }>)
      .filter((m) => m && typeof m.content === "string")
      .map((m) => `${m.role ?? "speaker"}: ${m.content}`)
      .join("\n");
  }

  try {
    // 1. Get a valid access token (refreshes if needed).
    let tokenResult;
    try {
      tokenResult = await getValidHubSpotToken(call.company_id);
    } catch (err) {
      if (err instanceof HubSpotNotConnectedError) {
        return await skip(supabase, call, null, "not_connected");
      }
      throw err;
    }

    // 2. Pick the other party number based on direction.
    const otherNumber = call.direction === "outbound" ? call.to_number : call.from_number;
    if (!otherNumber) {
      return await skip(supabase, call, tokenResult.connectionId, "no_phone_number");
    }

    // 3. Find phonebook contact by phone or mobile (two queries to avoid PostgREST escaping issues).
    const phonebook = await findPhonebookContact(supabase, call.company_id, otherNumber);

    // 4. Resolve HubSpot contact ID.
    let hubspotContactId = phonebook?.hubspot_contact_id ?? null;

    if (!hubspotContactId) {
      if (!phonebook) {
        return await skip(supabase, call, tokenResult.connectionId, "unknown_caller");
      }

      hubspotContactId = await searchHubSpotContactByPhone(
        tokenResult.accessToken,
        otherNumber,
      );

      if (!hubspotContactId) {
        // Don't auto create. Admin will be prompted later via the UI.
        return await skip(
          supabase,
          call,
          tokenResult.connectionId,
          "contact_not_in_hubspot",
        );
      }

      // Found in HubSpot. Persist the mapping for future calls.
      await persistContactMapping(
        supabase,
        call.company_id,
        tokenResult.connectionId,
        phonebook.id,
        hubspotContactId,
      );
    }

    // 5. Resolve a HubSpot-friendly recording URL.
    // The recording_url field on the calls row is a Telnyx pre-signed S3 URL
    // that expires in 10 minutes — useless for HubSpot. Use a Supabase
    // Storage signed URL from storage_path instead, which can last up to a
    // year. Fall back to the Telnyx URL only when storage_path isn't set
    // (e.g. legacy rows from before the storage upload was wired up).
    let recordingUrlForHubspot: string | null = null;
    if (call.storage_path) {
      try {
        const { data: signed, error: signError } = await supabase.storage
          .from(RECORDING_BUCKET)
          .createSignedUrl(call.storage_path, RECORDING_SIGNED_URL_TTL_SECONDS);
        if (signError) {
          console.error("Failed to sign storage URL:", signError.message);
        } else {
          recordingUrlForHubspot = signed?.signedUrl ?? null;
        }
      } catch (err) {
        console.error("Storage signed URL error:", err);
      }
    }
    if (!recordingUrlForHubspot) {
      recordingUrlForHubspot = call.recording_url;
    }

    // 6. Create the call engagement in HubSpot.
    const engagement = await createHubSpotCallEngagement({
      accessToken: tokenResult.accessToken,
      call: { ...call, recording_url: recordingUrlForHubspot },
      summary,
      transcript,
      contactId: hubspotContactId,
    });

    // 7. Update the calls row.
    await supabase
      .from("calls")
      .update({
        hubspot_engagement_id: engagement.id,
        crm_synced_at: new Date().toISOString(),
        crm_sync_status: "synced",
      })
      .eq("id", call_id);

    // 8. Store call mapping.
    await supabase
      .from("crm_object_mappings")
      .upsert({
        company_id: call.company_id,
        connection_id: tokenResult.connectionId,
        provider: "hubspot",
        kallo_object_type: "call",
        kallo_object_id: call_id,
        external_object_id: engagement.id,
        external_object_type: "call",
        last_synced_at: new Date().toISOString(),
        sync_direction: "outbound",
      }, { onConflict: "company_id,provider,kallo_object_type,kallo_object_id" });

    // 9. Log success.
    await supabase.from("crm_sync_log").insert({
      company_id: call.company_id,
      connection_id: tokenResult.connectionId,
      provider: "hubspot",
      operation: "push_call",
      kallo_object_type: "call",
      kallo_object_id: call_id,
      external_object_id: engagement.id,
      status: "success",
      http_status: 201,
      duration_ms: Date.now() - startTime,
    });

    return json({
      status: "success",
      engagement_id: engagement.id,
      contact_id: hubspotContactId,
    });
  } catch (err) {
    console.error("hubspot_push_call error", err);

    await supabase
      .from("calls")
      .update({ crm_sync_status: "failed" })
      .eq("id", call_id);

    await supabase.from("crm_sync_log").insert({
      company_id: call.company_id,
      provider: "hubspot",
      operation: "push_call",
      kallo_object_type: "call",
      kallo_object_id: call_id,
      status: "error",
      error_message: String((err as Error).message || err).slice(0, 1000),
      duration_ms: Date.now() - startTime,
    });

    return json({
      status: "error",
      error: String((err as Error).message || err),
    }, 500);
  }
});

async function findPhonebookContact(
  supabase: SupabaseClient,
  companyId: string,
  phone: string,
): Promise<PhonebookRow | null> {
  const { data: byPhone } = await supabase
    .from("phonebook_contacts")
    .select("id, name, phone_number, mobile_number, hubspot_contact_id")
    .eq("company_id", companyId)
    .eq("phone_number", phone)
    .maybeSingle();
  if (byPhone) return byPhone;

  const { data: byMobile } = await supabase
    .from("phonebook_contacts")
    .select("id, name, phone_number, mobile_number, hubspot_contact_id")
    .eq("company_id", companyId)
    .eq("mobile_number", phone)
    .maybeSingle();
  return byMobile ?? null;
}

async function persistContactMapping(
  supabase: SupabaseClient,
  companyId: string,
  connectionId: string,
  phonebookId: string,
  hubspotContactId: string,
): Promise<void> {
  await supabase
    .from("phonebook_contacts")
    .update({
      hubspot_contact_id: hubspotContactId,
      crm_last_synced_at: new Date().toISOString(),
    })
    .eq("id", phonebookId);

  await supabase
    .from("crm_object_mappings")
    .upsert({
      company_id: companyId,
      connection_id: connectionId,
      provider: "hubspot",
      kallo_object_type: "contact",
      kallo_object_id: phonebookId,
      external_object_id: hubspotContactId,
      external_object_type: "contact",
      last_synced_at: new Date().toISOString(),
      sync_direction: "bidirectional",
    }, { onConflict: "company_id,provider,kallo_object_type,kallo_object_id" });
}

async function searchHubSpotContactByPhone(
  accessToken: string,
  phone: string,
): Promise<string | null> {
  // Phone field on HubSpot can be either `phone` or `mobilephone`. Try both.
  const body = {
    filterGroups: [
      { filters: [{ propertyName: "phone", operator: "EQ", value: phone }] },
      { filters: [{ propertyName: "mobilephone", operator: "EQ", value: phone }] },
    ],
    properties: ["phone", "mobilephone", "firstname", "lastname"],
    limit: 1,
  };

  const resp = await fetch(`${HUBSPOT_API_BASE}/crm/v3/objects/contacts/search`, {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${accessToken}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(body),
  });

  if (!resp.ok) {
    const detail = await resp.text();
    throw new Error(`HubSpot contact search failed (${resp.status}): ${detail}`);
  }

  const data = await resp.json() as { results: Array<{ id: string }> };
  return data.results[0]?.id ?? null;
}

interface CreateCallParams {
  accessToken: string;
  call: CallRow;
  summary?: string;
  transcript?: string;
  contactId: string;
}

async function createHubSpotCallEngagement(
  params: CreateCallParams,
): Promise<{ id: string }> {
  const { accessToken, call, summary, transcript, contactId } = params;

  // Build the call body with summary and transcript as HTML.
  const bodyParts: string[] = [];
  if (summary) {
    bodyParts.push(
      `<p><strong>AI Summary</strong></p><p>${escapeHtml(summary)}</p>`,
    );
  }
  if (transcript) {
    bodyParts.push(
      `<p><strong>Transcript</strong></p><p>${
        escapeHtml(transcript).replace(/\n/g, "<br>")
      }</p>`,
    );
  }
  if (bodyParts.length === 0) {
    bodyParts.push("<p>Call logged from Kallo</p>");
  }

  // Prepend a small Kallo attribution so customers know where the data came from.
  bodyParts.unshift(`<p><em>Logged from Kallo</em></p>`);

  const direction = call.direction === "outbound" ? "OUTBOUND" : "INBOUND";
  const title = direction === "INBOUND"
    ? `Inbound call from ${call.from_number ?? "Unknown"}`
    : `Outbound call to ${call.to_number ?? "Unknown"}`;

  const durationMs = call.duration_seconds ? call.duration_seconds * 1000 : 0;
  const timestamp = call.ended_at ?? call.started_at ?? new Date().toISOString();

  const payload: Record<string, unknown> = {
    properties: {
      hs_timestamp: timestamp,
      hs_call_title: title,
      hs_call_body: bodyParts.join(""),
      hs_call_direction: direction,
      hs_call_duration: String(durationMs),
      hs_call_from_number: call.from_number ?? "",
      hs_call_to_number: call.to_number ?? "",
      hs_call_status: "COMPLETED",
      ...(call.recording_url && { hs_call_recording_url: call.recording_url }),
    },
    associations: [
      {
        to: { id: contactId },
        types: [
          {
            associationCategory: "HUBSPOT_DEFINED",
            associationTypeId: ASSOCIATION_CALL_TO_CONTACT,
          },
        ],
      },
    ],
  };

  const resp = await fetch(`${HUBSPOT_API_BASE}/crm/v3/objects/calls`, {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${accessToken}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(payload),
  });

  if (!resp.ok) {
    const detail = await resp.text();
    throw new Error(`HubSpot call creation failed (${resp.status}): ${detail}`);
  }

  return await resp.json();
}

async function skip(
  supabase: SupabaseClient,
  call: CallRow,
  connectionId: string | null,
  reason: string,
): Promise<Response> {
  await supabase
    .from("calls")
    .update({ crm_sync_status: "skipped" })
    .eq("id", call.id);

  if (call.company_id) {
    await supabase.from("crm_sync_log").insert({
      company_id: call.company_id,
      connection_id: connectionId,
      provider: "hubspot",
      operation: "push_call",
      kallo_object_type: "call",
      kallo_object_id: call.id,
      status: "skipped",
      error_message: reason,
    });
  }

  return json({ status: "skipped", reason });
}

function escapeHtml(text: string): string {
  return text
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#039;");
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}