// Shared HubSpot token management.
// Reads encrypted tokens from crm_connections, refreshes if expiring soon,
// writes the new encrypted tokens back, and returns the plaintext access token.

import { createClient, SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.45.0";
import { decryptSecret, encryptSecret } from "./crypto.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const HUBSPOT_CLIENT_ID = Deno.env.get("HUBSPOT_CLIENT_ID")!;
const HUBSPOT_CLIENT_SECRET = Deno.env.get("HUBSPOT_CLIENT_SECRET")!;
const HUBSPOT_TOKEN_URL = "https://api.hubapi.com/oauth/v1/token";

// Refresh if the token expires within this many seconds.
const REFRESH_BUFFER_SECONDS = 120;

export interface HubSpotTokenResult {
  accessToken: string;
  connectionId: string;
  externalAccountId: string | null;
}

export class HubSpotNotConnectedError extends Error {
  constructor(public companyId: string) {
    super(`No active HubSpot connection for company ${companyId}`);
    this.name = "HubSpotNotConnectedError";
  }
}

export class HubSpotRefreshError extends Error {
  constructor(message: string, public httpStatus?: number) {
    super(message);
    this.name = "HubSpotRefreshError";
  }
}

let cachedAdminClient: SupabaseClient | null = null;
function getAdminClient(): SupabaseClient {
  if (!cachedAdminClient) {
    cachedAdminClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
  }
  return cachedAdminClient;
}

/**
 * Get a valid HubSpot access token for the given company.
 * Refreshes automatically if the current token is within REFRESH_BUFFER_SECONDS of expiry.
 */
export async function getValidHubSpotToken(
  companyId: string,
): Promise<HubSpotTokenResult> {
  const supabase = getAdminClient();

  const { data: conn, error } = await supabase
    .from("crm_connections")
    .select(
      "id, access_token, refresh_token, token_expires_at, external_account_id, status",
    )
    .eq("company_id", companyId)
    .eq("provider", "hubspot")
    .maybeSingle();

  if (error) {
    throw new Error(`Failed to load crm_connections: ${error.message}`);
  }
  if (!conn || conn.status === "disconnected") {
    throw new HubSpotNotConnectedError(companyId);
  }

  const expiresAt = conn.token_expires_at ? new Date(conn.token_expires_at).getTime() : 0;
  const refreshAt = Date.now() + REFRESH_BUFFER_SECONDS * 1000;

  // Token still valid for more than the buffer; decrypt and return.
  if (expiresAt > refreshAt) {
    return {
      accessToken: await decryptSecret(conn.access_token),
      connectionId: conn.id,
      externalAccountId: conn.external_account_id,
    };
  }

  // Token expired or about to. Refresh.
  const refreshToken = await decryptSecret(conn.refresh_token);

  const body = new URLSearchParams({
    grant_type: "refresh_token",
    client_id: HUBSPOT_CLIENT_ID,
    client_secret: HUBSPOT_CLIENT_SECRET,
    refresh_token: refreshToken,
  });

  const resp = await fetch(HUBSPOT_TOKEN_URL, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: body.toString(),
  });

  if (!resp.ok) {
    const detail = await resp.text();

    // Mark the connection as errored so the UI can prompt re connection.
    await supabase
      .from("crm_connections")
      .update({
        status: resp.status === 400 || resp.status === 401 ? "expired" : "error",
        error_message: `Refresh failed: ${resp.status} ${detail}`.slice(0, 500),
      })
      .eq("id", conn.id);

    await supabase.from("crm_sync_log").insert({
      company_id: companyId,
      connection_id: conn.id,
      provider: "hubspot",
      operation: "token_refresh",
      status: "error",
      http_status: resp.status,
      error_message: detail.slice(0, 1000),
    });

    throw new HubSpotRefreshError(
      `HubSpot refresh failed (${resp.status}): ${detail}`,
      resp.status,
    );
  }

  const tokenJson = await resp.json() as {
    access_token: string;
    refresh_token: string;
    expires_in: number;
  };

  const newAccessCipher = await encryptSecret(tokenJson.access_token);
  const newRefreshCipher = await encryptSecret(tokenJson.refresh_token);
  const newExpiresAt = new Date(Date.now() + tokenJson.expires_in * 1000).toISOString();

  const { error: updateError } = await supabase
    .from("crm_connections")
    .update({
      access_token: newAccessCipher,
      refresh_token: newRefreshCipher,
      token_expires_at: newExpiresAt,
      status: "connected",
      error_message: null,
      last_refreshed_at: new Date().toISOString(),
    })
    .eq("id", conn.id);

  if (updateError) {
    throw new Error(`Failed to persist refreshed token: ${updateError.message}`);
  }

  await supabase.from("crm_sync_log").insert({
    company_id: companyId,
    connection_id: conn.id,
    provider: "hubspot",
    operation: "token_refresh",
    status: "success",
    http_status: 200,
  });

  return {
    accessToken: tokenJson.access_token,
    connectionId: conn.id,
    externalAccountId: conn.external_account_id,
  };
}