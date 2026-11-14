import 'package:flutter/material.dart';

import '../../../core/services/supabase_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/big_action_button.dart';
import '../../auth/data/models/user_profile_model.dart';
import '../data/market_repository.dart';
import '../data/models/product_model.dart';
import 'checkout_screen.dart';
import 'order_history_screen.dart';

/// Keranjang belanja dengan ubah jumlah, hapus, dan lanjut checkout.
class CartScreen extends StatefulWidget {
  const CartScreen({
    super.key,
    required this.profile,
    required this.onCartChanged,
    this.repository,
  });

  final UserProfileModel profile;
  final VoidCallback onCartChanged;
  final MarketRepository? repository;

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  late final MarketRepository _repository =
      widget.repository ?? MarketRepository();

  List<CartItemModel> _items = const [];
  bool _isLoading = true;
  String? _error;
  String? _busyItemId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final items = await _repository.fetchCart();
      if (!mounted) return;
      setState(() {
        _items = items;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = SupabaseService.friendlyError(error);
      });
    }
  }

  double get _total =>
      _items.fold(0, (sum, item) => sum + item.subtotal);

  List<String> get _storeIds =>
      _items.map((item) => item.product.storeId).toSet().toList();

  Future<void> _changeQuantity(CartItemModel item, int quantity) async {
    if (_busyItemId != null) return;
    setState(() => _busyItemId = item.id);
    try {
      await _repository.updateCartQuantity(item.id, quantity);
      widget.onCartChanged();
      await _load();
    } catch (error) {
      _showMessage(SupabaseService.friendlyError(error));
    } finally {
      if (mounted) setState(() => _busyItemId = null);
    }
  }

  Future<void> _remove(CartItemModel item) async {
    final confirmed = await _confirm(
      title: 'Hapus dari Keranjang?',
      message: '${item.product.name} akan dihapus dari keranjang.',
    );
    if (!confirmed) return;
    try {
      await _repository.removeCartItem(item.id);
      widget.onCartChanged();
      await _load();
    } catch (error) {
      _showMessage(SupabaseService.friendlyError(error));
    }
  }

  Future<bool> _confirm({
    required String title,
    required String message,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(
          message,
          style: const TextStyle(fontSize: 16, height: 1.5),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: Column(
              children: [
                BigActionButton(
                  label: 'Ya, Lanjutkan',
                  icon: Icons.check_rounded,
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
    return result ?? false;
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openCheckout() async {
    if (_items.isEmpty) return;
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => CheckoutScreen(
          items: _items,
          profile: widget.profile,
          repository: _repository,
        ),
      ),
    );
    if (created == true) {
      widget.onCartChanged();
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Keranjang Belanja'),
        actions: [
          IconButton(
            tooltip: 'Riwayat pesanan',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => OrderHistoryScreen(repository: _repository),
              ),
            ),
            icon: const Icon(Icons.receipt_long_rounded),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _buildError()
                : _items.isEmpty
                    ? _buildEmpty()
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                          children: [
                            Center(
                              child: ConstrainedBox(
                                constraints:
                                    const BoxConstraints(maxWidth: 760),
                                child: Column(
                                  children: [
                                    if (_storeIds.length > 1)
                                      Container(
                                        margin:
                                            const EdgeInsets.only(bottom: 12),
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: AppTheme.warningAmberBg,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: Border.all(
                                            color: AppTheme.warningAmberBorder,
                                          ),
                                        ),
                                        child: const Text(
                                          'Produk berasal dari beberapa kios. '
                                          'Satu pesanan hanya untuk satu kios. '
                                          'Silakan hapus produk dari kios lain.',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: AppTheme.textPrimary,
                                            height: 1.45,
                                          ),
                                        ),
                                      ),
                                    ..._items.map(
                                      (item) => Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 12),
                                        child: _CartTile(
                                          item: item,
                                          isBusy: _busyItemId == item.id,
                                          onMinus: () => _changeQuantity(
                                            item,
                                            item.quantity - 1,
                                          ),
                                          onPlus: () => _changeQuantity(
                                            item,
                                            item.quantity + 1,
                                          ),
                                          onRemove: () => _remove(item),
                                        ),
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
      bottomNavigationBar:
          _items.isEmpty || _isLoading ? null : _buildBottomBar(),
    );
  }

  Widget _buildBottomBar() {
    final canCheckout = _storeIds.length == 1;
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        decoration: const BoxDecoration(
          color: AppTheme.cardSurface,
          border:
              Border(top: BorderSide(color: AppTheme.cardBorder, width: 1.5)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Text(
                  'Total Belanja',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const Spacer(),
                Text(
                  AppFormatters.rupiah(_total),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryGreen,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            BigActionButton(
              label: 'Lanjut ke Checkout',
              icon: Icons.shopping_cart_checkout_rounded,
              onPressed: canCheckout ? _openCheckout : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.shopping_cart_outlined,
                size: 64, color: AppTheme.secondaryGreen),
            const SizedBox(height: 14),
            const Text(
              'Keranjang masih kosong',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Pilih pupuk, pakan, atau obat dari kios mitra.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            BigActionButton(
              label: 'Belanja Sekarang',
              icon: Icons.storefront_rounded,
              isOutlined: true,
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 56, color: AppTheme.dangerRed),
            const SizedBox(height: 12),
            Text(
              _error ?? 'Gagal memuat keranjang.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, height: 1.45),
            ),
            const SizedBox(height: 16),
            BigActionButton(
              label: 'Coba Lagi',
              icon: Icons.refresh_rounded,
              isOutlined: true,
              onPressed: _load,
            ),
          ],
        ),
      ),
    );
  }
}

class _CartTile extends StatelessWidget {
  const _CartTile({
    required this.item,
    required this.onMinus,
    required this.onPlus,
    required this.onRemove,
    required this.isBusy,
  });

  final CartItemModel item;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  final VoidCallback onRemove;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 80,
                    height: 80,
                    child: item.product.imageUrl == null
                        ? Container(
                            color: AppTheme.surfaceTintGreen,
                            child: const Icon(
                              Icons.inventory_2_rounded,
                              color: AppTheme.secondaryGreen,
                              size: 34,
                            ),
                          )
                        : Image.network(
                            item.product.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Container(
                              color: AppTheme.surfaceTintGreen,
                              child: const Icon(
                                Icons.inventory_2_rounded,
                                color: AppTheme.secondaryGreen,
                                size: 34,
                              ),
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.product.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.product.storeName,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${item.product.formattedPrice} / ${item.product.unit}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryGreen,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Hapus produk',
                  onPressed: isBusy ? null : onRemove,
                  icon: const Icon(Icons.delete_outline_rounded,
                      color: AppTheme.dangerRed),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton.filledTonal(
                  tooltip: 'Kurangi jumlah',
                  onPressed: isBusy || item.quantity <= 1 ? null : onMinus,
                  icon: const Icon(Icons.remove_rounded),
                  constraints:
                      const BoxConstraints(minWidth: 48, minHeight: 48),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: isBusy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          '${item.quantity}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
                IconButton.filledTonal(
                  tooltip: 'Tambah jumlah',
                  onPressed: isBusy ||
                          item.quantity >= item.product.stock
                      ? null
                      : onPlus,
                  icon: const Icon(Icons.add_rounded),
                  constraints:
                      const BoxConstraints(minWidth: 48, minHeight: 48),
                ),
                const Spacer(),
                Text(
                  item.formattedSubtotal,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryGreen,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
