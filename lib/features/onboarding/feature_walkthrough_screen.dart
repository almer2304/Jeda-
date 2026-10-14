import 'package:flutter/material.dart';
import 'permission_onboarding_screen.dart';

class FeatureWalkthroughScreen extends StatefulWidget {
  const FeatureWalkthroughScreen({super.key});

  @override
  State<FeatureWalkthroughScreen> createState() => _FeatureWalkthroughScreenState();
}

class _FeatureWalkthroughScreenState extends State<FeatureWalkthroughScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<WalkthroughSlideData> _slides = const [
    WalkthroughSlideData(
      badgeText: 'MINDFUL LIVING',
      emoji: '🌿',
      icon: Icons.spa_rounded,
      iconColor: Color(0xFF87A878),
      title: 'Selamat Datang di Jeda',
      subtitle: 'Ambil jeda sejenak, kendalikan waktu, dan bebaskan dirimu dari siklus doomscrolling.',
      features: [
        WalkthroughFeatureItem(
          icon: Icons.self_improvement_rounded,
          title: 'Mindful Pause',
          description: 'Membantumu bernapas dan berpikir sebelum membuka aplikasi pemicu distraksi.',
        ),
        WalkthroughFeatureItem(
          icon: Icons.hourglass_empty_rounded,
          title: 'Kontrol Waktu Nyata',
          description: 'Kembalikan berjam-jam waktumu untuk belajar, berkarya, dan beristirahat berkualitas.',
        ),
        WalkthroughFeatureItem(
          icon: Icons.lock_outline_rounded,
          title: '100% Privat & Offline',
          description: 'Statistik penggunaan diproses langsung di HP-mu tanpa data keluar.',
        ),
      ],
    ),
    WalkthroughSlideData(
      badgeText: 'PENGUNCIAN FLEKSIBEL',
      emoji: '⏳',
      icon: Icons.lock_clock_rounded,
      iconColor: Color(0xFF6B8E5F),
      title: 'Kunci App & Kuota Harian',
      subtitle: 'Sesuaikan metode penguncian dengan gaya hidup dan rutinitas harianmu.',
      features: [
        WalkthroughFeatureItem(
          icon: Icons.timer_outlined,
          title: 'Kunci Langsung & Terjadwal',
          description: 'Kunci instan (1-24 jam) saat ingin fokus atau pasang jadwal otomatis (misal: jam kerja/tidur).',
        ),
        WalkthroughFeatureItem(
          icon: Icons.pie_chart_outline_rounded,
          title: 'Batas Kuota Screen Time',
          description: 'Tetapkan batas waktu maksimal (misal: 30 menit/hari untuk media sosial).',
        ),
        WalkthroughFeatureItem(
          icon: Icons.confirmation_number_outlined,
          title: '2 Tiket Darurat Mingguan',
          description: 'Butuh buka app darurat? Gunakan tiket 5 menit tanpa membatalkan komitmen fokus.',
        ),
      ],
    ),
    WalkthroughSlideData(
      badgeText: 'KOMUNITAS & TANTANGAN',
      emoji: '🏆',
      icon: Icons.emoji_events_rounded,
      iconColor: Color(0xFFD48B38),
      title: 'Tantangan Bareng & Streak',
      subtitle: 'Disiplin terasa jauh lebih menyenangkan saat berjuang bersama teman.',
      features: [
        WalkthroughFeatureItem(
          icon: Icons.people_alt_outlined,
          title: 'Tantangan Private & Komunitas',
          description: 'Tantang temanmu bebas medsos bareng-bareng atau ikuti tantangan global.',
        ),
        WalkthroughFeatureItem(
          icon: Icons.local_fire_department_rounded,
          title: 'Streak Harian (+1 Hari)',
          description: 'Lewati hari tanpa pelanggaran untuk menaikkan streak dan melipatgandakan poin.',
        ),
        WalkthroughFeatureItem(
          icon: Icons.warning_amber_rounded,
          title: 'Deteksi Buka Paksa',
          description: 'Mencoba buka app terkunci akan tercatat realtime di riwayat tantangan bersama!',
        ),
      ],
    ),
    WalkthroughSlideData(
      badgeText: 'PERLINDUNGAN EKSTRA',
      emoji: '🛡️',
      icon: Icons.security_rounded,
      iconColor: Color(0xFF4A7C59),
      title: 'Mode Bodyguard Anti-Bypass',
      subtitle: 'Perlindungan tangguh untuk menjaga komitmenmu saat godaan datang.',
      features: [
        WalkthroughFeatureItem(
          icon: Icons.shield_outlined,
          title: 'Anti-Uninstall Protection',
          description: 'Mencegah Jeda dihapus secara impulsif saat dorongan kecanduan sedang kuat.',
        ),
        WalkthroughFeatureItem(
          icon: Icons.admin_panel_settings_outlined,
          title: 'Proteksi Aksesibilitas',
          description: 'Jika kamu memaksa menonaktifkan Device Admin dari pengaturan HP, kamu akan langsung terlempar keluar!',
        ),
        WalkthroughFeatureItem(
          icon: Icons.verified_user_outlined,
          title: 'Uninstall Resmi Hanya Lewat Jeda',
          description: 'Satu-satunya cara menghapus Jeda adalah melalui menu Pengaturan di dalam aplikasi dengan alur penonaktifan sadar.',
        ),
      ],
    ),
  ];

  void _onNext() {
    if (_currentPage < _slides.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      _goToPermissionScreen();
    }
  }

  void _goToPermissionScreen() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const PermissionOnboardingScreen()),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLastPage = _currentPage == _slides.length - 1;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E8),
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar: Progress Indicator & Skip Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Logo / App Title
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF87A878).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text('🌿', style: TextStyle(fontSize: 18)),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Jeda',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2D2D2D),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),

                  // Skip Button
                  if (!isLastPage)
                    TextButton(
                      onPressed: _goToPermissionScreen,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.grey[700],
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      ),
                      child: const Row(
                        children: [
                          Text('Lewati', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          SizedBox(width: 2),
                          Icon(Icons.chevron_right, size: 16),
                        ],
                      ),
                    )
                  else
                    const SizedBox(height: 36),
                ],
              ),
            ),

            // PageView Content
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _slides.length,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                itemBuilder: (context, index) {
                  return _buildSlide(_slides[index]);
                },
              ),
            ),

            // Bottom Navigation Area
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              child: Column(
                children: [
                  // Page Indicator Dots
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_slides.length, (index) {
                      final isActive = index == _currentPage;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        height: 8,
                        width: isActive ? 28 : 8,
                        decoration: BoxDecoration(
                          color: isActive ? const Color(0xFF87A878) : Colors.grey[350],
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 20),

                  // Main Action Button
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _onNext,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF87A878),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            isLastPage ? 'Mulai Siapkan Izin 🚀' : 'Lanjut',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            isLastPage ? Icons.arrow_forward_rounded : Icons.chevron_right_rounded,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlide(WalkthroughSlideData data) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Header Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF87A878).withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              data.badgeText,
              style: const TextStyle(
                color: Color(0xFF5A7D4C),
                fontWeight: FontWeight.bold,
                fontSize: 11,
                letterSpacing: 1.1,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Central Visual Avatar
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Center(
              child: Icon(
                data.icon,
                size: 46,
                color: data.iconColor,
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Slide Title & Subtitle
          Text(
            data.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2D2D2D),
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            data.subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[700],
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),

          // Feature Highlight Cards
          ...data.features.map((feat) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F0E8),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(feat.icon, size: 20, color: const Color(0xFF87A878)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            feat.title,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2D2D2D),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            feat.description,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: Colors.grey[700],
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

class WalkthroughSlideData {
  final String badgeText;
  final String emoji;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final List<WalkthroughFeatureItem> features;

  const WalkthroughSlideData({
    required this.badgeText,
    required this.emoji,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.features,
  });
}

class WalkthroughFeatureItem {
  final IconData icon;
  final String title;
  final String description;

  const WalkthroughFeatureItem({
    required this.icon,
    required this.title,
    required this.description,
  });
}
