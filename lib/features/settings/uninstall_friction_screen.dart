import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jeda/core/services/native_bridge_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

class UninstallFrictionScreen extends ConsumerStatefulWidget {
  const UninstallFrictionScreen({Key? key}) : super(key: key);

  @override
  _UninstallFrictionScreenState createState() => _UninstallFrictionScreenState();
}

class _UninstallFrictionScreenState extends ConsumerState<UninstallFrictionScreen> {
  int _currentStep = 0;
  final String _targetPhrase = "Saya sadar bahwa dengan menghapus Jeda, saya membiarkan diri saya kembali dikendalikan oleh distraksi digital. Saya secara sadar memilih untuk menyerah pada komitmen fokus saya.";
  final TextEditingController _textController = TextEditingController();
  
  // Timer for reading
  int _readingSecondsLeft = 120; // 2 minutes
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
        // Cooldown passed, allow disable
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
          _cooldownRemaining = "\${diff.inMinutes.toString().padLeft(2, '0')}:\${(diff.inSeconds % 60).toString().padLeft(2, '0')}";
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
    final end = DateTime.now().add(const Duration(hours: 1));
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
      appBar: AppBar(
        title: const Text("Nonaktifkan Perlindungan", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.red[900],
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      backgroundColor: Colors.grey[900],
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: _buildCurrentStep(),
        ),
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _buildStep1GuiltTrip();
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

  Widget _buildStep1GuiltTrip() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.shield_outlined, size: 80, color: Colors.white54),
        const SizedBox(height: 24),
        const Text(
          "Yakin mau melepaskan Bodyguard-mu?",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        const SizedBox(height: 16),
        const Text(
          "Jeda telah melindungimu dari ribuan distraksi. Jika kamu menonaktifkannya, kamu akan kembali rentan terhadap godaan media sosial dan aplikasi yang menyita waktumu.",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, color: Colors.white70),
        ),
        const SizedBox(height: 48),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey[800],
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          onPressed: () => Navigator.pop(context),
          child: const Text("Kembali Fokus", style: TextStyle(color: Colors.white, fontSize: 16)),
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: _nextStep,
          child: const Text("Saya tetap ingin menonaktifkan", style: TextStyle(color: Colors.redAccent)),
        ),
      ],
    );
  }

  Widget _buildStep2Typing() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          "Ketik Komitmenmu",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        const SizedBox(height: 16),
        const Text(
          "Ketik ulang teks di bawah ini dengan tepat (tanpa copy-paste) untuk membuktikan kamu sadar sepenuhnya:",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: Colors.white70),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white24),
          ),
          child: Text(
            _targetPhrase,
            style: const TextStyle(color: Colors.white, fontStyle: FontStyle.italic),
          ),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _textController,
          maxLines: 4,
          style: const TextStyle(color: Colors.white),
          enableInteractiveSelection: false, // Disables copy/paste
          decoration: InputDecoration(
            hintText: "Ketik di sini...",
            hintStyle: const TextStyle(color: Colors.white30),
            filled: true,
            fillColor: Colors.grey[800],
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onChanged: (val) => setState(() {}),
        ),
        const Spacer(),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: _textController.text == _targetPhrase ? Colors.red : Colors.grey,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          onPressed: _textController.text == _targetPhrase ? _nextStep : null,
          child: const Text("Lanjut", style: TextStyle(color: Colors.white, fontSize: 16)),
        ),
      ],
    );
  }

  Widget _buildStep3Reading() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          "Renungkan Sejenak",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const SingleChildScrollView(
              child: Text(
                "Aplikasi Jeda dirancang bukan sebagai penjara, melainkan sebagai tameng. "
                "Setiap kali kamu membuka HP, perusahaan teknologi menggunakan trik psikologis "
                "untuk mencuri perhatianmu. Mereka memenangkan miliaran dolar dari waktu yang "
                "seharusnya kamu gunakan untuk belajar, berkarya, atau beristirahat dengan benar.\n\n"
                "Dengan menonaktifkan Jeda, kamu sedang memberikan kembali kunci hidupmu kepada "
                "algoritma yang tidak peduli pada masa depanmu. "
                "Tarik napas dalam-dalam. Apakah kamu benar-benar perlu menghapus perlindungan ini sekarang? "
                "Atau ini hanya dorongan impulsif sementara?",
                style: TextStyle(color: Colors.white70, fontSize: 16, height: 1.5),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        if (_readingSecondsLeft > 0)
          Text(
            "Tombol lanjut akan muncul dalam $_readingSecondsLeft detik",
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white54),
          )
        else
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            onPressed: _initiateCooldown,
            child: const Text("Saya Paham, Lanjut", style: TextStyle(color: Colors.white, fontSize: 16)),
          ),
      ],
    );
  }

  Widget _buildStep4Cooldown() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.timer_outlined, size: 80, color: Colors.orange),
        const SizedBox(height: 24),
        const Text(
          "Waktu Tunggu (Cooling-Off)",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        const SizedBox(height: 16),
        const Text(
          "Permintaan penonaktifan diterima. Untuk memastikan ini bukan keputusan impulsif, perlindungan baru bisa dilepas dalam:",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, color: Colors.white70),
        ),
        const SizedBox(height: 32),
        Text(
          _cooldownRemaining,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.orangeAccent),
        ),
        const SizedBox(height: 48),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey[800],
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          onPressed: () => Navigator.pop(context),
          child: const Text("Tutup dan Kembali", style: TextStyle(color: Colors.white, fontSize: 16)),
        ),
      ],
    );
  }

  Widget _buildFinalAllow() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.warning_amber_rounded, size: 80, color: Colors.redAccent),
        const SizedBox(height: 24),
        const Text(
          "Perlindungan Siap Dilepas",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        const SizedBox(height: 16),
        const Text(
          "Waktu tunggu telah berakhir. Kamu sekarang bisa menonaktifkan Jeda.",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, color: Colors.white70),
        ),
        const SizedBox(height: 48),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red[900],
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          onPressed: () async {
            final bridge = ref.read(nativeBridgeServiceProvider);
            await bridge.removeDeviceAdmin();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Device Admin dinonaktifkan. Kamu bisa uninstall Jeda sekarang.')),
            );
            Navigator.pop(context);
          },
          child: const Text("Nonaktifkan Device Admin", style: TextStyle(color: Colors.white, fontSize: 16)),
        ),
      ],
    );
  }
}