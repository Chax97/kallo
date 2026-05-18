// POST /functions/v1/hubspot-update-engagement-body
// Auth: service role only (called from telnyx-webhook when call.analyzed
// arrives after the initial HubSpot push has already created an engagement).
// Body: { call_id: string }
// Response: { status: 'success' | 'skipped' | 'error', ... }
//
// Reads ai_summary from the calls row and PATCHes the existing HubSpot
// call engagement to prepend the summary. The engagement is identified
// via the hubspot_engagement_id stored on the calls row when the initial
// push ran.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.0";
import { corsHeaders } from "../_shared/cors.ts";
import {
  getValidHubSpotToken,
  HubSpotNotConnectedError,
} from "../_shared/hubspot_tokens.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const HUBSPOT_API_BASE = "https://api.hubapi.com";

interface UpdateBody {
  call_id?: string;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  // Service role only. Accepts either the legacy JWT-format key or the new
  // sb_secret_ format via simple equality comparison.
  const auth = req.headers.get("Authorization");
  if (!auth?.startsWith("Bearer ")) {
    return json({ error: "Missing Authorization" }, 401);
  }
  const token = auth.slice(7).trim();
  if (!token || token !== SUPABASE_SERVICE_ROLE_KEY) {
    return json({ error: "Unauthorized: service role key required" }, 401);
  }

  let body: UpdateBody;
  try {
    body = await req.json();
  } catch {
    return json({ error: "Invalid JSON body" }, 400);
  }

  const { call_id } = body;
  if (!call_id) {
    return json({ error: "call_id is required" }, 400);
  }

  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
  const startTime = Date.now();

  const { data: call, error: callError } = await supabase
    .from("calls")
    .select(
      "id, company_id, from_number, to_number, direction, ai_messages, ai_summary, hubspot_engagement_id",
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
    return json({ status: "skipped", reason: "no_company_id" });
  }
  if (!call.hubspot_engagement_id) {
    return json({ status: "skipped", reason: "no_engagement_yet" });
  }
  if (!call.ai_summary) {
    return json({ status: "skipped", reason: "no_summary" });
  }

  try {
    const tokenResult = await getValidHubSpotToken(call.company_id).catch(
      (err) => {
        if (err instanceof HubSpotNotConnectedError) return null;
        throw err;
      },
    );
    if (!tokenResult) {
      return json({ status: "skipped", reason: "not_connected" });
    }

    // Rebuild the engagement body with summary at the top, attribution,
    // then transcript. This overwrites whatever was there before, which is
    // fine because the calls row holds the canonical inputs.
    const transcriptText = Array.isArray(call.ai_messages) && call.ai_messages.length > 0
      ? (call.ai_messages as Array<{ role?: string; content?: string }>)
        .filter((m) => m && typeof m.content === "string")
        .map((m) => `${m.role ?? "speaker"}: ${m.content}`)
        .join("\n")
      : null;

    const parts: string[] = [`<p><em>Logged from Kallo</em></p>`];
    parts.push(
      `<p><strong>AI Summary</strong></p><p>${escapeHtml(call.ai_summary)}</p>`,
    );
    if (transcriptText) {
      parts.push(
        `<p><strong>Transcript</strong></p><p>${
          escapeHtml(transcriptText).replace(/\n/g, "<br>")
        }</p>`,
      );
    }

    const resp = await fetch(
      `${HUBSPOT_API_BASE}/crm/v3/objects/calls/${call.hubspot_engagement_id}`,
      {
        method: "PATCH",
        headers: {
          "Authorization": `Bearer ${tokenResult.accessToken}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          properties: { hs_call_body: parts.join("") },
        }),
      },
    );

    if (!resp.ok) {
      const detail = await resp.text();
      throw new Error(`HubSpot engagement PATCH failed (${resp.status}): ${detail}`);
    }

    await supabase.from("crm_sync_log").insert({
      company_id: call.company_id,
      connection_id: tokenResult.connectionId,
      provider: "hubspot",
      operation: "update_engagement_body",
      kallo_object_type: "call",
      kallo_object_id: call_id,
      external_object_id: call.hubspot_engagement_id,
      status: "success",
      http_status: resp.status,
      duration_ms: Date.now() - startTime,
    });

    return json({
      status: "success",
      engagement_id: call.hubspot_engagement_id,
    });
  } catch (err) {
    console.error("hubspot_update_engagement_body error", err);

    await supabase.from("crm_sync_log").insert({
      company_id: call.company_id,
      provider: "hubspot",
      operation: "update_engagement_body",
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