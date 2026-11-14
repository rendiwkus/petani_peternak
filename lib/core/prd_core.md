# Product Requirements Document (PRD)
**Nama Proyek:** TaniTernak Desa (Aplikasi Perawatan Pertanian, Perkebunan, Peternakan & Marketplace)  
**Tech Stack:** Flutter (Frontend & Offline Cache), Supabase (Auth, PostgreSQL, Storage), Gemini API (AI Agent Multimodal)  
**Metode Pengembangan:** Agile Scrum (4 Sprint)

---

## 1. Gambaran Produk & Tujuan Bisnis

### A. Latar Belakang & Masalah
Petani dan peternak di pedesaan sering kesulitan mendiagnosa penyakit tanaman atau gangguan kesehatan ternak secara cepat saat berada di kebun atau kandang. Selain itu, akses informasi takaran pupuk, pakan, dan pestisida yang tepat masih terbatas.

### B. Target Pengguna
1. **Warga Desa Usia 40-an ke Atas (Fokus Utama UX):** Membutuhkan tampilan super sederhana, tulisan besar, ikon jelas, minim ketikan (bisa pakai suara/foto), dan alur mirip aplikasi sehari-hari seperti WhatsApp.
2. **Anak Muda Desa / Petani Milenial:** Membutuhkan fitur manajemen usaha tani yang modern, pencatatan keuangan, jadwal perawatan otomatis, dan konsultasi AI cepat.
3. **Mitra Kios Tani & Ternak Lokal:** Pemilik toko pertanian/peternakan di kecamatan yang menjual produk lewat marketplace aplikasi.

### C. Model Bisnis & Monetisasi
1. **Freemium ke Akun Advance (Pro):**
   - **Gratis:** Pencarian solusi penyakit sepuasnya, akses marketplace, dan kuota tanya AI Agent terbatas (`5` pertanyaan per hari).
   - **Akun Advance / Pro (Berlangganan):** Tanya AI Agent tanpa batas, pengingat jadwal pemupukan/penyemprotan/vaksinasi otomatis, pembukuan modal vs hasil panen, dan chat langsung dengan penyuluh pertanian atau dokter hewan.
2. **Komisi & Biaya Layanan Marketplace:**
   - Penjualan pakan ternak, pupuk, pestisida, obat ternak, dan benih dari kios mitra lokal dengan potongan komisi platform tiap transaksi sukses.
   - Jalur transaksi langganan akun Pro (`subscription_transactions`) dipisah total dari jalur transaksi belanja marketplace (`market_orders` & `market_payments`).

---

## 2. Standar Wajib UI/UX (Ramah Usia 40-an & Sinyal Desa)

AI Code Generator **wajib** mematuhi aturan antarmuka berikut di seluruh halaman:
1. **Ukuran Huruf & Kontras:** Ukuran teks isi minimal `16sp`, judul kartu minimal `18sp`, judul halaman minimal `22sp`. Gunakan kontras warna tinggi (teks gelap `#1A1A1A` di atas latar putih/terang `#F8FAF8`).
2. **Area Sentuh Besar:** Tinggi tombol minimal `52dp–56dp` dengan sudut membulat `12px` dan ikon besar agar mudah ditekan jari orang tua.
3. **Minim Mengetik (Voice & Camera First):** Sediakan tombol mikrofon besar (`speech_to_text`) di kolom pencarian dan ruang chat AI, serta tombol kamera besar untuk foto daun/ternak sakit.
4. **Ramah yang Sulit Membaca Panjang:** Sediakan tombol **"Dengarkan Solusi"** (`flutter_tts`) di halaman artikel solusi.
5. **Tahan Sinyal Lemah (Offline-First):** Panduan solusi penyakit dan jadwal perawatan wajib di-cache secara lokal di memori HP menggunakan Hive agar tetap terbuka saat sinyal internet hilang di kebun atau kandang.

---

## 3. Konfigurasi Kredensial & Environment (`.env`)

Buat file `.env` di folder root proyek (tambahkan `.env` ke `.gitignore` agar kredensial aman):

```env
# Koneksi Klien Flutter ke Supabase
SUPABASE_URL=[https://masukkan-project-id-kamu.supabase.co](https://masukkan-project-id-kamu.supabase.co)
SUPABASE_ANON_KEY=masukkan-anon-public-key-kamu

# Kredensial Database PostgreSQL (Hanya untuk CLI/Migrasi/Server, JANGAN dipanggil di UI APK)
SUPABASE_DB_HOST=db.masukkan-project-id-kamu.supabase.co
SUPABASE_DB_PORT=5432
SUPABASE_DB_NAME=postgres
SUPABASE_DB_USER=postgres
SUPABASE_DB_PASSWORD=masukkan-password-database-supabase-kamu

# API Key AI Agent
GEMINI_API_KEY=masukkan-gemini-api-key-kamu