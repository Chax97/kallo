// POST /functions/v1/hubspot_oauth_initiate
// Headers: Authorization: Bearer <user JWT from Supabase auth>
// Returns: { url: "https://app.hubspot.com/oauth/authorize?..." }

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.0";
import { corsHeaders } from "../_shared/cors.ts";
import { signState } from "../_shared/oauth_state.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;
const HUBSPOT_CLIENT_ID = Deno.env.get("HUBSPOT_CLIENT_ID")!;
const HUBSPOT_REDIRECT_URI = Deno.env.get("HUBSPOT_REDIRECT_URI")!;
const HUBSPOT_APP_SCOPES = Deno.env.get("HUBSPOT_APP_SCOPES")!;
const HUBSPOT_OPTIONAL_SCOPES = Deno.env.get("HUBSPOT_OPTIONAL_SCOPES") ?? "";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // Authenticate caller via Supabase JWT.
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return json({ error: "Missing Authorization header" }, 401);
    }

    const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      global: { headers: { Authorization: authHeader } },
    });

    const { data: { user }, error: userError } = await supabase.auth.getUser();
    if (userError || !user) {
      return json({ error: "Invalid session" }, 401);
    }

    // Look up the caller's company and role.
    const { data: userRow, error: userRowError } = await supabase
      .from("users")
      .select("company_id, role")
      .eq("id", user.id)
      .single();

    if (userRowError || !userRow) {
      return json({ error: "User record not found" }, 404);
    }

    if (!["admin", "super_admin"].includes(userRow.role)) {
      return json({ error: "Only admins can connect CRMs" }, 403);
    }

    // Sign the state token so the callback can trust it.
    const state = await signState({
      company_id: userRow.company_id,
      user_id: user.id,
      provider: "hubspot",
    });

    // Build the HubSpot authorize URL.
    const params = new URLSearchParams({
      client_id: HUBSPOT_CLIENT_ID,
      redirect_uri: HUBSPOT_REDIRECT_URI,
      scope: HUBSPOT_APP_SCOPES,
      state,
    });
    if (HUBSPOT_OPTIONAL_SCOPES.trim()) {
      params.set("optional_scope", HUBSPOT_OPTIONAL_SCOPES);
    }

    const url = `https://app.hubspot.com/oauth/authorize?${params.toString()}`;
    return json({ url });
  } catch (err) {
    console.error("hubspot_oauth_initiate error", err);
    return json({ error: "Internal error" }, 500);
  }
});

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}