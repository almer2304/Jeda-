import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/models/quota_entry.dart';
import '../../core/services/native_bridge_service.dart';
import '../../core/services/storage_service.dart';

class AddQuotaScreen extends ConsumerStatefulWidget {
  const AddQuotaScreen({super.key});

  @override
  ConsumerState<AddQuotaScreen> createState() => _AddQuotaScreenState();
}

class _AddQuotaScreenState extends ConsumerState<AddQuotaScreen> {
  final _groupNameController = TextEditingController();
  final _searchController = TextEditingController();

  List<Map<String, dynamic>> _installedApps = [];
  List<Map<String, dynamic>> _filteredApps = [];
  final Set<String> _selectedPackageNames = {};
  final Map<String, String> _selectedAppNames = {};

  bool _isLoading = true;
  String? _error;
  int _quotaMinutes = 60; // Default 1 hour

  @override
  void initState() {
    super.initState();
    _loadApps();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _groupNameController.dispose();
    _searchController.dispose();
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
          _error = 'Gagal memuat daftar aplikasi: $e';
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
    if (_groupNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nama grup tidak boleh kosong!'), backgroundColor: Colors.red),
      );
      return;
    }

    if (_selectedPackageNames.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih setidaknya 1 aplikasi!'), backgroundColor: Colors.red),
      );
      return;
    }

    final storage = ref.read(storageServiceProvider);
    final entry = QuotaEntry(
      id: const Uuid().v4(),
      groupName: _groupNameController.text.trim(),
      packageNames: _selectedPackageNames.toList(),
      appNames: _selectedPackageNames.map((pkg) => _selectedAppNames[pkg] ?? pkg).toList(),
      dailyQuotaMinutes: _quotaMinutes,
      lastResetDate: DateTime.now(),
      emergencyTickets: 2,
      lastTicketResetDate: DateTime.now(),
    );

    await storage.addQuota(entry);

    final activeRules = storage.getActiveRules();
    ref.read(nativeBridgeServiceProvider).startMonitoring(activeRules);

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kuota Harian disimpan 🌱'),
          backgroundColor: Color(0xFF87A878),
          duration: Duration(seconds: 2),
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

  @override
  Widget build(BuildContext context) {
    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E8),
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text('Buat Kuota Harian 🌱', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFFF5F0E8),
        elevation: 0,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Nama Grup Kuota',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF2D2D2D)),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _groupNameController,
                  decoration: InputDecoration(
                    hintText: 'Contoh: Sosmed & Hiburan',
                    filled: true,
                    fillColor: Colors.white,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Cari aplikasi...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Text(
                  'Terpilih: ${_selectedPackageNames.length} aplikasi',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF87A878)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF87A878)))
                : _error != null
                    ? Center(child: Text(_error!))
                    : ListView.builder(
                        itemCount: _filteredApps.length,
                        itemBuilder: (context, index) {
                          final app = _filteredApps[index];
                          final pkg = app['packageName'] as String;
                          final name = app['name'] as String;
                          final isSelected = _selectedPackageNames.contains(pkg);

                          return CheckboxListTile(
                            value: isSelected,
                            activeColor: const Color(0xFF87A878),
                            title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text(pkg, style: const TextStyle(fontSize: 12, color: Colors.grey)),
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
                          );
                        },
                      ),
          ),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: 20,
              vertical: isKeyboardOpen ? 12 : 20,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                )
              ],
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isKeyboardOpen) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Jatah Waktu Harian:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        Text(
                          _formatMinutes(_quotaMinutes),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Color(0xFF87A878)),
                        ),
                      ],
                    ),
                    Slider(
                      value: _quotaMinutes.toDouble(),
                      min: 15,
                      max: 240, // 4 hours max
                      divisions: 15, // 15-minute increments
                      activeColor: const Color(0xFF87A878),
                      onChanged: (val) {
                        setState(() {
                          _quotaMinutes = val.toInt();
                        });
                      },
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F0E8),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.lock_outline, color: Color(0xFF87A878), size: 18),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "Termasuk 2 Pas Darurat / minggu. Aturan yang diset tidak dapat dihapus 🔒",
                              style: TextStyle(fontSize: 11, color: Color(0xFF2D2D2D)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  SizedBox(
                    width: double.infinity,
                    height: isKeyboardOpen ? 46 : 52,
                    child: ElevatedButton(
                      onPressed: _selectedPackageNames.isEmpty ? null : _saveQuota,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF87A878),
                        disabledBackgroundColor: Colors.grey[300],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        'Simpan Kuota Harian 🌱',
                        style: TextStyle(fontSize: isKeyboardOpen ? 15 : 17, fontWeight: FontWeight.bold),
                      ),
                    ),
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
