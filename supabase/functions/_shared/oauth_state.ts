// HMAC SHA256 signed OAuth state. Stateless: payload travels in the token itself.
// Format: base64url(json_payload).base64url(signature)

const SECRET = Deno.env.get("OAUTH_STATE_SECRET");
if (!SECRET) throw new Error("OAUTH_STATE_SECRET is not set");

const hmacKey = await crypto.subtle.importKey(
  "raw",
  new TextEncoder().encode(SECRET),
  { name: "HMAC", hash: "SHA-256" },
  false,
  ["sign", "verify"],
);

export interface StatePayload {
  company_id: string;
  user_id: string;
  provider: string;
  nonce: string;
  exp: number; // unix seconds
}

function b64url(bytes: Uint8Array): string {
  return btoa(String.fromCharCode(...bytes))
    .replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function b64urlDecode(s: string): Uint8Array {
  const pad = (4 - (s.length % 4)) % 4;
  const b64 = (s + "=".repeat(pad)).replace(/-/g, "+").replace(/_/g, "/");
  return Uint8Array.from(atob(b64), (c) => c.charCodeAt(0));
}

export async function signState(
  payload: Omit<StatePayload, "nonce" | "exp">,
  ttlSeconds = 600,
): Promise<string> {
  const full: StatePayload = {
    ...payload,
    nonce: crypto.randomUUID(),
    exp: Math.floor(Date.now() / 1000) + ttlSeconds,
  };
  const body = b64url(new TextEncoder().encode(JSON.stringify(full)));
  const sig = await crypto.subtle.sign(
    "HMAC", hmacKey, new TextEncoder().encode(body),
  );
  return `${body}.${b64url(new Uint8Array(sig))}`;
}

export async function verifyState(token: string): Promise<StatePayload | null> {
  const parts = token.split(".");
  if (parts.length !== 2) return null;
  const [body, sig] = parts;
  const ok = await crypto.subtle.verify(
    "HMAC",
    hmacKey,
    b64urlDecode(sig),
    new TextEncoder().encode(body),
  );
  if (!ok) return null;
  try {
    const payload: StatePayload = JSON.parse(
      new TextDecoder().decode(b64urlDecode(body)),
    );
    if (payload.exp < Math.floor(Date.now() / 1000)) return null;
    return payload;
  } catch {
    return null;
  }
}