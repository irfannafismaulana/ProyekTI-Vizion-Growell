// GroWell — Edge Function "reminders" (PRD F8): pengingat harian lewat push.
// Dipanggil Supabase Cron sekali sehari (mis. 07.00 WIB) dengan header x-cron-secret.
//  - jadwal kontrol besok  -> orang tua
//  - anak belum diukur > 30 hari -> orang tua
import { adminClient, cors, fail, json } from "../_shared/common.ts";
import { sendToUser } from "../_shared/fcm.ts";

const DAY = 86_400_000;

function wibDate(d: Date): string {
  return new Date(d.getTime() + 7 * 3_600_000).toISOString().slice(0, 10);
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  const secret = Deno.env.get("CRON_SECRET");
  if (!secret || req.headers.get("x-cron-secret") !== secret) return fail(401, "unauthorized", "x-cron-secret salah.");
  try {
    const admin = adminClient();
    const now = new Date();
    const tomorrow = wibDate(new Date(now.getTime() + DAY));
    let sent = 0;

    // 1. Kontrol besok
    const { data: appts } = await admin.from("appointments")
      .select("scheduled_at, children(name, parent_id), profiles:doctor_id(name)")
      .gte("scheduled_at", new Date(now.getTime()).toISOString())
      .lte("scheduled_at", new Date(now.getTime() + 2 * DAY).toISOString());
    for (const a of appts ?? []) {
      if (wibDate(new Date(a.scheduled_at)) !== tomorrow) continue;
      const c = a.children as unknown as { name: string; parent_id: string };
      const doc = (a.profiles as unknown as { name: string } | null)?.name ?? "tenaga kesehatan";
      const jam = new Date(a.scheduled_at).toLocaleTimeString("id-ID", { timeZone: "Asia/Jakarta", hour: "2-digit", minute: "2-digit" });
      sent += (await sendToUser(admin, c.parent_id, {
        title: `Besok kontrol ${c.name}`,
        body: `Pukul ${jam} bersama ${doc}. Bawa buku KIA ya.`,
        route: "/notifications",
      })).sent;
    }

    // 2. Belum diukur lebih dari 30 hari (hanya baduta)
    const { data: kids } = await admin.from("children").select("id, name, parent_id, birth_date, measurements(measured_on)");
    for (const k of kids ?? []) {
      const ageDays = (now.getTime() - new Date(k.birth_date).getTime()) / DAY;
      if (ageDays > 731) continue;
      const dates = ((k.measurements ?? []) as { measured_on: string }[]).map((m) => new Date(m.measured_on).getTime());
      const last = dates.length ? Math.max(...dates) : new Date(k.birth_date).getTime();
      const since = Math.floor((now.getTime() - last) / DAY);
      // Kirim sekali per 7 hari agar tidak mengganggu (hari ke-31, 38, 45, …).
      if (since > 30 && (since - 31) % 7 === 0) {
        sent += (await sendToUser(admin, k.parent_id, {
          title: `Saatnya menimbang ${k.name}`,
          body: `Sudah ${since} hari sejak pengukuran terakhir. Catat berat & tinggi dari posyandu.`,
          route: `/child/${k.id}`,
        })).sent;
      }
    }
    return json({ sent });
  } catch (e) {
    console.error(e);
    return fail(500, "internal", "Gagal menjalankan pengingat.");
  }
});
