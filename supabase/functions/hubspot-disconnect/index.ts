// POST /functions/v1/hubspot-disconnect
// Auth: user JWT (admin or super_admin only).
// Revokes the HubSpot refresh token (best effort) and marks the connection disconnected.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.0";
import { corsHeaders } from "../_shared/cors.ts";
import { decryptSecret } from "../_shared/crypto.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const authHeader = req.headers.get("Authorization");
  if (!authHeader) return json({ error: "Missing Authorization" }, 401);

  const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    global: { headers: { Authorization: authHeader } },
  });

  const { data: { user }, error: userError } = await userClient.auth.getUser();
  if (userError || !user) return json({ error: "Invalid session" }, 401);

  const { data: userRow } = await userClient
    .from("users")
    .select("company_id, role")
    .eq("id", user.id)
    .single();

  if (!userRow || !["admin", "super_admin"].includes(userRow.role)) {
    return json({ error: "Only admins can disconnect CRMs" }, 403);
  }

  let body: { provider?: string };
  try {
    body = await req.json();
  } catch {
    return json({ error: "Invalid JSON body" }, 400);
  }
  const provider = body.provider ?? "hubspot";

  const admin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
  const { data: conn } = await admin
    .from("crm_connections")
    .select("id, refresh_token, status")
    .eq("company_id", userRow.company_id)
    .eq("provider", provider)
    .maybeSingle();

  if (!conn) return json({ status: "not_connected" });

  // Best effort revoke at HubSpot. We don't fail the disconnect if revocation fails.
  if (provider === "hubspot" && conn.refresh_token) {
    try {
      const refreshToken = await decryptSecret(conn.refresh_token);
      await fetch(
        `https://api.hubapi.com/oauth/v1/refresh-tokens/${refreshToken}`,
        { method: "DELETE" },
      );
    } catch (err) {
      console.warn("Token revocation failed (continuing):", err);
    }
  }

  await admin
    .from("crm_connections")
    .update({ status: "disconnected", error_message: null })
    .eq("id", conn.id);

  await admin.from("crm_sync_log").insert({
    company_id: userRow.company_id,
    connection_id: conn.id,
    provider,
    operation: "oauth_disconnect",
    status: "success",
  });

  return json({ status: "success" });
});

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}