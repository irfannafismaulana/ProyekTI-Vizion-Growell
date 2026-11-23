// GroWell — Edge Function "ai" (PRD F6 & F7).
// Menjembatani aplikasi ke NanoGPT (API kompatibel OpenAI). Kunci API hanya ada di sini
// sebagai secret NANOGPT_API_KEY; aplikasi tidak pernah melihatnya.
//
// POST { action: "chat", messages: [{role, content}], child?: {...} }        -> { reply }
// POST { action: "food_photo", image: "data:image/jpeg;base64,...", foods: [{id, name}], child?: {...} }
//                                                                              -> { items: [{food_id, grams, confidence}], note }
import { adminClient, callerOf, cors, fail, json } from "../_shared/common.ts";

const BASE_URL = Deno.env.get("NANOGPT_BASE_URL") ?? "https://api.nano-gpt.com/api/subscription/v1";
const CHAT_MODEL = Deno.env.get("NANOGPT_CHAT_MODEL") ?? "deepseek/deepseek-v4-flash-latest";
const VISION_MODEL = Deno.env.get("NANOGPT_VISION_MODEL") ?? CHAT_MODEL;
const LIMITS: Record<string, number> = {
  chat: Number(Deno.env.get("AI_CHAT_DAILY_LIMIT") ?? 40),
  food_photo: Number(Deno.env.get("AI_PHOTO_DAILY_LIMIT") ?? 15),
};
const MAX_IMAGE_CHARS = 6_000_000; // ± 4,5 MB gambar base64

type Child = { name?: string; age_months?: number; sex?: string; status?: string };

/** Hanya data minimum anak yang dikirim ke AI (tanpa email/NIK/tanggal lahir lengkap). */
function childContext(c: unknown): string {
  if (!c || typeof c !== "object") return "Belum ada data anak.";
  const x = c as Child;
  const name = String(x.name ?? "anak").slice(0, 30);
  const age = typeof x.age_months === "number" ? Math.max(0, Math.min(60, x.age_months)).toFixed(1) : "?";
  const sex = x.sex === "female" ? "perempuan" : x.sex === "male" ? "laki-laki" : "-";
  const status = String(x.status ?? "belum diukur").slice(0, 60);
  return `Anak: ${name}, usia ${age} bulan, ${sex}, status pertumbuhan terakhir: ${status}.`;
}

const CHAT_SYSTEM = `Kamu adalah "Asisten Gizi GroWell", pendamping gizi untuk orang tua baduta (0–24 bulan) di Indonesia.
Aturan:
- Jawab dalam bahasa Indonesia sederhana dan hangat, maksimal 120 kata, boleh poin-poin singkat.
- Teks polos saja: JANGAN memakai markdown (tanpa **, __, #, atau tabel). Untuk poin gunakan "• " di awal baris. Emoji secukupnya.
- Topik: ASI, MPASI (tekstur, frekuensi, porsi sesuai usia), protein hewani, anak susah makan, kebersihan makanan, pemantauan pertumbuhan & pencegahan stunting.
- Ikuti pedoman Kemenkes/WHO: ASI eksklusif 0–6 bulan; MPASI mulai 6 bulan; protein hewani setiap makan; tanpa gula/garam berlebih di bawah 1 tahun; madu tidak untuk < 1 tahun.
- JANGAN memberi diagnosis, dosis obat, atau suplemen spesifik. Untuk tanda bahaya (demam tinggi, kejang, sesak, diare/muntah terus, lemas, berat turun, tidak mau makan berhari-hari) minta segera ke puskesmas/IGD.
- Ingatkan konsultasi ke tenaga kesehatan bila status anak "Kurang"/merah.
- Jika pertanyaan di luar topik gizi & kesehatan anak, tolak dengan sopan.`;

async function nano(model: string, messages: unknown[], extra: Record<string, unknown> = {}): Promise<string> {
  const key = Deno.env.get("NANOGPT_API_KEY");
  if (!key) throw new HttpError(503, "not_configured", "AI belum dikonfigurasi di server (NANOGPT_API_KEY).");
  const ctrl = new AbortController();
  const timer = setTimeout(() => ctrl.abort(), 60_000);
  try {
    const res = await fetch(`${BASE_URL}/chat/completions`, {
      method: "POST",
      signal: ctrl.signal,
      headers: { "Authorization": `Bearer ${key}`, "Content-Type": "application/json" },
      body: JSON.stringify({ model, messages, temperature: 0.3, max_tokens: 2000, ...extra }),
    });
    const text = await res.text();
    if (!res.ok) {
      console.error("NanoGPT error", res.status, text.slice(0, 500));
      throw new HttpError(502, "provider_error", `Layanan AI menolak permintaan (${res.status}).`);
    }
    const data = JSON.parse(text);
    const content: string = data?.choices?.[0]?.message?.content ?? "";
    return content.replace(/<think>[\s\S]*?<\/think>/g, "").trim();
  } catch (e) {
    if (e instanceof HttpError) throw e;
    if ((e as Error).name === "AbortError") throw new HttpError(504, "timeout", "Layanan AI terlalu lama merespons. Coba lagi.");
    throw new HttpError(502, "provider_error", "Tidak dapat menghubungi layanan AI.");
  } finally {
    clearTimeout(timer);
  }
}

class HttpError extends Error {
  constructor(public status: number, public code: string, message: string) {
    super(message);
  }
}

/** Aplikasi menampilkan teks polos: buang sisa markdown bila model tetap memakainya. */
function plainText(s: string): string {
  return s
    .replace(/\*\*(.+?)\*\*/g, "$1")
    .replace(/__(.+?)__/g, "$1")
    .replace(/^#{1,6}\s+/gm, "")
    .replace(/^\s*[-*]\s+/gm, "• ")
    .replace(/\n{3,}/g, "\n\n")
    .trim();
}

function firstJsonObject(s: string): Record<string, unknown> {
  const cleaned = s.replace(/```json|```/g, "");
  const start = cleaned.indexOf("{"), end = cleaned.lastIndexOf("}");
  if (start < 0 || end <= start) throw new HttpError(502, "bad_output", "Jawaban AI tidak terbaca. Coba foto lain.");
  return JSON.parse(cleaned.slice(start, end + 1));
}

async function chat(body: Record<string, unknown>): Promise<Response> {
  const raw = Array.isArray(body.messages) ? body.messages : [];
  const messages = raw
    .filter((m): m is { role: string; content: string } =>
      !!m && typeof m === "object" && (m.role === "user" || m.role === "assistant") && typeof m.content === "string")
    .slice(-10)
    .map((m) => ({ role: m.role, content: m.content.slice(0, 1000) }));
  if (messages.length === 0 || messages[messages.length - 1].role !== "user") {
    return fail(400, "bad_request", "Pertanyaan kosong.");
  }
  const reply = await nano(CHAT_MODEL, [
    { role: "system", content: `${CHAT_SYSTEM}\n\n${childContext(body.child)}` },
    ...messages,
  ]);
  if (!reply) throw new HttpError(502, "bad_output", "AI tidak memberi jawaban. Coba ulangi pertanyaan.");
  return json({ reply: plainText(reply), model: CHAT_MODEL });
}

async function foodPhoto(body: Record<string, unknown>): Promise<Response> {
  const image = typeof body.image === "string" ? body.image : "";
  if (!/^data:image\/(jpeg|png|webp);base64,/.test(image)) return fail(400, "bad_request", "Format foto harus JPG, PNG, atau WEBP.");
  if (image.length > MAX_IMAGE_CHARS) return fail(413, "too_large", "Foto terlalu besar. Gunakan foto maks. 4 MB.");
  const foods = (Array.isArray(body.foods) ? body.foods : [])
    .filter((f): f is { id: string; name: string } => !!f && typeof f.id === "string" && typeof f.name === "string")
    .slice(0, 300);
  if (foods.length === 0) return fail(400, "bad_request", "Daftar makanan kosong.");
  const ids = new Set(foods.map((f) => f.id));
  const list = foods.map((f) => `${f.id}: ${f.name}`).join("\n");

  const prompt = `Foto ini adalah makanan yang akan dimakan anak. ${childContext(body.child)}
Kenali setiap makanan yang terlihat dan perkirakan beratnya (gram, porsi yang terlihat di foto).
Pilih HANYA dari daftar berikut (format "id: nama"); bila tidak ada yang cocok, pilih yang paling mirip atau lewati:
${list}

Balas HANYA JSON dengan format:
{"items":[{"food_id":"<id dari daftar>","grams":<angka>,"confidence":<0..1>}],"note":"<catatan singkat bahasa Indonesia, mis. saran menambah protein hewani>"}
Jika foto bukan makanan, kembalikan {"items":[],"note":"Foto tidak tampak seperti makanan."}`;

  const out = await nano(
    VISION_MODEL,
    [{ role: "user", content: [{ type: "text", text: prompt }, { type: "image_url", image_url: { url: image } }] }],
    { response_format: { type: "json_object" } },
  );
  const parsed = firstJsonObject(out);
  const items = (Array.isArray(parsed.items) ? parsed.items : [])
    .filter((i): i is { food_id: string; grams: number; confidence?: number } =>
      !!i && typeof i === "object" && ids.has(String((i as { food_id?: unknown }).food_id)))
    .map((i) => ({
      food_id: String(i.food_id),
      grams: Math.round(Math.max(5, Math.min(500, Number(i.grams) || 30))),
      confidence: Math.max(0, Math.min(1, Number(i.confidence ?? 0.5))),
    }))
    .slice(0, 12);
  const note = typeof parsed.note === "string" ? plainText(parsed.note).slice(0, 300) : "";
  return json({ items, note, model: VISION_MODEL });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return fail(405, "method", "Gunakan POST.");
  try {
    const admin = adminClient();
    const me = await callerOf(req, admin);
    if (!me) return fail(401, "unauthorized", "Silakan masuk terlebih dahulu.");
    if (me.role !== "parent") return fail(403, "forbidden", "Fitur AI gizi hanya untuk akun orang tua.");

    const body = await req.json().catch(() => ({})) as Record<string, unknown>;
    const action = body.action === "food_photo" ? "food_photo" : body.action === "chat" ? "chat" : null;
    if (!action) return fail(400, "bad_request", "action harus 'chat' atau 'food_photo'.");
    if (!Deno.env.get("NANOGPT_API_KEY")) return fail(503, "not_configured", "AI belum dikonfigurasi di server (NANOGPT_API_KEY).");

    const { data: ok, error } = await admin.rpc("ai_take_quota", { p_user: me.id, p_kind: action, p_limit: LIMITS[action] });
    if (error) throw error;
    if (!ok) return fail(429, "quota", `Batas harian AI tercapai (${LIMITS[action]} per hari). Coba lagi besok.`);

    return action === "chat" ? await chat(body) : await foodPhoto(body);
  } catch (e) {
    if (e instanceof HttpError) return fail(e.status, e.code, e.message);
    console.error(e);
    return fail(500, "internal", "Terjadi kesalahan di server AI.");
  }
});
