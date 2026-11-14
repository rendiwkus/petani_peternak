import 'package:flutter/material.dart';

import '../../../core/services/supabase_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/big_action_button.dart';
import '../../../shared/widgets/dosage_highlight_box.dart';
import '../data/market_repository.dart';
import '../data/models/product_model.dart';

/// Detail produk marketplace dengan informasi dosis dan tombol keranjang.
class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({
    super.key,
    required this.productId,
    this.initialProduct,
    this.onCartChanged,
    this.onOpenCart,
    this.repository,
  });

  final String productId;
  final ProductModel? initialProduct;
  final VoidCallback? onCartChanged;
  final VoidCallback? onOpenCart;
  final MarketRepository? repository;

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  late final MarketRepository _repository =
      widget.repository ?? MarketRepository();

  ProductModel? _product;
  String? _error;
  bool _isLoading = true;
  bool _isAdding = false;
  int _quantity = 1;

  @override
  void initState() {
    super.initState();
    _product = widget.initialProduct;
    _isLoading = _product == null;
    if (_product == null) _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final product = await _repository.fetchProduct(widget.productId);
      if (!mounted) return;
      setState(() {
        _product = product;
        _isLoading = false;
        if (product == null) {
          _error = 'Produk tidak ditemukan atau sudah tidak dijual.';
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = SupabaseService.friendlyError(error);
      });
    }
  }

  Future<void> _add({bool openCart = false}) async {
    final product = _product;
    if (product == null || _isAdding) return;
    if (!product.inStock) {
      _showMessage('Stok produk sedang habis.');
      return;
    }
    setState(() => _isAdding = true);
    try {
      await _repository.addToCart(
        productId: product.id,
        quantity: _quantity,
      );
      if (!mounted) return;
      widget.onCartChanged?.call();
      _showMessage('Produk masuk keranjang.');
      if (openCart) widget.onOpenCart?.call();
    } catch (error) {
      _showMessage(SupabaseService.friendlyError(error));
    } finally {
      if (mounted) setState(() => _isAdding = false);
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
      appBar: AppBar(
        title: const Text('Detail Produk'),
        actions: [
          if (widget.onOpenCart != null)
            IconButton(
              tooltip: 'Buka keranjang',
              onPressed: widget.onOpenCart,
              icon: const Icon(Icons.shopping_cart_rounded),
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null && _product == null
                ? _buildError()
                : _buildContent(_product!),
      ),
      bottomNavigationBar:
          _product == null ? null : _buildBottomBar(_product!),
    );
  }

  Widget _buildContent(ProductModel product) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                child: AspectRatio(
                  aspectRatio: 16 / 10,
                  child: product.imageUrl == null ||
                          product.imageUrl!.isEmpty
                      ? Container(
                          color: AppTheme.surfaceTintGreen,
                          child: const Icon(
                            Icons.inventory_2_rounded,
                            size: 72,
                            color: AppTheme.secondaryGreen,
                          ),
                        )
                      : Image.network(
                          product.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            color: AppTheme.surfaceTintGreen,
                            child: const Icon(
                              Icons.inventory_2_rounded,
                              size: 72,
                              color: AppTheme.secondaryGreen,
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                product.name,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 10),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 10,
                runSpacing: 6,
                children: [
                  Text(
                    product.formattedPrice,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryGreen,
                    ),
                  ),
                  Text(
                    '/ ${product.unit}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  if (product.hasDiscount)
                    Text(
                      product.formattedOriginalPrice,
                      style: const TextStyle(
                        fontSize: 16,
                        color: AppTheme.textSecondary,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _chip(
                    icon: Icons.inventory_rounded,
                    text: product.inStock
                        ? 'Stok ${product.stock}'
                        : 'Stok habis',
                    color: product.inStock
                        ? AppTheme.secondaryGreen
                        : AppTheme.dangerRed,
                  ),
                  _chip(
                    icon: Icons.local_fire_department_rounded,
                    text: '${product.soldCount} terjual',
                    color: AppTheme.accentOrange,
                  ),
                  _chip(
                    icon: Icons.category_rounded,
                    text: _categoryLabel(product.category),
                    color: AppTheme.textSecondary,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _storeCard(product),
              if ((product.description ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 16),
                _section(
                  title: 'Deskripsi Produk',
                  child: Text(
                    product.description!,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
              ],
              if ((product.dosageGuide ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 16),
                DosageHighlightBox(
                  dosageText: product.dosageGuide!,
                  activeIngredients: product.activeIngredients,
                ),
              ],
              const SizedBox(height: 16),
              const Text(
                'Gunakan sesuai label kemasan. Simpan di tempat kering dan '
                'jauh dari jangkauan anak-anak.',
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
    );
  }

  Widget _storeCard(ProductModel product) {
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
                    product.storeName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    [
                      product.storeVillage,
                      product.storeDistrict,
                    ].whereType<String>().where((e) => e.isNotEmpty).join(', '),
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if ((product.storePhone ?? '').isNotEmpty)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceTintGreen,
                  borderRadius: BorderRadius.circular(AppTheme.radiusBadge),
                ),
                child: const Text(
                  'Kios Terverifikasi',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.secondaryGreen,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _section({required String title, required Widget child}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
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
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }

  Widget _chip({
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusBadge),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(ProductModel product) {
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
            if (product.inStock)
              Row(
                children: [
                  const Text(
                    'Jumlah',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  _qtyButton(
                    icon: Icons.remove_rounded,
                    onTap: _quantity <= 1
                        ? null
                        : () => setState(() => _quantity--),
                    tooltip: 'Kurangi jumlah',
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Text(
                      '$_quantity',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  _qtyButton(
                    icon: Icons.add_rounded,
                    onTap: _quantity >= product.stock
                        ? null
                        : () => setState(() => _quantity++),
                    tooltip: 'Tambah jumlah',
                  ),
                ],
              ),
            const SizedBox(height: 10),
            BigActionButton(
              label: product.inStock
                  ? 'Tambah ke Keranjang • ${AppFormatters.rupiah(product.effectivePrice * _quantity)}'
                  : 'Stok Habis',
              icon: Icons.add_shopping_cart_rounded,
              isLoading: _isAdding,
              onPressed: product.inStock ? () => _add() : null,
            ),
            if (widget.onOpenCart != null) ...[
              const SizedBox(height: 8),
              BigActionButton(
                label: 'Beli Sekarang',
                icon: Icons.shopping_cart_checkout_rounded,
                isOutlined: true,
                onPressed: product.inStock ? () => _add(openCart: true) : null,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _qtyButton({
    required IconData icon,
    required VoidCallback? onTap,
    required String tooltip,
  }) {
    return IconButton.filledTonal(
      tooltip: tooltip,
      onPressed: onTap,
      icon: Icon(icon),
      constraints: const BoxConstraints(minWidth: 52, minHeight: 52),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.inventory_2_outlined,
                size: 56, color: AppTheme.dangerRed),
            const SizedBox(height: 12),
            Text(
              _error ?? 'Produk tidak ditemukan.',
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

  static String _categoryLabel(String category) {
    switch (category) {
      case 'pupuk':
        return 'Pupuk';
      case 'pestisida':
        return 'Pestisida';
      case 'pakan':
        return 'Pakan Ternak';
      case 'benih':
        return 'Benih';
      case 'obat':
      case 'obat_ternak':
        return 'Obat Ternak';
      default:
        return 'Peralatan Tani';
    }
  }
}
