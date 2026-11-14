import 'package:flutter/material.dart';

import '../../../core/services/supabase_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/big_action_button.dart';
import '../data/market_repository.dart';
import '../data/models/product_model.dart';

/// Riwayat pesanan marketplace dengan pembatalan selama masih `pending`.
class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({super.key, this.repository});

  final MarketRepository? repository;

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  late final MarketRepository _repository =
      widget.repository ?? MarketRepository();

  List<MarketOrderModel> _orders = const [];
  bool _isLoading = true;
  String? _error;
  String? _cancellingId;

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
      final orders = await _repository.fetchOrders();
      if (!mounted) return;
      setState(() {
        _orders = orders;
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

  Future<void> _cancel(MarketOrderModel order) async {
    if (_cancellingId != null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Batalkan Pesanan?'),
        content: Text(
          'Pesanan ${order.orderNumber} akan dibatalkan. '
          'Tindakan ini tidak dapat diurungkan.',
          style: const TextStyle(fontSize: 16, height: 1.5),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: Column(
              children: [
                BigActionButton(
                  label: 'Ya, Batalkan Pesanan',
                  icon: Icons.cancel_rounded,
                  backgroundColor: AppTheme.dangerRed,
                  onPressed: () => Navigator.pop(context, true),
                ),
                const SizedBox(height: 8),
                BigActionButton(
                  label: 'Kembali',
                  icon: Icons.arrow_back_rounded,
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

    setState(() => _cancellingId = order.id);
    try {
      await _repository.cancelOrder(order.id);
      if (!mounted) return;
      _showMessage('Pesanan dibatalkan.');
      await _load();
    } catch (error) {
      if (!mounted) return;
      _showMessage(SupabaseService.friendlyError(error));
    } finally {
      if (mounted) setState(() => _cancellingId = null);
    }
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
      appBar: AppBar(title: const Text('Riwayat Pesanan')),
      body: SafeArea(
        top: false,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _buildError()
                : _orders.isEmpty
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
                                  children: _orders
                                      .map(
                                        (order) => Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 12,
                                          ),
                                          child: _OrderCard(
                                            order: order,
                                            isCancelling:
                                                _cancellingId == order.id,
                                            onCancel: () => _cancel(order),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                ),
                              ),
                            ),
                          ],
                        ),
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
            const Icon(
              Icons.receipt_long_outlined,
              size: 64,
              color: AppTheme.secondaryGreen,
            ),
            const SizedBox(height: 14),
            const Text(
              'Belum ada pesanan',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Pesanan yang Anda buat di Toko Tani akan muncul di sini.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: AppTheme.textSecondary,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 16),
            BigActionButton(
              label: 'Kembali Belanja',
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
            const Icon(
              Icons.error_outline_rounded,
              size: 56,
              color: AppTheme.dangerRed,
            ),
            const SizedBox(height: 12),
            Text(
              _error ?? 'Gagal memuat pesanan.',
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

class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.order,
    required this.onCancel,
    required this.isCancelling,
  });

  final MarketOrderModel order;
  final VoidCallback onCancel;
  final bool isCancelling;

  Color get _statusColor {
    switch (order.orderStatus) {
      case 'pending':
      case 'menunggu':
        return AppTheme.accentOrange;
      case 'diproses':
      case 'dikirim':
        return const Color(0xFF1565C0);
      case 'selesai':
        return AppTheme.secondaryGreen;
      case 'dibatalkan':
        return AppTheme.dangerRed;
      default:
        return AppTheme.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.orderNumber,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        AppFormatters.dateLong(order.createdAt),
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
                    color: _statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppTheme.radiusBadge),
                  ),
                  child: Text(
                    order.statusLabel,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _statusColor,
                    ),
                  ),
                ),
              ],
            ),
            if (order.items.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...order.items.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          '${item.productName} × ${item.quantity}',
                          style: const TextStyle(
                            fontSize: 16,
                            height: 1.4,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        AppFormatters.rupiah(item.subtotal),
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
            ],
            const Divider(height: 20),
            Row(
              children: [
                const Text(
                  'Total',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const Spacer(),
                Text(
                  order.formattedTotal,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryGreen,
                  ),
                ),
              ],
            ),
            if ((order.shippingAddress ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.location_on_rounded,
                    size: 18,
                    color: AppTheme.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      order.shippingAddress!,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (order.cancelReason != null &&
                order.cancelReason!.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Alasan batal: ${order.cancelReason}',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppTheme.dangerRed,
                  height: 1.4,
                ),
              ),
            ],
            if (order.canCancel) ...[
              const SizedBox(height: 12),
              BigActionButton(
                label: 'Batalkan Pesanan',
                icon: Icons.cancel_outlined,
                isOutlined: true,
                backgroundColor: AppTheme.dangerRed,
                isLoading: isCancelling,
                onPressed: isCancelling ? null : onCancel,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
