import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/big_action_button.dart';
import '../data/pro_repository.dart';

/// Pembukuan sederhana: catat pemasukan & pengeluaran usaha tani/ternak.
class FarmFinanceScreen extends StatefulWidget {
  const FarmFinanceScreen({super.key, this.repository});

  final ProRepository? repository;

  @override
  State<FarmFinanceScreen> createState() => _FarmFinanceScreenState();
}

class _FarmFinanceScreenState extends State<FarmFinanceScreen> {
  late final ProRepository _repository =
      widget.repository ?? ProRepository();

  List<FarmFinanceModel> _logs = const [];
  bool _isLoading = true;
  String? _error;

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
      final logs = await _repository.fetchFinance(forceRefresh: true);
      if (!mounted) return;
      setState(() {
        _logs = logs;
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

  Future<void> _addLog() async {
    final result = await showModalBottomSheet<_FinanceFormResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: const _FinanceForm(),
      ),
    );
    if (result == null) return;
    try {
      await _repository.addFinance(
        category: result.category,
        amount: result.amount,
        transactionDate: result.date,
        notes: result.notes,
      );
      if (!mounted) return;
      _showMessage('Catatan keuangan disimpan.');
      await _load();
    } catch (error) {
      if (!mounted) return;
      _showMessage(SupabaseService.friendlyError(error));
    }
  }

  Future<void> _delete(FarmFinanceModel log) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Catatan?'),
        content: Text(
          '${log.isIncome ? 'Pemasukan' : 'Pengeluaran'} '
          '${AppFormatters.rupiah(log.amount)} akan dihapus.',
          style: const TextStyle(fontSize: 16, height: 1.5),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: Column(
              children: [
                BigActionButton(
                  label: 'Ya, Hapus',
                  icon: Icons.delete_rounded,
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
    try {
      await _repository.deleteFinance(log.id);
      await _load();
    } catch (error) {
      if (!mounted) return;
      _showMessage(SupabaseService.friendlyError(error));
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
    final summary = ProRepository.summarize(_logs);
    return Scaffold(
      appBar: AppBar(title: const Text('Catatan Usaha')),
      body: SafeArea(
        top: false,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _buildError()
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                      children: [
                        Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 760),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _summaryCard(summary),
                                const SizedBox(height: 16),
                                const Text(
                                  'Riwayat Catatan',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                if (_logs.isEmpty)
                                  _buildEmpty()
                                else
                                  ..._logs.map(_buildTile),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addLog,
        backgroundColor: AppTheme.primaryGreen,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Catat',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _summaryCard(FinanceSummary summary) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Saldo Usaha',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              AppFormatters.rupiah(summary.balance),
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: summary.balance < 0
                    ? AppTheme.dangerRed
                    : AppTheme.primaryGreen,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _summaryItem(
                    label: 'Pemasukan',
                    amount: summary.income,
                    color: AppTheme.secondaryGreen,
                    icon: Icons.trending_up_rounded,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _summaryItem(
                    label: 'Pengeluaran',
                    amount: summary.expense,
                    color: AppTheme.dangerRed,
                    icon: Icons.trending_down_rounded,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryItem({
    required String label,
    required double amount,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 17, color: color),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            AppFormatters.rupiah(amount),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTile(FarmFinanceModel log) {
    final color = log.isIncome ? AppTheme.secondaryGreen : AppTheme.dangerRed;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  log.isIncome
                      ? Icons.arrow_downward_rounded
                      : Icons.arrow_upward_rounded,
                  color: color,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      log.isIncome ? 'Pemasukan' : 'Pengeluaran',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      AppFormatters.date(log.transactionDate),
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    if ((log.notes ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        log.notes!,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppTheme.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${log.isIncome ? '+' : '−'}${AppFormatters.rupiah(log.amount)}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Hapus catatan',
                    onPressed: () => _delete(log),
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: AppTheme.textSecondary,
                      size: 22,
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

  Widget _buildEmpty() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(
              Icons.account_balance_wallet_rounded,
              size: 58,
              color: AppTheme.secondaryGreen,
            ),
            const SizedBox(height: 12),
            const Text(
              'Belum ada catatan keuangan',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Catat hasil panen, penjualan ternak, dan biaya saprodi supaya '
              'Anda tahu untung rugi usaha.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: AppTheme.textSecondary,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 16),
            BigActionButton(
              label: 'Catat Pertama',
              icon: Icons.add_rounded,
              onPressed: _addLog,
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
              _error ?? 'Gagal memuat catatan keuangan.',
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

class _FinanceFormResult {
  const _FinanceFormResult({
    required this.category,
    required this.amount,
    required this.date,
    this.notes,
  });

  final String category;
  final double amount;
  final DateTime date;
  final String? notes;
}

class _FinanceForm extends StatefulWidget {
  const _FinanceForm();

  @override
  State<_FinanceForm> createState() => _FinanceFormState();
}

class _FinanceFormState extends State<_FinanceForm> {
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  String _category = AppConstants.financeExpense;
  DateTime _date = DateTime.now();
  String? _amountError;

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      helpText: 'Pilih tanggal transaksi',
      cancelText: 'Batal',
      confirmText: 'Pilih',
    );
    if (picked != null && mounted) setState(() => _date = picked);
  }

  void _submit() {
    final amount = double.tryParse(
      _amountController.text.replaceAll(RegExp(r'[^0-9]'), ''),
    );
    if (amount == null || amount <= 0) {
      setState(() => _amountError = 'Nominal wajib diisi lebih dari 0');
      return;
    }
    if (amount > 1000000000) {
      setState(() => _amountError = 'Nominal terlalu besar');
      return;
    }
    Navigator.pop(
      context,
      _FinanceFormResult(
        category: _category,
        amount: amount,
        date: _date,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isIncome = _category == AppConstants.financeIncome;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Catat Keuangan Usaha',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const SizedBox(
                        width: double.infinity,
                        child: Text('Pemasukan', textAlign: TextAlign.center),
                      ),
                      selected: isIncome,
                      onSelected: (_) => setState(
                        () => _category = AppConstants.financeIncome,
                      ),
                      labelStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ChoiceChip(
                      label: const SizedBox(
                        width: double.infinity,
                        child: Text('Pengeluaran', textAlign: TextAlign.center),
                      ),
                      selected: !isIncome,
                      onSelected: (_) => setState(
                        () => _category = AppConstants.financeExpense,
                      ),
                      labelStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Nominal (Rp)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(12),
                ],
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
                decoration: InputDecoration(
                  hintText: '0',
                  prefixText: 'Rp  ',
                  errorText: _amountError,
                ),
                onChanged: (_) {
                  if (_amountError != null) {
                    setState(() => _amountError = null);
                  }
                },
              ),
              const SizedBox(height: 16),
              const Text(
                'Tanggal',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_month_rounded),
                label: Text(AppFormatters.dateLong(_date)),
              ),
              const SizedBox(height: 16),
              const Text(
                'Keterangan (opsional)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _notesController,
                minLines: 2,
                maxLines: 3,
                maxLength: 300,
                style: const TextStyle(fontSize: 16, height: 1.5),
                decoration: const InputDecoration(
                  hintText: 'Contoh: jual 200 kg gabah kering',
                ),
              ),
              const SizedBox(height: 8),
              BigActionButton(
                label: 'Simpan Catatan',
                icon: Icons.save_rounded,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
