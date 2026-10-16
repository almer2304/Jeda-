import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import '../../core/services/native_bridge_service.dart';
import '../../core/theme/jeda_colors.dart';
import '../../core/theme/jeda_typography.dart';
import '../../core/widgets/jeda_button.dart';
import '../../core/widgets/jeda_card.dart';

class UninstallFrictionScreen extends ConsumerStatefulWidget {
  const UninstallFrictionScreen({super.key});

  @override
  ConsumerState<UninstallFrictionScreen> createState() => _UninstallFrictionScreenState();
}

class _UninstallFrictionScreenState extends ConsumerState<UninstallFrictionScreen> {
  int _currentStep = 0;
  final String _targetPhrase = "Saya memahami bahwa mencopot Jeda akan menonaktifkan seluruh perlindungan fokus dan batasan waktu layar yang telah saya atur. Saya secara sadar memilih untuk melanjutkan.";
  final TextEditingController _textController = TextEditingController();
  
  // Timer for reading reflection
  int _readingSecondsLeft = 60; // 1 minute calm reflection
  Timer? _readingTimer;

  // Cooldown
  DateTime? _cooldownEnd;
  Timer? _cooldownTimer;
  String _cooldownRemaining = "";

  @override
  void initState() {
    super.initState();
    _checkCooldown();
  }

  Future<void> _checkCooldown() async {
    final prefs = await SharedPreferences.getInstance();
    final endTimeStr = prefs.getString('uninstall_cooldown_end');
    if (endTimeStr != null) {
      _cooldownEnd = DateTime.parse(endTimeStr);
      if (_cooldownEnd!.isAfter(DateTime.now())) {
        setState(() {
          _currentStep = 3; // Go straight to cooldown step
        });
        _startCooldownTimer();
      } else {
        setState(() {
          _currentStep = 4; // Final allow step
        });
      }
    }
  }

  void _startReadingTimer() {
    _readingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_readingSecondsLeft > 0) {
        setState(() {
          _readingSecondsLeft--;
        });
      } else {
        timer.cancel();
      }
    });
  }

  void _startCooldownTimer() {
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_cooldownEnd == null) {
        timer.cancel();
        return;
      }
      final now = DateTime.now();
      if (_cooldownEnd!.isAfter(now)) {
        final diff = _cooldownEnd!.difference(now);
        setState(() {
          _cooldownRemaining = "${diff.inMinutes.toString().padLeft(2, '0')}:${(diff.inSeconds % 60).toString().padLeft(2, '0')}";
        });
      } else {
        timer.cancel();
        setState(() {
          _currentStep = 4;
        });
      }
    });
  }

  Future<void> _initiateCooldown() async {
    final prefs = await SharedPreferences.getInstance();
    final end = DateTime.now().add(const Duration(minutes: 30)); // 30-min mindful cooldown
    await prefs.setString('uninstall_cooldown_end', end.toIso8601String());
    setState(() {
      _cooldownEnd = end;
      _currentStep = 3;
    });
    _startCooldownTimer();
  }

  @override
  void dispose() {
    _textController.dispose();
    _readingTimer?.cancel();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _nextStep() {
    setState(() {
      _currentStep++;
      if (_currentStep == 2) {
        _startReadingTimer();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: JedaColors.background,
      appBar: AppBar(
        title: const Text("Pencopotan Terstruktur", style: JedaTypography.heading3),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: _buildCurrentStep(),
        ),
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _buildStep1Reflection();
      case 1:
        return _buildStep2Typing();
      case 2:
        return _buildStep3Reading();
      case 3:
        return _buildStep4Cooldown();
      case 4:
        return _buildFinalAllow();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildStep1Reflection() {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: JedaColors.primarySoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.shield_outlined, size: 36, color: JedaColors.primaryDark),
            ),
            const SizedBox(height: 24),
            const Text(
              "Apakah Anda ingin menonaktifkan Jeda?",
              textAlign: TextAlign.center,
              style: JedaTypography.heading2,
            ),
            const SizedBox(height: 12),
            Text(
              "Jeda dirancang untuk memberi Anda ruang bernapas sebelum refleks membuka aplikasi otomatis mengambil alih waktu Anda. Jika dicopot, semua proteksi dan batasan aktif akan terhenti.",
              textAlign: TextAlign.center,
              style: JedaTypography.bodySecondary.copyWith(height: 1.5),
            ),
            const SizedBox(height: 40),
            JedaButton(
              label: "Batalkan & Tetap Fokus",
              onPressed: () => Navigator.pop(context),
              variant: JedaButtonVariant.primary,
            ),
            const SizedBox(height: 12),
            JedaButton(
              label: "Lanjutkan Prosedur Pencopotan",
              onPressed: _nextStep,
              variant: JedaButtonVariant.ghost,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep2Typing() {
    final isMatch = _textController.text.trim() == _targetPhrase.trim();

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            "Konfirmasi Kesadaran Penuh",
            textAlign: TextAlign.center,
            style: JedaTypography.heading2,
          ),
          const SizedBox(height: 8),
          const Text(
            "Ketik ulang kalimat di bawah ini secara manual untuk memastikan keputusan ini diambil secara tenang dan terencana:",
            textAlign: TextAlign.center,
            style: JedaTypography.bodySecondary,
          ),
          const SizedBox(height: 20),
          JedaCard(
            backgroundColor: JedaColors.surfaceSecondary,
            child: Text(
              _targetPhrase,
              style: JedaTypography.body.copyWith(fontStyle: FontStyle.italic, height: 1.5),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _textController,
            maxLines: 4,
            enableInteractiveSelection: false,
            decoration: const InputDecoration(
              hintText: "Ketik kalimat di atas di sini...",
            ),
            onChanged: (val) => setState(() {}),
          ),
          const SizedBox(height: 24),
          JedaButton(
            label: isMatch ? "Lanjutkan" : "Ketik Kalimat Di Atas Lengkap",
            onPressed: isMatch ? _nextStep : null,
            variant: isMatch ? JedaButtonVariant.primary : JedaButtonVariant.secondary,
          ),
        ],
      ),
    );
  }

  Widget _buildStep3Reading() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          "Refleksi Sebelum Berpisah",
          textAlign: TextAlign.center,
          style: JedaTypography.heading2,
        ),
        const SizedBox(height: 8),
        const Text(
          "Satu menit untuk merenungkan kebiasaan digital Anda.",
          textAlign: TextAlign.center,
          style: JedaTypography.caption,
        ),
        const SizedBox(height: 20),
        const Expanded(
          child: JedaCard(
            child: SingleChildScrollView(
              physics: BouncingScrollPhysics(),
              child: Text(
                "Aplikasi media sosial dan hiburan modern dioptimalkan oleh ribuan insinyur terbaik dunia untuk menahan perhatian kita selama mungkin. Itu bukan kelemahan tekad Anda—itu adalah rancangan sistem yang sengaja memanfaatkan biologi dopamin manusia.\n\n"
                "Jeda hadir bukan untuk mengekang, melainkan memberikan jeda sepersekian detik yang seringkali hilang saat jari kita bergerak otomatis.\n\n"
                "Bila Anda merasa sudah memiliki kendali sadar atas penggunaan ponsel Anda, kami menghormati pilihan Anda sepenuhnya. Terima kasih telah melatih kesadaran bersama Jeda.",
                style: JedaTypography.body,
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        if (_readingSecondsLeft > 0)
          Center(
            child: Text(
              "Waktu hening tersisa: $_readingSecondsLeft detik",
              style: JedaTypography.caption.copyWith(color: JedaColors.textSecondary),
            ),
          )
        else
          JedaButton(
            label: "Saya Siap Masuk Masa Pendinginan",
            onPressed: _initiateCooldown,
            variant: JedaButtonVariant.primary,
          ),
      ],
    );
  }

  Widget _buildStep4Cooldown() {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.hourglass_bottom, size: 64, color: JedaColors.warning),
            const SizedBox(height: 20),
            const Text(
              "Masa Pendinginan (Cooling-off)",
              textAlign: TextAlign.center,
              style: JedaTypography.heading2,
            ),
            const SizedBox(height: 10),
            const Text(
              "Masa jeda 30 menit ini memastikan Anda tidak sedang mengambil tindakan reaktif saat emosi frustrasi sesaat.",
              textAlign: TextAlign.center,
              style: JedaTypography.bodySecondary,
            ),
            const SizedBox(height: 28),
            Text(
              _cooldownRemaining,
              textAlign: TextAlign.center,
              style: JedaTypography.display.copyWith(color: JedaColors.warning),
            ),
            const SizedBox(height: 36),
            JedaButton(
              label: "Tutup & Kembali Nanti",
              onPressed: () => Navigator.pop(context),
              variant: JedaButtonVariant.secondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinalAllow() {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.check_circle_outline, size: 64, color: JedaColors.success),
            const SizedBox(height: 20),
            const Text(
              "Izin Administrator Siap Dicabut",
              textAlign: TextAlign.center,
              style: JedaTypography.heading2,
            ),
            const SizedBox(height: 10),
            const Text(
              "Masa pendinginan telah selesai. Tekan tombol di bawah untuk mencabut izin Administrator Perangkat secara resmi.",
              textAlign: TextAlign.center,
              style: JedaTypography.bodySecondary,
            ),
            const SizedBox(height: 36),
            JedaButton(
              label: "Cabut Izin Device Administrator",
              variant: JedaButtonVariant.destructive,
              onPressed: () async {
                final bridge = ref.read(nativeBridgeServiceProvider);
                await bridge.removeDeviceAdmin();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Izin Administrator Perangkat berhasil dicabut. Anda dapat mencopot Jeda melalui Setelan perangkat.'),
                    backgroundColor: JedaColors.primaryDark,
                  ),
                );
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}