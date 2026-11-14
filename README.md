# TaniTernak Desa

Aplikasi Flutter untuk petani & peternak desa: cari solusi lewat suara, tanya
AI dengan foto, beli saprodi dari kios mitra, dan catat jadwal serta keuangan
usaha. Dirancang untuk layar HP, teks besar, tombol besar, dan sinyal desa yang
kadang hilang.

## Fitur

- **Cari Solusi (voice-first)**: pencarian gejala penyakit dengan mikrofon,
  filter kategori, teks besar, dan tombol "Dengarkan Panduan Suara" (TTS).
- **Tanya AI**: konsultasi ala WhatsApp dengan teks, foto, dan suara. API key
  Gemini hanya ada di Supabase Edge Function, tidak pernah di APK.
- **Toko Tani**: katalog pupuk/pakan/pestisida, keranjang, checkout yang harga
  dan stoknya divalidasi RPC server, serta riwayat pesanan.
- **Usaha Pro**: jadwal perawatan, pembukuan pemasukan/pengeluaran, dan tagihan
  langganan Pro.
- **Offline-first**: artikel, katalog, jadwal, dan catatan keuangan di-cache
  dengan Hive. Banner "Mode Tanpa Sinyal" muncul otomatis.

## Tumpukan

Flutter 3.47 / Dart 3.13, Supabase (Auth, Postgres + RLS, Storage, Edge
Functions), Hive, `speech_to_text`, `flutter_tts`, `image_picker`.

## Mulai cepat

```bash
cp .env.example .env      # isi SUPABASE_URL + publishable key
flutter pub get
flutter run
```

`.env` tidak boleh di-commit. Hanya **publishable/anon key** yang boleh ada di
klien. Service role key dan `GEMINI_API_KEY` disimpan sebagai secret Supabase.

Setup server (RLS, RPC, Edge Function) ada di
[docs/SETUP.md](docs/SETUP.md). Ringkasan kontrol keamanan ada di
[docs/SECURITY.md](docs/SECURITY.md). Akun uji dan data seed untuk pengujian ada
di [docs/TESTING.md](docs/TESTING.md).

## Struktur

```
lib/
  core/            konfigurasi env, konstanta, tema, service (Supabase, cache, konektivitas)
  shared/widgets/  komponen UI besar (tombol aksi, kartu produk, balon chat, dll.)
  features/
    auth/          OTP nomor HP + email fallback, profil pengguna
    knowledge_search/  panduan solusi + TTS
    ai_consultant/     chat AI via Edge Function + fallback lokal
    marketplace/       katalog, keranjang, checkout, pesanan
    pro_features/      jadwal perawatan, keuangan, langganan Pro
supabase/
  migrations/      RLS + RPC (checkout, kuota AI, tagihan Pro)
  functions/       ai-consultant (Gemini, system prompt terkunci)
test/              unit test logika formatter
```

## Perintah

```bash
flutter analyze
flutter test
flutter build apk --release
```

Catatan rilis: `--release` tetap membaca `.env` yang dibundel sebagai asset.
Karena itu `.env` hanya berisi kunci publik; jangan pernah menaruh rahasia di
sana.
