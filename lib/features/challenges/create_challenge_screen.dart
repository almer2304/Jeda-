import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/api_service.dart';
import '../../core/services/native_bridge_service.dart';
import '../../core/models/api_models.dart';

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
        const SnackBar(content: Text('Pilih aplikasi yang akan dikunci!'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    if (_challengeType == 'private' && _selectedFriendIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih minimal 1 teman untuk ditantang!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final api = ref.read(apiServiceProvider);
      await api.createChallenge(
        title: _titleController.text.trim(),
        description: _descController.text.trim(),
        packageName: _selectedApp!['packageName'] as String,
        appName: _selectedApp!['name'] as String,
        durationHours: _durationHours,
        challengeType: _challengeType,
        inviteUserIds: _selectedFriendIds.toList(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 Tantangan berhasil dibuat! Semangat berjuang bersama!'),
            backgroundColor: Color(0xFF87A878),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal membuat tantangan: ${e.toString().replaceFirst('Exception: ', '')}'),
            backgroundColor: Colors.redAccent,
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
      backgroundColor: const Color(0xFFF5F0E8),
      appBar: AppBar(
        title: const Text('Buat Tantangan Baru ⚔️', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFFF5F0E8),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF87A878)))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _loadInitialData,
                        child: const Text('Coba Lagi'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Judul Tantangan
                    const Text('Judul Tantangan', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _titleController,
                      decoration: InputDecoration(
                        hintText: 'Contoh: 24 Jam Bebas TikTok Bareng!',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Judul tantangan wajib diisi';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Deskripsi
                    const Text('Deskripsi (Opsional)', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _descController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: 'Yang pertama buka app kena denda / kalah!',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Pilih Aplikasi
                    const Text('Aplikasi yang Dikunci', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<Map<String, dynamic>>(
                          isExpanded: true,
                          value: _selectedApp,
                          items: _installedApps.map((app) {
                            return DropdownMenuItem<Map<String, dynamic>>(
                              value: app,
                              child: Text(
                                app['name'] as String,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                            );
                          }).toList(),
                          onChanged: (val) => setState(() => _selectedApp = val),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Durasi
                    const Text('Durasi Tantangan', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [3, 6, 12, 24, 48].map((hours) {
                        final isSelected = _durationHours == hours;
                        return ChoiceChip(
                          label: Text('$hours Jam'),
                          selected: isSelected,
                          selectedColor: const Color(0xFF87A878),
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : const Color(0xFF2D2D2D),
                            fontWeight: FontWeight.bold,
                          ),
                          onSelected: (sel) {
                            if (sel) setState(() => _durationHours = hours);
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),

                    // Jenis Tantangan
                    const Text('Tipe Tantangan', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => setState(() => _challengeType = 'private'),
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: _challengeType == 'private' ? const Color(0xFFEAF2E8) : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: _challengeType == 'private' ? const Color(0xFF87A878) : Colors.grey[300]!,
                                  width: 2,
                                ),
                              ),
                              child: Column(
                                children: const [
                                  Icon(Icons.group, color: Color(0xFF87A878)),
                                  SizedBox(height: 4),
                                  Text('Bersama Teman', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            onTap: () => setState(() => _challengeType = 'global'),
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: _challengeType == 'global' ? const Color(0xFFEAF2E8) : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: _challengeType == 'global' ? const Color(0xFF87A878) : Colors.grey[300]!,
                                  width: 2,
                                ),
                              ),
                              child: Column(
                                children: const [
                                  Icon(Icons.public, color: Color(0xFF87A878)),
                                  SizedBox(height: 4),
                                  Text('Tantangan Publik', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Undang Teman (Jika Private)
                    if (_challengeType == 'private') ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Undang Teman', style: TextStyle(fontWeight: FontWeight.bold)),
                          Text(
                            '${_selectedFriendIds.length} Dipilih',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF87A878), fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (_friends.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            children: const [
                              Icon(Icons.person_add_disabled_outlined, color: Colors.grey, size: 36),
                              SizedBox(height: 8),
                              Text(
                                'Kamu belum memiliki teman.',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Follow teman di menu Komunitas > Teman terlebih dahulu.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey, fontSize: 11),
                              ),
                            ],
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
                            itemCount: _friends.length,
                            separatorBuilder: (context, i) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final friend = _friends[index];
                              final isSelected = _selectedFriendIds.contains(friend.id);

                              return CheckboxListTile(
                                value: isSelected,
                                activeColor: const Color(0xFF87A878),
                                title: Text(friend.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text('@${friend.username} • 🔥 ${friend.currentStreakDays} Hari Streak'),
                                secondary: CircleAvatar(
                                  backgroundColor: const Color(0xFFEAF2E8),
                                  child: Text(
                                    friend.name.substring(0, 1).toUpperCase(),
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF87A878)),
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
                        ),
                      const SizedBox(height: 24),
                    ],

                    // Tombol Submit
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submitChallenge,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF87A878),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                              )
                            : const Text(
                                'Mulai Tantangan 🌱',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }
}
