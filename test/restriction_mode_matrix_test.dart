import 'package:flutter_test/flutter_test.dart';

/// Simulates the exact rule evaluation logic performed by native Android BlockRulesManager.kt
bool simulateNativeIsAppBlocked({
  required List<Map<String, dynamic>> rules,
  required String packageName,
  required DateTime currentTime,
}) {
  final currentDay = currentTime.weekday == 7 ? 1 : currentTime.weekday + 1; // Java Calendar convention: 1=Sun..7=Sat
  final currentMin = currentTime.hour * 60 + currentTime.minute;
  final currentMillis = currentTime.millisecondsSinceEpoch;

  for (final rule in rules) {
    if (rule['packageName'] != packageName) continue;

    final isQuota = rule['isQuota'] == true;
    if (isQuota) {
      final emergencyUntil = (rule['emergencyUntilMillis'] as num?)?.toInt() ?? 0;
      if (currentMillis < emergencyUntil) {
        // Emergency ticket bypasses this quota rule
        continue;
      }
      final dailyQuotaSec = (rule['dailyQuotaSeconds'] as num?)?.toInt() ?? 0;
      final usedSec = (rule['usedTodaySeconds'] as num?)?.toInt() ?? 0;
      if (usedSec >= dailyQuotaSec) {
        return true;
      }
      continue;
    }

    final isScheduled = rule['isScheduled'] == true;
    if (isScheduled) {
      final startMin = ((rule['startHour'] as num).toInt() * 60) + (rule['startMinute'] as num).toInt();
      final endMin = ((rule['endHour'] as num).toInt() * 60) + (rule['endMinute'] as num).toInt();
      final days = (rule['days'] as List).cast<int>();

      if (startMin <= endMin) {
        if (days.contains(currentDay) && currentMin >= startMin && currentMin <= endMin) {
          return true;
        }
      } else {
        // Crosses midnight
        if (days.contains(currentDay) && currentMin >= startMin) {
          return true;
        }
        final prevDay = currentDay == 1 ? 7 : currentDay - 1;
        if (days.contains(prevDay) && currentMin <= endMin) {
          return true;
        }
      }
    } else {
      // Detox / Instant Lock
      final endMillis = (rule['endTimeMillis'] as num?)?.toInt() ?? 0;
      if (endMillis == 0 || currentMillis < endMillis) {
        return true;
      }
    }
  }

  return false;
}

void main() {
  group('Audit & Validasi Interaksi Tiga Mode Pembatasan (Detox, Schedule, Quota)', () {
    const pkg = 'com.instagram.android';

    // -------------------------------------------------------------------------
    // Kombinasi 1: Detox Aktif + Jadwal Aktif
    // -------------------------------------------------------------------------
    test('Kombinasi 1: Detox Aktif + Jadwal Aktif -> Diblokir', () {
      final now = DateTime(2026, 10, 19, 10, 0); // Senin 10:00
      final rules = <Map<String, dynamic>>[
        // Detox aktif sampai 2 jam ke depan
        {
          'packageName': pkg,
          'isScheduled': false,
          'endTimeMillis': now.add(const Duration(hours: 2)).millisecondsSinceEpoch,
        },
        // Jadwal aktif 09:00 - 17:00 pada hari Senin (Java day 2)
        {
          'packageName': pkg,
          'isScheduled': true,
          'startHour': 9,
          'startMinute': 0,
          'endHour': 17,
          'endMinute': 0,
          'days': [2],
        },
      ];

      final isBlocked = simulateNativeIsAppBlocked(
        rules: rules,
        packageName: pkg,
        currentTime: now,
      );
      expect(isBlocked, isTrue);
    });

    // -------------------------------------------------------------------------
    // Kombinasi 2: Jadwal Aktif + Kuota Masih Tersedia -> Diblokir oleh Jadwal
    // -------------------------------------------------------------------------
    test('Kombinasi 2: Jadwal Aktif + Kuota Masih Tersedia -> Tetap Diblokir oleh Jadwal', () {
      final now = DateTime(2026, 10, 19, 10, 0); // Senin 10:00 (Jam kerja)
      final rules = <Map<String, dynamic>>[
        // Jadwal aktif 09:00 - 12:00
        {
          'packageName': pkg,
          'isScheduled': true,
          'startHour': 9,
          'startMinute': 0,
          'endHour': 12,
          'endMinute': 0,
          'days': [2], // Senin
        },
        // Kuota harian 60 menit, baru terpakai 10 menit (tersisa 50 menit)
        {
          'packageName': pkg,
          'isScheduled': false,
          'isQuota': true,
          'dailyQuotaSeconds': 3600,
          'usedTodaySeconds': 600,
          'emergencyUntilMillis': 0,
        },
      ];

      // Meskipun sisa kuota masih banyak, aturan jadwal wajib dihormati
      final isBlocked = simulateNativeIsAppBlocked(
        rules: rules,
        packageName: pkg,
        currentTime: now,
      );
      expect(isBlocked, isTrue);
    });

    // -------------------------------------------------------------------------
    // Kombinasi 3: Jadwal Tidak Aktif + Kuota Habis -> Diblokir oleh Kuota
    // -------------------------------------------------------------------------
    test('Kombinasi 3: Jadwal Tidak Aktif + Kuota Habis -> Diblokir oleh Kuota', () {
      final now = DateTime(2026, 10, 19, 13, 0); // Senin 13:00 (Di luar jam jadwal 09:00-12:00)
      final rules = <Map<String, dynamic>>[
        // Jadwal tidak aktif pada jam ini
        {
          'packageName': pkg,
          'isScheduled': true,
          'startHour': 9,
          'startMinute': 0,
          'endHour': 12,
          'endMinute': 0,
          'days': [2],
        },
        // Kuota harian 30 menit (1800 detik), sudah terpakai 1800 detik (Habis)
        {
          'packageName': pkg,
          'isScheduled': false,
          'isQuota': true,
          'dailyQuotaSeconds': 1800,
          'usedTodaySeconds': 1800,
          'emergencyUntilMillis': 0,
        },
      ];

      final isBlocked = simulateNativeIsAppBlocked(
        rules: rules,
        packageName: pkg,
        currentTime: now,
      );
      expect(isBlocked, isTrue);
    });

    // -------------------------------------------------------------------------
    // Kombinasi 4: Kuota Habis + Tiket Darurat Aktif (Di Luar Jadwal) -> Diizinkan
    // -------------------------------------------------------------------------
    test('Kombinasi 4: Kuota Habis + Tiket Darurat Aktif (Di Luar Jadwal) -> Akses Diizinkan', () {
      final now = DateTime(2026, 10, 19, 13, 0); // Senin 13:00 (Di luar jadwal)
      final emergencyExpiry = now.add(const Duration(minutes: 5)).millisecondsSinceEpoch;

      final rules = <Map<String, dynamic>>[
        // Jadwal pagi sudah selesai
        {
          'packageName': pkg,
          'isScheduled': true,
          'startHour': 9,
          'startMinute': 0,
          'endHour': 12,
          'endMinute': 0,
          'days': [2],
        },
        // Kuota habis, namun tiket darurat aktif untuk 5 menit
        {
          'packageName': pkg,
          'isScheduled': false,
          'isQuota': true,
          'dailyQuotaSeconds': 1800,
          'usedTodaySeconds': 1800,
          'emergencyUntilMillis': emergencyExpiry,
        },
      ];

      final isBlocked = simulateNativeIsAppBlocked(
        rules: rules,
        packageName: pkg,
        currentTime: now,
      );
      // Akses terbuka sementara berkat tiket darurat
      expect(isBlocked, isFalse);

      // Setelah 6 menit, tiket kedaluwarsa -> Kembali diblokir
      final sixMinsLater = now.add(const Duration(minutes: 6));
      final isBlockedAfterExpiry = simulateNativeIsAppBlocked(
        rules: rules,
        packageName: pkg,
        currentTime: sixMinsLater,
      );
      expect(isBlockedAfterExpiry, isTrue);
    });

    // -------------------------------------------------------------------------
    // Kombinasi 5: Jadwal Aktif + Kuota Habis + Tiket Darurat -> Tetap Diblokir oleh Jadwal
    // -------------------------------------------------------------------------
    test('Kombinasi 5: Jadwal Aktif + Kuota Habis + Tiket Darurat -> Tetap Diblokir oleh Jadwal', () {
      final now = DateTime(2026, 10, 19, 10, 30); // Senin 10:30 (Dalam jadwal)
      final emergencyExpiry = now.add(const Duration(minutes: 5)).millisecondsSinceEpoch;

      final rules = <Map<String, dynamic>>[
        // Jadwal aktif 09:00 - 12:00
        {
          'packageName': pkg,
          'isScheduled': true,
          'startHour': 9,
          'startMinute': 0,
          'endHour': 12,
          'endMinute': 0,
          'days': [2],
        },
        // Tiket darurat kuota aktif
        {
          'packageName': pkg,
          'isScheduled': false,
          'isQuota': true,
          'dailyQuotaSeconds': 1800,
          'usedTodaySeconds': 1800,
          'emergencyUntilMillis': emergencyExpiry,
        },
      ];

      // Tiket darurat kuota TIDAK boleh membocorkan sesi komitmen jadwal fokus
      final isBlocked = simulateNativeIsAppBlocked(
        rules: rules,
        packageName: pkg,
        currentTime: now,
      );
      expect(isBlocked, isTrue);
    });

    // -------------------------------------------------------------------------
    // Kombinasi 6: Pause atau Perubahan Konfigurasi saat Blokir Berjalan
    // -------------------------------------------------------------------------
    test('Kombinasi 6: Menonaktifkan aturan (Pause) langsung membebaskan aplikasi', () {
      final now = DateTime(2026, 10, 19, 10, 0);

      // Keadaan Awal: Aturan aktif
      var rules = <Map<String, dynamic>>[
        {
          'packageName': pkg,
          'isScheduled': true,
          'startHour': 9,
          'startMinute': 0,
          'endHour': 17,
          'endMinute': 0,
          'days': [2],
        },
      ];
      expect(simulateNativeIsAppBlocked(rules: rules, packageName: pkg, currentTime: now), isTrue);

      // Pengguna menghentikan / mem-pause aturan (rules dikosongkan atau di-update)
      rules = <Map<String, dynamic>>[];
      expect(simulateNativeIsAppBlocked(rules: rules, packageName: pkg, currentTime: now), isFalse);
    });

    // -------------------------------------------------------------------------
    // Kombinasi 7: Evaluasi Multi-Interval Lintas Tengah Malam di Sisi Native
    // -------------------------------------------------------------------------
    test('Kombinasi 7: Evaluasi multi-interval lintas tengah malam pada aturan native', () {
      final rules = <Map<String, dynamic>>[
        // Interval 1: 22:00 - 02:00 Senin malam (Java day 2)
        {
          'packageName': pkg,
          'isScheduled': true,
          'startHour': 22,
          'startMinute': 0,
          'endHour': 2,
          'endMinute': 0,
          'days': [2], // Senin (Java day 2)
        },
      ];

      // Senin 23:00 -> Aktif
      final mon23 = DateTime(2026, 10, 19, 23, 0);
      expect(simulateNativeIsAppBlocked(rules: rules, packageName: pkg, currentTime: mon23), isTrue);

      // Selasa 01:30 -> Aktif (karena spillover dari Senin malam)
      final tue0130 = DateTime(2026, 10, 20, 1, 30);
      expect(simulateNativeIsAppBlocked(rules: rules, packageName: pkg, currentTime: tue0130), isTrue);

      // Selasa 02:30 -> Selesai
      final tue0230 = DateTime(2026, 10, 20, 2, 30);
      expect(simulateNativeIsAppBlocked(rules: rules, packageName: pkg, currentTime: tue0230), isFalse);
    });
  });
}
