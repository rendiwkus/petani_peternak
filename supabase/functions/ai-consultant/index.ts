// Edge Function: ai-consultant
//
// Menyimpan GEMINI_API_KEY dan SYSTEM PROMPT di server. Klien hanya mengirim
// pertanyaan, riwayat singkat, dan foto (base64). Kuota harian diperiksa
// secara atomik lewat RPC consume_ai_quota() sebelum memanggil Gemini.
//
// Deploy:
//   supabase secrets set GEMINI_API_KEY=... --project-ref <ref>
//   supabase functions deploy ai-consultant --project-ref <ref>
//
// SUPABASE_URL, SUPABASE_ANON_KEY, dan SUPABASE_SERVICE_ROLE_KEY sudah
// disediakan otomatis oleh Supabase.

import { createClient } from "jsr:@supabase/supabase-js@2";

const MODEL = "gemini-2.5-flash";
const MAX_MESSAGE_CHARS = 2000;
const MAX_IMAGE_BYTES = 5 * 1024 * 1024;

const SYSTEM_PROMPT = `Kamu adalah Asisten Penyuluh Pertanian dan Dokter Hewan Desa yang ramah, sabar, dan berpengalaman.
Aturan wajib jawabanmu:
1. Gunakan bahasa Indonesia sehari-hari yang sederhana dan sopan agar mudah dipahami warga desa usia 40-an ke atas.
2. Hindari istilah ilmiah atau bahasa Latin yang rumit. Jika terpaksa menyebut nama bahan aktif atau penyakit, langsung jelaskan artinya dengan bahasa praktis.
3. Susun jawaban secara terstruktur: (a) Kemungkinan Penyebab, (b) Langkah Penanganan Cepat yang bisa langsung dilakukan hari ini, dan (c) Saran Pupuk/Obat/Pakan yang dibutuhkan beserta cara pakainya.
4. Jika foto daun atau ternak kurang jelas, minta pengguna memfoto ulang dari jarak lebih dekat dengan cahaya terang.
5. Jawab hanya seputar pertanian, perkebunan, dan peternakan. Tolak dengan sopan pertanyaan di luar topik tersebut.
6. Jangan pernah menuliskan resep dosis yang membahayakan; selalu ingatkan membaca label kemasan.
7. Pilih produk hanya dari daftar PRODUK MITRA yang diberikan. Jika tidak ada yang cocok, kembalikan daftar kosong.`;

const corsHeaders: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function isUuid(value: unknown): value is string {
  return (
    typeof value === "string" &&
    /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(
      value,
    )
  );
}

interface HistoryItem {
  sender: string;
  text: string;
}

interface CatalogItem {
  id: string;
  name: string;
  category: string;
  active_ingredients: string | null;
  dosage_guide: string | null;
}

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return json({ error: "METHOD_NOT_ALLOWED" }, 405);
  }

  const authHeader = req.headers.get("Authorization") ?? "";
  if (!authHeader.toLowerCase().startsWith("bearer ")) {
    return json({ error: "UNAUTHORIZED" }, 401);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const geminiKey = Deno.env.get("GEMINI_API_KEY");

  if (!supabaseUrl || !anonKey || !serviceKey) {
    return json({ error: "SERVER_NOT_CONFIGURED" }, 500);
  }
  if (!geminiKey) {
    return json({ error: "AI_NOT_CONFIGURED" }, 503);
  }

  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
    auth: { persistSession: false },
  });

  const { data: userData, error: userError } = await userClient.auth.getUser();
  const user = userData?.user;
  if (userError || !user) {
    return json({ error: "UNAUTHORIZED" }, 401);
  }

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return json({ error: "INVALID_BODY" }, 400);
  }

  const sessionId = body.session_id;
  const message = typeof body.message === "string" ? body.message.trim() : "";
  const imageBase64 = typeof body.image_base64 === "string"
    ? body.image_base64
    : null;
  const imageMime = typeof body.image_mime_type === "string"
    ? body.image_mime_type
    : "image/jpeg";

  if (!isUuid(sessionId)) {
    return json({ error: "SESSION_INVALID" }, 400);
  }
  if (message.length === 0 && !imageBase64) {
    return json({ error: "MESSAGE_EMPTY" }, 400);
  }
  if (message.length > MAX_MESSAGE_CHARS) {
    return json({ error: "MESSAGE_TOO_LONG" }, 400);
  }
  if (imageBase64 && !imageMime.startsWith("image/")) {
    return json({ error: "IMAGE_TYPE_INVALID" }, 400);
  }
  if (imageBase64 && imageBase64.length > MAX_IMAGE_BYTES * 1.4) {
    return json({ error: "IMAGE_TOO_LARGE" }, 413);
  }

  const admin = createClient(supabaseUrl, serviceKey, {
    auth: { persistSession: false },
  });

  // Sesi harus milik pengguna yang memanggil.
  const { data: session, error: sessionError } = await admin
    .from("ai_chat_sessions")
    .select("id,user_id")
    .eq("id", sessionId)
    .maybeSingle();

  if (sessionError || !session || session.user_id !== user.id) {
    return json({ error: "SESSION_FORBIDDEN" }, 403);
  }

  const { data: quota, error: quotaError } = await admin.rpc(
    "consume_ai_quota",
    { p_user_id: user.id },
  );
  if (quotaError) {
    return json({ error: "QUOTA_CHECK_FAILED" }, 500);
  }
  if (!quota?.allowed) {
    return json(
      {
        error: "QUOTA_EXCEEDED",
        message:
          "Kuota tanya AI hari ini sudah habis. Upgrade ke Pro untuk tanya tanpa batas.",
      },
      429,
    );
  }

  // Katalog ringkas agar rekomendasi produk selalu berasal dari kios mitra.
  const { data: products } = await admin
    .from("products")
    .select("id,name,category,active_ingredients,dosage_guide")
    .eq("is_active", true)
    .limit(60);

  const catalog = (products ?? []) as CatalogItem[];
  const catalogIds = new Set(catalog.map((item) => item.id));
  const catalogText = catalog.length === 0
    ? "Tidak ada produk mitra yang aktif saat ini."
    : catalog
      .map((item) =>
        `- ${item.id} | ${item.name} | ${item.category}` +
        (item.active_ingredients
          ? ` | bahan aktif: ${item.active_ingredients}`
          : "")
      )
      .join("\n");

  const history = Array.isArray(body.history)
    ? (body.history as HistoryItem[])
      .filter((item) =>
        (item?.sender === "user" || item?.sender === "ai") &&
        typeof item?.text === "string" &&
        item.text.trim().length > 0
      )
      .slice(-8)
    : [];

  const contents = [
    ...history.map((item) => ({
      role: item.sender === "user" ? "user" : "model",
      parts: [{ text: item.text.slice(0, MAX_MESSAGE_CHARS) }],
    })),
    {
      role: "user",
      parts: [
        {
          text:
            `${message || "Tolong periksa kondisi pada foto ini."}\n\n` +
            `PRODUK MITRA (pilih id yang relevan saja):\n${catalogText}`,
        },
        ...(imageBase64
          ? [{
            inline_data: {
              mime_type: imageMime,
              data: imageBase64,
            },
          }]
          : []),
      ],
    },
  ];

  const geminiResponse = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent?key=${geminiKey}`,
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        systemInstruction: { parts: [{ text: SYSTEM_PROMPT }] },
        contents,
        generationConfig: {
          temperature: 0.4,
          maxOutputTokens: 1200,
          responseMimeType: "application/json",
          responseSchema: {
            type: "OBJECT",
            properties: {
              answer: { type: "STRING" },
              recommended_product_ids: {
                type: "ARRAY",
                items: { type: "STRING" },
              },
            },
            required: ["answer", "recommended_product_ids"],
          },
        },
      }),
    },
  );

  if (!geminiResponse.ok) {
    // Detail error tidak dikirim ke klien agar tidak membocorkan konfigurasi.
    console.error("gemini_error", geminiResponse.status);
    return json({ error: "AI_UNAVAILABLE" }, 502);
  }

  const geminiJson = await geminiResponse.json();
  const rawText: string =
    geminiJson?.candidates?.[0]?.content?.parts?.[0]?.text ?? "";

  let parsed: { answer?: string; recommended_product_ids?: string[] } = {};
  try {
    parsed = JSON.parse(rawText);
  } catch {
    parsed = { answer: rawText, recommended_product_ids: [] };
  }

  const answer = (parsed.answer ?? "").trim();
  if (answer.length === 0) {
    return json({ error: "AI_EMPTY_ANSWER" }, 502);
  }

  const recommendedIds = Array.isArray(parsed.recommended_product_ids)
    ? parsed.recommended_product_ids
      .filter((id): id is string => typeof id === "string" && catalogIds.has(id))
      .slice(0, 4)
    : [];

  return json({
    answer,
    recommended_product_ids: recommendedIds,
    remaining_quota: quota?.remaining ?? null,
  });
});
