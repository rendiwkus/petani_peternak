import 'package:flutter/material.dart';

import '../../../core/services/supabase_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/big_action_button.dart';
import '../../auth/data/models/user_profile_model.dart';
import '../data/market_repository.dart';
import '../data/models/product_model.dart';

/// Konfirmasi pesanan: alamat kirim + ringkasan belanja.
///
/// Total akhir tetap dihitung ulang oleh RPC `create_market_order` di server,
/// jadi angka di layar ini hanya perkiraan untuk pengguna.
class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({
    super.key,
    required this.items,
    required this.profile,
    this.repository,
  });

  final List<CartItemModel> items;
  final UserProfileModel profile;
  final MarketRepository? repository;

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  late final MarketRepository _repository =
      widget.repository ?? MarketRepository();
  late final TextEditingController _addressController =
      TextEditingController(text: _defaultAddress());

  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  String _defaultAddress() {
    final profile = widget.profile;
    final parts = [
      profile.fullAddress,
      profile.village,
      profile.district,
      profile.regency,
      profile.province,
    ].whereType<String>().map((part) => part.trim()).where((part) {
      return part.isNotEmpty;
    }).toList();
    return parts.join(', ');
  }

  double get _estimateTotal =>
      widget.items.fold(0, (sum, item) => sum + item.subtotal);

  String get _storeName =>
      widget.items.isEmpty ? '-' : widget.items.first.product.storeName;

  Future<void> _submit() async {
    if (_isSubmitting) return;
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSubmitting = true);
    try {
      final result = await _repository.checkout(
        items: widget.items,
        shippingAddress: _addressController.text,
      );
      if (!mounted) return;
      await _showSuccess(result);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      _showMessage(SupabaseService.friendlyError(error));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _showSuccess(CheckoutResult result) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: AppTheme.secondaryGreen),
            SizedBox(width: 8),
            Expanded(child: Text('Pesanan Dibuat')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Nomor pesanan ${result.orderNumber}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Total ${AppFormatters.rupiah(result.grandTotal)}. '
              'Kios akan menghubungi Anda untuk pembayaran dan pengiriman.',
              style: const TextStyle(fontSize: 16, height: 1.5),
            ),
          ],
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
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Konfirmasi Pesanan')),
      body: SafeArea(
        top: false,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Alamat Pengiriman',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _addressController,
                        minLines: 3,
                        maxLines: 5,
                        maxLength: 400,
                        style: const TextStyle(fontSize: 16, height: 1.5),
                        decoration: const InputDecoration(
                          hintText:
                              'Tulis nama penerima, kampung/banjar, dan patokan '
                              'lokasi agar kios mudah mengantar.',
                          alignLabelWithHint: true,
                        ),
                        validator: (value) {
                          final clean = (value ?? '').trim();
                          if (clean.length < 10) {
                            return 'Alamat minimal 10 huruf agar kurir tidak tersesat';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),
                      _storeCard(),
                      const SizedBox(height: 16),
                      const Text(
                        'Rincian Belanja',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              ...widget.items.map(
                                (item) => Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          '${item.product.name} × ${item.quantity}',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            height: 1.4,
                                            color: AppTheme.textPrimary,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        item.formattedSubtotal,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.textPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const Divider(height: 22),
                              Row(
                                children: [
                                  const Expanded(
                                    child: Text(
                                      'Perkiraan Total',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.textPrimary,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    AppFormatters.rupiah(_estimateTotal),
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.primaryGreen,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Harga, stok, dan total akhir diperiksa ulang oleh server '
                        'saat pesanan dibuat. Pembayaran dilakukan langsung ke '
                        'kios mitra.',
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
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          decoration: const BoxDecoration(
            color: AppTheme.cardSurface,
            border: Border(
              top: BorderSide(color: AppTheme.cardBorder, width: 1.5),
            ),
          ),
          child: BigActionButton(
            label: 'Buat Pesanan',
            icon: Icons.shopping_bag_rounded,
            isLoading: _isSubmitting,
            onPressed: _isSubmitting ? null : _submit,
          ),
        ),
      ),
    );
  }

  Widget _storeCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppTheme.surfaceTintGreen,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.storefront_rounded,
                color: AppTheme.secondaryGreen,
                size: 28,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _storeName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  const Text(
                    'Kios mitra terverifikasi',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
