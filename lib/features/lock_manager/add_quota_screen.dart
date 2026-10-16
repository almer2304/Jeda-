import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/models/quota_entry.dart';
import '../../core/services/native_bridge_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/theme/jeda_colors.dart';
import '../../core/theme/jeda_radii.dart';
import '../../core/theme/jeda_typography.dart';
import '../../core/widgets/app_icon_widget.dart';
import '../../core/widgets/jeda_badge.dart';
import '../../core/widgets/jeda_button.dart';

class AddQuotaScreen extends ConsumerStatefulWidget {
  final QuotaEntry? editingQuota;

  const AddQuotaScreen({super.key, this.editingQuota});

  @override
  ConsumerState<AddQuotaScreen> createState() => _AddQuotaScreenState();
}

class _AddQuotaScreenState extends ConsumerState<AddQuotaScreen> {
  final _groupNameController = TextEditingController();
  final _searchController = TextEditingController();
  final _goalController = TextEditingController();
  final _descriptionController = TextEditingController();

  List<Map<String, dynamic>> _installedApps = [];
  List<Map<String, dynamic>> _filteredApps = [];
  final Set<String> _selectedPackageNames = {};
  final Map<String, String> _selectedAppNames = {};

  bool _isLoading = true;
  String? _error;
  int _quotaMinutes = 60; // Default 1 hour

  bool get _isEditMode => widget.editingQuota != null;

  @override
  void initState() {
    super.initState();
    final editing = widget.editingQuota;
    if (editing != null) {
      _groupNameController.text = editing.groupName;
      _quotaMinutes = editing.dailyQuotaMinutes.clamp(15, 240);
      for (int i = 0; i < editing.packageNames.length; i++) {
        final pkg = editing.packageNames[i];
        _selectedPackageNames.add(pkg);
        _selectedAppNames[pkg] = i < editing.appNames.length ? editing.appNames[i] : pkg;
      }
      _goalController.text = editing.focusGoal ?? 'Membatasi pemakaian harian secara sadar';
      _descriptionController.text = editing.description ?? '';
    } else {
      _goalController.text = 'Membatasi pemakaian harian secara sadar';
      _descriptionController.text = 'Gunakan kuota harianmu dengan bijak, bukan sekadar pelarian saat bosan.';
    }
    _loadApps();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _groupNameController.dispose();
    _searchController.dispose();
    _goalController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadApps() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final nativeBridge = ref.read(nativeBridgeServiceProvider);
      final apps = await nativeBridge.getInstalledApps();
      apps.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));

      if (mounted) {
        setState(() {
          _installedApps = apps;
          _filteredApps = apps;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Gagal memuat daftar aplikasi perangkat.';
          _isLoading = false;
        });
      }
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredApps = _installedApps.where((app) {
        final name = (app['name'] as String).toLowerCase();
        return name.contains(query);
      }).toList();
    });
  }

  Future<void> _saveQuota() async {
    final groupName = _groupNameController.text.trim();
    if (groupName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Masukkan nama grup kuota terlebih dahulu.'),
          backgroundColor: JedaColors.error,
        ),
      );
      return;
    }

    if (_selectedPackageNames.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih minimal satu aplikasi untuk grup kuota ini.'),
          backgroundColor: JedaColors.error,
        ),
      );
      return;
    }

    final storage = ref.read(storageServiceProvider);
    final goalText = _goalController.text.trim();
    final descText = _descriptionController.text.trim();

    final entry = QuotaEntry(
      id: widget.editingQuota?.id ?? const Uuid().v4(),
      groupName: groupName,
      packageNames: _selectedPackageNames.toList(),
      appNames: _selectedPackageNames.map((pkg) => _selectedAppNames[pkg] ?? pkg).toList(),
      dailyQuotaMinutes: _quotaMinutes,
      usedTodaySeconds: widget.editingQuota?.usedTodaySeconds ?? 0,
      lastResetDate: widget.editingQuota?.lastResetDate ?? DateTime.now(),
      emergencyTickets: widget.editingQuota?.emergencyTickets ?? 2,
      lastTicketResetDate: widget.editingQuota?.lastTicketResetDate ?? DateTime.now(),
      activeEmergencyUntil: widget.editingQuota?.activeEmergencyUntil,
      focusGoal: goalText.isNotEmpty ? goalText : null,
      description: descText.isNotEmpty ? descText : null,
    );

    await storage.addQuota(entry);

    final activeRules = storage.getActiveRules();
    await ref.read(nativeBridgeServiceProvider).startMonitoring(activeRules);
    await ref.read(nativeBridgeServiceProvider).updateBlockedList(activeRules);

    if (mounted) {
      Navigator.of(context).pop(entry);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEditMode
              ? 'Perubahan kuota "$groupName" berhasil disimpan 🌱'
              : 'Aturan kuota harian berhasil disimpan'),
          backgroundColor: JedaColors.primaryDark,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  String _formatMinutes(int minutes) {
    if (minutes < 60) return '$minutes Menit';
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (mins == 0) return '$hours Jam';
    return '$hours Jam $mins Menit';
  }

  Future<void> _openGoalSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: JedaColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: JedaRadii.sheetTop),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              24,
              12,
              24,
              MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: JedaColors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const Text('Tujuan & Pengingat Kuota Harian', style: JedaTypography.heading3),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _goalController,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Tujuan Fokus (Goals)',
                      hintText: 'Contoh: Hanya cek pesan penting maksimal 1 jam sehari',
                      prefixIcon: Icon(Icons.flag_outlined, size: 18),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _descriptionController,
                    maxLines: 3,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Deskripsi / Pesan Pengingat Diri',
                      hintText: 'Pesan untuk dirimu saat kuota harian habis...',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 20),
                  JedaButton(
                    label: 'Simpan Tujuan',
                    variant: JedaButtonVariant.primary,
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return Scaffold(
      backgroundColor: JedaColors.background,
      appBar: AppBar(
        title: Text(
          _isEditMode ? 'Edit Kuota Harian' : 'Buat Kuota Harian',
          style: JedaTypography.heading3,
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Group Name Input
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
            child: TextField(
              controller: _groupNameController,
              decoration: const InputDecoration(
                labelText: 'Nama Grup Kuota',
                hintText: 'Contoh: Media Sosial & Hiburan',
              ),
            ),
          ),

          // Search Field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 4.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Cari aplikasi...',
                prefixIcon: const Icon(Icons.search, size: 20, color: JedaColors.textTertiary),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
              ),
            ),
          ),

          // Selection counter
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Pilih Aplikasi Terkait',
                  style: JedaTypography.caption.copyWith(color: JedaColors.textPrimary, fontWeight: FontWeight.w600),
                ),
                JedaBadge(
                  label: '${_selectedPackageNames.length} dipilih',
                  variant: _selectedPackageNames.isNotEmpty ? JedaBadgeVariant.success : JedaBadgeVariant.neutral,
                ),
              ],
            ),
          ),

          // App List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2.2, color: JedaColors.primary))
                : _error != null
                    ? Center(child: Text(_error!, style: JedaTypography.bodySecondary))
                    : ListView.builder(
                        itemCount: _filteredApps.length,
                        itemBuilder: (context, index) {
                          final app = _filteredApps[index];
                          final pkg = app['packageName'] as String;
                          final name = app['name'] as String;
                          final isSelected = _selectedPackageNames.contains(pkg);

                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                            leading: AppIconWidget(
                              packageName: pkg,
                              size: 38,
                              backgroundColor: isSelected ? JedaColors.primarySoft : JedaColors.surfaceSecondary,
                              fallbackIconColor: isSelected ? JedaColors.primaryDark : JedaColors.textSecondary,
                            ),
                            title: Text(name, style: JedaTypography.labelBold),
                            subtitle: Text(
                              pkg,
                              style: JedaTypography.caption,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Checkbox(
                              value: isSelected,
                              activeColor: JedaColors.primary,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                              onChanged: (bool? val) {
                                setState(() {
                                  if (val == true) {
                                    _selectedPackageNames.add(pkg);
                                    _selectedAppNames[pkg] = name;
                                  } else {
                                    _selectedPackageNames.remove(pkg);
                                    _selectedAppNames.remove(pkg);
                                  }
                                });
                              },
                            ),
                            onTap: () {
                              setState(() {
                                if (isSelected) {
                                  _selectedPackageNames.remove(pkg);
                                  _selectedAppNames.remove(pkg);
                                } else {
                                  _selectedPackageNames.add(pkg);
                                  _selectedAppNames[pkg] = name;
                                }
                              });
                            },
                          );
                        },
                      ),
          ),

          // Bottom Configuration Panel
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: 20,
              vertical: isKeyboardOpen ? 12 : 18,
            ),
            decoration: const BoxDecoration(
              color: JedaColors.surface,
              borderRadius: JedaRadii.sheetTop,
              border: Border(top: BorderSide(color: JedaColors.border)),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isKeyboardOpen) ...[
                    InkWell(
                      onTap: _openGoalSheet,
                      borderRadius: JedaRadii.borderR12,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                        decoration: BoxDecoration(
                          color: JedaColors.primarySoft.withValues(alpha: 0.55),
                          borderRadius: JedaRadii.borderR12,
                          border: Border.all(color: JedaColors.primary.withValues(alpha: 0.45)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.psychology_outlined, size: 18, color: JedaColors.primaryDark),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _goalController.text.trim().isNotEmpty
                                    ? '🎯 Tujuan: ${_goalController.text.trim()}'
                                    : '🎯 Tetapkan Tujuan & Pengingat Kuota',
                                style: JedaTypography.caption.copyWith(
                                  color: JedaColors.primaryDark,
                                  fontWeight: FontWeight.w700,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const Icon(Icons.edit_note_rounded, size: 18, color: JedaColors.primaryDark),
                          ],
                        ),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Batas Kuota Harian', style: JedaTypography.labelBold),
                        Text(
                          _formatMinutes(_quotaMinutes),
                          style: JedaTypography.heading3.copyWith(color: JedaColors.primaryDark),
                        ),
                      ],
                    ),
                    Slider(
                      value: _quotaMinutes.toDouble(),
                      min: 15,
                      max: 240, // 4 jam maksimal
                      divisions: 15, // kelipatan 15 menit
                      activeColor: JedaColors.primary,
                      inactiveColor: JedaColors.surfaceSecondary,
                      onChanged: (val) {
                        setState(() {
                          _quotaMinutes = val.toInt();
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                  ],
                  JedaButton(
                    label: _selectedPackageNames.isEmpty
                        ? 'Pilih Minimal Satu Aplikasi'
                        : (_isEditMode ? 'Simpan Perubahan Kuota' : 'Simpan Kuota Harian'),
                    onPressed: _selectedPackageNames.isEmpty ? null : _saveQuota,
                    variant: JedaButtonVariant.primary,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
