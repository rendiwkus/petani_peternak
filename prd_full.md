# Technical PRD — Fitur Aplikasi (`PRD_FEATURES.md`)
**Cakupan Modul:** Bagian D (`auth`), Bagian E (`knowledge_search`), Bagian F (`ai_consultant`), Bagian G (`marketplace`), dan Bagian H (`pro_features`).  
**Dependensi Internal:** Wajib mengimpor pondasi dari `lib/core/` (`PRD_CORE.md`) dan komponen UI dari `lib/shared/widgets/` (`PRD_UI_UX.md`).

---

## Bagian D: `lib/features/auth/` (Autentikasi & Manajemen Profil)
**Tabel Supabase:** `auth.users`, `public.profiles`  
**Tujuan:** Akses masuk cepat tanpa password rumit bagi warga desa menggunakan OTP nomor HP (`+62`), serta dukungan login email untuk akun mitra kios dan testing.

### 1. `lib/features/auth/data/auth_repository.dart`
* **Class:** `AuthRepository`
* **Model Data (`UserProfileModel`):**
  * Properti: `id`, `fullName`, `phoneNumber`, `avatarUrl`, `role` (`petani`, `mitra_kios`, `penyuluh`, `admin`), `village`, `district`, `regency`, `province`, `fullAddress`, `isPro`, `proExpiresAt`, `dailyAiQuotaUsed`, `lastQuotaReset`.
  * Getter helper: `bool get isProActive => isPro && (proExpiresAt == null || proExpiresAt!.isAfter(DateTime.now()));`
* **Method Wajib:**
  * `Future<void> requestPhoneOtp(String rawPhone)`: Menormalisasi nomor menggunakan `AppFormatters.normalizePhone(rawPhone)` lalu memanggil `SupabaseService.instance.sendPhoneOtp()`.
  * `Future<UserProfileModel> verifyPhoneOtp({required String rawPhone, required String otpCode})`: Verifikasi kode OTP 6 digit, lalu panggil `fetchCurrentProfile()`.
  * `Future<UserProfileModel> loginWithEmail({required String email, required String password})`: Login email/password untuk testing akun mitra kios, lalu panggil `fetchCurrentProfile()`.
  * `Future<UserProfileModel?> fetchCurrentProfile()`: Mengambil baris dari `public.profiles` berdasarkan `currentUserId`. Simpan hasilnya ke `OfflineCacheService.instance.saveMap(AppConstants.boxUserProfile, 'current_user', data)`. Jika offline, kembalikan data dari cache lokal.
  * `Future<void> updateProfile({required String fullName, String? village, String? district, String? regency, String? fullAddress})`: Melakukan `UPDATE` ke `public.profiles` pada kolom non-sensitif (aman dari trigger proteksi RLS) dan memperbarui cache lokal.
  * `Future<void> logout()`: Memanggil `SupabaseService.instance.signOut()` dan `OfflineCacheService.instance.clearUserCache()`.

### 2. `lib/features/auth/presentation/login_screen.dart`
* **Widget:** `LoginScreen` (`StatefulWidget`)
* **Spesifikasi UI & Alur:**
  * **Tahap 1 (Input Nomor HP):** Judul besar `"Masuk ke Aplikasi TaniTernak"`, subjudul `"Masukkan nomor HP atau WhatsApp Anda untuk menerima kode masuk"`, kolom input angka besar (`keyboardType: TextInputType.phone`) dengan prefix `+62`, dan tombol `BigActionButton(label: 'Kirim Kode Masuk (OTP)', icon: Icons.sms_rounded)`. Sediakan tombol teks kecil di bawah untuk opsi `"Masuk dengan Email (Mitra Kios / Testing)"`.
  * **Tahap 2 (Verifikasi OTP):** Tampilkan nomor tujuan, kolom input 6 digit angka besar rata tengah (`fontSize: 24`, `letterSpacing: 8`), tombol `BigActionButton(label: 'Verifikasi & Masuk', icon: Icons.check_circle_rounded)`, serta tombol hitung mundur `60` detik untuk `"Kirim Ulang Kode"`.
  * Tangani seluruh error autentikasi dan tampilkan `SnackBar` berbahasa Indonesia ramah (misal: `"Kode OTP salah atau sudah kedaluwarsa, silakan coba lagi"`).

---

## Bagian E: `lib/features/knowledge_search/` (Pencarian Masalah & Solusi Instan)
**Tabel Supabase:** `commodities`, `knowledge_articles`, `article_recommended_products`, `products`, `stores`  
**Tujuan:** Halaman utama aplikasi tempat petani dan peternak mencari solusi gejala penyakit lewat ketikan maupun suara, tetap jalan saat tanpa sinyal, dan terhubung langsung ke produk marketplace.

### 1. `lib/features/knowledge_search/data/models/article_model.dart`
* **Class:** `ArticleModel` & `ArticleProductRecommendation`
* **Properti `ArticleModel`:** `id`, `commodityId`, `commodityName`, `category` (`pertanian`, `perkebunan`, `peternakan`), `title`, `symptomsKeywords`, `mainCause`, `quickSolution`, `preventionTips`, `imageUrl`, `viewCount`, dan `List<ArticleProductRecommendation> recommendedProducts`.
* **Properti `ArticleProductRecommendation`:** `usageNote`, `productId`, `productName`, `price`, `unit`, `imageUrl`, `storeName`, `storeDistrict`.
* **Factory:** `ArticleModel.fromJson(Map<String, dynamic> json)` untuk mem-parsing hasil relasi nested select Supabase beserta konversi ke `toJson()` untuk penyimpanan cache Hive.

### 2. `lib/features/knowledge_search/data/knowledge_repository.dart`
* **Class:** `KnowledgeRepository`
* **Method Wajib:**
  * `Future<List>> fetchCommodities({String? category})`: Mengambil daftar komoditas dari tabel `commodities`.
  * `Future<List<ArticleModel>> searchArticles({String? query, String? category, String? commodityId})`:
    * Melakukan query ke `knowledge_articles` dengan nested select `commodities(id, name)` dan `article_recommended_products(usage_note, products(id, name, price, unit, image_url, stores(store_name, district)))` dimana `is_published = true`.
    * Jika `category` diisi, filter `.eq('category', category)`.
    * Jika `commodityId` diisi, filter `.eq('commodity_id', commodityId)`.
    * Jika `query` tidak kosong, jalankan `.or('title.ilike.%$q%,symptoms_keywords.ilike.%$q%')`.
    * Jika query tanpa filter berhasil, simpan seluruh hasil ke `OfflineCacheService.instance.saveList(AppConstants.boxArticles, ...)`.
    * **Offline Fallback:** Tangkap `SocketException` atau error jaringan; ambil data dari `OfflineCacheService.instance.getList(AppConstants.boxArticles)` lalu filter di memori Dart berdasarkan `query` dan `category`.
  * `Future<void> incrementViewCount(String articleId)`: Menambah `view_count` artikel di latar belakang tanpa memblokir UI.

### 3. `lib/features/knowledge_search/presentation/home_search_screen.dart`
* **Widget:** `HomeSearchScreen` (`StatefulWidget`)
* **Spesifikasi UI & Alur:**
  * Di bagian paling atas tampilkan `OfflineStatusBanner(isOffline: _isOffline)`.
  * Header sapaan (`"Halo, [Nama User]"`) beserta badge status akun (`Gratis` atau `Juragan Pro`) dan ikon keranjang belanja.
  * Gunakan `VoiceSearchBar` yang terhubung ke package `speech_to_text` (locale `id_ID`). Saat tombol mikrofon ditekan, dengarkan suara pengguna dan otomatis masukkan hasil transkrip ke kolom pencarian lalu jalankan pencarian.
  * Kartu pintasan cepat berlatar `#FFF3E0` dengan tombol `"Punya foto daun/ternak sakit? Tanya AI Sekarang"` yang mengarahkan ke tab/layar `AiChatScreen`.
  * Tampilkan 3 `CategoryTileCard`: **Tanaman Pangan** (`pertanian`), **Perkebunan** (`perkebunan`), dan **Peternakan** (`peternakan`). Mengetuk kartu memfilter daftar artikel di bawahnya (ketuk ulang untuk reset filter).
  * **Empty State:** Jika hasil pencarian kosong, tampilkan pesan ramah dan tombol `BigActionButton` berlabel `"Tanyakan Gejala Ini ke AI Agent"` yang membawa teks `query` langsung ke `AiChatScreen`.

### 4. `lib/features/knowledge_search/presentation/article_detail_screen.dart`
* **Widget:** `ArticleDetailScreen` (`StatefulWidget`, menerima `ArticleModel article`)
* **Spesifikasi UI & Alur:**
  * Integrasi `flutter_tts` dengan konfigurasi `setLanguage('id-ID')` dan `setSpeechRate(0.45)` agar pelafalan jelas bagi orang tua usia 40-an.
  * Tombol besar oranye `#E65100` di atas konten: **"Dengarkan Panduan Suara"** (berubah menjadi **"Hentikan Suara"** saat sedang membacakan `mainCause` dan `quickSolution`). Pastikan `flutterTts.stop()` dipanggil pada `dispose()`.
  * Tampilkan bagian **Penyebab Utama** dalam kartu putih berborder tegas.
  * Pecah `quickSolution` berdasarkan baris baru (`\n`) dan tampilkan dengan badge nomor urut lingkaran hijau besar (`1`, `2`, `3`) di sisi kiri setiap langkah.
  * Jika `preventionTips` ada, tampilkan dalam kotak aksen hijau lembut `#E8F5E9`.
  * Di bagian bawah, tampilkan daftar `ProductRecommendCard` untuk setiap item di `article.recommendedProducts`.

---

## Bagian F: `lib/features/ai_consultant/` (AI Agent Konsultan Tani & Ternak)
**Tabel Supabase:** `ai_chat_sessions`, `ai_chat_messages`, `profiles`, `products`  
**Bucket Storage:** `consultations` (`AppConstants.bucketConsultations`)  
**Tujuan:** Ruang konsultasi interaktif ala WhatsApp berbasis Gemini API yang mampu menganalisis teks, foto daun/ternak, dan suara, serta merekomendasikan produk katalog.

### 1. `lib/features/ai_consultant/data/models/chat_message_model.dart`
* **Class:** `ChatMessageModel`
* **Properti:** `id`, `sessionId`, `sender` (`'user'` atau `'ai'`), `messageText`, `imageUrl` (path storage privat), `audioUrl` (path storage privat), `audioTranscript`, `List<String> recommendedProductIds`, `createdAt`, serta properti runtime `String? signedImageUrl` dan `List> resolvedProducts`.

### 2. `lib/features/ai_consultant/data/ai_chat_repository.dart`
* **Class:** `AiChatRepository` & Custom Exception `QuotaExceededException`
* **System Prompt Terkunci (`_systemPrompt`):**
  ```text
  Kamu adalah Asisten Penyuluh Pertanian dan Dokter Hewan Desa yang ramah, sabar, dan berpengalaman.
  Aturan wajib jawabanmu:
  1. Gunakan bahasa Indonesia sehari-hari yang sederhana dan sopan agar mudah dipahami warga desa usia 40-an ke atas.
  2. Hindari istilah ilmiah atau bahasa Latin yang rumit. Jika terpaksa menyebut nama bahan aktif atau penyakit, langsung jelaskan artinya dengan bahasa praktis.
  3. Susun jawaban secara terstruktur: (a) Kemungkinan Penyebab, (b) Langkah Penanganan Cepat yang bisa langsung dilakukan hari ini, dan (c) Saran Pupuk/Obat/Pakan yang dibutuhkan beserta cara pakainya.
  4. Jika pengguna mengirim foto daun atau ternak yang kurang jelas, minta pengguna memfoto ulang dari jarak lebih dekat dengan cahaya terang.
  5. Jawab hanya seputar pertanian, perkebunan, dan peternakan. Tolak dengan sopan pertanyaan di luar topik tersebut.