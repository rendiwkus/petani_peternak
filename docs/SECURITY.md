# Keamanan Aplikasi

Ringkasan kontrol keamanan, batas kepercayaan, dan hal yang **tidak** boleh
dilanggar saat mengembangkan lanjut.

## Batas kepercayaan

| Lapisan | Boleh dipercaya? | Catatan |
| --- | --- | --- |
| Aplikasi Flutter (`lib/`) | Tidak | Bisa dibongkar; anggap semua input pengguna berbahaya |
| Supabase PostgREST + RLS | Ya | Sumber kebenaran izin data |
| RPC `security definer` | Ya | Validasi harga, stok, kuota, tagihan |
| Edge Function | Ya | Pemegang `GEMINI_API_KEY` dan system prompt |

## Rahasia

- Klien hanya memegang **publishable/anon key** (`SUPABASE_ANON_KEY`). Kunci itu
  memang publik; yang melindungi data adalah RLS.
- `SUPABASE_SERVICE_ROLE_KEY` hanya ada di runtime Edge Function/admin.
- `GEMINI_API_KEY` hanya sebagai secret Edge Function. Tidak ada di `.env`, APK,
  maupun repo.
- `.env` masuk `.gitignore`; commit pertama hanya menyertakan `.env.example`.

## Kontrol data (RLS)

- `profiles`: `select/insert/update` hanya untuk `id = auth.uid()`.
  Trigger `guard_profile_privileges` membekukan `role`, `is_pro`,
  `pro_expires_at`, `daily_ai_quota_used`, `last_quota_reset`, dan `id`.
- `care_schedules`, `farm_financial_logs`, `cart_items`, `ai_chat_sessions`:
  CRUD hanya milik `user_id = auth.uid()`.
- `ai_chat_messages`: diakses lewat kepemilikan sesi induk.
- `market_orders`: klien hanya `select` miliknya dan `update` ke `dibatalkan`
  saat status masih `pending`/`menunggu`. Trigger `guard_market_order_update`
  menolak perubahan total, toko, nomor pesanan, atau status lain.
- `market_order_items`, `market_payments`: hanya terbaca lewat pesanan sendiri.
- `subscription_transactions`: hanya `select` milik sendiri; pembuatan tagihan
  lewat RPC.
- Katalog (`commodities`, `stores`, `products`, `knowledge_articles`,
  `article_recommended_products`): hanya `select` (produk aktif, artikel
  terbit). Tidak ada policy INSERT/UPDATE/DELETE untuk klien.

## Uang dan stok

- Checkout hanya lewat `create_market_order`. Total dihitung dari harga produk
  di database (memperhatikan `discount_price`), stok dikunci `for update`,
  divalidasi, lalu dipotong. Klien tidak mengirim harga.
- Aplikasi tidak punya fallback "insert order langsung" — bila RPC belum
  dipasang, checkout gagal dengan pesan ramah, bukan diam-diam tidak aman.
- Pembatalan hanya mengubah `order_status` menjadi `dibatalkan` dengan
  `cancel_reason`; stok **tidak** otomatis dikembalikan (kebijakan kios). Bila
  ingin restock otomatis, tambahkan RPC `cancel_market_order` di server.

## AI dan biaya

- System prompt dikunci di Edge Function; klien tidak bisa menggantinya.
- Function memverifikasi JWT dan kepemilikan `session_id` sebelum memanggil
  Gemini.
- Kuota harian diperiksa atomik lewat `consume_ai_quota` (default 5/hari,
  tanpa batas untuk Pro aktif). Habis → HTTP 429 → aplikasi menawarkan upgrade.
- Rekomendasi produk difilter terhadap katalog aktif di server.
- Pesan error Gemini tidak diteruskan ke klien; hanya `AI_UNAVAILABLE`.

## Media

- Bucket `consultations` **private**. Path `userId/sessionId/file` dengan policy
  folder pertama = `auth.uid()`, sehingga pengguna lain tidak bisa membaca.
- Foto ditampilkan lewat signed URL berumur pendek (1 jam).
- Ukuran foto dibatasi di klien (5 MB) dan di Edge Function (payload base64).
- `image_picker` mengecilkan foto (lebar maks 1280, kualitas 70) sebelum unggah.

## Platform

- Android: `allowBackup=false`, `fullBackupContent=false`,
  `usesCleartextTraffic=false`; hanya izin kamera, mikrofon, internet, dan
  galeri yang dibutuhkan.
- iOS: deskripsi izin kamera/mikrofon/pengenal suara/galeri wajib ada agar
  lolos review; enkripsi non-exempt dinyatakan `false` karena hanya HTTPS.
- Orientasi dikunci portrait lewat `SystemChrome.setPreferredOrientations`.

## Penanganan error

`SupabaseService.friendlyError` memetakan error auth/PostgREST/function ke pesan
Indonesia dan menyaring URL serta detail internal. Jangan menampilkan
`error.toString()` mentah ke pengguna baru.

## Utang keamanan yang diketahui

1. Status `paid` langganan Pro masih manual (admin). Idealnya webhook payment
   gateway.
2. Belum ada rate limit tambahan di Edge Function selain kuota harian.
3. Belum ada audit log akses data.
4. Belum ada penghapusan akun/data (UU PDP) — perlu RPC `delete_my_account`.

## Checklist review perubahan

- [ ] Tabel baru: `enable row level security` + policy minimal.
- [ ] Kolom baru yang memengaruhi harga/status/kuota: hanya ditulis server.
- [ ] Fungsi baru: `security definer` + `set search_path = public` +
      `revoke/grant` yang tepat.
- [ ] Tidak ada kunci rahasia di `lib/`, `assets/`, atau `.env`.
- [ ] Error baru tidak membocorkan detail internal.
