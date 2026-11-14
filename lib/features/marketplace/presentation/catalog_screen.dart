import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/services/connectivity_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/big_action_button.dart';
import '../../../shared/widgets/offline_status_banner.dart';
import '../data/market_repository.dart';
import '../data/models/product_model.dart';

/// Katalog marketplace dengan filter kategori, pencarian, dan cache offline.
class CatalogScreen extends StatefulWidget {
  const CatalogScreen({
    super.key,
    required this.cartCount,
    required this.onOpenCart,
    required this.onOpenProduct,
    required this.onCartChanged,
    this.repository,
  });

  final int cartCount;
  final VoidCallback onOpenCart;
  final ValueChanged<String> onOpenProduct;
  final VoidCallback onCartChanged;
  final MarketRepository? repository;

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  late final MarketRepository _repository =
      widget.repository ?? MarketRepository();
  final _searchController = TextEditingController();

  List<ProductModel> _products = const [];
  String? _selectedCategory;
  String? _error;
  bool _isLoading = true;
  bool _isOffline = false;
  String? _addingProductId;
  Timer? _debounce;
  StreamSubscription<bool>? _offlineSubscription;

  static const _categories = [
    ('semua', 'Semua'),
    ('pupuk', 'Pupuk'),
    ('pestisida', 'Pestisida'),
    ('pakan', 'Pakan Ternak'),
    ('benih', 'Benih'),
    ('obat_ternak', 'Obat Ternak'),
  ];

  @override
  void initState() {
    super.initState();
    _isOffline = ConnectivityService.instance.isOffline;
    _offlineSubscription =
        ConnectivityService.instance.changes.listen((offline) {
      if (!mounted) return;
      setState(() => _isOffline = offline);
      if (!offline) _load();
    });
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _offlineSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final products = await _repository.fetchProducts(
        query: _searchController.text,
        category: _selectedCategory,
        forceRefresh: !_isOffline,
      );
      if (!mounted) return;
      setState(() {
        _products = products;
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

  void _onSearchChanged(String value) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 420), _load);
  }

  Future<void> _selectCategory(String value) async {
    setState(() {
      _selectedCategory = value == 'semua' ? null : value;
    });
    await _load();
  }

  Future<void> _quickAdd(ProductModel product) async {
    if (_addingProductId != null) return;
    if (!product.inStock) {
      _showMessage('Stok produk sedang habis.');
      return;
    }
    setState(() => _addingProductId = product.id);
    try {
      await _repository.addToCart(productId: product.id);
      widget.onCartChanged();
      _showMessage('${product.name} masuk keranjang.');
    } catch (error) {
      _showMessage(SupabaseService.friendlyError(error));
    } finally {
      if (mounted) setState(() => _addingProductId = null);
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
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            children: [
              OfflineStatusBanner(isOffline: _isOffline),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Toko Tani',
                                    style: TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Pupuk, pakan, pestisida dari kios terdekat',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            _cartButton(),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _searchController,
                          onChanged: _onSearchChanged,
                          onSubmitted: (_) => _load(),
                          style: const TextStyle(fontSize: 16),
                          decoration: InputDecoration(
                            hintText: 'Cari pupuk, pakan, atau obat...',
                            prefixIcon: const Icon(Icons.search_rounded),
                            suffixIcon: _searchController.text.isEmpty
                                ? null
                                : IconButton(
                                    tooltip: 'Hapus pencarian',
                                    onPressed: () {
                                      _searchController.clear();
                                      _onSearchChanged('');
                                    },
                                    icon: const Icon(Icons.close_rounded),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: _categories
                                .map(
                                  (category) => Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: FilterChip(
                                      label: Text(category.$2),
                                      selected: _selectedCategory ==
                                              (category.$1 == 'semua'
                                                  ? null
                                                  : category.$1) &&
                                          (category.$1 != 'semua' ||
                                              _selectedCategory == null),
                                      onSelected: (_) =>
                                          _selectCategory(category.$1),
                                      labelStyle: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 8,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (_isLoading)
                          _buildSkeleton()
                        else if (_error != null)
                          _buildError()
                        else if (_products.isEmpty)
                          _buildEmpty()
                        else ...[
                          Text(
                            '${_products.length} produk tersedia',
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 10),
                          ..._products.map(
                            (product) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _ProductTile(
                                product: product,
                                isAdding: _addingProductId == product.id,
                                onTap: () =>
                                    widget.onOpenProduct(product.id),
                                onAdd: () => _quickAdd(product),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cartButton() {
    return Semantics(
      button: true,
      label: 'Buka keranjang, ${widget.cartCount} barang',
      child: InkWell(
        onTap: widget.onOpenCart,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: AppTheme.cardSurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.cardBorder, width: 1.5),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              const Icon(
                Icons.shopping_cart_rounded,
                color: AppTheme.primaryGreen,
                size: 27,
              ),
              if (widget.cartCount > 0)
                Positioned(
                  top: 5,
                  right: 4,
                  child: Container(
                    constraints:
                        const BoxConstraints(minWidth: 20, minHeight: 20),
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    decoration: const BoxDecoration(
                      color: AppTheme.dangerRed,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      widget.cartCount > 99 ? '99+' : '${widget.cartCount}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSkeleton() {
    return Column(
      children: List.generate(
        3,
        (_) => Container(
          margin: const EdgeInsets.only(bottom: 12),
          height: 150,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppTheme.radiusCard),
            border: Border.all(color: AppTheme.cardBorder, width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _buildError() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(Icons.storefront_outlined,
                color: AppTheme.dangerRed, size: 48),
            const SizedBox(height: 10),
            Text(
              _error ?? 'Gagal memuat produk.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, height: 1.45),
            ),
            const SizedBox(height: 14),
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

  Widget _buildEmpty() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(Icons.search_off_rounded,
                color: AppTheme.secondaryGreen, size: 52),
            const SizedBox(height: 10),
            const Text(
              'Produk tidak ditemukan',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Coba kata lain atau pilih kategori lain.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {
                _searchController.clear();
                setState(() => _selectedCategory = null);
                _load();
              },
              child: const Text('Tampilkan Semua Produk'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductTile extends StatelessWidget {
  const _ProductTile({
    required this.product,
    required this.onTap,
    required this.onAdd,
    required this.isAdding,
  });

  final ProductModel product;
  final VoidCallback onTap;
  final VoidCallback onAdd;
  final bool isAdding;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
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
                      width: 92,
                      height: 92,
                      child: product.imageUrl == null ||
                              product.imageUrl!.isEmpty
                          ? Container(
                              color: AppTheme.surfaceTintGreen,
                              child: const Icon(
                                Icons.inventory_2_rounded,
                                color: AppTheme.secondaryGreen,
                                size: 38,
                              ),
                            )
                          : Image.network(
                              product.imageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Container(
                                color: AppTheme.surfaceTintGreen,
                                child: const Icon(
                                  Icons.inventory_2_rounded,
                                  color: AppTheme.secondaryGreen,
                                  size: 38,
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
                          product.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(
                              Icons.storefront_rounded,
                              size: 15,
                              color: AppTheme.secondaryGreen,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                product.storeName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          product.inStock
                              ? 'Stok ${product.stock} • ${product.soldCount} terjual'
                              : 'Stok habis',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: product.inStock
                                ? AppTheme.textSecondary
                                : AppTheme.dangerRed,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.formattedPrice,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primaryGreen,
                          ),
                        ),
                        Text(
                          product.unit,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 44,
                    child: FilledButton.icon(
                      onPressed: product.inStock && !isAdding ? onAdd : null,
                      icon: isAdding
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.add_shopping_cart_rounded, size: 20),
                      label: Text(isAdding ? 'Menambah...' : 'Tambah'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.primaryGreen,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusButton),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
