// AES GCM symmetric encryption using a 32 byte key from Edge Function Secrets.
// Output format: base64(iv):base64(ciphertext+authtag)

const KEY_B64 = Deno.env.get("CRM_TOKEN_ENCRYPTION_KEY");
if (!KEY_B64) throw new Error("CRM_TOKEN_ENCRYPTION_KEY is not set");

const keyBytes = Uint8Array.from(atob(KEY_B64), (c) => c.charCodeAt(0));
if (keyBytes.length !== 32) {
  throw new Error("CRM_TOKEN_ENCRYPTION_KEY must be 32 bytes (base64 encoded)");
}

const cryptoKey = await crypto.subtle.importKey(
  "raw",
  keyBytes,
  { name: "AES-GCM" },
  false,
  ["encrypt", "decrypt"],
);

function bytesToB64(bytes: Uint8Array): string {
  return btoa(String.fromCharCode(...bytes));
}

function b64ToBytes(b64: string): Uint8Array {
  return Uint8Array.from(atob(b64), (c) => c.charCodeAt(0));
}

export async function encryptSecret(plaintext: string): Promise<string> {
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const cipherBuf = await crypto.subtle.encrypt(
    { name: "AES-GCM", iv },
    cryptoKey,
    new TextEncoder().encode(plaintext),
  );
  return `${bytesToB64(iv)}:${bytesToB64(new Uint8Array(cipherBuf))}`;
}

export async function decryptSecret(packed: string): Promise<string> {
  const [ivB64, ctB64] = packed.split(":");
  if (!ivB64 || !ctB64) throw new Error("Malformed ciphertext");
  const iv = b64ToBytes(ivB64);
  const ct = b64ToBytes(ctB64);
  const plainBuf = await crypto.subtle.decrypt(
    { name: "AES-GCM", iv },
    cryptoKey,
    ct,
  );
  return new TextDecoder().decode(plainBuf);
}