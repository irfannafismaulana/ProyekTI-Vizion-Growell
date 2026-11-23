// GroWell — Edge Function "notify" (PRD F8).
// Dipanggil aplikasi setelah sebuah aksi berhasil disimpan. Server memeriksa bahwa pemanggil
// memang pelaku aksi tersebut, lalu mengirim push ke penerimanya.
//   { type: "message", thread_id }     -> lawan bicara konsultasi
//   { type: "note", id }               -> orang tua (catatan konsultasi baru)
//   { type: "appointment", id }        -> orang tua (jadwal kontrol baru)
//   { type: "verified", user_id }      -> nakes yang diverifikasi admin
import { adminClient, callerOf, cors, fail, json } from "../_shared/common.ts";
import { sendToUser } from "../_shared/fcm.ts";

const snippet = (s: string, n = 90) => (s.length > n ? `${s.slice(0, n - 1)}…` : s);

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return fail(405, "method", "Gunakan POST.");
  try {
    const admin = adminClient();
    const me = await callerOf(req, admin);
    if (!me) return fail(401, "unauthorized", "Silakan masuk terlebih dahulu.");
    const body = await req.json().catch(() => ({})) as Record<string, string>;

    switch (body.type) {
      case "message": {
        const { data: t } = await admin.from("consult_threads").select("id, parent_id, doctor_id").eq("id", body.thread_id).maybeSingle();
        if (!t || (t.parent_id !== me.id && t.doctor_id !== me.id)) return fail(403, "forbidden", "Bukan peserta percakapan.");
        const { data: m } = await admin.from("consult_messages").select("body, sent_at").eq("thread_id", t.id).eq("sender_id", me.id)
          .order("sent_at", { ascending: false }).limit(1).maybeSingle();
        if (!m || Date.now() - new Date(m.sent_at).getTime() > 5 * 60_000) return fail(409, "stale", "Tidak ada pesan baru.");
        const to = t.parent_id === me.id ? t.doctor_id : t.parent_id;
        return json(await sendToUser(admin, to, { title: `Pesan baru dari ${me.name}`, body: snippet(m.body), route: `/consult/${t.id}` }));
      }
      case "note": {
        const { data: n } = await admin.from("consult_notes").select("id, title, doctor_id, thread_id, consult_threads(parent_id)")
          .eq("id", body.id).maybeSingle();
        if (!n || n.doctor_id !== me.id) return fail(403, "forbidden", "Bukan penulis catatan.");
        const parent = (n.consult_threads as unknown as { parent_id: string }).parent_id;
        return json(await sendToUser(admin, parent, { title: "Catatan konsultasi baru", body: `${me.name}: ${snippet(n.title)}`, route: `/consult/note/${n.id}` }));
      }
      case "appointment": {
        const { data: a } = await admin.from("appointments").select("id, doctor_id, scheduled_at, children(name, parent_id)")
          .eq("id", body.id).maybeSingle();
        if (!a || a.doctor_id !== me.id) return fail(403, "forbidden", "Bukan pembuat jadwal.");
        const c = a.children as unknown as { name: string; parent_id: string };
        const when = new Date(a.scheduled_at).toLocaleString("id-ID", { timeZone: "Asia/Jakarta", dateStyle: "full", timeStyle: "short" });
        return json(await sendToUser(admin, c.parent_id, { title: `Jadwal kontrol ${c.name}`, body: `${when} bersama ${me.name}`, route: "/notifications" }));
      }
      case "verified": {
        if (me.role !== "admin") return fail(403, "forbidden", "Hanya admin.");
        const { data: p } = await admin.from("profiles").select("id, verified").eq("id", body.user_id).maybeSingle();
        if (!p?.verified) return fail(409, "stale", "Akun belum terverifikasi.");
        return json(await sendToUser(admin, p.id, { title: "STR terverifikasi", body: "Akun GroWell Anda sudah aktif. Dashboard dan konsultasi kini bisa digunakan.", route: "/app" }));
      }
      default:
        return fail(400, "bad_request", "type tidak dikenal.");
    }
  } catch (e) {
    console.error(e);
    return fail(500, "internal", "Gagal mengirim notifikasi.");
  }
});
