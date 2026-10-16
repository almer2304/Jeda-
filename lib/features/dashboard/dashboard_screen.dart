import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/services/native_bridge_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/models/lock_entry.dart';
import '../../core/models/quota_entry.dart';
import '../../core/theme/jeda_colors.dart';
import '../../core/theme/jeda_radii.dart';
import '../../core/theme/jeda_spacing.dart';
import '../../core/theme/jeda_typography.dart';
import '../../core/widgets/app_icon_widget.dart';
import '../../core/widgets/jeda_badge.dart';
import '../../core/widgets/jeda_bottom_sheet.dart';
import '../../core/widgets/jeda_button.dart';
import '../../core/widgets/jeda_card.dart';
import '../lock_manager/add_lock_screen.dart';
import '../lock_manager/add_quota_screen.dart';
import '../education/education_screen.dart';
import '../settings/settings_screen.dart';
import '../settings/uninstall_friction_screen.dart';
import '../gamification/gamification_screen.dart';
import '../../core/services/api_service.dart';
import '../../core/providers/auth_provider.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;
  final Set<int> _loadedTabs = {0};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          const DashboardBody(),
          _loadedTabs.contains(1) ? const GamificationScreen() : const SizedBox.shrink(),
          _loadedTabs.contains(2) ? const EducationScreen() : const SizedBox.shrink(),
          _loadedTabs.contains(3) ? const SettingsScreen() : const SizedBox.shrink(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
            _loadedTabs.add(index);
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Beranda',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Komunitas',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: 'Edukasi',
          ),
          NavigationDestination(
            icon: Icon(Icons.tune_outlined),
            selectedIcon: Icon(Icons.tune),
            label: 'Pengaturan',
          ),
        ],
      ),
    );
  }
}

class DashboardBody extends ConsumerStatefulWidget {
  const DashboardBody({super.key});

  @override
  ConsumerState<DashboardBody> createState() => _DashboardBodyState();
}

class _DashboardBodyState extends ConsumerState<DashboardBody> with WidgetsBindingObserver {
  Timer? _countdownTimer;
  StreamSubscription? _blockEventSub;
  List<LockEntry> _activeLocks = [];
  List<QuotaEntry> _quotas = [];
  int _hoursSaved = 0;
  int _streakDays = 0;
  bool _isWarningDialogShowing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadLocalDataSync();
    _initData();
    
    final nativeBridge = ref.read(nativeBridgeServiceProvider);
    _blockEventSub = nativeBridge.appBlockedEvents.listen((event) async {
      if (event == 'ADMIN_DISABLE_REQUESTED' || event == 'FORCED_UNINSTALL_ATTEMPT') {
        _showAdminDisableWarningDialog();
      } else if (event.startsWith('EMERGENCY_TICKET_USED:')) {
        final parts = event.split(':');
        if (parts.length >= 3) {
          final quotaId = parts[1];
          final durationMinutes = int.tryParse(parts[2]) ?? 5;
          final storage = ref.read(storageServiceProvider);
          await storage.useEmergencyTicket(quotaId, durationMinutes);
          _initData();
        }
      } else if (event.startsWith('QUOTA_USAGE:')) {
        final parts = event.split(':');
        if (parts.length >= 3) {
          final packageName = parts[1];
          final seconds = int.tryParse(parts[2]) ?? 0;
          final storage = ref.read(storageServiceProvider);
          await storage.addQuotaUsage(packageName, seconds);
          _initData();
        }
      } else if (event.startsWith('FORCED_OPEN:') || event.startsWith('BLOCKED:') || event.startsWith('ATTEMPT:')) {
        final packageName = event.split(':').last.trim();
        await _handleBlockedAppAttempt(packageName);
      } else if (event.isNotEmpty && event.contains('.')) {
        final packageName = event.trim();
        await _handleBlockedAppAttempt(packageName);
      }
    });
  }

  Future<void> _handleBlockedAppAttempt(String packageName) async {
    try {
      final api = ref.read(apiServiceProvider);
      if (await api.isLoggedIn()) {
        final res = await api.reportForcedOpen(packageName);
        if (res['tolerance_exceeded'] == true) {
          final storage = ref.read(storageServiceProvider);
          await storage.saveStreakDays(0);
          if (mounted) {
            setState(() {
              _streakDays = 0;
            });
          }
          await ref.read(authStateProvider.notifier).refreshProfile();
        }
      }
    } catch (_) {}
  }

  void _showAdminDisableWarningDialog() {
    if (!mounted || _isWarningDialogShowing) return;
    _isWarningDialogShowing = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: JedaColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: JedaRadii.sheetTop),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: JedaColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const JedaBadge(
                  label: 'Proteksi Bodyguard Aktif',
                  variant: JedaBadgeVariant.warning,
                  icon: Icons.shield_outlined,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Upaya Penonaktifan Dicegah',
                  style: JedaTypography.heading2,
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: JedaColors.surfaceSecondary,
                    borderRadius: JedaRadii.borderR12,
                    border: Border.all(color: JedaColors.border),
                  ),
                  child: Text(
                    'Anda baru saja mencoba mencabut izin Administrator Perangkat dari Setelan Android.\n\n'
                    'Mode Bodyguard bertugas menghentikan refleks impulsif saat dorongan membuka aplikasi sangat kuat. '
                    'Bila Anda ingin mencopot Jeda secara sadar dan resmi, gunakan menu Pengaturan di dalam aplikasi Jeda.',
                    style: JedaTypography.bodySecondary.copyWith(
                      color: JedaColors.textPrimary,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                JedaButton(
                  label: 'Saya Mengerti & Kembali Fokus',
                  onPressed: () => Navigator.pop(ctx),
                  variant: JedaButtonVariant.primary,
                ),
                const SizedBox(height: 10),
                JedaButton(
                  label: 'Buka Prosedur Pencopotan Resmi',
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const UninstallFrictionScreen(),
                      ),
                    );
                  },
                  variant: JedaButtonVariant.ghost,
                ),
              ],
            ),
          ),
        );
      },
    ).then((_) {
      _isWarningDialogShowing = false;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _initData();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _countdownTimer?.cancel();
      _countdownTimer = null;
    }
  }

  void _loadLocalDataSync() {
    final storage = ref.read(storageServiceProvider);
    _activeLocks = storage.getActiveLocksSync();
    _quotas = storage.getAllQuotasSync();
    _hoursSaved = storage.getTotalHoursSavedSync();
    _streakDays = storage.getStreakDaysSync();
  }

  Future<void> _initData() async {
    final storage = ref.read(storageServiceProvider);
    await storage.cleanExpiredLocks();

    try {
      final nativeBridge = ref.read(nativeBridgeServiceProvider);
      final nativeUsage = await nativeBridge.getNativeQuotaUsage();
      if (nativeUsage.isNotEmpty) {
        await storage.syncNativeQuotaUsage(nativeUsage);
      }
    } catch (_) {}
    
    final active = await storage.getActiveLocks();
    final quotaList = await storage.getAllQuotas();
    final hours = await storage.getTotalHoursSaved();
    int streak = await storage.getStreakDays();

    // Update UI immediately with fresh local storage data (Frame 0/1)
    if (mounted) {
      setState(() {
        _activeLocks = active;
        _quotas = quotaList;
        _hoursSaved = hours;
        _streakDays = streak;
      });
      _updateCountdownTimer();
    }

    // Immediately sync local rules to Android Native so blocking never waits on network latency
    final rules = storage.getActiveRules();
    if (rules.isNotEmpty) {
      await ref.read(nativeBridgeServiceProvider).startMonitoring(rules);
      await ref.read(nativeBridgeServiceProvider).updateBlockedList(rules);
    }

    // Remote sync in background without blocking local UI presentation
    final api = ref.read(apiServiceProvider);
    if (await api.isLoggedIn()) {
      try {
        final profile = await api.getMe();
        if (profile != null && profile.currentStreakDays != streak) {
          streak = profile.currentStreakDays;
          await storage.saveStreakDays(profile.currentStreakDays);
          if (mounted) {
            setState(() {
              _streakDays = streak;
            });
          }
        }
      } catch (_) {}
    }

    if (await api.isLoggedIn() && active.isNotEmpty) {
      final lockDataList = active.map((l) => {
        'id': l.id,
        'package_name': l.packageName,
        'app_name': l.appName,
        'lock_type': l.isScheduled ? 'scheduled' : 'direct',
        'start_time': l.startTime.toIso8601String(),
        'duration_hours': l.durationHours,
        'is_active': l.isActive,
      }).toList();
      api.syncLocks(lockDataList);
    }

    bool addedChallengeRules = false;
    try {
      if (await api.isLoggedIn()) {
        final myChallenges = await api.getMyChallenges();
        for (final ch in myChallenges) {
          if (ch.status == 'active' && ch.myStatus != 'invited' && ch.myStatus != 'declined' && ch.myStatus != 'surrendered') {
            final endMillis = ch.endTime?.millisecondsSinceEpoch ?? DateTime.now().add(Duration(hours: ch.durationHours)).millisecondsSinceEpoch;
            final alreadyBlocked = rules.any((r) => r['packageName'] == ch.packageName);
            if (!alreadyBlocked && DateTime.now().millisecondsSinceEpoch < endMillis) {
              rules.add({
                'packageName': ch.packageName,
                'isScheduled': false,
                'endTimeMillis': endMillis,
                'isChallenge': true,
                'challengeId': ch.id,
              });
              addedChallengeRules = true;
            }
          }
        }
      }
    } catch (_) {}

    if (rules.isNotEmpty) {
      if (addedChallengeRules) {
        await ref.read(nativeBridgeServiceProvider).startMonitoring(rules);
        await ref.read(nativeBridgeServiceProvider).updateBlockedList(rules);
      }
    } else {
      try { await ref.read(nativeBridgeServiceProvider).stopMonitoring(); } catch (_) {}
    }
  }

  void _updateCountdownTimer() {
    final hasActiveCountdowns = _activeLocks.any((l) => l.isActive && !l.isScheduled);
    if (hasActiveCountdowns) {
      if (_countdownTimer == null || !_countdownTimer!.isActive) {
        _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (!mounted) {
            timer.cancel();
            _countdownTimer = null;
            return;
          }
          final stillHasActive = _activeLocks.any((l) => l.isActive && !l.isScheduled);
          if (!stillHasActive) {
            timer.cancel();
            _countdownTimer = null;
          }
          setState(() {});
        });
      }
    } else {
      _countdownTimer?.cancel();
      _countdownTimer = null;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _countdownTimer?.cancel();
    _blockEventSub?.cancel();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    if (duration.isNegative) return "00:00:00";
    if (duration.inDays > 0) {
      int remainingDays = duration.inDays;
      final months = remainingDays ~/ 30;
      remainingDays %= 30;
      final weeks = remainingDays ~/ 7;
      final days = remainingDays % 7;
      final hours = duration.inHours.remainder(24);

      final parts = <String>[];
      if (months > 0) parts.add("$months bln");
      if (weeks > 0) parts.add("$weeks mgg");
      if (days > 0) parts.add("$days hr");
      if (hours > 0 && months == 0) parts.add("$hours jam");
      return parts.isEmpty ? "0 jam" : parts.join(" ");
    }
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    return "${twoDigits(duration.inHours)}:${twoDigits(duration.inMinutes.remainder(60))}:${twoDigits(duration.inSeconds.remainder(60))}";
  }

  String _formatTotalDetoxHours(int totalHours) {
    int remaining = totalHours;
    final months = remaining ~/ (30 * 24);
    remaining %= (30 * 24);
    final weeks = remaining ~/ (7 * 24);
    remaining %= (7 * 24);
    final days = remaining ~/ 24;
    final hours = remaining % 24;

    final parts = <String>[];
    if (months > 0) parts.add('$months Bulan');
    if (weeks > 0) parts.add('$weeks Minggu');
    if (days > 0) parts.add('$days Hari');
    if (hours > 0) parts.add('$hours Jam');
    if (parts.isEmpty) return '$totalHours Jam';
    return parts.join(' ');
  }

  String _formatSecondsToMinutes(int seconds) {
    final mins = seconds ~/ 60;
    return "$mins mnt";
  }

  void _showAddOptionModal() {
    JedaBottomSheet.show(
      context: context,
      title: 'Pilih Mode Pembatasan',
      subtitle: 'Tentukan bagaimana Anda ingin mengelola waktu layar hari ini.',
      child: Column(
        children: [
          _buildModeOptionTile(
            title: 'Kuota Harian (Budget Waktu)',
            desc: 'Bebas membuka aplikasi terpilih sampai jatah menit harian tercapai.',
            icon: Icons.timelapse_outlined,
            onTap: () async {
              Navigator.pop(context);
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const AddQuotaScreen()),
              );
              _initData();
            },
          ),
          const SizedBox(height: 12),
          _buildModeOptionTile(
            title: 'Detoks Penuh & Jadwal Rutin',
            desc: 'Kunci langsung dengan durasi penuh atau jadwalkan di jam-jam tertentu.',
            icon: Icons.shield_outlined,
            onTap: () async {
              Navigator.pop(context);
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const AddLockScreen()),
              );
              _initData();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildModeOptionTile({
    required String title,
    required String desc,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return JedaCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: JedaColors.primarySoft,
              borderRadius: JedaRadii.borderR12,
            ),
            child: Icon(icon, color: JedaColors.primaryDark, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: JedaTypography.labelBold),
                const SizedBox(height: 4),
                Text(desc, style: JedaTypography.caption.copyWith(color: JedaColors.textSecondary, height: 1.35)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: JedaColors.textTertiary, size: 20),
        ],
      ),
    );
  }

  String _formatDaysToText(List<int> days) {
    if (days.isEmpty) return 'Tidak ada hari dipilih';
    final sorted = List<int>.from(days)..sort();
    if (sorted.length == 7) return 'Setiap Hari';
    if (sorted.length == 5 && sorted.every((d) => d >= 1 && d <= 5)) {
      return 'Senin - Jumat (Hari Kerja)';
    }
    if (sorted.length == 2 && sorted.contains(6) && sorted.contains(7)) {
      return 'Sabtu - Minggu (Akhir Pekan)';
    }
    const dayMap = {
      1: 'Senin',
      2: 'Selasa',
      3: 'Rabu',
      4: 'Kamis',
      5: 'Jumat',
      6: 'Sabtu',
      7: 'Minggu',
    };
    return sorted.map((d) => dayMap[d] ?? '$d').join(', ');
  }

  Widget _buildDetailRow({
    required String label,
    required String value,
    required IconData icon,
    Color? valueColor,
    bool isBold = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              Icon(icon, size: 16, color: JedaColors.textSecondary),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  style: JedaTypography.bodySecondary,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: isBold
                ? JedaTypography.labelBold.copyWith(color: valueColor ?? JedaColors.textPrimary)
                : JedaTypography.body.copyWith(color: valueColor ?? JedaColors.textPrimary),
          ),
        ),
      ],
    );
  }

  String _formatDeletionCooldown(Duration d) {
    final days = d.inDays;
    final hours = d.inHours % 24;
    final mins = d.inMinutes % 60;
    if (days > 0) {
      return '$days Hari $hours Jam';
    }
    if (hours > 0) {
      return '$hours Jam $mins Menit';
    }
    return '${mins.clamp(1, 59)} Menit';
  }

  Widget _buildPsychologicalGoalSection({
    required String? focusGoal,
    required String? description,
    required VoidCallback onEditTap,
  }) {
    final hasGoal = focusGoal != null && focusGoal.trim().isNotEmpty;
    final hasDesc = description != null && description.trim().isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: JedaColors.primarySoft.withValues(alpha: 0.55),
        borderRadius: JedaRadii.borderR12,
        border: Border.all(color: JedaColors.primary.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.psychology_outlined, size: 18, color: JedaColors.primaryDark),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Jangkar Psikologis & Tujuan Fokus',
                  style: JedaTypography.caption.copyWith(
                    color: JedaColors.primaryDark,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              InkWell(
                onTap: onEditTap,
                borderRadius: JedaRadii.borderR8,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Text(
                    'Ubah',
                    style: JedaTypography.caption.copyWith(
                      color: JedaColors.primaryDark,
                      fontWeight: FontWeight.w700,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            hasGoal ? '🎯 ${focusGoal.trim()}' : '🎯 Menjaga kendali diri & ketenangan pikiran',
            style: JedaTypography.labelBold.copyWith(color: JedaColors.textPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            hasDesc
                ? '“${description.trim()}”'
                : '“Setiap kali kamu menahan impuls membuka aplikasi ini, kamu sedang memperkuat otot fokus dan ketenangan pikiranmu.”',
            style: JedaTypography.caption.copyWith(
              color: JedaColors.textSecondary,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openEditLock(LockEntry lock, BuildContext sheetCtx) async {
    if (sheetCtx.mounted) {
      Navigator.pop(sheetCtx);
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddLockScreen(editingLock: lock),
      ),
    );
    _initData();
  }

  Future<void> _openEditQuota(QuotaEntry quota, BuildContext sheetCtx) async {
    if (sheetCtx.mounted) {
      Navigator.pop(sheetCtx);
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddQuotaScreen(editingQuota: quota),
      ),
    );
    _initData();
  }

  void _showLockDetailModal(LockEntry lock) {
    final isScheduled = lock.isScheduled;
    final isCurrentlyBlocking = lock.isCurrentlyBlocking;
    final intervals = lock.allIntervals;
    final storage = ref.read(storageServiceProvider);
    final canDeleteNow = storage.canDeleteLockNow();
    final remainingCooldown = storage.getRemainingDeletionCooldown();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: JedaColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: JedaRadii.sheetTop),
      builder: (ctx) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: JedaColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  children: [
                    AppIconWidget(
                      packageName: lock.packageName,
                      size: 54,
                      borderRadius: JedaRadii.borderR16,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            lock.appName,
                            style: JedaTypography.heading3.copyWith(fontSize: 18),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            lock.packageName,
                            style: JedaTypography.caption.copyWith(color: JedaColors.textTertiary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => _openEditLock(lock, ctx),
                      icon: const Icon(Icons.edit_outlined, color: JedaColors.primaryDark),
                      tooltip: 'Edit Penguncian',
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    JedaBadge(
                      label: isScheduled ? 'Jadwal Jam (1–24)' : 'Detoks Penuh',
                      variant: JedaBadgeVariant.neutral,
                      icon: isScheduled ? Icons.calendar_today_outlined : Icons.timer_outlined,
                    ),
                    if (isScheduled)
                      JedaBadge(
                        label: isCurrentlyBlocking ? 'Aktif Memblokir Sekarang' : 'Di Luar Jam Jadwal',
                        variant: isCurrentlyBlocking ? JedaBadgeVariant.success : JedaBadgeVariant.neutral,
                        icon: isCurrentlyBlocking ? Icons.lock_outline : Icons.schedule_outlined,
                      )
                    else
                      JedaBadge(
                        label: !lock.isExpired ? 'Fokus Berjalan' : 'Selesai',
                        variant: !lock.isExpired ? JedaBadgeVariant.success : JedaBadgeVariant.neutral,
                        icon: !lock.isExpired ? Icons.lock_outline : Icons.check_circle_outline,
                      ),
                  ],
                ),
                const SizedBox(height: 16),

                // Psychological Goal & Reflection Note Section
                _buildPsychologicalGoalSection(
                  focusGoal: lock.focusGoal,
                  description: lock.description,
                  onEditTap: () => _openEditLock(lock, ctx),
                ),

                const SizedBox(height: 16),
                if (!isScheduled) ...[
                  JedaCard(
                    backgroundColor: JedaColors.surfaceSecondary,
                    borderColor: JedaColors.border,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _buildDetailRow(
                          label: 'Total Durasi Fokus',
                          value: _formatTotalDetoxHours(lock.durationHours),
                          icon: Icons.hourglass_top_outlined,
                        ),
                        const Divider(height: 20, color: JedaColors.border),
                        _buildDetailRow(
                          label: 'Dimulai Pada',
                          value: DateFormat('d MMM yyyy, HH:mm').format(lock.startTime),
                          icon: Icons.play_circle_outline,
                        ),
                        const Divider(height: 20, color: JedaColors.border),
                        _buildDetailRow(
                          label: 'Berakhir Pada',
                          value: DateFormat('d MMM yyyy, HH:mm').format(lock.endTime),
                          icon: Icons.flag_outlined,
                        ),
                        const Divider(height: 20, color: JedaColors.border),
                        _buildDetailRow(
                          label: 'Sisa Waktu',
                          value: _formatDuration(lock.remaining),
                          icon: Icons.alarm,
                          valueColor: JedaColors.primaryDark,
                          isBold: true,
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  Text(
                    'Rincian Interval Jadwal (${intervals.length})',
                    style: JedaTypography.labelBold,
                  ),
                  const SizedBox(height: 10),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: intervals.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, idx) {
                      final interval = intervals[idx];
                      final isIntervalActive = interval.isCurrentlyActive();
                      final dayNames = _formatDaysToText(interval.days);

                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: isIntervalActive ? JedaColors.primarySoft : JedaColors.surfaceSecondary,
                          borderRadius: JedaRadii.borderR12,
                          border: Border.all(
                            color: isIntervalActive ? JedaColors.primary : JedaColors.border,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isIntervalActive ? Icons.lock_clock : Icons.access_time_rounded,
                              color: isIntervalActive ? JedaColors.primaryDark : JedaColors.textSecondary,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${interval.start} - ${interval.end}',
                                    style: JedaTypography.labelBold.copyWith(
                                      color: isIntervalActive ? JedaColors.primaryDark : JedaColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    dayNames,
                                    style: JedaTypography.caption.copyWith(
                                      color: isIntervalActive ? JedaColors.primaryDark : JedaColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isIntervalActive)
                              const JedaBadge(
                                label: 'Aktif',
                                variant: JedaBadgeVariant.success,
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: canDeleteNow
                        ? JedaColors.surfaceSecondary.withValues(alpha: 0.7)
                        : JedaColors.warningSoft.withValues(alpha: 0.65),
                    borderRadius: JedaRadii.borderR12,
                    border: Border.all(
                      color: canDeleteNow ? JedaColors.border : const Color(0xFFE8D3B4),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        canDeleteNow ? Icons.shield_outlined : Icons.lock_clock_outlined,
                        size: 18,
                        color: canDeleteNow ? JedaColors.primary : JedaColors.warning,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          canDeleteNow
                              ? 'Aturan Komitmen Jeda: Kamu hanya dapat menghapus maksimal 1 penguncian setiap 4 hari.'
                              : 'Kuota hapus sedang terkunci demi menjaga komitmenmu. Tersedia kembali dalam ${_formatDeletionCooldown(remainingCooldown)}.',
                          style: JedaTypography.caption.copyWith(
                            color: canDeleteNow ? JedaColors.textSecondary : JedaColors.warning,
                            fontWeight: canDeleteNow ? FontWeight.normal : FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: JedaButton(
                        label: 'Edit',
                        icon: Icons.edit_outlined,
                        variant: JedaButtonVariant.secondary,
                        onPressed: () => _openEditLock(lock, ctx),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: JedaButton(
                        label: canDeleteNow ? 'Hapus' : 'Terkunci',
                        icon: Icons.delete_outline_rounded,
                        variant: JedaButtonVariant.destructive,
                        onPressed: () => _confirmDeleteLock(lock, ctx),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showDeletionCooldownBlockedModal({
    required String itemName,
    required String? focusGoal,
    required Duration remainingCooldown,
    required VoidCallback onEditInstead,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: JedaColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: JedaRadii.sheetTop),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: JedaColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    color: JedaColors.warningSoft,
                    borderRadius: JedaRadii.borderR12,
                  ),
                  child: const Icon(Icons.psychology_alt_outlined, color: JedaColors.warning, size: 26),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Jeda Melindungi Komitmen Fokusmu 🌱',
                  style: JedaTypography.heading3,
                ),
                const SizedBox(height: 8),
                Text(
                  'Kamu sudah menggunakan jatah hapus penguncian dalam 4 hari terakhir. Untuk mencegah pembatalan impulsif saat otak mencari dopamin cepat, Jeda hanya mengizinkan 1 penghapusan setiap 4 hari.',
                  style: JedaTypography.bodySecondary.copyWith(height: 1.5),
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: JedaColors.surfaceSecondary,
                    borderRadius: JedaRadii.borderR12,
                    border: Border.all(color: JedaColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.hourglass_bottom_rounded, size: 16, color: JedaColors.warning),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Kuota hapus berikutnya: ${_formatDeletionCooldown(remainingCooldown)} lagi',
                              style: JedaTypography.labelBold.copyWith(color: JedaColors.warning),
                            ),
                          ),
                        ],
                      ),
                      if (focusGoal != null && focusGoal.trim().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Ingat tujuan awalmu mengunci $itemName:\n“${focusGoal.trim()}”',
                          style: JedaTypography.caption.copyWith(
                            color: JedaColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: JedaButton(
                        label: 'Edit Aturan',
                        variant: JedaButtonVariant.secondary,
                        onPressed: () {
                          Navigator.pop(ctx);
                          onEditInstead();
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: JedaButton(
                        label: 'Tetap Fokus 🌱',
                        variant: JedaButtonVariant.primary,
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmDeleteLock(LockEntry lock, BuildContext sheetCtx) async {
    final storage = ref.read(storageServiceProvider);
    if (!storage.canDeleteLockNow()) {
      final remaining = storage.getRemainingDeletionCooldown();
      await _showDeletionCooldownBlockedModal(
        itemName: lock.appName,
        focusGoal: lock.focusGoal,
        remainingCooldown: remaining,
        onEditInstead: () => _openEditLock(lock, sheetCtx),
      );
      return;
    }

    final goalInfo = (lock.focusGoal != null && lock.focusGoal!.trim().isNotEmpty)
        ? '\n\n🎯 Tujuan awalmu: "${lock.focusGoal!.trim()}"'
        : '';

    final confirmed = await JedaBottomSheet.showConfirmation(
      context: context,
      title: 'Gunakan Kuota Hapus (1x / 4 Hari)?',
      message:
          'Kamu hanya diperbolehkan menghapus 1 penguncian dalam rentang 4 hari. Jika kamu menghapus "${lock.appName}" sekarang, kamu tidak dapat menghapus penguncian aplikasi lain selama 4 hari ke depan.$goalInfo',
      confirmLabel: 'Ya, Hapus',
      cancelLabel: 'Tetap Fokus',
      isDestructive: true,
      icon: Icons.psychology_outlined,
    );

    if (confirmed == true && mounted) {
      final nativeBridge = ref.read(nativeBridgeServiceProvider);

      await storage.removeLock(lock.id);
      await storage.recordLockDeletion();
      final activeRules = storage.getActiveRules();
      await nativeBridge.updateBlockedList(activeRules);

      if (sheetCtx.mounted) {
        Navigator.pop(sheetCtx);
      }

      _loadLocalDataSync();
      setState(() {});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Penguncian "${lock.appName}" dihapus. Kuota hapus berikutnya tersedia dalam 4 hari.',
            ),
            backgroundColor: JedaColors.primaryDark,
          ),
        );
      }
    }
  }

  void _showQuotaDetailModal(QuotaEntry quota) {
    final usedMinutes = quota.usedTodaySeconds ~/ 60;
    final remainingMinutes = quota.remainingSeconds ~/ 60;
    final isExhausted = quota.isQuotaExhausted;
    final isEmergency = quota.isEmergencyActive;
    final storage = ref.read(storageServiceProvider);
    final canDeleteNow = storage.canDeleteLockNow();
    final remainingCooldown = storage.getRemainingDeletionCooldown();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: JedaColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: JedaRadii.sheetTop),
      builder: (ctx) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: JedaColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  children: [
                    if (quota.packageNames.isNotEmpty)
                      AppIconWidget(
                        packageName: quota.packageNames.first,
                        size: 54,
                        borderRadius: JedaRadii.borderR16,
                      ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(quota.groupName, style: JedaTypography.heading3.copyWith(fontSize: 18)),
                          const SizedBox(height: 2),
                          Text(
                            '${quota.packageNames.length} aplikasi terdaftar',
                            style: JedaTypography.caption.copyWith(color: JedaColors.textTertiary),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => _openEditQuota(quota, ctx),
                      icon: const Icon(Icons.edit_outlined, color: JedaColors.primaryDark),
                      tooltip: 'Edit Kuota',
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    const JedaBadge(
                      label: 'Kuota Waktu Harian',
                      variant: JedaBadgeVariant.neutral,
                      icon: Icons.timelapse_outlined,
                    ),
                    if (isEmergency)
                      const JedaBadge(label: 'Darurat Aktif (5m)', variant: JedaBadgeVariant.warning)
                    else if (isExhausted)
                      const JedaBadge(label: 'Kuota Habis', variant: JedaBadgeVariant.error, icon: Icons.lock_outline)
                    else
                      JedaBadge(label: '$remainingMinutes mnt tersisa', variant: JedaBadgeVariant.success),
                  ],
                ),
                const SizedBox(height: 16),

                // Psychological Goal & Reflection Note Section
                _buildPsychologicalGoalSection(
                  focusGoal: quota.focusGoal,
                  description: quota.description,
                  onEditTap: () => _openEditQuota(quota, ctx),
                ),

                const SizedBox(height: 16),
                JedaCard(
                  backgroundColor: JedaColors.surfaceSecondary,
                  borderColor: JedaColors.border,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildDetailRow(
                        label: 'Jatah Kuota Harian',
                        value: '${quota.dailyQuotaMinutes} Menit',
                        icon: Icons.timer_outlined,
                      ),
                      const Divider(height: 20, color: JedaColors.border),
                      _buildDetailRow(
                        label: 'Terpakai Hari Ini',
                        value: '$usedMinutes Menit',
                        icon: Icons.history,
                      ),
                      const Divider(height: 20, color: JedaColors.border),
                      _buildDetailRow(
                        label: 'Sisa Waktu',
                        value: '$remainingMinutes Menit',
                        icon: Icons.alarm,
                        valueColor: isExhausted ? JedaColors.error : JedaColors.primaryDark,
                        isBold: true,
                      ),
                      const Divider(height: 20, color: JedaColors.border),
                      _buildDetailRow(
                        label: 'Tiket Darurat Mingguan',
                        value: '${quota.emergencyTickets}/2 Tersedia',
                        icon: Icons.confirmation_number_outlined,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Aplikasi Dalam Grup Ini:', style: JedaTypography.labelBold),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(quota.packageNames.length, (i) {
                    final pkg = quota.packageNames[i];
                    final name = i < quota.appNames.length ? quota.appNames[i] : pkg;
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: JedaColors.surfaceSecondary,
                        borderRadius: JedaRadii.borderR8,
                        border: Border.all(color: JedaColors.border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AppIconWidget(packageName: pkg, size: 20, borderRadius: JedaRadii.borderR8),
                          const SizedBox(width: 8),
                          Text(name, style: JedaTypography.caption.copyWith(fontWeight: FontWeight.w600)),
                        ],
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: canDeleteNow
                        ? JedaColors.surfaceSecondary.withValues(alpha: 0.7)
                        : JedaColors.warningSoft.withValues(alpha: 0.65),
                    borderRadius: JedaRadii.borderR12,
                    border: Border.all(
                      color: canDeleteNow ? JedaColors.border : const Color(0xFFE8D3B4),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        canDeleteNow ? Icons.shield_outlined : Icons.lock_clock_outlined,
                        size: 18,
                        color: canDeleteNow ? JedaColors.primary : JedaColors.warning,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          canDeleteNow
                              ? 'Aturan Komitmen Jeda: Kamu hanya dapat menghapus maksimal 1 aturan setiap 4 hari.'
                              : 'Kuota hapus sedang terkunci demi menjaga komitmenmu. Tersedia kembali dalam ${_formatDeletionCooldown(remainingCooldown)}.',
                          style: JedaTypography.caption.copyWith(
                            color: canDeleteNow ? JedaColors.textSecondary : JedaColors.warning,
                            fontWeight: canDeleteNow ? FontWeight.normal : FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: JedaButton(
                        label: 'Edit',
                        icon: Icons.edit_outlined,
                        variant: JedaButtonVariant.secondary,
                        onPressed: () => _openEditQuota(quota, ctx),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: JedaButton(
                        label: canDeleteNow ? 'Hapus' : 'Terkunci',
                        icon: Icons.delete_outline_rounded,
                        variant: JedaButtonVariant.destructive,
                        onPressed: () => _confirmDeleteQuota(quota, ctx),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmDeleteQuota(QuotaEntry quota, BuildContext sheetCtx) async {
    final storage = ref.read(storageServiceProvider);
    if (!storage.canDeleteLockNow()) {
      final remaining = storage.getRemainingDeletionCooldown();
      await _showDeletionCooldownBlockedModal(
        itemName: quota.groupName,
        focusGoal: quota.focusGoal,
        remainingCooldown: remaining,
        onEditInstead: () => _openEditQuota(quota, sheetCtx),
      );
      return;
    }

    final goalInfo = (quota.focusGoal != null && quota.focusGoal!.trim().isNotEmpty)
        ? '\n\n🎯 Tujuan awalmu: "${quota.focusGoal!.trim()}"'
        : '';

    final confirmed = await JedaBottomSheet.showConfirmation(
      context: context,
      title: 'Gunakan Kuota Hapus (1x / 4 Hari)?',
      message:
          'Kamu hanya diperbolehkan menghapus 1 penguncian dalam rentang 4 hari. Jika kamu menghapus grup kuota "${quota.groupName}" sekarang, kamu tidak dapat menghapus penguncian lain selama 4 hari ke depan.$goalInfo',
      confirmLabel: 'Ya, Hapus',
      cancelLabel: 'Tetap Fokus',
      isDestructive: true,
      icon: Icons.psychology_outlined,
    );

    if (confirmed == true && mounted) {
      final nativeBridge = ref.read(nativeBridgeServiceProvider);

      await storage.removeQuota(quota.id);
      await storage.recordLockDeletion();
      final activeRules = storage.getActiveRules();
      await nativeBridge.updateBlockedList(activeRules);

      if (sheetCtx.mounted) {
        Navigator.pop(sheetCtx);
      }

      _loadLocalDataSync();
      setState(() {});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Grup kuota "${quota.groupName}" dihapus. Kuota hapus berikutnya tersedia dalam 4 hari.',
            ),
            backgroundColor: JedaColors.primaryDark,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final displayStreak = authState.value?.currentStreakDays ?? _streakDays;

    final activelyBlockingLocks = _activeLocks.where((l) => l.isCurrentlyBlocking).toList();
    final exhaustedQuotas = _quotas.where((q) => q.isCurrentlyBlocking).toList();
    final isAnyAppActivelyBlocked = activelyBlockingLocks.isNotEmpty || exhaustedQuotas.isNotEmpty;

    return Scaffold(
      backgroundColor: JedaColors.background,
      appBar: AppBar(
        title: const Text('Jeda', style: JedaTypography.heading2),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: JedaColors.textPrimary),
            tooltip: 'Tambah Pembatasan',
            onPressed: _showAddOptionModal,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _initData,
        color: JedaColors.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: JedaSpacing.screenPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. HERO STATUS CARD (Fokus visual utama)
              _buildHeroStatus(isAnyAppActivelyBlocked, activelyBlockingLocks, exhaustedQuotas),

              const SizedBox(height: 20),

              // 2. RINGKASAN PROGRES (Metrik yang tenang & berguna)
              _buildProgressSummary(displayStreak),

              const SizedBox(height: 28),

              // 3. SECTION: KUOTA HARIAN
              if (_quotas.isNotEmpty) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Kuota Waktu Harian', style: JedaTypography.heading3),
                    Text('${_quotas.length} grup', style: JedaTypography.caption),
                  ],
                ),
                const SizedBox(height: 12),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _quotas.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) => _buildQuotaCard(_quotas[index]),
                ),
                const SizedBox(height: 28),
              ],

              // 4. SECTION: DETOKS PENUH & JADWAL
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Detoks & Jadwal Rutin', style: JedaTypography.heading3),
                  if (_activeLocks.isNotEmpty)
                    Text('${_activeLocks.length} aturan', style: JedaTypography.caption),
                ],
              ),
              const SizedBox(height: 12),
              if (_activeLocks.isEmpty)
                _buildEmptyStateCard()
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _activeLocks.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) => _buildLockCard(_activeLocks[index]),
                ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroStatus(
    bool isBlocking,
    List<LockEntry> blockingLocks,
    List<QuotaEntry> exhaustedQuotas,
  ) {
    if (!isBlocking) {
      return JedaCard(
        backgroundColor: JedaColors.surfaceSecondary,
        borderColor: JedaColors.border,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                JedaBadge(
                  label: 'Kondisi Tenang',
                  variant: JedaBadgeVariant.neutral,
                  icon: Icons.check_circle_outline,
                ),
                Icon(Icons.spa_outlined, color: JedaColors.primary, size: 20),
              ],
            ),
            const SizedBox(height: 14),
            const Text(
              'Tidak ada aplikasi yang sedang diblokir.',
              style: JedaTypography.heading3,
            ),
            const SizedBox(height: 6),
            const Text(
              'Pikiran Anda bebas. Buat pembatasan saat Anda ingin melindungi waktu kerja atau istirahat.',
              style: JedaTypography.bodySecondary,
            ),
            const SizedBox(height: 18),
            JedaButton(
              label: 'Mulai Pembatasan Baru',
              onPressed: _showAddOptionModal,
              variant: JedaButtonVariant.primary,
              height: 44,
              icon: Icons.add,
            ),
          ],
        ),
      );
    }

    final blockedNames = <String>[];
    for (var l in blockingLocks) {
      blockedNames.add(l.appName);
    }
    for (var q in exhaustedQuotas) {
      blockedNames.addAll(q.appNames);
    }
    final summaryApps = blockedNames.toSet().take(3).join(', ');

    return JedaCard(
      backgroundColor: JedaColors.primarySoft,
      borderColor: const Color(0xFFC7DAC9),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const JedaBadge(
                label: 'Pembatasan Sedang Berjalan',
                variant: JedaBadgeVariant.success,
                icon: Icons.lock_clock,
              ),
              Text(
                '${blockedNames.toSet().length} aplikasi',
                style: JedaTypography.caption.copyWith(color: JedaColors.primaryDark),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            summaryApps.isNotEmpty ? 'Menjaga jarak dari $summaryApps' : 'Sesi Fokus Terlindungi',
            style: JedaTypography.heading3.copyWith(color: JedaColors.primaryDark),
          ),
          const SizedBox(height: 6),
          Text(
            'Layar jeda akan muncul jika aplikasi terkait dibuka untuk mengembalikan fokus Anda.',
            style: JedaTypography.bodySecondary.copyWith(color: JedaColors.primaryDark.withValues(alpha: 0.8)),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressSummary(int streak) {
    return JedaCard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$_hoursSaved jam',
                  style: JedaTypography.heading2.copyWith(color: JedaColors.primaryDark),
                ),
                const SizedBox(height: 2),
                const Text('Waktu terselamatkan', style: JedaTypography.caption),
              ],
            ),
          ),
          Container(width: 1, height: 36, color: JedaColors.border),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$streak hari',
                  style: JedaTypography.heading2.copyWith(color: JedaColors.primaryDark),
                ),
                const SizedBox(height: 2),
                const Text('Komitmen beruntun', style: JedaTypography.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuotaCard(QuotaEntry quota) {
    final totalSec = quota.dailyQuotaMinutes * 60;
    final progress = (quota.usedTodaySeconds / totalSec).clamp(0.0, 1.0);
    final isExhausted = quota.isQuotaExhausted;
    final isEmergency = quota.isEmergencyActive;

    return JedaCard(
      onTap: () => _showQuotaDetailModal(quota),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (quota.packageNames.isNotEmpty) ...[
                AppIconWidget(
                  packageName: quota.packageNames.first,
                  size: 32,
                  borderRadius: JedaRadii.borderR8,
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(quota.groupName, style: JedaTypography.labelBold),
              ),
              if (isEmergency)
                const JedaBadge(
                  label: 'Darurat Aktif (5m)',
                  variant: JedaBadgeVariant.warning,
                )
              else if (isExhausted)
                const JedaBadge(
                  label: 'Kuota Habis',
                  variant: JedaBadgeVariant.error,
                  icon: Icons.lock_outline,
                )
              else
                JedaBadge(
                  label: '${_formatSecondsToMinutes(quota.remainingSeconds)} tersisa',
                  variant: JedaBadgeVariant.neutral,
                ),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right, size: 18, color: JedaColors.textTertiary),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: JedaColors.surfaceSecondary,
              valueColor: AlwaysStoppedAnimation<Color>(
                isExhausted ? JedaColors.error : JedaColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  quota.appNames.join(', '),
                  style: JedaTypography.caption,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${quota.emergencyTickets}/2 Tiket Darurat',
                style: JedaTypography.caption.copyWith(color: JedaColors.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLockCard(LockEntry lock) {
    final isScheduled = lock.isScheduled;
    final isCurrentlyActive = lock.isCurrentlyBlocking;

    return JedaCard(
      onTap: () => _showLockDetailModal(lock),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          AppIconWidget(
            packageName: lock.packageName,
            size: 40,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(lock.appName, style: JedaTypography.labelBold),
                const SizedBox(height: 2),
                Text(
                  isScheduled
                      ? 'Jadwal: ${lock.schedulePreviewText}'
                      : 'Detoks sisa: ${_formatDuration(lock.remaining)}',
                  style: JedaTypography.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (lock.focusGoal != null && lock.focusGoal!.trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    '🎯 ${lock.focusGoal!.trim()}',
                    style: JedaTypography.caption.copyWith(
                      fontSize: 11,
                      color: JedaColors.primaryDark,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (isScheduled) ...[
            JedaBadge(
              label: isCurrentlyActive ? 'Aktif Sekarang' : 'Terjadwal',
              variant: isCurrentlyActive ? JedaBadgeVariant.success : JedaBadgeVariant.neutral,
            ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right, size: 18, color: JedaColors.textTertiary),
          ] else ...[
            Text(
              _formatDuration(lock.remaining),
              style: JedaTypography.labelBold.copyWith(color: JedaColors.primaryDark),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right, size: 18, color: JedaColors.textTertiary),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyStateCard() {
    return JedaCard(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      backgroundColor: JedaColors.surfaceSecondary,
      borderColor: JedaColors.border,
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.hourglass_empty_rounded, color: JedaColors.textTertiary, size: 32),
            const SizedBox(height: 12),
            const Text('Belum ada detoks atau jadwal rutin', style: JedaTypography.labelBold),
            const SizedBox(height: 4),
            Text(
              'Gunakan tombol + di sudut kanan atas untuk menetapkan komitmen baru.',
              style: JedaTypography.caption.copyWith(color: JedaColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
