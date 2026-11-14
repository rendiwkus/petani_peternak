import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/services/supabase_service.dart';
import 'core/theme/app_theme.dart';
import 'features/ai_consultant/presentation/ai_chat_screen.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/auth/data/models/user_profile_model.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/knowledge_search/presentation/home_search_screen.dart';
import 'features/marketplace/data/market_repository.dart';
import 'features/marketplace/presentation/cart_screen.dart';
import 'features/marketplace/presentation/catalog_screen.dart';
import 'features/marketplace/presentation/product_detail_screen.dart';
import 'features/pro_features/presentation/upgrade_pro_screen.dart';

class TaniTernakApp extends StatelessWidget {
  const TaniTernakApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TaniTernak Desa',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      locale: const Locale('id', 'ID'),
      supportedLocales: const [Locale('id', 'ID'), Locale('en', 'US')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const AuthGate(),
    );
  }
}

/// Gerbang sesi: menampilkan login atau shell utama sesuai sesi Supabase.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final AuthRepository _auth = AuthRepository();
  StreamSubscription<AuthState>? _authSubscription;

  UserProfileModel? _profile;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _authSubscription = SupabaseService.instance.authStateChanges.listen((
      state,
    ) {
      if (!mounted) return;
      final event = state.event;
      if (event == AuthChangeEvent.signedOut) {
        setState(() {
          _profile = null;
          _isLoading = false;
          _error = null;
        });
      } else if (_profile == null &&
          (event == AuthChangeEvent.signedIn ||
              event == AuthChangeEvent.initialSession)) {
        _loadProfile();
      }
    });
    _loadProfile();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    if (!SupabaseService.instance.isAuthenticated) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final profile = await _auth.ensureProfile();
      if (!mounted) return;
      setState(() {
        _profile = profile;
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

  Future<void> _refreshProfile() async {
    final profile = await _auth.fetchCurrentProfile(forceRemote: true);
    if (!mounted || profile == null) return;
    setState(() => _profile = profile);
  }

  Future<void> _logout() async {
    await _auth.logout();
    if (!mounted) return;
    setState(() {
      _profile = null;
      _error = null;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                'Menyiapkan data Anda...',
                style: TextStyle(fontSize: 16, color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    final profile = _profile;
    if (profile == null) {
      if (_error != null) {
        return _SessionErrorScreen(message: _error!, onRetry: _loadProfile);
      }
      return const LoginScreen();
    }

    return AppShell(
      profile: profile,
      onProfileUpdated: (updated) => setState(() => _profile = updated),
      onRefreshProfile: _refreshProfile,
      onLogout: _logout,
    );
  }
}

class _SessionErrorScreen extends StatelessWidget {
  const _SessionErrorScreen({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                size: 64,
                color: AppTheme.dangerRed,
              ),
              const SizedBox(height: 14),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, height: 1.5),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shell 4 tab: Cari Solusi, Tanya AI, Toko Tani, Usaha Pro.
class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.profile,
    required this.onProfileUpdated,
    required this.onRefreshProfile,
    required this.onLogout,
  });

  final UserProfileModel profile;
  final ValueChanged<UserProfileModel> onProfileUpdated;
  final Future<void> Function() onRefreshProfile;
  final Future<void> Function() onLogout;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final MarketRepository _market = MarketRepository();

  int _tabIndex = 0;
  int _cartCount = 0;
  String? _aiPrompt;

  @override
  void initState() {
    super.initState();
    _refreshCart();
  }

  Future<void> _refreshCart() async {
    final count = await _market.cartCount();
    if (!mounted) return;
    setState(() => _cartCount = count);
  }

  void _askAi(String query) {
    setState(() {
      _tabIndex = 1;
      _aiPrompt = query.trim().isEmpty ? null : query.trim();
    });
  }

  Future<void> _openCart() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CartScreen(
          profile: widget.profile,
          onCartChanged: _refreshCart,
        ),
      ),
    );
    await _refreshCart();
  }

  Future<void> _openProduct(String productId) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProductDetailScreen(
          productId: productId,
          onCartChanged: _refreshCart,
          onOpenCart: _openCart,
        ),
      ),
    );
    await _refreshCart();
  }

  void _onDestinationSelected(int index) {
    if (index == _tabIndex) return;
    setState(() => _tabIndex = index);
    if (index == 2) _refreshCart();
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;
    return Scaffold(
      body: IndexedStack(
        index: _tabIndex,
        children: [
          HomeSearchScreen(
            profile: profile,
            cartCount: _cartCount,
            onOpenCart: _openCart,
            onAskAi: _askAi,
            onOpenProduct: _openProduct,
            onOpenProfile: () => setState(() => _tabIndex = 3),
            onRefreshProfile: widget.onRefreshProfile,
          ),
          AiChatScreen(
            profile: profile,
            onOpenProduct: _openProduct,
            onUpgradeTap: () => setState(() => _tabIndex = 3),
            onQuotaUsed: () async {
              await widget.onRefreshProfile();
            },
            initialPrompt: _aiPrompt,
            onPromptConsumed: () {
              if (_aiPrompt != null) setState(() => _aiPrompt = null);
            },
          ),
          CatalogScreen(
            cartCount: _cartCount,
            onOpenCart: _openCart,
            onOpenProduct: _openProduct,
            onCartChanged: _refreshCart,
          ),
          UpgradeProScreen(
            profile: profile,
            onProfileUpdated: widget.onProfileUpdated,
            onLogout: widget.onLogout,
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: _onDestinationSelected,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.search_rounded),
            selectedIcon: Icon(Icons.search_rounded),
            label: 'Cari Solusi',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline_rounded),
            selectedIcon: Icon(Icons.chat_bubble_rounded),
            label: 'Tanya AI',
          ),
          NavigationDestination(
            icon: Icon(Icons.storefront_outlined),
            selectedIcon: Icon(Icons.storefront_rounded),
            label: 'Toko Tani',
          ),
          NavigationDestination(
            icon: Icon(Icons.workspace_premium_outlined),
            selectedIcon: Icon(Icons.workspace_premium_rounded),
            label: 'Usaha Pro',
          ),
        ],
      ),
    );
  }
}
