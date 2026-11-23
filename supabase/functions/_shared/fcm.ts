// Firebase Cloud Messaging HTTP v1 (PRD F8). Kredensial = secret FIREBASE_SERVICE_ACCOUNT (JSON service account).
import type { SupabaseClient } from "npm:@supabase/supabase-js@2";

type ServiceAccount = { project_id: string; client_email: string; private_key: string };

let cached: { token: string; exp: number } | null = null;

function serviceAccount(): ServiceAccount | null {
  const raw = Deno.env.get("FIREBASE_SERVICE_ACCOUNT");
  if (!raw) return null;
  try {
    const sa = JSON.parse(raw);
    return sa.project_id && sa.client_email && sa.private_key ? sa : null;
  } catch {
    return null;
  }
}

export const pushConfigured = () => serviceAccount() !== null;

const b64url = (data: ArrayBuffer | string) => {
  const bytes = typeof data === "string" ? new TextEncoder().encode(data) : new Uint8Array(data);
  let s = "";
  for (const b of bytes) s += String.fromCharCode(b);
  return btoa(s).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
};

async function accessToken(sa: ServiceAccount): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (cached && cached.exp - 60 > now) return cached.token;
  const header = b64url(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const claims = b64url(JSON.stringify({
    iss: sa.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  }));
  const pem = sa.private_key.replace(/-----[^-]+-----/g, "").replace(/\s+/g, "");
  const der = Uint8Array.from(atob(pem), (c) => c.charCodeAt(0));
  const key = await crypto.subtle.importKey("pkcs8", der, { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" }, false, ["sign"]);
  const sig = await crypto.subtle.sign("RSASSA-PKCS1-v1_5", key, new TextEncoder().encode(`${header}.${claims}`));
  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: `${header}.${claims}.${b64url(sig)}`,
    }),
  });
  if (!res.ok) throw new Error(`OAuth Google gagal: ${res.status} ${await res.text()}`);
  const data = await res.json();
  cached = { token: data.access_token, exp: now + (data.expires_in ?? 3600) };
  return cached.token;
}

export type Push = { title: string; body: string; route?: string };

/** Kirim ke semua perangkat pengguna; token yang sudah tidak berlaku dihapus. */
export async function sendToUser(admin: SupabaseClient, userId: string, push: Push): Promise<{ sent: number; skipped?: string }> {
  const sa = serviceAccount();
  if (!sa) return { sent: 0, skipped: "FIREBASE_SERVICE_ACCOUNT belum diatur" };
  const { data: rows } = await admin.from("push_tokens").select("token, platform").eq("user_id", userId);
  if (!rows || rows.length === 0) return { sent: 0, skipped: "penerima belum mendaftarkan perangkat" };
  const token = await accessToken(sa);
  const siteUrl = Deno.env.get("GROWELL_SITE_URL") ?? "";
  let sent = 0;
  for (const r of rows) {
    const message: Record<string, unknown> = {
      token: r.token,
      notification: { title: push.title, body: push.body },
      data: push.route ? { route: push.route } : {},
      android: { priority: "high" },
    };
    if (r.platform === "web" && siteUrl && push.route) {
      message.webpush = { fcm_options: { link: `${siteUrl}/#${push.route}` } };
    }
    const res = await fetch(`https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`, {
      method: "POST",
      headers: { "Authorization": `Bearer ${token}`, "Content-Type": "application/json" },
      body: JSON.stringify({ message }),
    });
    if (res.ok) {
      sent++;
    } else {
      const text = await res.text();
      if (res.status === 404 || text.includes("UNREGISTERED") || text.includes("INVALID_ARGUMENT")) {
        await admin.from("push_tokens").delete().eq("token", r.token);
      } else {
        console.error("FCM gagal", res.status, text.slice(0, 300));
      }
    }
  }
  return { sent };
}
