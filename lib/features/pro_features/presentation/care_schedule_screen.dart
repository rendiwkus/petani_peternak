import 'package:flutter/material.dart';

import '../../../core/services/supabase_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/big_action_button.dart';
import '../data/pro_repository.dart';

/// Jadwal perawatan tanaman & ternak milik pengguna.
class CareScheduleScreen extends StatefulWidget {
  const CareScheduleScreen({super.key, this.repository});

  final ProRepository? repository;

  @override
  State<CareScheduleScreen> createState() => _CareScheduleScreenState();
}

class _CareScheduleScreenState extends State<CareScheduleScreen> {
  late final ProRepository _repository =
      widget.repository ?? ProRepository();

  List<CareScheduleModel> _schedules = const [];
  bool _isLoading = true;
  String? _error;
  String? _busyId;

  static const _activityOptions = [
    ('pemupukan', 'Pemupukan', Icons.compost_rounded),
    ('penyemprotan', 'Penyemprotan', Icons.sanitizer_rounded),
    ('pemberian_pakan', 'Pemberian Pakan', Icons.grass_rounded),
    ('vaksinasi', 'Vaksinasi', Icons.vaccines_rounded),
    ('pemeriksaan', 'Pemeriksaan Kesehatan', Icons.medical_services_rounded),
    ('panen', 'Panen', Icons.agriculture_rounded),
  ];

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
      final schedules = await _repository.fetchSchedules(forceRefresh: true);
      if (!mounted) return;
      setState(() {
        _schedules = schedules;
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

  Future<void> _addSchedule() async {
    final result = await showModalBottomSheet<_ScheduleFormResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: const _ScheduleForm(),
      ),
    );
    if (result == null) return;
    try {
      await _repository.addSchedule(
        activityType: result.activityType,
        scheduledDate: result.date,
        notes: result.notes,
      );
      if (!mounted) return;
      _showMessage('Jadwal perawatan disimpan.');
      await _load();
    } catch (error) {
      if (!mounted) return;
      _showMessage(SupabaseService.friendlyError(error));
    }
  }

  Future<void> _toggle(CareScheduleModel schedule) async {
    if (_busyId != null) return;
    setState(() => _busyId = schedule.id);
    try {
      await _repository.setScheduleCompleted(
        schedule.id,
        isCompleted: !schedule.isCompleted,
      );
      await _load();
    } catch (error) {
      if (!mounted) return;
      _showMessage(SupabaseService.friendlyError(error));
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _delete(CareScheduleModel schedule) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Jadwal?'),
        content: Text(
          'Jadwal ${schedule.activityLabel} pada '
          '${AppFormatters.date(schedule.scheduledDate)} akan dihapus.',
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
      await _repository.deleteSchedule(schedule.id);
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

  IconData _iconFor(String activityType) {
    for (final option in _activityOptions) {
      if (option.$1 == activityType) return option.$3;
    }
    return Icons.event_note_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final pending = _schedules.where((item) => !item.isCompleted).toList();
    final done = _schedules.where((item) => item.isCompleted).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Jadwal Perawatan')),
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
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (_schedules.isEmpty)
                                  _buildEmpty()
                                else ...[
                                  _sectionTitle(
                                    'Akan Datang (${pending.length})',
                                  ),
                                  if (pending.isEmpty)
                                    const _Hint(
                                      text: 'Tidak ada jadwal yang menunggu.',
                                    )
                                  else
                                    ...pending.map(_buildTile),
                                  if (done.isNotEmpty) ...[
                                    const SizedBox(height: 20),
                                    _sectionTitle(
                                      'Sudah Selesai (${done.length})',
                                    ),
                                    ...done.map(_buildTile),
                                  ],
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addSchedule,
        backgroundColor: AppTheme.primaryGreen,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Tambah Jadwal',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppTheme.textPrimary,
        ),
      ),
    );
  }

  Widget _buildTile(CareScheduleModel schedule) {
    final overdue = schedule.isOverdue;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: schedule.isCompleted
                          ? AppTheme.disabledBg
                          : AppTheme.surfaceTintGreen,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      _iconFor(schedule.activityType),
                      color: schedule.isCompleted
                          ? AppTheme.disabledFg
                          : AppTheme.secondaryGreen,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          schedule.activityLabel,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: schedule.isCompleted
                                ? AppTheme.textSecondary
                                : AppTheme.textPrimary,
                            decoration: schedule.isCompleted
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          AppFormatters.dateLong(schedule.scheduledDate),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: overdue
                                ? AppTheme.dangerRed
                                : AppTheme.textSecondary,
                          ),
                        ),
                        if ((schedule.notes ?? '').trim().isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            schedule.notes!,
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppTheme.textSecondary,
                              height: 1.4,
                            ),
                          ),
                        ],
                        if (overdue) ...[
                          const SizedBox(height: 6),
                          const Text(
                            'Terlewat — segera lakukan',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.dangerRed,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Hapus jadwal',
                    onPressed: () => _delete(schedule),
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: AppTheme.dangerRed,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              BigActionButton(
                label: schedule.isCompleted
                    ? 'Tandai Belum Selesai'
                    : 'Tandai Sudah Selesai',
                icon: schedule.isCompleted
                    ? Icons.undo_rounded
                    : Icons.check_circle_rounded,
                isOutlined: schedule.isCompleted,
                isLoading: _busyId == schedule.id,
                onPressed: _busyId == schedule.id
                    ? null
                    : () => _toggle(schedule),
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
              Icons.event_available_rounded,
              size: 60,
              color: AppTheme.secondaryGreen,
            ),
            const SizedBox(height: 12),
            const Text(
              'Belum ada jadwal perawatan',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Catat jadwal pemupukan, penyemprotan, vaksinasi, atau panen '
              'agar tidak terlewat.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: AppTheme.textSecondary,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 16),
            BigActionButton(
              label: 'Tambah Jadwal Pertama',
              icon: Icons.add_rounded,
              onPressed: _addSchedule,
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
              _error ?? 'Gagal memuat jadwal.',
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

class _Hint extends StatelessWidget {
  const _Hint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: const TextStyle(fontSize: 16, color: AppTheme.textSecondary),
      ),
    );
  }
}

class _ScheduleFormResult {
  const _ScheduleFormResult({
    required this.activityType,
    required this.date,
    this.notes,
  });

  final String activityType;
  final DateTime date;
  final String? notes;
}

class _ScheduleForm extends StatefulWidget {
  const _ScheduleForm();

  @override
  State<_ScheduleForm> createState() => _ScheduleFormState();
}

class _ScheduleFormState extends State<_ScheduleForm> {
  final _notesController = TextEditingController();
  String _activityType = 'pemupukan';
  DateTime _date = DateTime.now().add(const Duration(days: 1));

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
      helpText: 'Pilih tanggal perawatan',
      cancelText: 'Batal',
      confirmText: 'Pilih',
    );
    if (picked != null && mounted) setState(() => _date = picked);
  }

  @override
  Widget build(BuildContext context) {
    final options = _CareFormOptions.activities;
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
                'Tambah Jadwal Perawatan',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Jenis Perawatan',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: options
                    .map(
                      (option) => ChoiceChip(
                        label: Text(option.$2),
                        selected: _activityType == option.$1,
                        onSelected: (_) =>
                            setState(() => _activityType = option.$1),
                        labelStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 10,
                        ),
                      ),
                    )
                    .toList(),
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
                'Catatan (opsional)',
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
                maxLines: 4,
                maxLength: 300,
                style: const TextStyle(fontSize: 16, height: 1.5),
                decoration: const InputDecoration(
                  hintText: 'Contoh: 2 karung NPK per bedengan',
                ),
              ),
              const SizedBox(height: 8),
              BigActionButton(
                label: 'Simpan Jadwal',
                icon: Icons.save_rounded,
                onPressed: () {
                  Navigator.pop(
                    context,
                    _ScheduleFormResult(
                      activityType: _activityType,
                      date: _date,
                      notes: _notesController.text.trim().isEmpty
                          ? null
                          : _notesController.text.trim(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CareFormOptions {
  _CareFormOptions._();

  static const activities = [
    ('pemupukan', 'Pemupukan'),
    ('penyemprotan', 'Penyemprotan'),
    ('pemberian_pakan', 'Pemberian Pakan'),
    ('vaksinasi', 'Vaksinasi'),
    ('pemeriksaan', 'Pemeriksaan Kesehatan'),
    ('panen', 'Panen'),
  ];
}
