# Jeda — Project State

## Status Fase
- [x] Fase 0: Inisialisasi proyek
- [x] Fase 1: Models & Storage
- [x] Fase 2: Native Kotlin Bridge
- [x] Fase 3: UI Utama
- [x] Fase 4: Edukasi & Web Filter
- [x] Fitur Baru: Kuota Harian (Daily Time Budget) & Pas Darurat (Emergency Pass Friction)
- [ ] Fase 5: Build & Deploy

## Identitas App
- Nama app: Jeda
- Package: com.mindfullock.app
- Channel MethodChannel: "com.mindfullock/control"
- Channel EventChannel: "com.mindfullock/app_events"

## Keputusan Teknis
- State management: Riverpod
- Database: Hive (lokal, zero cloud)
- Native bridge: MethodChannel "com.mindfullock/control" + EventChannel "com.mindfullock/app_events"
- Web filter: VpnService lokal + DNS upstream 1.1.1.3
- Min SDK: 31 (Android 12)

## Filosofi App
Teman sadar, bukan penjara digital. Nama app: Jeda.
Tone empatik, bahasa Indonesia, tidak ada desain menakutkan.
Friction psikologis (countdown + refleksi), bukan hard lock absolut.

## Fitur Tambahan Terimplementasi: Kuota Harian & Pas Darurat
1. **Model `QuotaEntry` & Hive Storage**:
   - Grup aplikasi dengan jatah waktu harian (`dailyQuotaMinutes`).
   - Reset otomatis tiap pergantian hari (pukul 00:00).
   - Pengelompokan stok **Pas Darurat** (`emergencyTickets`, default 2 tiket / minggu).
2. **Dynamic Overlay & Friction Flow**:
   - Layar Overlay Kotlin menampilkan pesan khusus kuota habis.
   - Pemicuan Pas Darurat menyertakan **Cooling-off Countdown 90 detik** sebelum memberikan akses darurat sementara selama 5 menit.
3. **Flutter UI**:
   - [AddQuotaScreen](file:///D:/Jeda/lib/features/lock_manager/add_quota_screen.dart): Antarmuka memilih grup aplikasi & batas waktu harian.
   - [DashboardScreen](file:///D:/Jeda/lib/features/dashboard/dashboard_screen.dart): Menampilkan *Progress Bar* Kuota Harian, sisa tiket darurat, serta modal opsi pembuatan fokus baru.

## Struktur Folder
- lib/core/models/ (LockEntry, BlockedDomain, QuotaEntry)
- lib/core/services/ (StorageService, NativeBridgeService)
- lib/features/dashboard/ (DashboardScreen)
- lib/features/lock_manager/ (AddLockScreen, AddQuotaScreen)
- lib/features/education/ (EducationScreen)
- lib/features/settings/ (SettingsScreen, UninstallFrictionScreen)
- lib/features/onboarding/ (PermissionOnboardingScreen)
- assets/education/articles/

## File yang Sudah Ada
- pubspec.yaml (name: jeda, semua dependency lengkap)
- android/app/build.gradle.kts (namespace & applicationId: com.mindfullock.app)
- android/app/src/main/AndroidManifest.xml (semua permission + service stubs lengkap)
- android/app/src/main/res/xml/file_paths.xml
- lib/main.dart (dengan routing Onboarding -> Dashboard)
- lib/core/models/lock_entry.dart & .g.dart
- lib/core/models/quota_entry.dart & .g.dart
- lib/core/models/blocked_domain.dart & .g.dart
- lib/core/services/storage_service.dart
- android/app/src/main/kotlin/com/mindfullock/app/MainActivity.kt
- android/app/src/main/kotlin/com/mindfullock/app/UsageStatsHelper.kt
- android/app/src/main/kotlin/com/mindfullock/app/OverlayManager.kt
- android/app/src/main/kotlin/com/mindfullock/app/BlockRulesManager.kt
- android/app/src/main/kotlin/com/mindfullock/app/AppMonitorService.kt
- android/app/src/main/kotlin/com/mindfullock/app/DnsFilterService.kt
- lib/core/services/native_bridge_service.dart
- lib/features/onboarding/permission_onboarding_screen.dart
- lib/features/dashboard/dashboard_screen.dart
- lib/features/lock_manager/add_lock_screen.dart
- lib/features/lock_manager/add_quota_screen.dart
- lib/features/education/education_screen.dart
- lib/features/settings/settings_screen.dart
- assets/education/index.html
- assets/education/reflection.html
- assets/education/articles/doomscrolling.html
- assets/education/articles/habit_replacement.html
- assets/education/articles/triggers.html
- PROJECT_STATE.md
- PROJECT_PROMPTS.md

## Catatan AndroidManifest
- android:label "Jeda"
- Service stubs AppMonitorService dan DnsFilterService sudah ada
- FileProvider sudah dikonfigurasi

## Catatan itelOS
- Device: itel S23, Android 12 (API 31), itelOS V8.6.0
- itelOS punya aggressive battery killer
- Intent battery settings: coba "com.itel.powermanager" dulu, fallback ke ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS
- Overlay dan Usage Access harus grant manual di Settings

## Fase Berikutnya
Fase 5: Build & Deploy. Persiapan rilis APK. Prompt ada di PROJECT_PROMPTS.md.