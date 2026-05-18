// GET /functions/v1/hubspot_oauth_callback?code=...&state=...
// Redirected to by HubSpot after the user grants access.
// Persists encrypted tokens and redirects browser back to APP_URL.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.0";
import { corsHeaders } from "../_shared/cors.ts";
import { verifyState } from "../_shared/oauth_state.ts";
import { encryptSecret } from "../_shared/crypto.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const HUBSPOT_CLIENT_ID = Deno.env.get("HUBSPOT_CLIENT_ID")!;
const HUBSPOT_CLIENT_SECRET = Deno.env.get("HUBSPOT_CLIENT_SECRET")!;
const HUBSPOT_REDIRECT_URI = Deno.env.get("HUBSPOT_REDIRECT_URI")!;
const APP_URL = Deno.env.get("APP_URL")!;

const HUBSPOT_TOKEN_URL = "https://api.hubapi.com/oauth/v1/token";
const HUBSPOT_ACCESS_TOKEN_INFO_URL =
  "https://api.hubapi.com/oauth/v1/access-tokens";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const url = new URL(req.url);
  const code = url.searchParams.get("code");
  const stateToken = url.searchParams.get("state");
  const hubspotError = url.searchParams.get("error");

  // User cancelled or HubSpot returned an error.
  if (hubspotError) {
    return redirectToApp({
      provider: "hubspot",
      status: "error",
      message: hubspotError,
    });
  }

  if (!code || !stateToken) {
    return redirectToApp({
      provider: "hubspot",
      status: "error",
      message: "missing_code_or_state",
    });
  }

  // Verify our signed state token. Untrusted input until this passes.
  const state = await verifyState(stateToken);
  if (!state || state.provider !== "hubspot") {
    return redirectToApp({
      provider: "hubspot",
      status: "error",
      message: "invalid_state",
    });
  }

  try {
    // Exchange the auth code for access and refresh tokens.
    const tokenBody = new URLSearchParams({
      grant_type: "authorization_code",
      client_id: HUBSPOT_CLIENT_ID,
      client_secret: HUBSPOT_CLIENT_SECRET,
      redirect_uri: HUBSPOT_REDIRECT_URI,
      code,
    });

    const tokenResp = await fetch(HUBSPOT_TOKEN_URL, {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: tokenBody.toString(),
    });

    if (!tokenResp.ok) {
      const detail = await tokenResp.text();
      console.error("HubSpot token exchange failed", tokenResp.status, detail);
      return redirectToApp({
        provider: "hubspot",
        status: "error",
        message: "token_exchange_failed",
      });
    }

    const tokenJson = await tokenResp.json() as {
      access_token: string;
      refresh_token: string;
      expires_in: number; // seconds
    };

    // Fetch token info to get the HubSpot portal/hub ID and account details.
    const infoResp = await fetch(
      `${HUBSPOT_ACCESS_TOKEN_INFO_URL}/${tokenJson.access_token}`,
    );
    let hubId: string | null = null;
    let hubDomain: string | null = null;
    let scopes: string[] = [];
    if (infoResp.ok) {
      const info = await infoResp.json() as {
        hub_id?: number;
        hub_domain?: string;
        scopes?: string[];
      };
      hubId = info.hub_id ? String(info.hub_id) : null;
      hubDomain = info.hub_domain ?? null;
      scopes = info.scopes ?? [];
    }

    // Encrypt tokens before they hit the database.
    const accessTokenCipher = await encryptSecret(tokenJson.access_token);
    const refreshTokenCipher = await encryptSecret(tokenJson.refresh_token);
    const expiresAt = new Date(Date.now() + tokenJson.expires_in * 1000)
      .toISOString();

    // Write to crm_connections using the service role (bypasses RLS).
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    const { error: upsertError } = await supabase
      .from("crm_connections")
      .upsert({
        company_id: state.company_id,
        provider: "hubspot",
        access_token: accessTokenCipher,
        refresh_token: refreshTokenCipher,
        token_expires_at: expiresAt,
        scopes,
        external_account_id: hubId,
        external_account_name: hubDomain,
        status: "connected",
        error_message: null,
        connected_by: state.user_id,
        connected_at: new Date().toISOString(),
        last_refreshed_at: new Date().toISOString(),
      }, { onConflict: "company_id,provider" });

    if (upsertError) {
      console.error("crm_connections upsert failed", upsertError);
      return redirectToApp({
        provider: "hubspot",
        status: "error",
        message: "db_write_failed",
      });
    }

    // Log the success for audit.
    await supabase.from("crm_sync_log").insert({
      company_id: state.company_id,
      provider: "hubspot",
      operation: "oauth_connect",
      status: "success",
      http_status: 200,
    });

    return redirectToApp({
      provider: "hubspot",
      status: "success",
      hub_id: hubId ?? "",
    });
  } catch (err) {
    console.error("hubspot_oauth_callback error", err);
    return redirectToApp({
      provider: "hubspot",
      status: "error",
      message: "internal_error",
    });
  }
});

function redirectToApp(params: Record<string, string>): Response {
  const search = new URLSearchParams(params).toString();
  return Response.redirect(`${APP_URL}/integrations?${search}`, 302);
}