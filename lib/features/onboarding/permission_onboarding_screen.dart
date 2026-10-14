import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/native_bridge_service.dart';
import '../../core/services/storage_service.dart';
import '../auth/login_screen.dart';


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
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }


  @override
  Widget build(BuildContext context) {
    const totalSteps = 5;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E8),
      body: SafeArea(
        child: Column(
          children: [
            // Top Step Progress Indicator
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Aktivasi Perlindungan',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF87A878).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Langkah ${_currentStep + 1} dari $totalSteps',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF5A7D4C),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: (_currentStep + 1) / totalSteps,
                      backgroundColor: Colors.grey[300],
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF87A878)),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            ),

            // Step Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: IndexedStack(
                  index: _currentStep,
                  children: [
                    _buildStep(
                      emoji: '📊',
                      title: 'Izinkan Pemantauan App',
                      description: 'Agar Jeda tahu kapan kamu membuka app yang ingin dikunci, kami perlu akses statistik penggunaan. Data ini diproses lokal di HP-mu.',
                      permissionBadge: 'Izin Akses Penggunaan',
                      onAllow: () => ref.read(nativeBridgeServiceProvider).openSettingsFor('usage'),
                    ),
                    _buildStep(
                      emoji: '🛡️',
                      title: 'Izinkan Tampilan Pengingat',
                      description: 'Saat kamu membuka app yang dikunci, Jeda akan menampilkan overlay layar jeda untuk membantumu bernapas dan membatalkan kebiasaan refleks.',
                      permissionBadge: 'Tampil di Atas App Lain',
                      onAllow: () => ref.read(nativeBridgeServiceProvider).openSettingsFor('overlay'),
                    ),
                    _buildStep(
                      emoji: '🔋',
                      title: 'Jaga Jeda Tetap Aktif',
                      description: 'Sistem Android dapat mematikan background app secara agresif. Pengecualian baterai memastikan perlindungan tidak mati mendadak.',
                      permissionBadge: 'Optimasi Baterai',
                      onAllow: () => ref.read(nativeBridgeServiceProvider).openSettingsFor('battery'),
                      onSkip: () => setState(() => _currentStep = 3),
                    ),
                    _buildStep(
                      emoji: '🔒',
                      title: 'Mode Bodyguard (Wajib)',
                      description: 'Mencegah Jeda dihapus saat dorongan kecanduan muncul. Jika kamu memaksa menonaktifkannya di pengaturan HP, kamu akan langsung terlempar keluar! Satu-satunya cara adalah uninstall melalui menu Pengaturan Jeda.',
                      permissionBadge: 'Device Admin Policy',
                      onAllow: () => ref.read(nativeBridgeServiceProvider).openSettingsFor('deviceAdmin'),
                    ),
                    _buildStep(
                      emoji: '🛑',
                      title: 'Cegah Kecurangan (Wajib)',
                      description: 'Langkah terakhir! Izin aksesibilitas memantau dan memblokir upaya bypass atau penonaktifan paksa di pengaturan Android, memastikan kamu tetap fokus pada tujuanmu.',
                      permissionBadge: 'Accessibility Service',
                      onAllow: () => ref.read(nativeBridgeServiceProvider).openSettingsFor('accessibility'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep({
    required String emoji,
    required String title,
    required String description,
    required String permissionBadge,
    required VoidCallback onAllow,
    VoidCallback? onSkip,
  }) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Card Container
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                  color: Color(0xFFF5F0E8),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(emoji, style: const TextStyle(fontSize: 42)),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Text(
                  permissionBadge,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D2D2D),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                description,
                style: TextStyle(
                  fontSize: 13.5,
                  color: Colors.grey[700],
                  height: 1.45,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),

        // Action Button
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: onAllow,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF87A878),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Buka Pengaturan & Aktifkan',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                SizedBox(width: 8),
                Icon(Icons.open_in_new_rounded, size: 18),
              ],
            ),
          ),
        ),
        if (onSkip != null) ...[
          const SizedBox(height: 12),
          TextButton(
            onPressed: onSkip,
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey[600],
            ),
            child: const Text(
              'Lewati (Tidak Disarankan)',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ],
    );
  }
}
