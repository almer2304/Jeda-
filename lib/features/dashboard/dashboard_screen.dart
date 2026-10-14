import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/native_bridge_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/models/lock_entry.dart';
import '../../core/models/quota_entry.dart';
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
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.emoji_events_outlined),
            selectedIcon: Icon(Icons.emoji_events),
            label: 'Komunitas',
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_stories_outlined),
            selectedIcon: Icon(Icons.auto_stories),
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
        try {
          final api = ref.read(apiServiceProvider);
          if (await api.isLoggedIn()) {
            await api.reportForcedOpen(packageName);
          }
        } catch (_) {}
      } else if (event.isNotEmpty && event.contains('.')) {
        // APP_BLOCKED_EVENT dari native: event == packageName plain (mis. com.sudoku.game)
        final packageName = event.trim();
        try {
          final api = ref.read(apiServiceProvider);
          if (await api.isLoggedIn()) {
            // reportForcedOpen backend menangani forced_opens user + challenge_forced_opens sekaligus secara atomic
            await api.reportForcedOpen(packageName);
          }
        } catch (_) {}
      }
    });
  }

  void _showAdminDisableWarningDialog() {
    if (!mounted || _isWarningDialogShowing) return;
    _isWarningDialogShowing = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF5F0E8),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top drag handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),

              // Shield Icon Avatar
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.red[200]!, width: 2),
                ),
                child: const Center(
                  child: Text('🛡️', style: TextStyle(fontSize: 38)),
                ),
              ),
              const SizedBox(height: 18),

              // Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red[100],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'PROTEKSI BODYGUARD AKTIF',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.redAccent,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Title
              const Text(
                'Upaya Penonaktifan Terdeteksi',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D2D2D),
                ),
              ),
              const SizedBox(height: 12),

              // Explanation
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  'Kamu baru saja mencoba menonaktifkan izin Administrator Perangkat dari pengaturan Android.\n\n'
                  'Mode Bodyguard dirancang untuk melindungimu dari keputusan impulsif saat dorongan kecanduan sedang kuat. '
                  'Jika kamu benar-benar ingin menonaktifkan Jeda secara sadar, silakan gunakan prosedur resmi melalui menu Pengaturan Jeda.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13.5,
                    color: Colors.grey[800],
                    height: 1.45,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Primary CTA (Stay Focused)
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF87A878),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Saya Mengerti & Tetap Fokus 🌿',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Secondary CTA (Go to official uninstall flow)
              SizedBox(
                width: double.infinity,
                height: 48,
                child: TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const UninstallFrictionScreen(),
                      ),
                    );
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red[800],
                  ),
                  child: const Text(
                    'Buka Prosedur Penonaktifan Resmi',
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
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

  Future<void> _initData() async {
    final storage = ref.read(storageServiceProvider);
    await storage.cleanExpiredLocks();

    // Sync native quota usage
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

    final api = ref.read(apiServiceProvider);
    if (await api.isLoggedIn()) {
      try {
        final profile = await api.getMe();
        if (profile != null) {
          streak = profile.currentStreakDays;
          await storage.saveStreakDays(profile.currentStreakDays);
        }
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        _activeLocks = active;
        _quotas = quotaList;
        _hoursSaved = hours;
        _streakDays = streak;
      });
      _updateCountdownTimer();
    }

    // Sync locks to cloud backend if logged in
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

    // Gabungkan rules lokal + aturan challenge aktif yang sudah diterima (hanya jika status=active)
    final rules = storage.getActiveRules();
    try {
      if (await api.isLoggedIn()) {
        final myChallenges = await api.getMyChallenges();
        for (final ch in myChallenges) {
          // Hanya kunci aplikasi jika tantangan sudah aktif dan saya peserta aktif (bukan invited/declined/surrendered)
          if (ch.status == 'active' && ch.myStatus != 'invited' && ch.myStatus != 'declined' && ch.myStatus != 'surrendered') {
            final endMillis = ch.endTime?.millisecondsSinceEpoch ?? DateTime.now().add(Duration(hours: ch.durationHours)).millisecondsSinceEpoch;
            // Hindari duplikasi jika sudah ada rule lokal untuk paket yang sama
            final alreadyBlocked = rules.any((r) => r['packageName'] == ch.packageName);
            if (!alreadyBlocked && DateTime.now().millisecondsSinceEpoch < endMillis) {
              rules.add({
                'packageName': ch.packageName,
                'isScheduled': false,
                'endTimeMillis': endMillis,
                'isChallenge': true,
                'challengeId': ch.id,
              });
            }
          }
        }
      }
    } catch (_) {}

    if (rules.isNotEmpty) {
      await ref.read(nativeBridgeServiceProvider).startMonitoring(rules);
      await ref.read(nativeBridgeServiceProvider).updateBlockedList(rules);
    } else {
      // Tidak ada aturan aktif, hentikan monitoring untuk hemat baterai
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
          setState(() {
            // Rebuild only when active countdown is ticking
          });
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
      int totalDays = duration.inDays;
      int years = totalDays ~/ 365;
      int remainingDays = totalDays % 365;
      int months = remainingDays ~/ 30;
      remainingDays = remainingDays % 30;
      int weeks = remainingDays ~/ 7;
      int days = remainingDays % 7;
      
      List<String> parts = [];
      if (years > 0) parts.add("$years tahun");
      if (months > 0) parts.add("$months bulan");
      if (weeks > 0) parts.add("$weeks minggu");
      if (days > 0) parts.add("$days hari");
      
      if (parts.isEmpty) return "Kurang dari 1 hari";
      return parts.take(2).join(" ");
    }

    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }

  String _formatSecondsToMinutes(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    if (mins == 0) {
      return "${secs}d";
    } else if (secs == 0) {
      return "$mins m";
    }
    return "$mins m ${secs}d";
  }

  void _showAddOptionModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Pilih Mode Fokus 🌱', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFEAF2E8),
                    child: Icon(Icons.timer_outlined, color: Color(0xFF87A878)),
                  ),
                  title: const Text('Kuota Harian (Budget Waktu)', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Bebas buka aplikasi sampai jatah menit harian habis.'),
                  onTap: () async {
                    Navigator.pop(context);
                    await Navigator.of(context).push(
                      MaterialPageRoute(builder: (context) => const AddQuotaScreen()),
                    );
                    _initData();
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFEAF2E8),
                    child: Icon(Icons.lock_clock_outlined, color: Color(0xFF87A878)),
                  ),
                  title: const Text('Kunci Penuh / Jadwal Rutin', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Kunci aplikasi langsung dengan durasi atau jam tertentu.'),
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
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final displayStreak = authState.value?.currentStreakDays ?? _streakDays;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E8),
      appBar: AppBar(
        title: const Text('Jeda 🌿', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFFF5F0E8),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          '$_hoursSaved jam',
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF87A878)),
                        ),
                        const SizedBox(height: 4),
                        const Text('berhasil ditahan', style: TextStyle(color: Colors.grey), textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                  Container(width: 1, height: 40, color: Colors.grey.withValues(alpha: 0.3)),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          '$displayStreak hari',
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF87A878)),
                        ),
                        const SizedBox(height: 4),
                        const Text('Streak', style: TextStyle(color: Colors.grey), textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // SECTION 1: KUOTA HARIAN
            if (_quotas.isNotEmpty) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Kuota Harian',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2D2D2D)),
                  ),
                  Row(
                    children: const [
                      Icon(Icons.lock_outline, size: 14, color: Colors.grey),
                      SizedBox(width: 4),
                      Text('Terkunci', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _quotas.length,
                itemBuilder: (context, index) {
                  final quota = _quotas[index];
                  final totalSec = quota.dailyQuotaMinutes * 60;
                  final progress = (quota.usedTodaySeconds / totalSec).clamp(0.0, 1.0);
                  final isExhausted = quota.isQuotaExhausted;
                  final isEmergency = quota.isEmergencyActive;

                  // Quota cards cannot be deleted manually to enforce focus commitment
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 0,
                    color: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Text(quota.groupName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  const SizedBox(width: 8),
                                  if (isEmergency)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.orange[100],
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Text('Darurat Aktif (5m)', style: TextStyle(fontSize: 10, color: Colors.orange, fontWeight: FontWeight.bold)),
                                    ),
                                ],
                              ),
                              Text(
                                isExhausted ? 'Habis 🔒' : '${_formatSecondsToMinutes(quota.usedTodaySeconds)} / ${quota.dailyQuotaMinutes}m',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isExhausted ? Colors.red : const Color(0xFF87A878),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: progress,
                              backgroundColor: Colors.grey[200],
                              valueColor: AlwaysStoppedAnimation<Color>(
                                isExhausted ? Colors.redAccent : const Color(0xFF87A878),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  quota.appNames.join(', '),
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                '🎫 ${quota.emergencyTickets}/2 Tiket',
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
            ],

            // SECTION 2: SEDANG DIKUNCI
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Sedang Dikunci Direct',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2D2D2D)),
                ),
                if (_activeLocks.isNotEmpty)
                  Row(
                    children: const [
                      Icon(Icons.lock_outline, size: 14, color: Colors.grey),
                      SizedBox(width: 4),
                      Text('Terkunci', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _activeLocks.isEmpty && _quotas.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('🌱', style: TextStyle(fontSize: 64)),
                          const SizedBox(height: 16),
                          const Text('Belum ada sesi fokus aktif', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Text('Tap tombol + untuk mulai fokus', style: TextStyle(color: Colors.grey[600])),
                        ],
                      ),
                    ),
                  )
                : _activeLocks.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12.0),
                        child: Text('Belum ada penguncian langsung.', style: TextStyle(color: Colors.grey)),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _activeLocks.length,
                        itemBuilder: (context, index) {
                          final lock = _activeLocks[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: 0,
                            color: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              leading: CircleAvatar(
                                backgroundColor: Colors.grey[200],
                                child: const Icon(Icons.apps, color: Colors.grey), 
                              ),
                              title: Text(lock.appName, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text(lock.isScheduled 
                                  ? 'Rutin: ${lock.scheduledStart} - ${lock.scheduledEnd}' 
                                  : 'Menjaga jarak...'),
                              trailing: lock.isScheduled
                                  ? const Icon(Icons.calendar_today, color: Color(0xFF87A878))
                                  : Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          _formatDuration(lock.remaining),
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF87A878),
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          );
                        },
                      ),
            if (_quotas.isNotEmpty || _activeLocks.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF2E8),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.shield_outlined, color: Color(0xFF87A878), size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Aturan & Jadwal yang telah dibuat dikunci permanen dan tidak dapat dihapus demi komitmen fokusmu 🌱",
                        style: TextStyle(fontSize: 12, color: Color(0xFF2D2D2D)),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddOptionModal,
        backgroundColor: const Color(0xFF87A878),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Fokus Baru', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}
