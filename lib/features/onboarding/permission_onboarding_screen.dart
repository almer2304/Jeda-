import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/native_bridge_service.dart';
import '../../core/services/storage_service.dart';
import '../dashboard/dashboard_screen.dart';

class PermissionOnboardingScreen extends ConsumerStatefulWidget {
  const PermissionOnboardingScreen({super.key});

  @override
  ConsumerState<PermissionOnboardingScreen> createState() => _PermissionOnboardingScreenState();
}

class _PermissionOnboardingScreenState extends ConsumerState<PermissionOnboardingScreen> {
  int _currentStep = 0;
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      final nativeBridge = ref.read(nativeBridgeServiceProvider);
      final permissions = await nativeBridge.checkAllPermissions();
      
      if (!mounted) return;

      if (_currentStep == 0 && (permissions['usage'] ?? false)) {
        setState(() => _currentStep = 1);
      } else if (_currentStep == 1 && (permissions['overlay'] ?? false)) {
        setState(() => _currentStep = 2);
      } else if (_currentStep == 2 && (permissions['battery'] ?? false)) {
        setState(() => _currentStep = 3);
      } else if (_currentStep == 3 && (permissions['deviceAdmin'] ?? false)) {
        setState(() => _currentStep = 4);
      } else if (_currentStep == 4 && (permissions['accessibility'] ?? false)) {
        _finishOnboarding();
      }
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  void _finishOnboarding() async {
    _pollingTimer?.cancel();
    final storage = ref.read(storageServiceProvider);
    await storage.setOnboardingDone(true);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const DashboardScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E8),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: IndexedStack(
            index: _currentStep,
            children: [
              _buildStep(
                emoji: '📊',
                title: 'Izinkan pemantauan app',
                description: 'Agar Jeda tahu kapan kamu membuka app yang ingin dikunci, kami perlu akses statistik penggunaan. Data ini tidak pernah meninggalkan HP-mu.',
                onAllow: () => ref.read(nativeBridgeServiceProvider).openSettingsFor('usage'),
              ),
              _buildStep(
                emoji: '🛡️',
                title: 'Izinkan tampilan pengingat',
                description: 'Saat kamu membuka app yang dikunci, Jeda akan menampilkan pengingat lembut. Ini butuh izin tampil di atas app lain.',
                onAllow: () => ref.read(nativeBridgeServiceProvider).openSettingsFor('overlay'),
              ),
              _buildStep(
                emoji: '🔋',
                title: 'Jaga Jeda tetap aktif',
                description: 'Beberapa HP mematikan app di background untuk hemat baterai. Izinkan pengecualian agar perlindunganmu tidak terhenti tiba-tiba.',
                onAllow: () => ref.read(nativeBridgeServiceProvider).openSettingsFor('battery'),
                onSkip: () => setState(() => _currentStep = 3), // Battery optimization can sometimes fail on custom Android skins, allowing skip
              ),
              _buildStep(
                emoji: '🔒',
                title: 'Mode Bodyguard (Wajib)',
                description: 'Agar kamu tidak tergoda menghapus Jeda saat sedang kecanduan, Jeda membutuhkan akses Administrator Perangkat. Berani berkomitmen?',
                onAllow: () => ref.read(nativeBridgeServiceProvider).openSettingsFor('deviceAdmin'),
              ),
              _buildStep(
                emoji: '🛑',
                title: 'Cegah Kecurangan (Wajib)',
                description: 'Satu langkah terakhir. Izinkan aksesibilitas agar Jeda bisa mencegahmu menonaktifkan Mode Bodyguard secara paksa dari pengaturan HP.',
                onAllow: () => ref.read(nativeBridgeServiceProvider).openSettingsFor('accessibility'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep({
    required String emoji,
    required String title,
    required String description,
    required VoidCallback onAllow,
    VoidCallback? onSkip,
  }) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 80)),
        const SizedBox(height: 32),
        Text(
          title,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2D2D2D),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          description,
          style: const TextStyle(
            fontSize: 16,
            color: Color(0xFF2D2D2D),
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 48),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: onAllow,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF87A878),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text('Aktifkan', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
        ),
        if (onSkip != null) ...[
          const SizedBox(height: 16),
          TextButton(
            onPressed: onSkip,
            child: const Text(
              'Lewati (Tidak Disarankan)',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ),
        ],
      ],
    );
  }
}
