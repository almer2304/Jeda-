import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/services/api_service.dart';
import '../../core/services/native_bridge_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/models/api_models.dart';
import '../../core/providers/auth_provider.dart';

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
    // Auto refresh every 5 seconds to sync attempt logs and surrender status
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) => _loadDetail(silent: true));
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
            content: Text(action == 'accept' ? 'Kamu menerima tantangan! 🌱 Mengaktifkan penguncian...' : 'Kamu menolak tantangan.'),
            backgroundColor: action == 'accept' ? const Color(0xFF87A878) : Colors.grey,
          ),
        );
      }
      await _loadDetail();
      // Jika accept dan challenge jadi aktif, sinkronkan ke native agar langsung terkunci
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
          SnackBar(content: Text('Gagal: ${e.toString().replaceFirst('Exception: ', '')}'), backgroundColor: Colors.redAccent),
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
            content: Text('🎉 Berhasil bergabung ke tantangan! Mengaktifkan penguncian...'),
            backgroundColor: Color(0xFF87A878),
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
          SnackBar(content: Text('Gagal bergabung: ${e.toString().replaceFirst('Exception: ', '')}'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _surrender() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('⚠️ Yakin Ingin Menyerah?'),
        content: const Text(
          'Jika menyerah, poin kamu akan dikurangi 50 poin, streak kamu akan di-reset menjadi 0 hari, dan teman tantanganmu akan diberitahu.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
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
            content: Text('Kamu telah menyerah dari tantangan. Poin -50 dan streak di-reset.'),
            backgroundColor: Colors.redAccent,
          ),
        );
        _loadDetail();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyerah: ${e.toString().replaceFirst('Exception: ', '')}'),
            backgroundColor: Colors.redAccent,
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
      backgroundColor: const Color(0xFFF5F0E8),
      appBar: AppBar(
        title: const Text('Detail Tantangan ⚔️', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFFF5F0E8),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadDetail(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF87A878)))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.redAccent)))
              : _challenge == null
                  ? const Center(child: Text('Tantangan tidak ditemukan'))
                  : RefreshIndicator(
                      onRefresh: () => _loadDetail(),
                      color: const Color(0xFF87A878),
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 0. COMPLETION BANNER (If challenge is completed/expired)
                            if (isCompleted) ...[
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                margin: const EdgeInsets.only(bottom: 16),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF87A878), Color(0xFF5E8B54)],
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF87A878).withValues(alpha: 0.3),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.emoji_events_rounded, color: Colors.amber, size: 38),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Tantangan Selesai! 🎉',
                                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            isUserSurrendered
                                                ? 'Waktu tantangan telah berakhir. Kamu telah menyerah pada tantangan ini.'
                                                : 'Selamat! Waktu tantangan telah berakhir dan kamu berhasil melaluinya! 🏆',
                                            style: const TextStyle(fontSize: 12, color: Colors.white, height: 1.3),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            // 1. SURRENDER BANNER (If any friend surrendered)
                            if (surrenderedFriends.isNotEmpty) ...[
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(14),
                                margin: const EdgeInsets.only(bottom: 16),
                                decoration: BoxDecoration(
                                  color: Colors.red[50],
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.flag, color: Colors.redAccent, size: 28),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Teman Menyerah! 🏳️',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.red[800],
                                              fontSize: 14,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${surrenderedFriends.map((f) => '${f.name} (@${f.username})').join(', ')} telah menyerah dari tantangan ini.',
                                            style: TextStyle(fontSize: 12, color: Colors.red[900]),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            // 2. CHALLENGE HEADER CARD
                            Card(
                              elevation: 0,
                              color: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              child: Padding(
                                padding: const EdgeInsets.all(20.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFEAF2E8),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            '⏳ ${_challenge!.durationHours} Jam',
                                            style: const TextStyle(
                                              color: Color(0xFF87A878),
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: _challenge!.status == 'active'
                                                ? Colors.green[50]
                                                : _challenge!.status == 'pending'
                                                    ? Colors.orange[50]
                                                    : _challenge!.status == 'cancelled'
                                                        ? Colors.red[50]
                                                        : Colors.grey[200],
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            _challenge!.status == 'active'
                                                ? '● Aktif'
                                                : _challenge!.status == 'pending'
                                                    ? '⏳ Menunggu persetujuan'
                                                    : _challenge!.status == 'cancelled'
                                                        ? '✕ Dibatalkan'
                                                        : 'Selesai',
                                            style: TextStyle(
                                              color: _challenge!.status == 'active'
                                                  ? Colors.green[800]
                                                  : _challenge!.status == 'pending'
                                                      ? Colors.orange[800]
                                                      : _challenge!.status == 'cancelled'
                                                          ? Colors.red[800]
                                                          : Colors.grey[700],
                                              fontWeight: FontWeight.bold,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      _challenge!.title,
                                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                                    ),
                                    if (_challenge!.description != null &&
                                        _challenge!.description!.isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      Text(
                                        _challenge!.description!,
                                        style: TextStyle(color: Colors.grey[700], fontSize: 13),
                                      ),
                                    ],
                                    const Divider(height: 24),
                                    Row(
                                      children: [
                                        const Icon(Icons.apps, size: 18, color: Color(0xFF87A878)),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Target Kunci: ',
                                          style: TextStyle(color: Colors.grey[600], fontSize: 13),
                                        ),
                                        Text(
                                          _challenge!.appName,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        const Icon(Icons.person_pin, size: 18, color: Color(0xFF87A878)),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Dibuat oleh: ',
                                          style: TextStyle(color: Colors.grey[600], fontSize: 13),
                                        ),
                                        Text(
                                          _challenge!.creatorName ?? _challenge!.creatorUsername ?? 'User',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            // Pending info banner
                            if (_challenge!.status == 'pending') ...[
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.orange[50],
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.orange[200]!),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.hourglass_top, color: Colors.orange[800], size: 22),
                                    const SizedBox(width: 10),
                                    const Expanded(
                                      child: Text(
                                        'Tantangan belum aktif — tunggu semua teman menerima undangan. Penguncian akan mulai otomatis setelah semua menyetujui.',
                                        style: TextStyle(fontSize: 12, height: 1.4),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],

                            // Invite action for current user — tampil jika status invited (pending maupun active legacy)
                            if (myParticipant?.status == 'invited') ...[
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () => _respondInvite('decline'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.redAccent,
                                        side: const BorderSide(color: Colors.redAccent),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                      child: const Text('Tolak'),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: () => _respondInvite('accept'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF87A878),
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                      child: const Text('Setuju? ✓'),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                            ],

                            // Join action for current user (Public/Global challenge)
                            if ((myParticipant == null || myParticipant.status == 'none' || myParticipant.userId.isEmpty) && _challenge!.status == 'active' && !isCompleted) ...[
                              SizedBox(
                                width: double.infinity,
                                height: 52,
                                child: ElevatedButton.icon(
                                  onPressed: _joinChallenge,
                                  icon: const Icon(Icons.rocket_launch, color: Colors.white),
                                  label: const Text(
                                    '🚀 Ikuti Tantangan Ini (Join Challenge)',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF87A878),
                                    foregroundColor: Colors.white,
                                    elevation: 2,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],

                            const SizedBox(height: 20),

                            // 3. PESERTA TANTANGAN
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Peserta Tantangan 👥',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  '${_challenge!.participants.length} Orang',
                                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _challenge!.participants.length,
                              itemBuilder: (context, index) {
                                final participant = _challenge!.participants[index];
                                final isMe = participant.userId == currentUserId;
                                final bool isInvited = participant.status == 'invited';
                                final bool isDeclined = participant.status == 'declined';

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  elevation: 0,
                                  color: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    leading: CircleAvatar(
                                      backgroundColor: participant.isSurrendered || isDeclined
                                          ? Colors.red[100]
                                          : isInvited ? Colors.orange[100] : const Color(0xFFEAF2E8),
                                      child: Text(
                                        participant.name.isNotEmpty ? participant.name.substring(0, 1).toUpperCase() : '?',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: participant.isSurrendered || isDeclined
                                              ? Colors.redAccent
                                              : isInvited ? Colors.orange[800] : const Color(0xFF87A878),
                                        ),
                                      ),
                                    ),
                                    title: Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            participant.name,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (isMe) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF87A878),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: const Text('Kamu',
                                                style: TextStyle(fontSize: 10, color: Colors.white)),
                                          ),
                                        ],
                                      ],
                                    ),
                                    subtitle: Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Text(
                                        isInvited
                                            ? '⏳ Menunggu persetujuan'
                                            : isDeclined
                                                ? '❌ Menolak tantangan'
                                                : participant.isSurrendered
                                                    ? '🏳️ Telah Menyerah'
                                                    : '🔥 ${participant.currentStreakDays}h • 🌟 ${participant.totalPoints}',
                                        style: TextStyle(
                                          color: isInvited ? Colors.orange[800] : participant.isSurrendered || isDeclined ? Colors.redAccent : Colors.grey,
                                          fontSize: 11,
                                          fontWeight: isInvited || participant.isSurrendered || isDeclined ? FontWeight.bold : FontWeight.normal,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    trailing: ConstrainedBox(
                                      constraints: const BoxConstraints(maxWidth: 110),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: participant.isSurrendered || isDeclined
                                              ? Colors.red[50]
                                              : isInvited ? Colors.orange[50] : participant.forcedOpenCount > 0
                                                  ? Colors.orange[50]
                                                  : const Color(0xFFEAF2E8),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text(
                                            isInvited
                                                ? 'Diundang'
                                                : isDeclined
                                                    ? 'Ditolak'
                                                    : participant.isSurrendered
                                                        ? 'Menyerah'
                                                        : '${participant.forcedOpenCount}x Coba',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: participant.isSurrendered || isDeclined
                                                  ? Colors.redAccent
                                                  : isInvited ? Colors.orange[800] : participant.forcedOpenCount > 0
                                                      ? Colors.orange[800]
                                                      : const Color(0xFF87A878),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 20),

                            // 4. RIWAYAT PERCOBAAN MEMBUKA APLIKASI (REALTIME ATTEMPT LOGS)
                            const Text(
                              'Riwayat Percobaan Membuka App 📜',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Setiap kali kamu atau teman membuka ${_challenge!.appName} saat terkunci, tercatat di sini:',
                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                            ),
                            const SizedBox(height: 8),
                            if (_challenge!.attempts.isEmpty)
                              Card(
                                elevation: 0,
                                color: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                child: Padding(
                                  padding: const EdgeInsets.all(24.0),
                                  child: Center(
                                    child: Column(
                                      children: const [
                                        Icon(Icons.verified_user_outlined, size: 40, color: Color(0xFF87A878)),
                                        SizedBox(height: 8),
                                        Text(
                                          'Belum Ada yang Membuka Paksa 🌱',
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                        ),
                                        SizedBox(height: 2),
                                        Text(
                                          'Pertahankan komitmen dan saling menyemangati!',
                                          style: TextStyle(color: Colors.grey, fontSize: 11),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              )
                            else
                              Card(
                                elevation: 0,
                                color: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                child: ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: _challenge!.attempts.length,
                                  separatorBuilder: (context, i) => const Divider(height: 1),
                                  itemBuilder: (context, index) {
                                    final attempt = _challenge!.attempts[index];
                                    final isMe = attempt.userId == currentUserId;
                                    final timeFormatted =
                                        DateFormat('dd MMM, HH:mm:ss').format(attempt.openedAt.toLocal());

                                    return ListTile(
                                      leading: const CircleAvatar(
                                        backgroundColor: Color(0xFFFFEEEE),
                                        child: Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 20),
                                      ),
                                      title: Text(
                                        isMe ? 'Kamu mencoba membuka app' : '${attempt.name} mencoba membuka app',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                      subtitle: Text(
                                        timeFormatted,
                                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                                      ),
                                      trailing: const Text(
                                        'Terdeteksi ⚠️',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.redAccent,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            const SizedBox(height: 24),

                            // 5. TOMBOL MENYERAH
                            if (_challenge!.status == 'active' && !isUserSurrendered && !isCompleted) ...[
                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: OutlinedButton.icon(
                                  onPressed: _surrender,
                                  icon: const Icon(Icons.flag_outlined, color: Colors.redAccent),
                                  label: const Text(
                                    'Menyerah dari Tantangan (-50 Pts)',
                                    style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: Colors.redAccent),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  ),
                                ),
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
