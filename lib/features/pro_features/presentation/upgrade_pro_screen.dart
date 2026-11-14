import 'package:flutter/material.dart';

import '../../../core/services/supabase_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/big_action_button.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/data/models/user_profile_model.dart';
import '../../marketplace/presentation/order_history_screen.dart';
import '../data/pro_repository.dart';
import 'care_schedule_screen.dart';
import 'farm_finance_screen.dart';

/// Pusat fitur "Usaha Pro": profil, jadwal, pembukuan, dan langganan.
class UpgradeProScreen extends StatefulWidget {
  const UpgradeProScreen({
    super.key,
    required this.profile,
    required this.onProfileUpdated,
    required this.onLogout,
    this.authRepository,
    this.proRepository,
  });

  final UserProfileModel profile;
  final ValueChanged<UserProfileModel> onProfileUpdated;
  final Future<void> Function() onLogout;
  final AuthRepository? authRepository;
  final ProRepository? proRepository;

  @override
  State<UpgradeProScreen> createState() => _UpgradeProScreenState();
}

class _UpgradeProScreenState extends State<UpgradeProScreen> {
  late final AuthRepository _auth = widget.authRepository ?? AuthRepository();
  late final ProRepository _pro = widget.proRepository ?? ProRepository();

  String? _requestingPlan;
  bool _isLoggingOut = false;

  Future<void> _requestPlan(ProPlan plan) async {
    if (_requestingPlan != null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(plan.name),
        content: Text(
          'Tagihan ${AppFormatters.rupiah(plan.price)} untuk ${plan.days} hari. '
          'Setelah dikonfirmasi, Anda akan menerima nomor invoice untuk '
          'pembayaran ke admin kios.',
          style: const TextStyle(fontSize: 16, height: 1.5),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: Column(
              children: [
                BigActionButton(
                  label: 'Buat Tagihan',
                  icon: Icons.receipt_long_rounded,
                  onPressed: () => Navigator.pop(context, true),
                ),
                const SizedBox(height: 8),
                BigActionButton(
                  label: 'Batal',
                  icon: Icons.close_rounded,
                  isOutlined: true,
                  onPressed: () => Navigator.pop(context, false),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _requestingPlan = plan.name);
    try {
      final invoice = await _pro.requestProSubscription(plan);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Tagihan Dibuat'),
          content: Text(
            'Nomor invoice: $invoice\n\n'
            'Simpan nomor ini dan hubungi admin kios untuk pembayaran. '
            'Status Pro aktif setelah pembayaran diverifikasi.',
            style: const TextStyle(fontSize: 16, height: 1.5),
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: BigActionButton(
                label: 'Mengerti',
                icon: Icons.done_rounded,
                onPressed: () => Navigator.pop(dialogContext),
              ),
            ),
          ],
        ),
      );
    } catch (error) {
      if (!mounted) return;
      _showMessage(SupabaseService.friendlyError(error));
    } finally {
      if (mounted) setState(() => _requestingPlan = null);
    }
  }

  Future<void> _editProfile() async {
    final result = await showModalBottomSheet<_ProfileFormResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: _ProfileForm(profile: widget.profile),
      ),
    );
    if (result == null) return;
    try {
      final updated = await _auth.updateProfile(
        fullName: result.fullName,
        village: result.village,
        district: result.district,
        regency: result.regency,
        province: result.province,
        fullAddress: result.fullAddress,
      );
      if (!mounted) return;
      widget.onProfileUpdated(updated);
      _showMessage('Profil berhasil diperbarui.');
    } catch (error) {
      if (!mounted) return;
      _showMessage(SupabaseService.friendlyError(error));
    }
  }

  Future<void> _logout() async {
    if (_isLoggingOut) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Keluar dari Aplikasi?'),
        content: const Text(
          'Anda perlu masuk kembali untuk mengakses data usaha.',
          style: TextStyle(fontSize: 16, height: 1.5),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: Column(
              children: [
                BigActionButton(
                  label: 'Ya, Keluar',
                  icon: Icons.logout_rounded,
                  backgroundColor: AppTheme.dangerRed,
                  onPressed: () => Navigator.pop(context, true),
                ),
                const SizedBox(height: 8),
                BigActionButton(
                  label: 'Batal',
                  icon: Icons.close_rounded,
                  isOutlined: true,
                  onPressed: () => Navigator.pop(context, false),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _isLoggingOut = true);
    try {
      await widget.onLogout();
    } catch (error) {
      if (!mounted) return;
      _showMessage(SupabaseService.friendlyError(error));
    } finally {
      if (mounted) setState(() => _isLoggingOut = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _open(Widget screen) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _profileCard(profile),
                    const SizedBox(height: 20),
                    const Text(
                      'Usaha Saya',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _menuTile(
                      icon: Icons.event_available_rounded,
                      title: 'Jadwal Perawatan',
                      subtitle: 'Pemupukan, vaksinasi, panen',
                      onTap: () => _open(const CareScheduleScreen()),
                    ),
                    const SizedBox(height: 10),
                    _menuTile(
                      icon: Icons.account_balance_wallet_rounded,
                      title: 'Catatan Keuangan',
                      subtitle: 'Pemasukan dan pengeluaran usaha',
                      onTap: () => _open(const FarmFinanceScreen()),
                    ),
                    const SizedBox(height: 10),
                    _menuTile(
                      icon: Icons.receipt_long_rounded,
                      title: 'Riwayat Pesanan',
                      subtitle: 'Status pesanan dari kios mitra',
                      onTap: () => _open(const OrderHistoryScreen()),
                    ),
                    const SizedBox(height: 24),
                    if (!profile.isProActive) ...[
                      const Text(
                        'Paket Usaha Pro',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Tanya AI tanpa batas, catat usaha tanpa ribet, dan '
                        'dapatkan pendampingan prioritas.',
                        style: TextStyle(
                          fontSize: 16,
                          height: 1.5,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...ProPlan.plans.map(
                        (plan) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _planCard(plan),
                        ),
                      ),
                    ] else
                      _proActiveCard(profile),
                    const SizedBox(height: 24),
                    BigActionButton(
                      label: 'Ubah Profil & Alamat',
                      icon: Icons.person_rounded,
                      isOutlined: true,
                      onPressed: _editProfile,
                    ),
                    const SizedBox(height: 10),
                    BigActionButton(
                      label: 'Keluar',
                      icon: Icons.logout_rounded,
                      isOutlined: true,
                      backgroundColor: AppTheme.dangerRed,
                      isLoading: _isLoggingOut,
                      onPressed: _isLoggingOut ? null : _logout,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Data usaha Anda hanya dapat dibaca oleh akun ini. '
                      'Kunci rahasia server tidak pernah disimpan di HP.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _profileCard(UserProfileModel profile) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceTintGreen,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppTheme.secondaryGreen.withValues(alpha: 0.4),
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.person_rounded,
                    size: 36,
                    color: AppTheme.primaryGreen,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.fullName,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        profile.displayRole,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        AppFormatters.displayPhone(profile.phoneNumber),
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: profile.isProActive
                        ? AppTheme.accentOrange
                        : AppTheme.surfaceTintGreen,
                    borderRadius: BorderRadius.circular(AppTheme.radiusBadge),
                  ),
                  child: Text(
                    profile.isProActive ? 'PRO' : 'GRATIS',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: profile.isProActive
                          ? Colors.white
                          : AppTheme.primaryGreen,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.location_on_rounded,
                  size: 20,
                  color: AppTheme.textSecondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    profile.shortLocation,
                    style: const TextStyle(
                      fontSize: 16,
                      color: AppTheme.textPrimary,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _menuTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: AppTheme.cardSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        side: const BorderSide(color: AppTheme.cardBorder, width: 1.5),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 72),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceTintGreen,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: AppTheme.secondaryGreen, size: 26),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppTheme.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _planCard(ProPlan plan) {
    final isYearly = plan.days >= 365;
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardSurface,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(
          color: isYearly ? AppTheme.accentOrange : AppTheme.cardBorder,
          width: isYearly ? 2 : 1.5,
        ),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  plan.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              if (isYearly)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.warningAmberBg,
                    borderRadius: BorderRadius.circular(AppTheme.radiusBadge),
                  ),
                  child: const Text(
                    'Paling Hemat',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF8D6E00),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${AppFormatters.rupiah(plan.price)} / ${plan.days} hari',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.primaryGreen,
            ),
          ),
          const SizedBox(height: 10),
          BigActionButton(
            label: 'Pilih Paket Ini',
            icon: Icons.workspace_premium_rounded,
            isLoading: _requestingPlan == plan.name,
            onPressed: _requestingPlan == null
                ? () => _requestPlan(plan)
                : null,
          ),
        ],
      ),
    );
  }

  Widget _proActiveCard(UserProfileModel profile) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.warningAmberBg,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(color: AppTheme.warningAmberBorder, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.workspace_premium_rounded,
                color: AppTheme.accentOrange,
                size: 28,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Usaha Pro Aktif',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            profile.proExpiresAt == null
                ? 'Tanya AI tanpa batas sudah aktif untuk akun Anda.'
                : 'Berlaku sampai ${AppFormatters.dateLong(profile.proExpiresAt)}.',
            style: const TextStyle(
              fontSize: 16,
              height: 1.5,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileFormResult {
  const _ProfileFormResult({
    required this.fullName,
    this.village,
    this.district,
    this.regency,
    this.province,
    this.fullAddress,
  });

  final String fullName;
  final String? village;
  final String? district;
  final String? regency;
  final String? province;
  final String? fullAddress;
}

class _ProfileForm extends StatefulWidget {
  const _ProfileForm({required this.profile});

  final UserProfileModel profile;

  @override
  State<_ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends State<_ProfileForm> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController =
      TextEditingController(text: widget.profile.fullName);
  late final _villageController =
      TextEditingController(text: widget.profile.village ?? '');
  late final _districtController =
      TextEditingController(text: widget.profile.district ?? '');
  late final _regencyController =
      TextEditingController(text: widget.profile.regency ?? '');
  late final _provinceController =
      TextEditingController(text: widget.profile.province ?? '');
  late final _addressController =
      TextEditingController(text: widget.profile.fullAddress ?? '');

  @override
  void dispose() {
    _nameController.dispose();
    _villageController.dispose();
    _districtController.dispose();
    _regencyController.dispose();
    _provinceController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    String? hint,
    int maxLines = 1,
    bool required = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        maxLength: maxLines > 1 ? 300 : 80,
        style: const TextStyle(fontSize: 16, height: 1.45),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          counterText: '',
          alignLabelWithHint: maxLines > 1,
        ),
        validator: required
            ? (value) {
                final clean = (value ?? '').trim();
                if (clean.length < 2) return '$label minimal 2 huruf';
                return null;
              }
            : null,
      ),
    );
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.pop(
      context,
      _ProfileFormResult(
        fullName: _nameController.text.trim(),
        village: _villageController.text.trim(),
        district: _districtController.text.trim(),
        regency: _regencyController.text.trim(),
        province: _provinceController.text.trim(),
        fullAddress: _addressController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Ubah Profil & Alamat',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                _field(
                  controller: _nameController,
                  label: 'Nama Lengkap',
                  required: true,
                ),
                _field(
                  controller: _villageController,
                  label: 'Desa / Kampung',
                  hint: 'Contoh: Banjar Anyar',
                ),
                _field(
                  controller: _districtController,
                  label: 'Kecamatan',
                ),
                _field(
                  controller: _regencyController,
                  label: 'Kabupaten / Kota',
                ),
                _field(
                  controller: _provinceController,
                  label: 'Provinsi',
                ),
                _field(
                  controller: _addressController,
                  label: 'Alamat Lengkap Pengiriman',
                  hint: 'Nama penerima, patokan lokasi, RT/RW',
                  maxLines: 3,
                ),
                const SizedBox(height: 4),
                BigActionButton(
                  label: 'Simpan Perubahan',
                  icon: Icons.save_rounded,
                  onPressed: _save,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
