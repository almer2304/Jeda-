import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/services/api_service.dart';
import '../../core/services/native_bridge_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/models/api_models.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/theme/jeda_colors.dart';
import '../../core/theme/jeda_radii.dart';
import '../../core/theme/jeda_typography.dart';
import '../../core/widgets/app_icon_widget.dart';
import '../../core/widgets/jeda_card.dart';
import '../../core/widgets/jeda_badge.dart';
import '../../core/widgets/jeda_button.dart';

class ChallengeDetailScreen extends ConsumerStatefulWidget {
  final String challengeId;
  const ChallengeDetailScreen({super.key, required this.challengeId});

  @override
  ConsumerState<ChallengeDetailScreen> createState() => _ChallengeDetailScreenState();
}

class _ChallengeDetailScreenState extends ConsumerState<ChallengeDetailScreen> {
  bool _isLoading = true;
  ChallengeModel? _challenge;
  String? _error;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadDetail();
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) => _loadDetail(silent: true));
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadDetail({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final api = ref.read(apiServiceProvider);
      final challenge = await api.getChallengeDetail(widget.challengeId);
      if (mounted) {
        setState(() {
          _challenge = challenge;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted && !silent) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _respondInvite(String action) async {
    try {
      final api = ref.read(apiServiceProvider);
      await api.respondChallengeInvite(widget.challengeId, action);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(action == 'accept' ? 'Anda menerima tantangan. Mengaktifkan pembatasan...' : 'Anda menolak tantangan.'),
            backgroundColor: action == 'accept' ? JedaColors.primary : JedaColors.textSecondary,
          ),
        );
      }
      await _loadDetail();
      if (action == 'accept') {
        try {
          final storage = ref.read(storageServiceProvider);
          final nativeBridge = ref.read(nativeBridgeServiceProvider);
          final api2 = ref.read(apiServiceProvider);
          if (await api2.isLoggedIn()) {
            final rules = storage.getActiveRules();
            final myChallenges = await api2.getMyChallenges();
            for (final ch in myChallenges) {
              if (ch.status == 'active' && ch.myStatus != 'invited' && ch.myStatus != 'declined' && ch.myStatus != 'surrendered') {
                final endMillis = ch.endTime?.millisecondsSinceEpoch ?? DateTime.now().add(Duration(hours: ch.durationHours)).millisecondsSinceEpoch;
                if (DateTime.now().millisecondsSinceEpoch < endMillis && !rules.any((r) => r['packageName'] == ch.packageName)) {
                  rules.add({'packageName': ch.packageName, 'isScheduled': false, 'endTimeMillis': endMillis, 'isChallenge': true, 'challengeId': ch.id});
                }
              }
            }
            if (rules.isNotEmpty) {
              await nativeBridge.startMonitoring(rules);
              await nativeBridge.updateBlockedList(rules);
            }
          }
        } catch (_) {}
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal: ${e.toString().replaceFirst('Exception: ', '')}'), backgroundColor: JedaColors.error),
        );
      }
    }
  }

  Future<void> _joinChallenge() async {
    try {
      final api = ref.read(apiServiceProvider);
      await api.joinChallenge(widget.challengeId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Berhasil bergabung ke tantangan komunitas!'),
            backgroundColor: JedaColors.primary,
          ),
        );
      }
      await _loadDetail();
      try {
        final storage = ref.read(storageServiceProvider);
        final nativeBridge = ref.read(nativeBridgeServiceProvider);
        final api2 = ref.read(apiServiceProvider);
        if (await api2.isLoggedIn()) {
          final rules = storage.getActiveRules();
          final myChallenges = await api2.getMyChallenges();
          for (final ch in myChallenges) {
            if (ch.status == 'active' && ch.myStatus != 'invited' && ch.myStatus != 'declined' && ch.myStatus != 'surrendered') {
              final endMillis = ch.endTime?.millisecondsSinceEpoch ?? DateTime.now().add(Duration(hours: ch.durationHours)).millisecondsSinceEpoch;
              if (DateTime.now().millisecondsSinceEpoch < endMillis && !rules.any((r) => r['packageName'] == ch.packageName)) {
                rules.add({'packageName': ch.packageName, 'isScheduled': false, 'endTimeMillis': endMillis, 'isChallenge': true, 'challengeId': ch.id});
              }
            }
          }
          if (rules.isNotEmpty) {
            await nativeBridge.startMonitoring(rules);
            await nativeBridge.updateBlockedList(rules);
          }
        }
      } catch (_) {}
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal bergabung: ${e.toString().replaceFirst('Exception: ', '')}'),
            backgroundColor: JedaColors.error,
          ),
        );
      }
    }
  }

  Future<void> _surrender() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: JedaColors.surface,
        shape: const RoundedRectangleBorder(borderRadius: JedaRadii.borderR16),
        title: Text(
          'Konfirmasi Menyerah',
          style: JedaTypography.heading3.copyWith(color: JedaColors.error),
        ),
        content: Text(
          'Apakah Anda yakin ingin menyerah dari tantangan ini?\n\n'
          'Poin Anda akan berkurang 50 poin dan streak akan di-reset.',
          style: JedaTypography.bodySecondary.copyWith(height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Batal', style: JedaTypography.labelBold.copyWith(color: JedaColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: JedaColors.error,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: const RoundedRectangleBorder(borderRadius: JedaRadii.borderR8),
            ),
            child: const Text('Ya, Saya Menyerah'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final api = ref.read(apiServiceProvider);
      await api.surrenderChallenge(widget.challengeId);
      ref.read(authStateProvider.notifier).refreshProfile();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Anda telah menyerah dari tantangan. Poin -50 dan streak di-reset.'),
            backgroundColor: JedaColors.error,
          ),
        );
        _loadDetail();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyerah: ${e.toString().replaceFirst('Exception: ', '')}'),
            backgroundColor: JedaColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final currentUserId = authState.value?.id;

    final myParticipant = _challenge?.participants.firstWhere(
      (p) => p.userId == currentUserId,
      orElse: () => ChallengeParticipantModel(
        id: '',
        userId: '',
        username: '',
        status: 'none',
      ),
    );

    final bool isUserSurrendered = myParticipant?.isSurrendered ?? false;
    final bool isCompleted = _challenge?.status == 'completed' ||
        (_challenge?.endTime != null && DateTime.now().isAfter(_challenge!.endTime!));
    final List<ChallengeParticipantModel> surrenderedFriends = _challenge?.participants
            .where((p) => p.isSurrendered && p.userId != currentUserId)
            .toList() ??
        [];

    return Scaffold(
      backgroundColor: JedaColors.background,
      appBar: AppBar(
        title: Text(
          'Detail Tantangan',
          style: JedaTypography.heading3.copyWith(
            color: JedaColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: JedaColors.background,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: JedaColors.textSecondary),
            onPressed: () => _loadDetail(),
            tooltip: 'Segarkan',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: JedaColors.primary))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_error!, style: JedaTypography.bodySecondary.copyWith(color: JedaColors.error)),
                        const SizedBox(height: 12),
                        JedaButton(
                          label: 'Coba Lagi',
                          isFullWidth: false,
                          onPressed: () => _loadDetail(),
                        ),
                      ],
                    ),
                  ),
                )
              : _challenge == null
                  ? const Center(child: Text('Tantangan tidak ditemukan', style: JedaTypography.bodySecondary))
                  : RefreshIndicator(
                      onRefresh: () => _loadDetail(),
                      color: JedaColors.primary,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 0. Completion Banner
                            if (isCompleted) ...[
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                margin: const EdgeInsets.only(bottom: 14),
                                decoration: BoxDecoration(
                                  color: JedaColors.primarySoft,
                                  borderRadius: JedaRadii.borderR16,
                                  border: Border.all(color: JedaColors.primary),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.check_circle_outline_rounded, color: JedaColors.primaryDark, size: 30),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Tantangan Telah Selesai',
                                            style: JedaTypography.labelBold.copyWith(
                                              fontSize: 14.5,
                                              color: JedaColors.primaryDark,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            isUserSurrendered
                                                ? 'Waktu tantangan telah berakhir. Anda berstatus menyerah pada sesi ini.'
                                                : 'Selamat! Anda berhasil menjaga komitmen hingga akhir tantangan.',
                                            style: JedaTypography.bodySecondary.copyWith(
                                              fontSize: 12.5,
                                              color: JedaColors.primaryDark,
                                              height: 1.35,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            // 1. Surrender Friends Banner
                            if (surrenderedFriends.isNotEmpty) ...[
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(14),
                                margin: const EdgeInsets.only(bottom: 14),
                                decoration: BoxDecoration(
                                  color: JedaColors.errorSoft,
                                  borderRadius: JedaRadii.borderR12,
                                  border: Border.all(color: JedaColors.error.withValues(alpha: 0.3)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.info_outline_rounded, color: JedaColors.error, size: 22),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Pembaruan Peserta',
                                            style: JedaTypography.labelBold.copyWith(
                                              fontSize: 13,
                                              color: JedaColors.error,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${surrenderedFriends.map((f) => '${f.name} (@${f.username})').join(', ')} telah menyerah.',
                                            style: JedaTypography.caption.copyWith(color: JedaColors.error),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            // 2. Challenge Header Card
                            JedaCard(
                              padding: const EdgeInsets.all(18),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      JedaBadge(
                                        label: '${_challenge!.durationHours} Jam',
                                        variant: JedaBadgeVariant.neutral,
                                      ),
                                      JedaBadge(
                                        label: _challenge!.status == 'active'
                                            ? 'Aktif'
                                            : _challenge!.status == 'pending'
                                                ? 'Menunggu'
                                                : _challenge!.status == 'cancelled'
                                                    ? 'Dibatalkan'
                                                    : 'Selesai',
                                        variant: _challenge!.status == 'active'
                                            ? JedaBadgeVariant.success
                                            : _challenge!.status == 'pending'
                                                ? JedaBadgeVariant.warning
                                                : _challenge!.status == 'cancelled'
                                                    ? JedaBadgeVariant.error
                                                    : JedaBadgeVariant.neutral,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    _challenge!.title,
                                    style: JedaTypography.heading3.copyWith(
                                      fontSize: 18,
                                      color: JedaColors.textPrimary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  if (_challenge!.description != null && _challenge!.description!.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      _challenge!.description!,
                                      style: JedaTypography.bodySecondary.copyWith(fontSize: 13, height: 1.4),
                                    ),
                                  ],
                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 14),
                                    child: Divider(color: JedaColors.borderSubtle, height: 1),
                                  ),
                                  Row(
                                    children: [
                                      AppIconWidget(
                                        packageName: _challenge!.packageName,
                                        size: 20,
                                        borderRadius: JedaRadii.borderR8,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Aplikasi Target: ',
                                        style: JedaTypography.caption.copyWith(color: JedaColors.textSecondary),
                                      ),
                                      Text(
                                        _challenge!.appName,
                                        style: JedaTypography.labelBold.copyWith(fontSize: 13),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      const Icon(Icons.person_outline_rounded, size: 16, color: JedaColors.primary),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Inisiator: ',
                                        style: JedaTypography.caption.copyWith(color: JedaColors.textSecondary),
                                      ),
                                      Text(
                                        _challenge!.creatorName ?? _challenge!.creatorUsername ?? 'Pengguna Jeda',
                                        style: JedaTypography.labelBold.copyWith(fontSize: 13),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Pending Banner
                            if (_challenge!.status == 'pending') ...[
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: JedaColors.warningSoft,
                                  borderRadius: JedaRadii.borderR12,
                                  border: Border.all(color: JedaColors.warning.withValues(alpha: 0.3)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.hourglass_top_rounded, color: JedaColors.warning, size: 18),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'Tantangan belum aktif. Menunggu seluruh teman yang diundang menyetujui.',
                                        style: JedaTypography.caption.copyWith(
                                          color: JedaColors.warning,
                                          height: 1.35,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],

                            // Invite Action Buttons
                            if (myParticipant?.status == 'invited') ...[
                              Row(
                                children: [
                                  Expanded(
                                    child: JedaButton(
                                      label: 'Tolak',
                                      variant: JedaButtonVariant.secondary,
                                      height: 40,
                                      onPressed: () => _respondInvite('decline'),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: JedaButton(
                                      label: 'Terima Tantangan',
                                      variant: JedaButtonVariant.primary,
                                      height: 40,
                                      onPressed: () => _respondInvite('accept'),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                            ],

                            // Join Action (Public)
                            if ((myParticipant == null || myParticipant.status == 'none' || myParticipant.userId.isEmpty) && _challenge!.status == 'active' && !isCompleted) ...[
                              JedaButton(
                                label: 'Ikuti Tantangan Komunitas Ini',
                                icon: Icons.group_add_outlined,
                                variant: JedaButtonVariant.primary,
                                height: 46,
                                onPressed: _joinChallenge,
                              ),
                              const SizedBox(height: 16),
                            ],

                            const SizedBox(height: 12),

                            // 3. Peserta Tantangan
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Peserta Tantangan',
                                  style: JedaTypography.labelBold.copyWith(fontSize: 15),
                                ),
                                Text(
                                  '${_challenge!.participants.length} Orang',
                                  style: JedaTypography.caption.copyWith(color: JedaColors.textSecondary),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ..._challenge!.participants.map((participant) {
                              final isMe = participant.userId == currentUserId;
                              final bool isInvited = participant.status == 'invited';
                              final bool isDeclined = participant.status == 'declined';

                              JedaBadgeVariant partBadgeVariant;
                              String partBadgeLabel;

                              if (participant.isSurrendered) {
                                partBadgeVariant = JedaBadgeVariant.error;
                                partBadgeLabel = 'Menyerah';
                              } else if (isDeclined) {
                                partBadgeVariant = JedaBadgeVariant.error;
                                partBadgeLabel = 'Ditolak';
                              } else if (isInvited) {
                                partBadgeVariant = JedaBadgeVariant.warning;
                                partBadgeLabel = 'Diundang';
                              } else {
                                partBadgeVariant = JedaBadgeVariant.success;
                                partBadgeLabel = participant.forcedOpenCount > 0
                                    ? '${participant.forcedOpenCount}x Pelanggaran'
                                    : 'Fokus Berjalan';
                              }

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8.0),
                                child: JedaCard(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 17,
                                        backgroundColor: participant.isSurrendered || isDeclined
                                            ? JedaColors.errorSoft
                                            : isInvited
                                                ? JedaColors.warningSoft
                                                : JedaColors.primarySoft,
                                        child: Text(
                                          participant.name.isNotEmpty ? participant.name.substring(0, 1).toUpperCase() : 'U',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: participant.isSurrendered || isDeclined
                                                ? JedaColors.error
                                                : isInvited
                                                    ? JedaColors.warning
                                                    : JedaColors.primary,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Flexible(
                                                  child: Text(
                                                    participant.name,
                                                    style: JedaTypography.labelBold.copyWith(fontSize: 13.5),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                if (isMe) ...[
                                                  const SizedBox(width: 6),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                                    decoration: const BoxDecoration(
                                                      color: JedaColors.primary,
                                                      borderRadius: JedaRadii.borderR8,
                                                    ),
                                                    child: Text(
                                                      'Anda',
                                                      style: JedaTypography.caption.copyWith(
                                                        color: Colors.white,
                                                        fontSize: 9.5,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '@${participant.username} • ${participant.currentStreakDays}h streak • ${participant.totalPoints} poin',
                                              style: JedaTypography.caption.copyWith(color: JedaColors.textSecondary),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      JedaBadge(
                                        label: partBadgeLabel,
                                        variant: partBadgeVariant,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),

                            const SizedBox(height: 18),

                            // 4. Riwayat Percobaan Membuka App (Attempts)
                            Text(
                              'Riwayat Deteksi Pelanggaran',
                              style: JedaTypography.labelBold.copyWith(fontSize: 15),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Pencatatan otomatis saat aplikasi target terdeteksi dibuka:',
                              style: JedaTypography.caption.copyWith(color: JedaColors.textSecondary),
                            ),
                            const SizedBox(height: 8),
                            if (_challenge!.attempts.isEmpty)
                              JedaCard(
                                padding: const EdgeInsets.all(20),
                                child: Center(
                                  child: Column(
                                    children: [
                                      const Icon(Icons.shield_outlined, size: 32, color: JedaColors.primary),
                                      const SizedBox(height: 6),
                                      Text(
                                        'Belum ada pelanggaran terdeteksi',
                                        style: JedaTypography.labelBold.copyWith(fontSize: 13),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Semua peserta konsisten mematuhi kesepakatan.',
                                        style: JedaTypography.caption.copyWith(color: JedaColors.textSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            else
                              ..._challenge!.attempts.map((attempt) {
                                final isMe = attempt.userId == currentUserId;
                                final timeFormatted = DateFormat('dd MMM, HH:mm:ss').format(attempt.openedAt.toLocal());

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 6.0),
                                  child: JedaCard(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    borderColor: JedaColors.error.withValues(alpha: 0.3),
                                    backgroundColor: JedaColors.errorSoft.withValues(alpha: 0.5),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.warning_amber_rounded, color: JedaColors.error, size: 18),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                isMe ? 'Anda terdeteksi membuka aplikasi' : '${attempt.name} terdeteksi membuka aplikasi',
                                                style: JedaTypography.caption.copyWith(
                                                  fontWeight: FontWeight.w600,
                                                  color: JedaColors.textPrimary,
                                                ),
                                              ),
                                              Text(
                                                timeFormatted,
                                                style: JedaTypography.caption.copyWith(color: JedaColors.textTertiary, fontSize: 11),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }),

                            const SizedBox(height: 24),

                            // 5. Tombol Menyerah
                            if (_challenge!.status == 'active' && !isUserSurrendered && !isCompleted) ...[
                              JedaButton(
                                label: 'Menyerah dari Tantangan (-50 Poin)',
                                variant: JedaButtonVariant.destructive,
                                height: 46,
                                onPressed: _surrender,
                              ),
                              const SizedBox(height: 24),
                            ],
                          ],
                        ),
                      ),
                    ),
    );
  }
}
