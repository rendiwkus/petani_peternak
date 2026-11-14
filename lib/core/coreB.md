# Technical PRD — Bagian B: `lib/core/`
**Role Modul:** Infrastruktur inti aplikasi (konfigurasi `.env`, konstanta bisnis & database, client Supabase Auth/DB/Storage, cache offline Hive, tema global, dan helper format data).  
**Aturan Arsitektur:** Folder `lib/core/` tidak boleh meng-import file apa pun dari `lib/features/` atau `lib/shared/` untuk mencegah *circular dependency*.

---

## 1. Setup Environment (`.env` di Root Proyek)
Pastikan file `.env` sudah ada di root proyek dan terdaftar di `pubspec.yaml` pada bagian `assets`:

```env
SUPABASE_URL= https://efhffpytctfkoubpjoie.supabase.co
SUPABASE_ANON_KEY=sb_publishable_wIpK6FcvXNLudfVBklpV6w_oo8WHiS2
