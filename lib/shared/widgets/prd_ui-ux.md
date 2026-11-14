# UI/UX Design System & Component PRD (`PRD_UI_UX.md`)
**Proyek:** TaniTernak Desa  
**Target Ergonomi:** Penggunaan luar ruang di bawah sinar matahari langsung, pengoperasian satu tangan, serta aksesibilitas lintas usia dari anak muda hingga orang tua umur 40-an ke atas.

---

## 1. Prinsip Desain & Ergonomi Lapangan

AI Code Generator **wajib** menerapkan empat hukum ergonomi berikut pada setiap halaman dan komponen:
1. **Kontras Luar Ruang:** Seluruh teks utama menggunakan kontras minimal `7:1` terhadap warna latar agar tetap terbaca jelas di bawah terik matahari sawah, kebun, atau kandang.
2. **Area Sentuh Ramah Jari:** Tinggi minimal elemen interaktif adalah `52dp` hingga `56dp` dengan jarak antar tombol minimal `12dp` untuk mencegah salah tekan saat tangan berkeringat atau kotor.
3. **Ikon Wajib Berlabel Teks:** Dilarang membuat tombol yang hanya berisi ikon tanpa keterangan teks di samping atau di bawahnya.
4. **Navigasi Datar Maksimal 4 Tab:** Hindari penggunaan menu samping tersembunyi. Seluruh fitur inti harus langsung terlihat di bilah navigasi bawah.

---

## 2. Design Tokens (Sistem Visual Global)

### A. Palet Warna Semantik
| Token Warna | Kode Hex | Fungsi Penggunaan |
| :--- | :--- | :--- |
| `primaryGreen` | `#1B5E20` | Tombol aksi utama, header aktif, dan identitas merek |
| `secondaryGreen` | `#2E7D32` | Aksen pendukung, ikon kategori aktif, dan indikator status sehat |
| `surfaceTintGreen` | `#E8F5E9` | Latar kotak sorotan solusi cepat dan balon chat pengguna |
| `accentOrange` | `#E65100` | Tombol panggilan suara, ajakan beli produk, dan badge akun Pro |
| `warningAmberBg` | `#FFF8E1` | Latar kotak peringatan takaran dosis pupuk, pakan, dan obat |
| `warningAmberBorder` | `#FFB300` | Garis tepi kotak peringatan dosis |
| `dangerRed` | `#C62828` | Peringatan gejala penyakit parah, stok habis, dan pesan gagal |
| `scaffoldBg` | `#F6F8F6` | Latar belakang utama layar agar tidak menyilaukan mata |
| `cardSurface` | `#FFFFFF` | Latar kartu konten dengan border tegas `#CBD5CB` ketebalan `1.5dp` |
| `textPrimary` | `#121612` | Judul dan isi paragraf utama |
| `textSecondary` | `#424A42` | Subjudul, nama kios, dan keterangan waktu |

### B. Skala Tipografi (`Plus Jakarta Sans` atau `Inter`)
* **Page Title (`headlineMedium`):** `22sp`, `FontWeight.w700`, letter-spacing `-0.3`
* **Section & Card Title (`titleLarge`):** `18sp`, `FontWeight.w700`, line-height `1.3`
* **Body & Solusi (`bodyLarge`):** `16sp`, `FontWeight.w400`, line-height `1.55`
* **Button & Tab Label (`labelLarge`):** `16sp`, `FontWeight.w600`, letter-spacing `0.2`
* **Caption / Harga Satuan (`bodySmall`):** `14sp`, `FontWeight.w500` *(batas minimum mutlak di seluruh aplikasi)*

### C. Sistem Spasi, Radius & Elevasi
* **Grid Spasi:** Kelipatan `8dp` (`8dp` antar elemen rapat, `16dp` padding dalam kartu dan tepi layar, `24dp` jarak antar bagian).
* **Border Radius:** Kartu besar `16dp`, tombol dan kolom input `12dp`, badge status `8dp`.
* **Elevasi & Garis Tepi:** Utamakan border tegas `1.5dp` warna `#CBD5CB` dibanding bayangan tipis agar batas kartu tetap kelihatan jelas di layar HP dengan tingkat kecerahan rendah.

---

## 3. Spesifikasi Komponen UI Kit (`lib/shared/widgets/`)

### Komponen 1: `BigActionButton` (`lib/shared/widgets/big_action_button.dart`)
Tombol aksi utama untuk seluruh tindakan penting seperti kirim OTP, mulai konsultasi, dan bayar pesanan.
* **Properti Dart:**
  * `required String label`
  * `required IconData icon`
  * `required VoidCallback? onPressed`
  * `Color backgroundColor = AppTheme.primaryGreen`
  * `bool isLoading = false`
  * `bool isOutlined = false`
* **Anatomi Visual:** Tinggi tetap `56dp`, lebar penuh layar, ikon ukuran `24dp` di sebelah kiri teks dengan jarak `12dp`, teks rata tengah maksimal 1 baris.
* **Interactive States:**
  * *Pressed:* Memicu `HapticFeedback.mediumImpact()` dan perubahan warna menekan yang jelas.
  * *Loading:* Menampilkan `CircularProgressIndicator` putih berdiameter `24dp` di sebelah teks `"Memproses..."` dan mengunci klik ganda.
  * *Disabled:* Latar abu-abu `#D8DFD8` dengan teks `#6E776E`.

### Komponen 2: `VoiceSearchBar` (`lib/shared/widgets/voice_search_bar.dart`)
Kolom pencarian gejala masalah yang menggabungkan ketikan teks dan tombol mikrofon besar untuk warga yang lebih nyaman berbicara.
* **Properti Dart:**
  * `required TextEditingController controller`
  * `required ValueChanged<String> onChanged`
  * `required VoidCallback onMicTap`
  * `required bool isListening`
  * `String hintText = 'Ketik atau ucapkan masalah, misal: daun cabai keriting'`
* **Anatomi Visual:** Tinggi `60dp`, sudut membulat `16dp`, border `2dp` warna `#1B5E20`. Di sisi kanan tertanam tombol mikrofon lingkaran berdiameter `46dp` berwarna `#E65100` dengan ikon mikrofon putih `24dp`.
* **Interactive States:**
  * *Listening Active:* Tombol mikrofon berdenyut merah `#C62828` disertai label kecil di bawah kolom berbunyi `"Sedang mendengarkan suara Anda... Silakan bicara"`.

### Komponen 3: `CategoryTileCard` (`lib/shared/widgets/category_tile_card.dart`)
Kartu pilihan sektor utama pada halaman beranda.
* **Properti Dart:**
  * `required String title` (`Tanaman Pangan`, `Perkebunan`, `Peternakan`)
  * `required String subtitle` (contoh: `Padi, Jagung, Cabai, Sayur`)
  * `required IconData icon`
  * `required Color accentColor`
  * `required bool isSelected`
  * `required VoidCallback onTap`
* **Anatomi Visual:** Tinggi minimal `88dp`, wadah ikon persegi membulat `52dp x 52dp` di kiri, judul `18sp` tebal dan subjudul `14sp` di tengah, serta ikon panah kanan `24dp`. Saat terpilih, latar berubah menjadi `#E8F5E9` dengan border hijau `2dp`.

### Komponen 4: `ProductRecommendCard` (`lib/shared/widgets/product_recommend_card.dart`)
Kartu produk pakan, pupuk, atau pestisida yang muncul di bawah artikel solusi dan di dalam ruang chat AI.
* **Properti Dart:**
  * `required String productId`
  * `required String name`
  * `required String formattedPrice`
  * `required String unit`
  * `required String storeName`
  * `String? imageUrl`
  * `String? usageNote`
  * `required VoidCallback onBuyTap`
* **Anatomi Visual:** Kartu putih dengan gambar produk persegi `84dp x 84dp` di kiri, nama produk maksimal 2 baris (`16sp` bold), harga tebal warna `#1B5E20` (`18sp`), badge nama kios, serta tombol hijau solid bertuliskan **"Lihat & Beli"** setinggi `44dp` di bagian bawah kartu.

### Komponen 5: `DosageHighlightBox` (`lib/shared/widgets/dosage_highlight_box.dart`)
Kotak panduan takaran pakai agar petani dan peternak tidak salah dosis saat mencampur pupuk, pestisida, atau vitamin ternak.
* **Properti Dart:**
  * `required String dosageText`
  * `String? activeIngredients`
* **Anatomi Visual:** Kotak dengan latar kuning hangat `#FFF8E1`, garis tepi kiri tebal `5dp` warna `#FFB300`, ikon gelas takar/peringatan `26dp`, judul tebal **"Takaran & Cara Pakai"**, dan isi teks `16sp` dengan spasi antar baris lega.

### Komponen 6: `OfflineStatusBanner` (`lib/shared/widgets/offline_status_banner.dart`)
Indikator status jaringan otomatis di bagian atas layar saat sinyal internet di kebun atau kandang terputus.
* **Properti Dart:**
  * `required bool isOffline`
* **Anatomi Visual:** Muncul halus dengan tinggi `40dp`, latar `#37474F`, ikon awan terputus putih, dan teks `14sp` berbunyi **"Mode Tanpa Sinyal — Menampilkan panduan tersimpan di HP"**.

### Komponen 7: `ConsultantChatBubble` (`lib/shared/widgets/consultant_chat_bubble.dart`)
Balon percakapan ala WhatsApp untuk fitur AI Agent dan konsultasi penyuluh.
* **Properti Dart:**
  * `required bool isUser`
  * `String? messageText`
  * `String? imageUrl`
  * `String? audioDurationLabel`
  * `VoidCallback? onPlayAudio`
  * `List<Widget> recommendedProductCards = const []`
  * `required String timeLabel`
* **Anatomi Visual:**
  * Balon pengguna rata kanan berwarna `#DCF8C6` dengan border `#B2DFDB`.
  * Balon AI rata kiri berwarna `#FFFFFF` dengan label kecil di atasnya bertuliskan **"Asisten Tani & Ternak"** beserta ikon perisai centang hijau.
  * Lampiran foto penyakit ditampilkan dengan rasio aspek `4:3`, sudut membulat `12dp`, dan dapat diketuk untuk diperbesar penuh.

---

## 4. Blueprint Tata Letak Layar Utama

### A. Bilah Navigasi Bawah (`BottomNavigationBar`)
Tinggi `72dp`, latar putih dengan garis atas `#CBD5CB`, selalu menampilkan label teks di bawah ikon:
1. **Cari Solusi** (`Icons.search_rounded`) — Halaman beranda pencarian masalah & panduan.
2. **Tanya AI** (`Icons.chat_bubble_rounded`) — Ruang konsultasi AI Agent foto & suara.
3. **Toko Tani** (`Icons.storefront_rounded`) — Marketplace pakan, pupuk, pestisida & keranjang.
4. **Usaha Pro** (`Icons.workspace_premium_rounded`) — Jadwal perawatan otomatis, pembukuan panen & profil.

### B. Layar Beranda & Pencarian (`home_search_screen.dart`)
Susunan vertikal dari atas ke bawah dalam `SingleChildScrollView`:
1. `OfflineStatusBanner` jika perangkat tidak terhubung internet.
2. Header sapaan hangat (`"Halo, Pak/Bu [Nama]"`), status lencana (`Akun Gratis` atau `Juragan Pro`), dan pintasan keranjang belanja dengan badge angka merah.
3. `VoiceSearchBar` ukuran besar sebagai elemen fokus pertama.
4. Baris tombol cepat **Tanya AI Langsung** berlatar oranye lembut untuk kasus yang butuh foto daun atau rekaman suara.
5. Daftar 3 `CategoryTileCard` (`Tanaman Pangan`, `Perkebunan`, `Peternakan`).
6. Bagian **"Masalah yang Sering Dicari"** berisi kartu artikel ringkas yang dapat langsung diketuk.

### C. Layar Detail Solusi (`article_detail_screen.dart`)
1. Judul masalah (`22sp` bold) dan badge nama komoditas.
2. Tombol besar penuh lebar berlatar `#E65100` dengan ikon speaker: **"Dengarkan Panduan Suara"** yang berubah menjadi **"Hentikan Suara"** saat audio pembaca teks aktif.
3. Kartu **Penyebab Utama** dengan ikon tanda tanya.
4. Kartu **Langkah Penanganan Cepat** dengan nomor urut lingkaran hijau besar (`1`, `2`, `3`) di sebelah kiri tiap langkah.
5. Bagian **Rekomendasi Produk Terkait** yang merender daftar `ProductRecommendCard`.

---

## 5. Micro-Interactions & Penanganan Kondisi Kosong

* **Loading State:** Gunakan efek *shimmer* abu-abu lembut berbentuk kartu saat mengambil data dari Supabase, hindari layar putih kosong dengan spinner kecil di tengah.
* **Empty State Pencarian:** Jika kata kunci gejala tidak ditemukan di basis pengetahuan, tampilkan ilustrasi ramah dan tombol besar **"Tanyakan Masalah Ini ke AI Agent"** yang otomatis membawa kata kunci pencarian pengguna ke ruang chat AI.
* **Konfirmasi Transaksi & Hapus Data:** Setiap tindakan krusial seperti checkout COD atau menghapus jadwal perawatan wajib memunculkan dialog konfirmasi dengan dua tombol bertumpuk vertikal (`Ya, Lanjutkan` di atas dan `Batal` di bawah) agar tidak tertekan tidak sengaja.