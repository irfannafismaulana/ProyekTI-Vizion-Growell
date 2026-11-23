// Bantuan bersama Edge Function GroWell.
import { createClient, type SupabaseClient } from "npm:@supabase/supabase-js@2";

export const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-cron-secret",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

export function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });
}

export function fail(status: number, code: string, message: string): Response {
  return json({ error: message, code }, status);
}

/** Klien service_role (melewati RLS) — hanya dipakai di server. */
export function adminClient(): SupabaseClient {
  return createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
}

export type Caller = { id: string; role: string; name: string; verified: boolean };

/** Pengguna yang memanggil fungsi (dari JWT), atau null. */
export async function callerOf(req: Request, admin: SupabaseClient): Promise<Caller | null> {
  const token = (req.headers.get("Authorization") ?? "").replace(/^Bearer\s+/i, "");
  if (!token) return null;
  const { data, error } = await admin.auth.getUser(token);
  if (error || !data.user) return null;
  const { data: p } = await admin.from("profiles").select("id, role, name, verified").eq("id", data.user.id).maybeSingle();
  return p ? { id: p.id, role: p.role, name: p.name, verified: p.verified } : null;
}
