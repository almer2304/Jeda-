import 'package:flutter/material.dart';
import '../../core/theme/jeda_colors.dart';
import '../../core/theme/jeda_radii.dart';
import '../../core/theme/jeda_typography.dart';
import '../../core/widgets/jeda_card.dart';
import '../../core/widgets/jeda_badge.dart';
import '../../core/widgets/jeda_button.dart';

class EducationScreen extends StatefulWidget {
  const EducationScreen({super.key});

  @override
  State<EducationScreen> createState() => _EducationScreenState();
}

class _EducationScreenState extends State<EducationScreen> {
  String _selectedCategory = 'Semua';
  String? _selectedMood;
  String? _moodAffirmation;

  final List<String> _categories = [
    'Semua',
    'Psikologi Layar',
    'Kebiasaan Baru',
    'Latihan Sadar',
  ];

  final List<_ArticleData> _articles = [
    const _ArticleData(
      id: 'distraction',
      title: 'Kenapa Sulit Lepas dari Layar?',
      category: 'Psikologi Layar',
      readTimeMinutes: 3,
      subtitle: 'Memahami desain adiktif, variable reward, dan notifikasi merah di balik aplikasi modern.',
      icon: Icons.psychology_outlined,
      paragraphs: [
        'Pernahkah Anda membuka ponsel untuk mengecek jam, lalu setengah jam kemudian tersadar sedang menggulir konten tanpa arah? Ini bukan semata kelemahan disiplin diri Anda, melainkan hasil dari rekayasa antarmuka yang sangat disengaja.',
        'Aplikasi hiburan dan media sosial dirancang menggunakan prinsip "Variable Reward" (imbalan variabel) — pola psikologis yang sama dengan mesin jackpot di kasino. Setiap tarikan ke bawah (pull-to-refresh) menciptakan rasa penasaran: apa hal menarik berikutnya yang akan muncul?',
        'Warna merah cerah pada lonceng notifikasi, infinite scroll tanpa batas bawah, dan video putar otomatis sengaja menonaktifkan "tanda berhenti alami" (stopping cues) yang biasanya memberi tahu otak manusia bahwa sebuah aktivitas telah selesai.',
      ],
      practicalSteps: [
        'Ubah layar ke mode Grayscale (Skala Abu-abu) di Pengaturan Android untuk menurunkan rangsangan dopamin visual.',
        'Nonaktifkan notifikasi yang bukan berasal dari pesan manusia nyata (seperti rekomendasi berita, diskon, atau like).',
        'Ciptakan "tanda berhenti alami" buatan: tentukan jumlah video atau waktu sebelum Anda membuka aplikasi hiburan.',
      ],
      quote: 'Langkah pertama pemulihan kendali bukan dengan menyalahkan diri sendiri, melainkan menyadari bagaimana sistem memancing perhatian Anda.',
    ),
    const _ArticleData(
      id: 'habit_replacement',
      title: '5 Alternatif Sederhana Pengganti Gawai',
      category: 'Kebiasaan Baru',
      readTimeMinutes: 4,
      subtitle: 'Mengganti refleks otomatis meraih ponsel dengan kebiasaan fisik mikro yang menyegarkan pikiran.',
      icon: Icons.spa_outlined,
      paragraphs: [
        'Otak manusia membenci kekosongan. Ketika Anda melarang diri membuka ponsel tanpa menyediakan pengganti konkret, pikiran akan terus menuntut stimulasi dan akhirnya menyerah pada godaan.',
        'Kuncinya bukan menahan dorongan dengan kekerasan tekad (willpower), melainkan mengalihkan gerakan motorik tangan ke tindakan alternatif yang memiliki gesekan sangat rendah.',
        'Aktivitas pengganti tidak perlu rumit atau memakan waktu lama. Sering kali, jeda mikro selama 60 hingga 90 detik sudah cukup untuk meredakan gelombang impuls dopamin.',
      ],
      practicalSteps: [
        'Teguk segelas air putih secara perlahan: Rasakan sensasi dingin di tenggorokan untuk mengembalikan kesadaran sensori tubuh.',
        'Latihan Napas Kotak (Box Breathing): Tarik napas 4 detik, tahan 4 detik, hembuskan 4 detik, dan tahan 4 detik.',
        'Alihkan pandangan ke luar jendela (Aturan 20-20-20): Istirahatkan otot mata dengan menatap objek yang berjarak jauh.',
        'Gerakan peregangan bahu & leher: Lepaskan ketegangan otot yang menumpuk akibat postur membungkuk menatap layar.',
        'Tulis 1 kalimat di jurnal fisik: Catat apa yang sedang Anda pikirkan atau rasakan saat dorongan membuka HP muncul.',
      ],
      quote: 'Kebiasaan tidak bisa dihilangkan seketika, namun ia dapat digantikan dengan tindakan yang lebih menenangkan.',
    ),
    const _ArticleData(
      id: 'triggers',
      title: 'Kenali Pemicu Utama (Triggers) Anda',
      category: 'Psikologi Layar',
      readTimeMinutes: 3,
      subtitle: 'Membedakan antara kelelahan emosional, kebosanan sesaat, dan sekadar memori otot.',
      icon: Icons.radar_outlined,
      paragraphs: [
        'Sebagian besar waktu screen time yang tidak diinginkan sebenarnya bukan dimulai dari kebutuhan informasi, melainkan respons refleks terhadap ketidaknyamanan batiniah.',
        'Pemicu internal biasanya berwujud: rasa bosan saat menunggu, kecemasan menghadapi tugas sulit, kelelahan setelah bekerja seharian, atau rasa kesepian.',
        'Ponsel menjadi "dot penenang digital" yang paling mudah dijangkau saat kita enggan merasakan emosi-emosi tersebut, meskipun hanya untuk beberapa menit.',
      ],
      practicalSteps: [
        'Saat tangan otomatis menyentuh ponsel, tanyakan dalam hati: "Perasaan apa yang sedang ingin saya hindari saat ini?"',
        'Beri nama emosinya: "Saya sedang cemas", "Saya sedang bosan", atau "Saya sedang lelah". Menamai emosi menurunkan intensitas reaksi limbik otak.',
        'Beri diri Anda izin untuk merasa bosan selama 2 menit tanpa langsung mencari distraksi.',
      ],
      quote: 'Kebosanan adalah ruang tenang tempat kreativitas dan pemikiran orisinal manusia bertumbuh.',
    ),
    const _ArticleData(
      id: 'one_minute_pause',
      title: 'Teknik "Jeda Satu Menit"',
      category: 'Latihan Sadar',
      readTimeMinutes: 2,
      subtitle: 'Menanamkan ruang antara dorongan impulsif dan tindakan nyata untuk melatih otot kontrol diri.',
      icon: Icons.hourglass_empty_outlined,
      paragraphs: [
        'Psikolog Viktor Frankl pernah menulis: "Di antara stimulus dan respons ada sebuah ruang. Di ruang itulah terletak kebebasan dan kekuatan kita untuk memilih respons kita."',
        'Ketika dorongan membuka media sosial muncul, gelombang impuls dopamin mencapai puncaknya dalam waktu sekitar 60 detik. Jika Anda dapat menunda tindakan selama 1 menit, intensitas dorongan tersebut biasanya turun drastis.',
        'Aplikasi Jeda dirancang untuk menyediakan ruang fisik tersebut: memberi waktu bagi korteks prefrontal Anda untuk kembali mengambil alih kemudi.',
      ],
      practicalSteps: [
        'Setiap kali hendak membuka aplikasi yang rentan distraksi, hitung mundur perlahan 10 hingga 20 tarikan napas.',
        'Tanyakan satu pertanyaan sederhana: "Apakah setelah membuka aplikasi ini selama 30 menit ke depan, saya akan merasa lebih baik atau lebih lelah?"',
        'Jika jawabannya adalah lelah, letakkan ponsel dengan layar menghadap ke bawah di meja.',
      ],
      quote: 'Kekuatan terbesar bukanlah tidak pernah tergoda, melainkan mampu berhenti sejenak sebelum memutuskan melangkah.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final filteredArticles = _selectedCategory == 'Semua'
        ? _articles
        : _articles.where((a) => a.category == _selectedCategory).toList();

    return Scaffold(
      backgroundColor: JedaColors.background,
      appBar: AppBar(
        title: Text(
          'Ruang Edukasi & Refleksi',
          style: JedaTypography.heading3.copyWith(
            color: JedaColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: JedaColors.background,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _buildReflectionCard(),
          const SizedBox(height: 24),
          _buildCategoryFilters(),
          const SizedBox(height: 16),
          _buildArticlesList(filteredArticles),
        ],
      ),
    );
  }

  Widget _buildReflectionCard() {
    return JedaCard(
      backgroundColor: JedaColors.surface,
      borderColor: JedaColors.border,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: JedaColors.primarySoft,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.self_improvement_outlined,
                  color: JedaColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pemeriksaan Diri Hari Ini',
                      style: JedaTypography.labelBold.copyWith(
                        fontSize: 15,
                        color: JedaColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Bagaimana hubunganmu dengan gawai saat ini?',
                      style: JedaTypography.bodySecondary.copyWith(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildMoodChip('Tenang & Sadar', '🌿', 'Pertahankan ritme ini. Luangkan waktu untuk hadir utuh di luar layar.'),
              _buildMoodChip('Cukup Fokus', '🎯', 'Kondisi yang baik. Tetap istirahatkan mata sejenak setiap jam.'),
              _buildMoodChip('Mulai Terdistraksi', '⚡', 'Tarik napas dalam 3 kali. Beri jeda 1 menit sebelum membuka layar lagi.'),
              _buildMoodChip('Kelelahan Layar', '☁️', 'Tubuhmu butuh rehat fisik. Singkirkan gawai dan istirahatkan pandangan.'),
            ],
          ),
          if (_moodAffirmation != null) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: JedaColors.surfaceSecondary,
                borderRadius: JedaRadii.borderR12,
                border: Border.all(color: JedaColors.borderSubtle),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    color: JedaColors.primary,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _moodAffirmation!,
                      style: JedaTypography.bodySecondary.copyWith(
                        color: JedaColors.textPrimary,
                        fontSize: 12.5,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMoodChip(String label, String icon, String affirmation) {
    final isSelected = _selectedMood == label;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedMood = label;
          _moodAffirmation = affirmation;
        });
      },
      borderRadius: JedaRadii.borderFull,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? JedaColors.primary : JedaColors.surfaceSecondary,
          borderRadius: JedaRadii.borderFull,
          border: Border.all(
            color: isSelected ? JedaColors.primaryDark : JedaColors.border,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(icon, style: const TextStyle(fontSize: 13)),
            const SizedBox(width: 6),
            Text(
              label,
              style: JedaTypography.caption.copyWith(
                color: isSelected ? Colors.white : JedaColors.textPrimary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryFilters() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Wawasan & Panduan Tenang',
          style: JedaTypography.heading3.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _categories.map((cat) {
              final isSelected = _selectedCategory == cat;
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: ChoiceChip(
                  label: Text(cat),
                  selected: isSelected,
                  selectedColor: JedaColors.primary,
                  backgroundColor: JedaColors.surface,
                  side: BorderSide(
                    color: isSelected ? JedaColors.primaryDark : JedaColors.border,
                  ),
                  labelStyle: JedaTypography.caption.copyWith(
                    color: isSelected ? Colors.white : JedaColors.textPrimary,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _selectedCategory = cat);
                    }
                  },
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildArticlesList(List<_ArticleData> articles) {
    if (articles.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Text(
            'Tidak ada panduan dalam topik ini.',
            style: JedaTypography.bodySecondary,
          ),
        ),
      );
    }

    return Column(
      children: articles.map((article) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: JedaCard(
            onTap: () => _openArticleDetail(article),
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: JedaColors.primarySoft,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        article.icon,
                        color: JedaColors.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              JedaBadge(
                                label: article.category,
                                variant: JedaBadgeVariant.neutral,
                              ),
                              const Spacer(),
                              Text(
                                '${article.readTimeMinutes} menit baca',
                                style: JedaTypography.caption.copyWith(
                                  color: JedaColors.textTertiary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            article.title,
                            style: JedaTypography.labelBold.copyWith(
                              fontSize: 15,
                              color: JedaColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  article.subtitle,
                  style: JedaTypography.bodySecondary.copyWith(
                    fontSize: 13,
                    height: 1.45,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Text(
                      'Baca Panduan',
                      style: JedaTypography.labelBold.copyWith(
                        fontSize: 12.5,
                        color: JedaColors.primary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      size: 14,
                      color: JedaColors.primary,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  void _openArticleDetail(_ArticleData article) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: JedaColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: JedaRadii.sheetTop),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.88,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          expand: false,
          builder: (context, scrollController) {
            return SafeArea(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: const BoxDecoration(
                        color: JedaColors.border,
                        borderRadius: JedaRadii.borderFull,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      JedaBadge(
                        label: article.category,
                        variant: JedaBadgeVariant.neutral,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '•  ${article.readTimeMinutes} menit baca',
                        style: JedaTypography.caption.copyWith(
                          color: JedaColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    article.title,
                    style: JedaTypography.heading2.copyWith(
                      color: JedaColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    article.subtitle,
                    style: JedaTypography.bodySecondary.copyWith(
                      fontSize: 14,
                      color: JedaColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Divider(color: JedaColors.borderSubtle),
                  const SizedBox(height: 16),
                  ...article.paragraphs.map(
                    (p) => Padding(
                      padding: const EdgeInsets.only(bottom: 14.0),
                      child: Text(
                        p,
                        style: JedaTypography.body.copyWith(
                          fontSize: 14.5,
                          height: 1.6,
                          color: JedaColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: JedaColors.surfaceSecondary,
                      borderRadius: JedaRadii.borderR16,
                      border: Border.all(color: JedaColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.checklist_rounded,
                              color: JedaColors.primary,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Langkah Praktis Hari Ini',
                              style: JedaTypography.labelBold.copyWith(
                                color: JedaColors.textPrimary,
                                fontSize: 13.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ...article.practicalSteps.map(
                          (step) => Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '• ',
                                  style: TextStyle(
                                    color: JedaColors.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    step,
                                    style: JedaTypography.bodySecondary.copyWith(
                                      color: JedaColors.textPrimary,
                                      fontSize: 13,
                                      height: 1.45,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: const BoxDecoration(
                      color: JedaColors.primarySoft,
                      borderRadius: JedaRadii.borderR12,
                    ),
                    child: Text(
                      '“${article.quote}”',
                      style: JedaTypography.bodySecondary.copyWith(
                        color: JedaColors.primaryDark,
                        fontStyle: FontStyle.italic,
                        height: 1.45,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 24),
                  JedaButton(
                    label: 'Tutup & Kembali Tenang',
                    variant: JedaButtonVariant.secondary,
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _ArticleData {
  final String id;
  final String title;
  final String category;
  final int readTimeMinutes;
  final String subtitle;
  final IconData icon;
  final List<String> paragraphs;
  final List<String> practicalSteps;
  final String quote;

  const _ArticleData({
    required this.id,
    required this.title,
    required this.category,
    required this.readTimeMinutes,
    required this.subtitle,
    required this.icon,
    required this.paragraphs,
    required this.practicalSteps,
    required this.quote,
  });
}
