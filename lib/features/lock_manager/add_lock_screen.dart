import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/models/lock_entry.dart';
import '../../core/models/schedule_interval.dart';
import '../../core/services/native_bridge_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/theme/jeda_colors.dart';
import '../../core/theme/jeda_radii.dart';
import '../../core/theme/jeda_typography.dart';
import '../../core/widgets/app_icon_widget.dart';
import '../../core/widgets/circular_24h_clock_picker.dart';
import '../../core/widgets/jeda_badge.dart';
import '../../core/widgets/jeda_button.dart';

class AddLockScreen extends ConsumerStatefulWidget {
  final LockEntry? editingLock;

  const AddLockScreen({super.key, this.editingLock});

  @override
  ConsumerState<AddLockScreen> createState() => _AddLockScreenState();
}

class _AddLockScreenState extends ConsumerState<AddLockScreen> {
  final _searchController = TextEditingController();
  final _goalController = TextEditingController();
  final _descriptionController = TextEditingController();

  List<Map<String, dynamic>> _installedApps = [];
  List<Map<String, dynamic>> _filteredApps = [];
  bool _isLoading = true;
  String? _error;

  Map<String, dynamic>? _selectedApp;

  // Tab/Mode state (false = Detoks Penuh, true = Jadwal Rutin)
  bool _isScheduled = false;

  // Instant mode state
  int _durationMonths = 0;
  int _durationWeeks = 0;
  int _durationDays = 0;
  int _durationHours = 2;

  // Multi-interval scheduled mode state
  late List<ScheduleInterval> _intervals;

  // Existing conflict info
  bool _hasExistingConflict = false;
  String? _conflictDescription;

  static const List<String> _presetGoals = [
    'Tidur Nyenyak Tanpa Scroll',
    'Fokus Skripsi & Kerja Mendalam',
    'Hadir Bersama Keluarga & Teman',
    'Ketenangan Pikiran & Detoks Dopamin',
    'Waktu Ibadah & Refleksi Diri',
  ];

  bool get _isEditMode => widget.editingLock != null;

  @override
  void initState() {
    super.initState();
    final editing = widget.editingLock;
    if (editing != null) {
      _selectedApp = {
        'name': editing.appName,
        'packageName': editing.packageName,
      };
      _isScheduled = editing.isScheduled;
      if (!editing.isScheduled) {
        int remainingHours = editing.durationHours;
        _durationMonths = (remainingHours ~/ (30 * 24)).clamp(0, 12);
        remainingHours %= (30 * 24);
        _durationWeeks = (remainingHours ~/ (7 * 24)).clamp(0, 4);
        remainingHours %= (7 * 24);
        _durationDays = (remainingHours ~/ 24).clamp(0, 30);
        _durationHours = (remainingHours % 24).clamp(0, 23);
      }
      final existingIntervals = editing.allIntervals;
      if (existingIntervals.isNotEmpty) {
        _intervals = List<ScheduleInterval>.from(existingIntervals);
      } else {
        _intervals = [
          ScheduleInterval(
            start: '08:00',
            end: '17:00',
            days: [1, 2, 3, 4, 5],
          ),
        ];
      }
      _goalController.text = editing.focusGoal ?? _presetGoals.first;
      _descriptionController.text = editing.description ?? '';
    } else {
      _intervals = [
        ScheduleInterval(
          start: '08:00',
          end: '17:00',
          days: [1, 2, 3, 4, 5], // Senin - Jumat default
        ),
      ];
      _goalController.text = _presetGoals.first;
      _descriptionController.text =
          '5 menit scroll sering berubah menjadi 2 jam penyesalan. Tarik napas dan kembali ke tujuanmu.';
    }

    _loadApps();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _goalController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadApps() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final nativeBridge = ref.read(nativeBridgeServiceProvider);
      final apps = await nativeBridge.getInstalledApps();
      apps.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));

      if (mounted) {
        setState(() {
          _installedApps = apps;
          _filteredApps = apps;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Gagal memuat daftar aplikasi perangkat.';
          _isLoading = false;
        });
      }
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredApps = _installedApps.where((app) {
        final name = (app['name'] as String).toLowerCase();
        return name.contains(query);
      }).toList();
    });
  }

  int _calculateTotalHours() {
    return (_durationMonths * 30 * 24) +
        (_durationWeeks * 7 * 24) +
        (_durationDays * 24) +
        _durationHours;
  }

  String _formatSelectedDetoxSummary() {
    final parts = <String>[];
    if (_durationMonths > 0) parts.add('$_durationMonths bln');
    if (_durationWeeks > 0) parts.add('$_durationWeeks mgg');
    if (_durationDays > 0) parts.add('$_durationDays hr');
    if (_durationHours > 0) parts.add('$_durationHours jam');
    if (parts.isEmpty) return '0 jam';
    return parts.join(' ');
  }

  Future<void> _checkAppConflict(Map<String, dynamic> app) async {
    final storage = ref.read(storageServiceProvider);
    final activeLocks = await storage.getActiveLocks();
    final quotas = await storage.getAllQuotas();

    final pkg = app['packageName'] as String;
    bool conflict = false;
    String? desc;

    final existingLock = activeLocks
        .where((l) =>
            l.packageName == pkg &&
            l.isCurrentlyBlocking &&
            l.id != widget.editingLock?.id)
        .toList();
    final existingQuota = quotas.where((q) => q.packageNames.contains(pkg)).toList();

    if (existingLock.isNotEmpty) {
      conflict = true;
      desc = 'Aplikasi ini sudah memiliki aturan kunci/jadwal aktif.';
    } else if (existingQuota.isNotEmpty) {
      conflict = true;
      desc = 'Aplikasi ini terdaftar dalam grup Kuota Harian "${existingQuota.first.groupName}".';
    }

    if (mounted) {
      setState(() {
        _hasExistingConflict = conflict;
        _conflictDescription = desc;
      });
    }
  }

  String? _validateIntervals() {
    if (_intervals.isEmpty) {
      return 'Tambahkan minimal satu interval jadwal.';
    }

    for (int i = 0; i < _intervals.length; i++) {
      final it = _intervals[i];
      if (it.days.isEmpty) {
        return 'Interval ${it.formattedRange} belum memilih hari.';
      }
      if (it.start == it.end) {
        return 'Jam mulai dan jam selesai interval tidak boleh sama (${it.start}).';
      }
    }

    // Check overlaps
    for (int i = 0; i < _intervals.length; i++) {
      for (int j = i + 1; j < _intervals.length; j++) {
        if (_intervals[i].overlapsWith(_intervals[j])) {
          final commonDays = _intervals[i]
              .days
              .where((d) => _intervals[j].days.contains(d))
              .map(ScheduleInterval.dayName)
              .join(', ');
          return 'Interval ${_intervals[i].formattedRange} dan ${_intervals[j].formattedRange} bertumpang tindih pada hari ($commonDays).';
        }
      }
    }

    return null;
  }

  Future<void> _startFocus() async {
    if (_selectedApp == null) return;

    if (!_isScheduled) {
      final totalHours = _calculateTotalHours();
      if (totalHours <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tentukan durasi pembatasan minimal 1 jam.'),
            backgroundColor: JedaColors.error,
          ),
        );
        return;
      }
    } else {
      final validationError = _validateIntervals();
      if (validationError != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(validationError),
            backgroundColor: JedaColors.error,
          ),
        );
        return;
      }
    }

    final storage = ref.read(storageServiceProvider);

    // Multi-interval encoding
    final intervalsJson = _isScheduled
        ? _intervals.map((i) => jsonEncode(i.toJson())).toList()
        : null;

    // Legacy fallback fields using first interval
    final primaryInterval = _isScheduled ? _intervals.first : null;

    final goalText = _goalController.text.trim();
    final descText = _descriptionController.text.trim();

    final entry = LockEntry(
      id: widget.editingLock?.id ?? const Uuid().v4(),
      packageName: _selectedApp!['packageName'],
      appName: _selectedApp!['name'],
      appIconBytes: widget.editingLock?.appIconBytes ?? [],
      startTime: _isEditMode && !_isScheduled ? DateTime.now() : (widget.editingLock?.startTime ?? DateTime.now()),
      durationHours: _isScheduled ? 0 : _calculateTotalHours(),
      isScheduled: _isScheduled,
      scheduledStart: primaryInterval?.start,
      scheduledEnd: primaryInterval?.end,
      scheduledDays: primaryInterval?.days,
      intervalsJson: intervalsJson,
      focusGoal: goalText.isNotEmpty ? goalText : null,
      description: descText.isNotEmpty ? descText : null,
    );

    await storage.addLock(entry);

    final activeRules = storage.getActiveRules();
    await ref.read(nativeBridgeServiceProvider).startMonitoring(activeRules);
    await ref.read(nativeBridgeServiceProvider).updateBlockedList(activeRules);

    if (mounted) {
      Navigator.of(context).pop(entry);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEditMode
              ? 'Perubahan penguncian "${entry.appName}" berhasil disimpan 🌱'
              : (_isScheduled
                  ? 'Jadwal multi-interval berhasil disimpan (${_intervals.length} interval)'
                  : 'Sesi detoks dimulai')),
          backgroundColor: JedaColors.primaryDark,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  String _getEndTimePreview() {
    final totalHours = _calculateTotalHours();
    final endTime = DateTime.now().add(Duration(hours: totalHours));
    String twoDigits(int n) => n.toString().padLeft(2, "0");

    if (totalHours > 24) {
      return "${twoDigits(endTime.day)}/${twoDigits(endTime.month)}/${endTime.year} ${twoDigits(endTime.hour)}:${twoDigits(endTime.minute)}";
    }
    return "${twoDigits(endTime.hour)}:${twoDigits(endTime.minute)}";
  }

  void _addInterval() {
    String start = '19:00';
    String end = '21:00';
    if (_intervals.isNotEmpty) {
      final last = _intervals.last;
      if (last.end == '17:00') {
        start = '19:00';
        end = '22:00';
      }
    }

    final newInterval = ScheduleInterval(
      start: start,
      end: end,
      days: [1, 2, 3, 4, 5],
    );

    setState(() {
      _intervals.add(newInterval);
    });
    _openIntervalEditorSheet(_intervals.length - 1);
  }

  void _copyInterval(int index) {
    final original = _intervals[index];
    final copy = original.copyWith(
      id: const Uuid().v4(),
    );
    setState(() {
      _intervals.add(copy);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Interval ${original.formattedRange} disalin. Silakan sesuaikan jam atau hari.'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _deleteInterval(int index) {
    if (_intervals.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Jadwal minimal harus memiliki 1 interval.'),
          backgroundColor: JedaColors.warning,
        ),
      );
      return;
    }
    setState(() {
      _intervals.removeAt(index);
    });
  }

  Future<void> _openIntervalEditorSheet(int index) async {
    final interval = _intervals[index];
    final result = await showModalBottomSheet<ScheduleInterval>(
      context: context,
      isScrollControlled: true,
      backgroundColor: JedaColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: JedaRadii.sheetTop),
      builder: (ctx) => _IntervalEditorModal(initialInterval: interval),
    );

    if (result != null && mounted) {
      setState(() {
        _intervals[index] = result;
      });
    }
  }

  Future<void> _openPsychologicalGoalModal() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: JedaColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: JedaRadii.sheetTop),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  24,
                  12,
                  24,
                  MediaQuery.of(context).viewInsets.bottom + 24,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 36,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: JedaColors.border,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const Row(
                        children: [
                          Icon(Icons.psychology_outlined, color: JedaColors.primaryDark, size: 22),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Jangkar Psikologis & Tujuan Fokus',
                              style: JedaTypography.heading3,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Menuliskan alasan emosional dan tujuan fokus terbukti secara psikologis menurunkan dorongan impulsif hingga 60%. Pesan ini akan muncul di layar saat kamu tergoda membuka aplikasi.',
                        style: JedaTypography.caption,
                      ),
                      const SizedBox(height: 16),
                      const Text('Pilih Cepat Tujuan Fokus (Goals)', style: JedaTypography.labelBold),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: _presetGoals.map((preset) {
                          final isSelected = _goalController.text.trim() == preset;
                          return InkWell(
                            onTap: () {
                              setModalState(() {
                                _goalController.text = preset;
                              });
                              setState(() {});
                            },
                            borderRadius: JedaRadii.borderFull,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                              decoration: BoxDecoration(
                                color: isSelected ? JedaColors.primary : JedaColors.surfaceSecondary,
                                borderRadius: JedaRadii.borderFull,
                                border: Border.all(
                                  color: isSelected ? JedaColors.primary : JedaColors.border,
                                ),
                              ),
                              child: Text(
                                preset,
                                style: JedaTypography.caption.copyWith(
                                  color: isSelected ? JedaColors.textOnPrimary : JedaColors.textPrimary,
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _goalController,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          labelText: 'Tujuan Fokus Utama (Goals)',
                          hintText: 'Contoh: Menyelesaikan bab 4 skripsi tanpa distraksi',
                          prefixIcon: Icon(Icons.flag_outlined, size: 18),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _descriptionController,
                        maxLines: 3,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          labelText: 'Deskripsi / Pesan Pengingat untuk Dirimu',
                          hintText: 'Tulis pesan pengingat yang akan menyadarkanmu saat tergoda membuka aplikasi ini...',
                          alignLabelWithHint: true,
                        ),
                      ),
                      const SizedBox(height: 20),
                      JedaButton(
                        label: 'Simpan Tujuan & Pengingat',
                        variant: JedaButtonVariant.primary,
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPsychologicalGoalBanner() {
    final goal = _goalController.text.trim();
    final desc = _descriptionController.text.trim();

    return InkWell(
      onTap: _openPsychologicalGoalModal,
      borderRadius: JedaRadii.borderR12,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: JedaColors.primarySoft.withValues(alpha: 0.55),
          borderRadius: JedaRadii.borderR12,
          border: Border.all(color: JedaColors.primary.withValues(alpha: 0.45)),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: JedaColors.surface,
                borderRadius: JedaRadii.borderR8,
              ),
              child: const Icon(Icons.psychology_outlined, size: 18, color: JedaColors.primaryDark),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    goal.isNotEmpty ? '🎯 Tujuan: $goal' : '🎯 Tetapkan Tujuan Fokus & Pengingat Diri',
                    style: JedaTypography.caption.copyWith(
                      color: JedaColors.primaryDark,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (desc.isNotEmpty)
                    Text(
                      '“$desc”',
                      style: JedaTypography.caption.copyWith(
                        fontSize: 11,
                        color: JedaColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.edit_note_rounded, size: 18, color: JedaColors.primaryDark),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return Scaffold(
      backgroundColor: JedaColors.background,
      appBar: AppBar(
        title: Text(
          _isEditMode ? 'Edit Penguncian & Tujuan' : 'Pembatasan Aplikasi',
          style: JedaTypography.heading3,
        ),
      ),
      body: Column(
        children: [
          // Mode Switcher (Detoks Penuh vs Jadwal Rutin)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: JedaColors.surfaceSecondary,
                borderRadius: JedaRadii.borderR12,
                border: Border.all(color: JedaColors.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildModeTab(
                      label: 'Detoks Penuh',
                      isSelected: !_isScheduled,
                      onTap: () => setState(() => _isScheduled = false),
                    ),
                  ),
                  Expanded(
                    child: _buildModeTab(
                      label: 'Jadwal Jam (1–24)',
                      isSelected: _isScheduled,
                      onTap: () => setState(() => _isScheduled = true),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Search Field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 4.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Cari aplikasi...',
                prefixIcon: const Icon(Icons.search, size: 20, color: JedaColors.textTertiary),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
              ),
            ),
          ),

          // Conflict notice if any
          if (_hasExistingConflict && _conflictDescription != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: JedaColors.warningSoft,
                  borderRadius: JedaRadii.borderR12,
                  border: Border.all(color: const Color(0xFFE8D3B4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 16, color: JedaColors.warning),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _conflictDescription!,
                        style: JedaTypography.caption.copyWith(color: JedaColors.warning),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // App List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2.2, color: JedaColors.primary))
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(_error!, style: JedaTypography.bodySecondary, textAlign: TextAlign.center),
                              const SizedBox(height: 16),
                              JedaButton(
                                label: 'Coba Lagi',
                                isFullWidth: false,
                                onPressed: _loadApps,
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _filteredApps.length,
                        itemBuilder: (context, index) {
                          final app = _filteredApps[index];
                          final pkgName = app['packageName'] as String;
                          final isSelected = _selectedApp?['packageName'] == pkgName;

                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                            leading: AppIconWidget(
                              packageName: pkgName,
                              size: 40,
                              backgroundColor: isSelected ? JedaColors.primarySoft : JedaColors.surfaceSecondary,
                              fallbackIconColor: isSelected ? JedaColors.primaryDark : JedaColors.textSecondary,
                            ),
                            title: Text(app['name'], style: JedaTypography.labelBold),
                            subtitle: Text(
                              pkgName,
                              style: JedaTypography.caption,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isSelected ? JedaColors.primary : Colors.transparent,
                                border: Border.all(
                                  color: isSelected ? JedaColors.primary : JedaColors.border,
                                  width: 1.5,
                                ),
                              ),
                              child: isSelected
                                  ? const Icon(Icons.check, size: 14, color: JedaColors.textOnPrimary)
                                  : null,
                            ),
                            onTap: () {
                              setState(() => _selectedApp = app);
                              _checkAppConflict(app);
                            },
                          );
                        },
                      ),
          ),

          // Bottom Configuration Panel
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: 20,
              vertical: isKeyboardOpen ? 12 : 16,
            ),
            decoration: const BoxDecoration(
              color: JedaColors.surface,
              borderRadius: JedaRadii.sheetTop,
              border: Border(top: BorderSide(color: JedaColors.border)),
            ),
            child: SafeArea(
              top: false,
              child: _isScheduled
                  ? _buildMultiIntervalPanel(isKeyboardOpen)
                  : _buildInstantPanel(isKeyboardOpen),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeTab({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: JedaRadii.borderR8,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? JedaColors.surface : Colors.transparent,
          borderRadius: JedaRadii.borderR8,
        ),
        child: Text(
          label,
          style: JedaTypography.labelBold.copyWith(
            color: isSelected ? JedaColors.textPrimary : JedaColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildInstantPanel(bool isKeyboardOpen) {
    final hasApp = _selectedApp != null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!isKeyboardOpen) ...[
          _buildPsychologicalGoalBanner(),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Durasi Detoks', style: JedaTypography.labelBold),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: JedaColors.primaryDark.withValues(alpha: 0.12),
                    borderRadius: JedaRadii.borderR8,
                  ),
                  child: Text(
                    _formatSelectedDetoxSummary(),
                    style: JedaTypography.caption.copyWith(
                      color: JedaColors.primaryDark,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildDurationSelector(
                  label: 'Bulan',
                  value: _durationMonths,
                  max: 12,
                  onChanged: (v) => setState(() => _durationMonths = v),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildDurationSelector(
                  label: 'Minggu',
                  value: _durationWeeks,
                  max: 4,
                  onChanged: (v) => setState(() => _durationWeeks = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildDurationSelector(
                  label: 'Hari',
                  value: _durationDays,
                  max: 30,
                  onChanged: (v) => setState(() => _durationDays = v),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildDurationSelector(
                  label: 'Jam',
                  value: _durationHours,
                  max: 23,
                  onChanged: (v) => setState(() => _durationHours = v),
                ),
              ),
            ],
          ),
          if (hasApp) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: const BoxDecoration(
                color: JedaColors.surfaceSecondary,
                borderRadius: JedaRadii.borderR12,
              ),
              child: Row(
                children: [
                  AppIconWidget(
                    packageName: _selectedApp!['packageName'],
                    size: 28,
                    borderRadius: JedaRadii.borderR8,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "${_selectedApp!['name']} akan diblokir sampai ${_getEndTimePreview()}.",
                      style: JedaTypography.caption.copyWith(color: JedaColors.textPrimary, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
        ],
        JedaButton(
          label: hasApp
              ? (_isEditMode ? 'Simpan Perubahan Penguncian' : 'Mulai Detoks Penuh')
              : 'Pilih Aplikasi Terlebih Dahulu',
          onPressed: hasApp ? _startFocus : null,
          variant: JedaButtonVariant.primary,
        ),
      ],
    );
  }

  Widget _buildDurationSelector({
    required String label,
    required int value,
    required int max,
    required ValueChanged<int> onChanged,
  }) {
    final safeValue = value.clamp(0, max);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: JedaColors.surfaceSecondary,
        borderRadius: JedaRadii.borderR12,
        border: Border.all(color: JedaColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              label,
              style: JedaTypography.caption,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          DropdownButton<int>(
            value: safeValue,
            isDense: true,
            underline: const SizedBox(),
            icon: const Icon(Icons.arrow_drop_down, color: JedaColors.textSecondary),
            items: List.generate(max + 1, (i) {
              return DropdownMenuItem(
                value: i,
                child: Text('$i', style: JedaTypography.labelBold),
              );
            }),
            onChanged: (v) {
              if (v != null) onChanged(v);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMultiIntervalPanel(bool isKeyboardOpen) {
    final hasApp = _selectedApp != null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!isKeyboardOpen) ...[
          _buildPsychologicalGoalBanner(),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  if (hasApp) ...[
                    AppIconWidget(
                      packageName: _selectedApp!['packageName'],
                      size: 22,
                      borderRadius: JedaRadii.borderR8,
                    ),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    'Rentang Jam Harian (${_intervals.length})',
                    style: JedaTypography.labelBold,
                  ),
                ],
              ),
              InkWell(
                onTap: _addInterval,
                borderRadius: JedaRadii.borderR8,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      Icon(Icons.schedule_rounded, size: 15, color: JedaColors.primary),
                      SizedBox(width: 4),
                      Text(
                        '+ Tambah Jam',
                        style: TextStyle(
                          fontSize: 12,
                          color: JedaColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Intervals list preview
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 160),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: _intervals.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, idx) {
                final it = _intervals[idx];
                return InkWell(
                  onTap: () => _openIntervalEditorSheet(idx),
                  borderRadius: JedaRadii.borderR12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: JedaColors.surfaceSecondary,
                      borderRadius: JedaRadii.borderR12,
                      border: Border.all(color: JedaColors.border),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: const BoxDecoration(
                            color: JedaColors.primarySoft,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.access_time_filled_rounded, size: 18, color: JedaColors.primaryDark),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    it.formattedRange,
                                    style: JedaTypography.labelBold.copyWith(
                                      color: JedaColors.primaryDark,
                                      fontSize: 15,
                                    ),
                                  ),
                                  if (it.isMidnightCrossing) ...[
                                    const SizedBox(width: 6),
                                    const JedaBadge(
                                      label: 'Lintas Malam',
                                      variant: JedaBadgeVariant.info,
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${it.formattedDays} • Ketuk untuk buka jam bulat',
                                style: JedaTypography.caption,
                              ),
                            ],
                          ),
                        ),
                        // Copy button
                        IconButton(
                          icon: const Icon(Icons.copy_outlined, size: 16, color: JedaColors.textSecondary),
                          tooltip: 'Salin Interval',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                          onPressed: () => _copyInterval(idx),
                        ),
                        // Edit button
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 16, color: JedaColors.primary),
                          tooltip: 'Atur dengan Jam Bulat',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                          onPressed: () => _openIntervalEditorSheet(idx),
                        ),
                        // Delete button
                        if (_intervals.length > 1)
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 16, color: JedaColors.error),
                            tooltip: 'Hapus Interval',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                            onPressed: () => _deleteInterval(idx),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
        ],

        JedaButton(
          label: hasApp
              ? (_isEditMode
                  ? 'Simpan Perubahan Jadwal (${_intervals.length} Interval)'
                  : 'Simpan ${_intervals.length} Interval Jadwal')
              : 'Pilih Aplikasi Terlebih Dahulu',
          onPressed: hasApp ? _startFocus : null,
          variant: JedaButtonVariant.primary,
        ),
      ],
    );
  }
}

/// Modal bottom sheet to edit or create a specific schedule interval using the 24-hour Circular Clock
class _IntervalEditorModal extends StatefulWidget {
  final ScheduleInterval initialInterval;

  const _IntervalEditorModal({required this.initialInterval});

  @override
  State<_IntervalEditorModal> createState() => _IntervalEditorModalState();
}

class _IntervalEditorModalState extends State<_IntervalEditorModal> {
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  late List<int> _selectedDays;

  @override
  void initState() {
    super.initState();
    final sParts = widget.initialInterval.start.split(':');
    final eParts = widget.initialInterval.end.split(':');
    _startTime = TimeOfDay(hour: int.parse(sParts[0]), minute: int.parse(sParts[1]));
    _endTime = TimeOfDay(hour: int.parse(eParts[0]), minute: int.parse(eParts[1]));
    _selectedDays = List<int>.from(widget.initialInterval.days);
  }

  bool get _isMidnightCrossing {
    final sMin = _startTime.hour * 60 + _startTime.minute;
    final eMin = _endTime.hour * 60 + _endTime.minute;
    return sMin > eMin;
  }

  void _toggleDay(int day) {
    setState(() {
      if (_selectedDays.contains(day)) {
        if (_selectedDays.length > 1) {
          _selectedDays.remove(day);
        }
      } else {
        _selectedDays.add(day);
      }
      _selectedDays.sort();
    });
  }

  void _save() {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    final formattedStart = "${twoDigits(_startTime.hour)}:${twoDigits(_startTime.minute)}";
    final formattedEnd = "${twoDigits(_endTime.hour)}:${twoDigits(_endTime.minute)}";

    if (formattedStart == formattedEnd) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Jam mulai dan selesai tidak boleh persis sama.'),
          backgroundColor: JedaColors.error,
        ),
      );
      return;
    }

    final updated = widget.initialInterval.copyWith(
      start: formattedStart,
      end: formattedEnd,
      days: _selectedDays,
    );

    Navigator.of(context).pop(updated);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: JedaColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Text('Pilih Rentang Jam Fokus (1 – 24)', style: JedaTypography.heading3),
            const SizedBox(height: 4),
            const Text(
              'Sentuh atau geser lingkaran jam 24-jam di bawah untuk menentukan waktu mulai dan selesai penguncian.',
              style: JedaTypography.caption,
            ),
            const SizedBox(height: 16),

            // 24-Hour Circular Clock Range Picker
            Circular24HourClockPicker(
              startTime: _startTime,
              endTime: _endTime,
              onStartTimeChanged: (newStart) {
                setState(() => _startTime = newStart);
              },
              onEndTimeChanged: (newEnd) {
                setState(() => _endTime = newEnd);
              },
            ),

            if (_isMidnightCrossing) ...[
              const SizedBox(height: 12),
              const Center(
                child: JedaBadge(
                  label: 'Rentang jam melewati tengah malam (berlanjut ke pagi berikutnya)',
                  variant: JedaBadgeVariant.info,
                ),
              ),
            ],

            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Hari Berlaku', style: JedaTypography.labelBold),
                InkWell(
                  onTap: () {
                    setState(() {
                      if (_selectedDays.length == 7) {
                        _selectedDays = [1, 2, 3, 4, 5];
                      } else {
                        _selectedDays = [1, 2, 3, 4, 5, 6, 7];
                      }
                    });
                  },
                  child: Text(
                    _selectedDays.length == 7 ? 'Pilih Hari Kerja' : 'Pilih Setiap Hari',
                    style: JedaTypography.caption.copyWith(
                      color: JedaColors.primaryDark,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [1, 2, 3, 4, 5, 6, 7].map((day) {
                final isSelected = _selectedDays.contains(day);
                return InkWell(
                  onTap: () => _toggleDay(day),
                  borderRadius: JedaRadii.borderFull,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? JedaColors.primary : JedaColors.surfaceSecondary,
                      borderRadius: JedaRadii.borderFull,
                      border: Border.all(
                        color: isSelected ? JedaColors.primary : JedaColors.border,
                      ),
                    ),
                    child: Text(
                      ScheduleInterval.dayName(day),
                      style: JedaTypography.caption.copyWith(
                        color: isSelected ? JedaColors.textOnPrimary : JedaColors.textSecondary,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: JedaButton(
                    label: 'Batal',
                    variant: JedaButtonVariant.secondary,
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: JedaButton(
                    label: 'Terapkan Rentang Jam',
                    variant: JedaButtonVariant.primary,
                    onPressed: _save,
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
