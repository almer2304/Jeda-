import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/native_bridge_service.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/theme/jeda_colors.dart';
import '../../core/theme/jeda_radii.dart';
import '../../core/theme/jeda_typography.dart';
import '../../core/widgets/jeda_badge.dart';
import '../../core/widgets/jeda_button.dart';
import '../../core/widgets/jeda_card.dart';
import '../auth/login_screen.dart';
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
    Future.microtask(() {
      _refreshPermissions();
      ref.read(authStateProvider.notifier).checkCurrentUser();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    ref.read(authStateProvider.notifier).checkCurrentUser();
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
      backgroundColor: JedaColors.background,
      appBar: AppBar(
        title: const Text('Pengaturan', style: JedaTypography.heading2),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          _buildSectionHeader('Akun & Sinkronisasi Cloud'),
          Consumer(
            builder: (context, ref, child) {
              final authState = ref.watch(authStateProvider);
              return authState.when(
                data: (user) {
                  if (user != null) {
                    return JedaCard(
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 50,
                                height: 50,
                                decoration: const BoxDecoration(
                                  color: JedaColors.primarySoft,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    user.name.isNotEmpty ? user.name.substring(0, 1).toUpperCase() : 'U',
                                    style: JedaTypography.heading3.copyWith(color: JedaColors.primaryDark),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(user.name, style: JedaTypography.labelBold),
                                    Text(
                                      '@${user.username} • ${user.email}',
                                      style: JedaTypography.caption,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 6),
                                    Wrap(
                                      spacing: 6,
                                      children: [
                                        JedaBadge(
                                          label: '${user.totalPoints} Poin',
                                          variant: JedaBadgeVariant.neutral,
                                        ),
                                        JedaBadge(
                                          label: '${user.currentStreakDays} Hari Streak',
                                          variant: JedaBadgeVariant.success,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              TextButton.icon(
                                onPressed: () {
                                  ref.read(authStateProvider.notifier).refreshProfile();
                                },
                                icon: const Icon(Icons.refresh, size: 16, color: JedaColors.primary),
                                label: const Text('Sinkron Profil'),
                              ),
                              TextButton.icon(
                                onPressed: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      shape: const RoundedRectangleBorder(borderRadius: JedaRadii.borderR16),
                                      title: const Text('Keluar Akun', style: JedaTypography.heading3),
                                      content: const Text(
                                        'Apakah Anda yakin ingin keluar? Pengaturan lokal Anda tetap aman di perangkat ini.',
                                        style: JedaTypography.body,
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(ctx, false),
                                          child: const Text('Batal'),
                                        ),
                                        TextButton(
                                          onPressed: () => Navigator.pop(ctx, true),
                                          style: TextButton.styleFrom(foregroundColor: JedaColors.error),
                                          child: const Text('Keluar'),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirm == true) {
                                    await ref.read(authStateProvider.notifier).logout();
                                  }
                                },
                                icon: const Icon(Icons.logout, size: 16, color: JedaColors.error),
                                label: const Text('Keluar Akun', style: TextStyle(color: JedaColors.error)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  } else {
                    return JedaCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Mode Mandiri (Offline)', style: JedaTypography.labelBold),
                          const SizedBox(height: 4),
                          const Text(
                            'Data disimpan lokal di perangkat. Masuk akun bila ingin berpartisipasi dalam tantangan komunitas dan papan peringkat.',
                            style: JedaTypography.caption,
                          ),
                          const SizedBox(height: 14),
                          JedaButton(
                            label: 'Masuk / Daftar Akun',
                            height: 44,
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (context) => const LoginScreen()),
                              );
                            },
                          ),
                        ],
                      ),
                    );
                  }
                },
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: CircularProgressIndicator(strokeWidth: 2.2, color: JedaColors.primary),
                  ),
                ),
                error: (e, _) => JedaCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Gagal Memuat Akun Cloud', style: JedaTypography.labelBold),
                      const SizedBox(height: 4),
                      Text(
                        e.toString().replaceFirst('Exception: ', ''),
                        style: JedaTypography.caption,
                      ),
                      const SizedBox(height: 12),
                      JedaButton(
                        label: 'Coba Lagi',
                        height: 40,
                        variant: JedaButtonVariant.secondary,
                        onPressed: () => ref.read(authStateProvider.notifier).checkCurrentUser(),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 24),
          _buildSectionHeader('Status Izin Sistem'),

          JedaCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: FutureBuilder<Map<String, bool>>(
              future: _permissionsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(strokeWidth: 2.2, color: JedaColors.primary),
                    ),
                  );
                }
                final permissions = snapshot.data ?? {};
                return Column(
                  children: [
                    _buildPermissionItem(
                      'Akses Data Penggunaan',
                      permissions['usage'] ?? false,
                      'usage',
                    ),
                    const Divider(),
                    _buildPermissionItem(
                      'Tampil di Atas Aplikasi Lain',
                      permissions['overlay'] ?? false,
                      'overlay',
                    ),
                    const Divider(),
                    _buildPermissionItem(
                      'Pengecualian Penghemat Baterai',
                      permissions['battery'] ?? false,
                      'battery',
                    ),
                    const Divider(),
                    _buildPermissionItem(
                      'Mode Bodyguard (Admin Perangkat)',
                      permissions['deviceAdmin'] ?? false,
                      'deviceAdmin',
                    ),
                    const Divider(),
                    _buildPermissionItem(
                      'Layanan Aksesibilitas (Deteksi App)',
                      permissions['accessibility'] ?? false,
                      'accessibility',
                    ),
                  ],
                );
              },
            ),
          ),

          const SizedBox(height: 24),
          _buildSectionHeader('Pencopotan Aplikasi'),
          JedaCard(
            padding: EdgeInsets.zero,
            child: ListTile(
              leading: const Icon(Icons.shield_outlined, color: JedaColors.error),
              title: const Text('Prosedur Pencopotan Jeda', style: JedaTypography.labelBold),
              subtitle: const Text(
                'Mencabut hak izin Administrator Perangkat secara sadar dan aman.',
                style: JedaTypography.caption,
              ),
              trailing: const Icon(Icons.chevron_right, color: JedaColors.textTertiary),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const UninstallFrictionScreen()),
                ).then((_) => _refreshPermissions());
              },
            ),
          ),

          const SizedBox(height: 24),
          _buildSectionHeader('Filter Konten (DNS)'),
          JedaCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Aktifkan Filter DNS Bersih', style: JedaTypography.labelBold),
                  subtitle: const Text(
                    'Menyaring akses situs judi dan konten berisiko secara lokal di perangkat tanpa server proxy.',
                    style: JedaTypography.caption,
                  ),
                  value: _isVpnEnabled,
                  activeThumbColor: JedaColors.primary,
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
              ],
            ),
          ),

          const SizedBox(height: 24),
          _buildSectionHeader('Tentang Aplikasi'),
          const JedaCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Jeda v1.0.0', style: JedaTypography.labelBold),
                SizedBox(height: 6),
                Text(
                  'Pemrosesan pembatasan berjalan 100% lokal pada perangkat. Jeda menghormati privasi penuh Anda tanpa pelacak latar belakang.',
                  style: JedaTypography.caption,
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: JedaTypography.labelBold.copyWith(color: JedaColors.textSecondary),
      ),
    );
  }

  Widget _buildPermissionItem(String title, bool isGranted, String type) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Icon(
        isGranted ? Icons.check_circle_outlined : Icons.warning_amber_rounded,
        color: isGranted ? JedaColors.success : JedaColors.warning,
        size: 20,
      ),
      title: Text(title, style: JedaTypography.body),
      trailing: isGranted
          ? const JedaBadge(
              label: 'Aktif',
              variant: JedaBadgeVariant.success,
            )
          : TextButton(
              onPressed: () async {
                await ref.read(nativeBridgeServiceProvider).openSettingsFor(type);
                Future.delayed(const Duration(seconds: 1), _refreshPermissions);
              },
              child: const Text('Aktifkan', style: TextStyle(color: JedaColors.warning, fontWeight: FontWeight.w600)),
            ),
    );
  }
}
