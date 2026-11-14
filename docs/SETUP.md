# Setup Supabase

Panduan ini menyiapkan server yang dipakai aplikasi: RLS, RPC, storage privat,
dan Edge Function AI.

## 1. Kredensial klien

Salin `.env.example` ke `.env`:

```
SUPABASE_URL=https://<project-ref>.supabase.co
SUPABASE_ANON_KEY=<publishable / anon key>
AI_FUNCTION_NAME=ai-consultant
```

Ini satu-satunya kunci yang boleh ada di HP. **Jangan** menaruh
`SUPABASE_SERVICE_ROLE_KEY` atau `GEMINI_API_KEY` di `.env` aplikasi.

## 2. Migrasi database

Jalankan `supabase/migrations/20261115000000_security_and_rpc.sql` di SQL
Editor, atau:

```bash
supabase link --project-ref <project-ref>
supabase db push
```

Migrasi ini membuat:

| Objek | Kegunaan |
| --- | --- |
| Policy RLS `*_public_read` | katalog (`commodities`, `stores`, `products`, `knowledge_articles`) bisa dibaca anon |
| Policy `*_own` | data pengguna hanya bisa diakses pemiliknya |
| `guard_profile_privileges` | klien tidak bisa menaikkan `role`, `is_pro`, `pro_expires_at`, atau kuota AI |
| `guard_market_order_update` | klien hanya boleh membatalkan pesanan `pending` |
| `increment_article_view(uuid)` | statistik baca tanpa izin UPDATE tabel |
| `create_market_order(uuid, jsonb, text)` | checkout: harga & stok dihitung server, stok dipotong atomik |
| `request_pro_subscription(int, text, numeric)` | tagihan Pro dengan harga resmi server |
| `consume_ai_quota(uuid)` | kuota AI harian, hanya untuk service role |
| Storage policy `consultations_*_own` | foto konsultasi privat per folder pengguna |

Verifikasi cepat di SQL Editor:

```sql
select proname from pg_proc
 where proname in ('increment_article_view','create_market_order',
                   'request_pro_subscription','consume_ai_quota');
```

## 3. Autentikasi

Aplikasi memakai **OTP nomor HP** sebagai jalur utama dan **email/password**
sebagai jalur mitra kios/pengujian.

1. Authentication → Providers → **Phone**: aktifkan dan isi provider SMS
   (mis. Twilio). Tanpa provider, OTP HP akan gagal.
2. Untuk pengujian cepat: Authentication → Users → **Add user**, isi email dan
   password, lalu aktifkan **Auto Confirm** agar bisa login tanpa klik tautan
   email.
3. Isi template SMS agar kode mudah dibaca, mis.:
   `Kode masuk TaniTernak Desa Anda: {{ .Token }}`

Bila login email dipakai untuk produksi, matikan kembali akun uji dan wajibkan
konfirmasi email.

## 4. Edge Function `ai-consultant`

```bash
supabase login
supabase link --project-ref <project-ref>
supabase secrets set GEMINI_API_KEY=<kunci-gemini> --project-ref <project-ref>
supabase functions deploy ai-consultant --project-ref <project-ref>
```

`SUPABASE_URL`, `SUPABASE_ANON_KEY`, dan `SUPABASE_SERVICE_ROLE_KEY` otomatis
tersedia di runtime function.

Sifat function:

- Memverifikasi JWT pengguna (`auth.getUser()`) sebelum memproses.
- Menolak sesi chat milik pengguna lain.
- Mengunci **system prompt** di server; klien tidak mengirim prompt.
- Memeriksa kuota lewat `consume_ai_quota` (429 bila habis).
- Hanya merekomendasikan produk aktif dari kios mitra.

Uji manual:

```bash
curl -i -X POST "https://<ref>.supabase.co/functions/v1/ai-consultant" \
  -H "Authorization: Bearer <access_token_pengguna>" \
  -H "Content-Type: application/json" \
  -d '{"session_id":"<uuid>","message":"daun cabai keriting"}'
```

Tanpa function aktif, aplikasi otomatis memakai panduan lokal yang tersimpan di
HP (tidak error, tetapi tanpa analisis foto).

## 5. Storage

Bucket `consultations` harus **private**. Migrasi sudah menjalankannya:

```sql
select id, public from storage.buckets where id = 'consultations';
```

Path foto mengikuti `userId/sessionId/timestamp.jpg`, sehingga policy
`(storage.foldername(name))[1] = auth.uid()::text` cukup untuk mengisolasi
pengguna.

## 6. Verifikasi pembayaran & aktivasi Pro

Aplikasi hanya membuat tagihan `pending`. Aktivasi dilakukan admin **di server**
(mis. SQL Editor dengan service role):

```sql
update public.subscription_transactions
   set payment_status = 'paid', paid_at = now()
 where invoice_number = 'PRO-...';

update public.profiles
   set is_pro = true,
       pro_expires_at = now() + interval '30 days'
 where id = '<user-id>';
```

Jangan pernah memberi klien izin menulis `is_pro`; trigger
`guard_profile_privileges` akan mengembalikannya.

## 7. Checklist rilis

- [ ] Migrasi dijalankan dan `pg_proc` memuat semua RPC.
- [ ] Provider SMS aktif dan template SMS berisi `{{ .Token }}`.
- [ ] `GEMINI_API_KEY` terpasang sebagai secret (bukan di `.env`).
- [ ] Bucket `consultations` private.
- [ ] `.env` berisi publishable key saja.
- [ ] `flutter analyze` dan `flutter test` hijau.
