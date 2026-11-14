/// Konstanta bisnis dan nama tabel/bucket Supabase.
///
/// Modul ini tidak boleh mengimpor `lib/features/` atau `lib/shared/`.
class AppConstants {
  AppConstants._();

  static const appName = 'TaniTernak Desa';
  static const appTagline = 'Solusi tani & ternak di genggaman';

  // Hive boxes
  static const boxUserProfile = 'user_profile_box';
  static const boxArticles = 'articles_box';
  static const boxCommodities = 'commodities_box';
  static const boxProducts = 'products_box';
  static const boxCareSchedules = 'care_schedules_box';
  static const boxFinance = 'farm_finance_box';

  // Supabase tables
  static const tableProfiles = 'profiles';
  static const tableCommodities = 'commodities';
  static const tableArticles = 'knowledge_articles';
  static const tableArticleProducts = 'article_recommended_products';
  static const tableProducts = 'products';
  static const tableStores = 'stores';
  static const tableAiSessions = 'ai_chat_sessions';
  static const tableAiMessages = 'ai_chat_messages';
  static const tableCareSchedules = 'care_schedules';
  static const tableFinance = 'farm_financial_logs';
  static const tableOrders = 'market_orders';
  static const tableOrderItems = 'market_order_items';
  static const tablePayments = 'market_payments';
  static const tableSubscriptions = 'subscription_transactions';
  static const tableCart = 'cart_items';

  // Storage
  static const bucketConsultations = 'consultations';

  // Business rules
  static const freeDailyAiQuota = 5;

  // Categories
  static const categoryPertanian = 'pertanian';
  static const categoryPerkebunan = 'perkebunan';
  static const categoryPeternakan = 'peternakan';
  static const categories = [categoryPertanian, categoryPerkebunan, categoryPeternakan];

  static const categoryLabels = {
    categoryPertanian: 'Tanaman Pangan',
    categoryPerkebunan: 'Perkebunan',
    categoryPeternakan: 'Peternakan',
  };

  static const categorySubtitles = {
    categoryPertanian: 'Padi, Jagung, Cabai, Sayur',
    categoryPerkebunan: 'Kopi, Kakao, Kelapa, Buah',
    categoryPeternakan: 'Ayam, Sapi, Kambing, Ikan',
  };

  static const rolePetani = 'petani';
  static const roleMitraKios = 'mitra_kios';
  static const rolePenyuluh = 'penyuluh';
  static const roleAdmin = 'admin';

  static const orderPending = 'pending';
  static const orderDiproses = 'diproses';
  static const orderDikirim = 'dikirim';
  static const orderSelesai = 'selesai';
  static const orderDibatalkan = 'dibatalkan';

  static const financeIncome = 'pemasukan';
  static const financeExpense = 'pengeluaran';
}
