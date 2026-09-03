import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/native_bridge_service.dart';
import 'uninstall_friction_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _isVpnEnabled = false;
  Future<Map<String, bool>>? _permissionsFuture;

  @override
  void initState() {
    super.initState();
    // We delay the first fetch slightly to let the widget mount and ref be ready
    Future.microtask(() {
      _refreshPermissions();
    });
  }

  void _refreshPermissions() {
    setState(() {
      _permissionsFuture = ref.read(nativeBridgeServiceProvider).checkAllPermissions().then((permissions) {
        if (mounted) {
          setState(() {
            _isVpnEnabled = permissions['vpn'] ?? false;
          });
        }
        return permissions;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E8),
      appBar: AppBar(
        title: const Text('Pengaturan', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFFF5F0E8),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionHeader('Status Izin Sistem'),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: FutureBuilder<Map<String, bool>>(
                future: _permissionsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator(color: Color(0xFF87A878)),
                      ),
                    );
                  }
                  final permissions = snapshot.data ?? {};
                  return Column(
                    children: [
                      _buildPermissionItem(
                        'Akses Penggunaan',
                        permissions['usage'] ?? false,
                        'usage',
                      ),
                      const Divider(height: 1, indent: 16, endIndent: 16),
                      _buildPermissionItem(
                        'Tampil di Atas App Lain',
                        permissions['overlay'] ?? false,
                        'overlay',
                      ),
                      const Divider(height: 1, indent: 16, endIndent: 16),
                      _buildPermissionItem(
                        'Pengecualian Baterai',
                        permissions['battery'] ?? false,
                        'battery',
                      ),
                      const Divider(height: 1, indent: 16, endIndent: 16),
                      _buildPermissionItem(
                        'Mode Bodyguard (Admin)',
                        permissions['deviceAdmin'] ?? false,
                        'deviceAdmin',
                      ),
                      const Divider(height: 1, indent: 16, endIndent: 16),
                      _buildPermissionItem(
                        'Cegah Hapus Paksa (Aksesibilitas)',
                        permissions['accessibility'] ?? false,
                        'accessibility',
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          _buildSectionHeader('Perlindungan Ekstra'),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.shield_outlined, color: Colors.redAccent),
                  title: const Text('Nonaktifkan Bodyguard (Uninstall)'),
                  subtitle: const Text(
                    'Melewati tahapan khusus untuk mematikan pelindung agar Jeda bisa dihapus.',
                    style: TextStyle(fontSize: 12),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const UninstallFrictionScreen()),
                    ).then((_) => _refreshPermissions());
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          _buildSectionHeader('Filter Web (VPN)'),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Aktifkan Filter DNS', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text(
                    'Memblokir akses ke situs judi dan konten dewasa menggunakan filter DNS lokal di perangkatmu.',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  value: _isVpnEnabled,
                  activeColor: const Color(0xFF87A878),
                  onChanged: (value) async {
                    setState(() {
                      _isVpnEnabled = value;
                    });
                    if (value) {
                      await ref.read(nativeBridgeServiceProvider).startVpnService();
                    } else {
                      await ref.read(nativeBridgeServiceProvider).stopVpnService();
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.public_off, color: Color(0xFF87A878)),
                  title: const Text('Kelola Domain Khusus'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    // TODO: Navigate to blocked domain manager
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Segera hadir')),
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          _buildSectionHeader('Tentang'),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: const Padding(
              padding: EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Jeda v1.0.0', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  SizedBox(height: 8),
                  Text(
                    'Semua data tersimpan di perangkatmu. Tidak ada informasi yang dikirim ke server manapun. Privasimu adalah prioritas.',
                    style: TextStyle(color: Colors.grey, height: 1.4),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 12),
      child: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2D2D2D)),
      ),
    );
  }

  Widget _buildPermissionItem(String title, bool isGranted, String type) {
    return ListTile(
      leading: Icon(
        isGranted ? Icons.check_circle : Icons.warning_amber_rounded,
        color: isGranted ? const Color(0xFF87A878) : Colors.orange,
      ),
      title: Text(title),
      trailing: isGranted
          ? const Text('Aktif', style: TextStyle(color: Color(0xFF87A878), fontWeight: FontWeight.bold))
          : TextButton(
              onPressed: () async {
                await ref.read(nativeBridgeServiceProvider).openSettingsFor(type);
                // We add a slight delay so when they return, we refresh the UI
                Future.delayed(const Duration(seconds: 1), _refreshPermissions);
              },
              child: const Text('Perbaiki', style: TextStyle(color: Colors.orange)),
            ),
    );
  }
}
