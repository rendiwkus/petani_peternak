# Data Uji & Akun Testing

Panduan membuat akun uji (mitra kios dan penguji) serta data contoh yang sudah
ada di Supabase live, supaya setiap rilis bisa diuji ulang dengan langkah sama.

## 1. Akun uji

Buat akun lewat **Supabase Dashboard → Authentication → Users → Add user**,
lalu aktifkan **Auto Confirm User** (email `example.com` ditolak Supabase dan
konfirmasi email butuh kotak masuk sungguhan).

| Peran | Email | Password | Catatan |
| --- | --- | --- | --- |
| Mitra kios | `mitra.kios@taniternakdesa.id` | `<isi-saat-membuat-akun>` | role `mitra_kios`, lihat pesanan masuk |
| Mitra kios 2 | `mitra.ternak@taniternakdesa.id` | `<isi-saat-membuat-akun>` | toko pakan & obat ternak |
| Petani (gratis) | `petani.uji@taniternakdesa.id` | `<isi-saat-membuat-akun>` | kuota AI 5 tanya/hari |
| Petani (Pro) | `pro.uji@taniternakdesa.id` | `<isi-saat-membuat-akun>` | `is_pro = true`, tanpa batas kuota |
| Penyuluh | `penyuluh@taniternakdesa.id` | `<isi-saat-membuat-akun>` | role `penyuluh` |

Aturan:

- Jangan menulis password asli di repo. Simpan di password manager tim.
- Bila perlu berbagi antar pengembang, taruh di `.env.test` (sudah di-`gitignore`
  lewat pola `.env*`, hanya `.env.example` yang di-commit).
- Ganti domain email bila ada domain resmi; yang penting bukan `example.com`.
- Setelah login email berhasil, isi nomor HP di profil agar tampilan
  `displayPhone` dan alur OTP bisa diuji tanpa akun terpisah.

Naikkan akun uji jadi Pro (jalankan di SQL Editor, bukan dari aplikasi):

```sql
update public.profiles
   set is_pro = true,
       pro_expires_at = now() + interval '30 days'
 where id = (select id from auth.users
              where email = 'pro.uji@taniternakdesa.id');
```

Reset kuota AI akun gratis:

```sql
update public.profiles
   set daily_ai_quota_used = 0, last_quota_reset = now()
 where id = (select id from auth.users
              where email = 'petani.uji@taniternakdesa.id');
```

## 2. Data seed yang sudah ada

### Toko

| Toko | ID | Wilayah |
| --- | --- | --- |
| Kios Tani Subur Makmur | `33333333-3333-3333-3333-333333333333` | Sukasada, Buleleng |
| UD Ternak Jaya Pakan & Obat | `44444444-4444-4444-4444-444444444444` | Banjar, Buleleng |

### Produk contoh (stok bisa berubah setelah uji checkout)

| Produk | Kategori | Harga | Stok awal |
| --- | --- | --- | --- |
| Pupuk NPK Mutiara 16-16-16 (1 kg) | `pupuk` | 22.000 | 120 |
| Insektisida Abamectin 18 EC (100 ml) | `pestisida` | 38.000 | 65 |
| Fungisida Mankozeb 80 WP (400 gr) | `pestisida` | 45.000 | 40 |
| Benih Cabai Rawit Unggul (10 gr) | `bibit_benih` | 35.000 | 50 |
| Pakan Konsentrat Ayam BR-1 (5 kg) | `pakan` | 58.000 | 90 |
| Vita Chicks Vitamin & Anti Stres (250 gr) | `obat_ternak` | 25.000 | 80 |
| Obat Cacing Kalbazen SG (100 ml) | `obat_ternak` | 32.000 | 45 |

Catat stok sebelum uji agar bisa dikembalikan:

```sql
select id, name, stock from public.products order by name;
```

### Artikel panduan

| Artikel | Kategori | Kata kunci uji |
| --- | --- | --- |
| Daun Cabai Keriting, Menguning, dan Tanaman Kerdil | `pertanian` | `kutu kebul`, `keriting` |
| Daun Padi Bercak Cokelat dan Mengering | `pertanian` | `bercak coklat`, `blas` |
| Buah Kopi Muda Rontok dan Biji Menghitam | `perkebunan` | `kopi rontok` |
| Ayam Lemas, Sayap Menggantung | `peternakan` | `ayam lemas` |
| Sapi Kurus dan Bulu Kusam | `peternakan` | `sapi kurus`, `cacingan` |

Komoditas: Padi Sawah, Cabai Rawit, Jagung, Kopi Robusta, Kakao, Ayam Kampung,
Sapi Potong.

## 3. Skenario uji manual

### Auth

1. Login email akun uji → `AuthGate` menampilkan shell 4 tab.
2. Tutup aplikasi lalu buka lagi → sesi tetap masuk (session restore).
3. Login OTP HP: **hanya jalan bila provider Phone aktif** di dashboard.
   Tanpa provider, aplikasi menampilkan pesan gagal kirim OTP.
4. Logout → kembali ke `LoginScreen`.

### Cari Solusi

1. Ketik `ayam lemas` → artikel peternakan muncul paling atas.
2. Tekan mikrofon, ucapkan `daun padi bercak coklat` → kolom terisi otomatis
   (butuh izin mikrofon dan layanan pengenal suara di HP).
3. Buka artikel → tekan **Dengarkan Panduan Suara** (TTS bahasa Indonesia).
4. Matikan data/Wi-Fi → buka artikel yang pernah dibuka → tetap tampil dari
   cache Hive dan banner "Mode Tanpa Sinyal" muncul.

### Tanya AI

1. Akun gratis: kirim 5 pertanyaan → pertanyaan ke-6 mendapat tawaran upgrade
   (Edge Function balas 429).
2. Kirim foto daun + teks → jawaban berisi bagian penyebab, langkah cepat, saran
   produk dari kios mitra.
3. Selama Edge Function belum di-deploy → aplikasi memakai panduan artikel
   lokal, tanpa error.
4. Akun Pro (`is_pro = true`) → tidak kena batas kuota.

### Toko Tani

1. Tambah 2 produk dari toko berbeda → keranjang memisahkan/menandai toko.
2. Ubah jumlah, hapus item, lalu buka checkout.
3. Isi alamat < 10 huruf → validasi menolak.
4. Checkout sukses → nomor `TT-YYMMDD-XXXXXX`, stok produk berkurang, item
   hilang dari keranjang.
5. Ubah `grand_total` lewat request manual → RPC tetap memakai harga server
   (total di klien hanya perkiraan).
6. Batalkan pesanan `pending` → status `dibatalkan`, pesanan `diproses` tidak
   punya tombol batal.

### Usaha Pro

1. Tambah jadwal pemupukan besok → muncul di bagian "Akan Datang".
2. Tandai selesai → pindah ke "Sudah Selesai"; jadwal lewat tanggal diberi
   label merah "Terlewat".
3. Catat pemasukan 200.000 dan pengeluaran 50.000 → saldo 150.000.
4. Buat tagihan paket 30 hari → invoice `PRO-...` tersimpan sebagai `pending`;
   status Pro baru aktif setelah admin meng-update `payment_status`.

## 4. Cek cepat server

```sql
-- RPC wajib ada
select proname from pg_proc
 where proname in ('increment_article_view','create_market_order',
                   'request_pro_subscription','consume_ai_quota');

-- RLS aktif
select tablename, rowsecurity from pg_tables
 where schemaname = 'public' order by tablename;
```

```bash
curl -s "https://<project-ref>.supabase.co/auth/v1/settings" \
  -H "apikey: <publishable-key>"
# "phone": true  -> OTP HP siap diuji
```

## 5. Kondisi live saat dokumen ini dibuat

- Provider Phone **nonaktif** → OTP HP belum bisa diuji end-to-end.
- Migrasi `20261115000000_security_and_rpc.sql` belum dijalankan → checkout,
  tagihan Pro, dan kuota AI server gagal dengan pesan ramah.
- Edge Function `ai-consultant` belum di-deploy → AI memakai fallback artikel.
- Belum ada akun uji di database; akun pada tabel di atas harus dibuat manual.

Setelah tiga hal pertama beres, ulangi seluruh skenario di bagian 3.
