import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/api_service.dart';
import '../../core/services/native_bridge_service.dart';
import '../../core/models/api_models.dart';
import '../../core/theme/jeda_colors.dart';
import '../../core/theme/jeda_radii.dart';
import '../../core/theme/jeda_typography.dart';
import '../../core/widgets/app_icon_widget.dart';
import '../../core/widgets/jeda_card.dart';
import '../../core/widgets/jeda_button.dart';
import '../../core/widgets/jeda_badge.dart';

class CreateChallengeScreen extends ConsumerStatefulWidget {
  const CreateChallengeScreen({super.key});

  @override
  ConsumerState<CreateChallengeScreen> createState() => _CreateChallengeScreenState();
}

class _CreateChallengeScreenState extends ConsumerState<CreateChallengeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();

  List<Map<String, dynamic>> _installedApps = [];
  Map<String, dynamic>? _selectedApp;
  List<UserModel> _friends = [];
  final Set<String> _selectedFriendIds = {};

  int _durationHours = 24;
  String _challengeType = 'private'; // 'private' or 'global'
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final nativeBridge = ref.read(nativeBridgeServiceProvider);
      final api = ref.read(apiServiceProvider);

      final appsFuture = nativeBridge.getInstalledApps();
      final friendsFuture = api.getFriends();

      final apps = await appsFuture;
      final friends = await friendsFuture;

      apps.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));

      if (mounted) {
        setState(() {
          _installedApps = apps;
          _friends = friends;
          if (apps.isNotEmpty) _selectedApp = apps.first;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _submitChallenge() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedApp == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih aplikasi yang akan dikunci!'),
          backgroundColor: JedaColors.error,
        ),
      );
      return;
    }

    if (_challengeType == 'private' && _selectedFriendIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih minimal 1 teman untuk ditantang!'),
          backgroundColor: JedaColors.warning,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final api = ref.read(apiServiceProvider);

      await api.createChallenge(
        title: _titleController.text.trim(),
        description: _descController.text.trim().isEmpty ? null : _descController.text.trim(),
        packageName: _selectedApp!['packageName'] as String,
        appName: _selectedApp!['name'] as String,
        durationHours: _durationHours,
        challengeType: _challengeType,
        inviteUserIds: _challengeType == 'private' ? _selectedFriendIds.toList() : const [],
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tantangan berhasil dibuat! Menunggu persetujuan teman.'),
            backgroundColor: JedaColors.primary,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal membuat tantangan: ${e.toString().replaceFirst('Exception: ', '')}'),
            backgroundColor: JedaColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: JedaColors.background,
      appBar: AppBar(
        title: Text(
          'Buat Tantangan Baru',
          style: JedaTypography.heading3.copyWith(
            color: JedaColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: JedaColors.background,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
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
                        const SizedBox(height: 16),
                        JedaButton(
                          label: 'Coba Lagi',
                          isFullWidth: false,
                          onPressed: _loadInitialData,
                        ),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1. Judul Tantangan
                        JedaCard(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Judul Tantangan',
                                style: JedaTypography.labelBold.copyWith(fontSize: 13.5),
                              ),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _titleController,
                                style: JedaTypography.body,
                                decoration: InputDecoration(
                                  hintText: 'Contoh: 24 Jam Bebas Media Sosial',
                                  hintStyle: JedaTypography.bodySecondary.copyWith(color: JedaColors.textTertiary),
                                  filled: true,
                                  fillColor: JedaColors.surfaceSecondary,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  enabledBorder: const OutlineInputBorder(
                                    borderRadius: JedaRadii.borderR12,
                                    borderSide: BorderSide(color: JedaColors.border),
                                  ),
                                  focusedBorder: const OutlineInputBorder(
                                    borderRadius: JedaRadii.borderR12,
                                    borderSide: BorderSide(color: JedaColors.primary, width: 1.5),
                                  ),
                                ),
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) return 'Judul tantangan wajib diisi';
                                  return null;
                                },
                              ),
                              const SizedBox(height: 14),
                              Text(
                                'Catatan Komitmen (Opsional)',
                                style: JedaTypography.labelBold.copyWith(fontSize: 13.5),
                              ),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _descController,
                                maxLines: 2,
                                style: JedaTypography.body,
                                decoration: InputDecoration(
                                  hintText: 'Contoh: Yang pertama buka aplikasi traktir makan siang!',
                                  hintStyle: JedaTypography.bodySecondary.copyWith(color: JedaColors.textTertiary),
                                  filled: true,
                                  fillColor: JedaColors.surfaceSecondary,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  enabledBorder: const OutlineInputBorder(
                                    borderRadius: JedaRadii.borderR12,
                                    borderSide: BorderSide(color: JedaColors.border),
                                  ),
                                  focusedBorder: const OutlineInputBorder(
                                    borderRadius: JedaRadii.borderR12,
                                    borderSide: BorderSide(color: JedaColors.primary, width: 1.5),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // 2. Aplikasi yang Dikunci
                        JedaCard(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Aplikasi Target Kunci',
                                style: JedaTypography.labelBold.copyWith(fontSize: 13.5),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                                decoration: BoxDecoration(
                                  color: JedaColors.surfaceSecondary,
                                  borderRadius: JedaRadii.borderR12,
                                  border: Border.all(color: JedaColors.border),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<Map<String, dynamic>>(
                                    isExpanded: true,
                                    value: _selectedApp,
                                    items: _installedApps.map((app) {
                                      return DropdownMenuItem<Map<String, dynamic>>(
                                        value: app,
                                        child: Row(
                                          children: [
                                            AppIconWidget(
                                              packageName: app['packageName'] as String,
                                              size: 24,
                                              borderRadius: JedaRadii.borderR8,
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                app['name'] as String,
                                                style: JedaTypography.body.copyWith(
                                                  fontWeight: FontWeight.w600,
                                                  color: JedaColors.textPrimary,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: (val) => setState(() => _selectedApp = val),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // 3. Durasi
                        JedaCard(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Durasi Waktu Kunci',
                                style: JedaTypography.labelBold.copyWith(fontSize: 13.5),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                children: [3, 6, 12, 24, 48].map((hours) {
                                  final isSelected = _durationHours == hours;
                                  return ChoiceChip(
                                    label: Text('$hours Jam'),
                                    selected: isSelected,
                                    selectedColor: JedaColors.primary,
                                    backgroundColor: JedaColors.surfaceSecondary,
                                    side: BorderSide(
                                      color: isSelected ? JedaColors.primaryDark : JedaColors.border,
                                    ),
                                    labelStyle: JedaTypography.caption.copyWith(
                                      color: isSelected ? Colors.white : JedaColors.textPrimary,
                                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                    ),
                                    onSelected: (sel) {
                                      if (sel) setState(() => _durationHours = hours);
                                    },
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // 4. Jenis Tantangan
                        JedaCard(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Cakupan Tantangan',
                                style: JedaTypography.labelBold.copyWith(fontSize: 13.5),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: InkWell(
                                      onTap: () => setState(() => _challengeType = 'private'),
                                      borderRadius: JedaRadii.borderR12,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                                        decoration: BoxDecoration(
                                          color: _challengeType == 'private' ? JedaColors.primarySoft : JedaColors.surfaceSecondary,
                                          borderRadius: JedaRadii.borderR12,
                                          border: Border.all(
                                            color: _challengeType == 'private' ? JedaColors.primary : JedaColors.border,
                                            width: _challengeType == 'private' ? 1.5 : 1,
                                          ),
                                        ),
                                        child: Column(
                                          children: [
                                            Icon(
                                              Icons.group_outlined,
                                              color: _challengeType == 'private' ? JedaColors.primary : JedaColors.textSecondary,
                                              size: 22,
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              'Tantangan Teman',
                                              style: JedaTypography.caption.copyWith(
                                                fontWeight: FontWeight.w600,
                                                color: _challengeType == 'private' ? JedaColors.primaryDark : JedaColors.textPrimary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: InkWell(
                                      onTap: () => setState(() => _challengeType = 'global'),
                                      borderRadius: JedaRadii.borderR12,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                                        decoration: BoxDecoration(
                                          color: _challengeType == 'global' ? JedaColors.primarySoft : JedaColors.surfaceSecondary,
                                          borderRadius: JedaRadii.borderR12,
                                          border: Border.all(
                                            color: _challengeType == 'global' ? JedaColors.primary : JedaColors.border,
                                            width: _challengeType == 'global' ? 1.5 : 1,
                                          ),
                                        ),
                                        child: Column(
                                          children: [
                                            Icon(
                                              Icons.public_outlined,
                                              color: _challengeType == 'global' ? JedaColors.primary : JedaColors.textSecondary,
                                              size: 22,
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              'Tantangan Publik',
                                              style: JedaTypography.caption.copyWith(
                                                fontWeight: FontWeight.w600,
                                                color: _challengeType == 'global' ? JedaColors.primaryDark : JedaColors.textPrimary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // 5. Undang Teman (Jika Private)
                        if (_challengeType == 'private') ...[
                          JedaCard(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Pilih Teman yang Ditantang',
                                      style: JedaTypography.labelBold.copyWith(fontSize: 13.5),
                                    ),
                                    JedaBadge(
                                      label: '${_selectedFriendIds.length} Dipilih',
                                      variant: _selectedFriendIds.isNotEmpty ? JedaBadgeVariant.success : JedaBadgeVariant.neutral,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                if (_friends.isEmpty)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    child: Center(
                                      child: Column(
                                        children: [
                                          const Icon(Icons.people_outline_rounded, color: JedaColors.textTertiary, size: 36),
                                          const SizedBox(height: 6),
                                          Text(
                                            'Belum ada teman terhubung.\nIkuti teman terlebih dahulu di tab Teman.',
                                            textAlign: TextAlign.center,
                                            style: JedaTypography.caption.copyWith(color: JedaColors.textSecondary),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                else
                                  ListView.separated(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    itemCount: _friends.length,
                                    separatorBuilder: (context, i) => const Divider(height: 1, color: JedaColors.borderSubtle),
                                    itemBuilder: (context, index) {
                                      final friend = _friends[index];
                                      final isSelected = _selectedFriendIds.contains(friend.id);

                                      return CheckboxListTile(
                                        value: isSelected,
                                        activeColor: JedaColors.primary,
                                        contentPadding: EdgeInsets.zero,
                                        title: Text(
                                          friend.name,
                                          style: JedaTypography.labelBold.copyWith(fontSize: 13.5),
                                        ),
                                        subtitle: Text(
                                          '@${friend.username} • ${friend.currentStreakDays} hari streak',
                                          style: JedaTypography.caption.copyWith(color: JedaColors.textSecondary),
                                        ),
                                        secondary: CircleAvatar(
                                          radius: 16,
                                          backgroundColor: JedaColors.primarySoft,
                                          child: Text(
                                            friend.name.isNotEmpty ? friend.name.substring(0, 1).toUpperCase() : 'U',
                                            style: JedaTypography.caption.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: JedaColors.primary,
                                            ),
                                          ),
                                        ),
                                        onChanged: (val) {
                                          setState(() {
                                            if (val == true) {
                                              _selectedFriendIds.add(friend.id);
                                            } else {
                                              _selectedFriendIds.remove(friend.id);
                                            }
                                          });
                                        },
                                      );
                                    },
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],

                        // Tombol Submit
                        JedaButton(
                          label: 'Mulai Tantangan Bersama',
                          variant: JedaButtonVariant.primary,
                          isLoading: _isSubmitting,
                          onPressed: _submitChallenge,
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
    );
  }
}
