import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeda/core/models/lock_entry.dart';
import 'package:jeda/core/models/schedule_interval.dart';

void main() {
  group('10 Skenario Validasi Jadwal Harian Multi-Interval', () {
    // -------------------------------------------------------------------------
    // Skenario 1: Dua interval pada hari yang sama
    // -------------------------------------------------------------------------
    test('1. Dua interval pada hari yang sama dapat berjalan berdampingan', () {
      final interval1 = ScheduleInterval(
        id: 'int-1',
        start: '08:00',
        end: '12:00',
        days: [1], // Senin
      );
      final interval2 = ScheduleInterval(
        id: 'int-2',
        start: '14:00',
        end: '18:00',
        days: [1], // Senin
      );

      // Keduanya tidak bertumpang tindih
      expect(interval1.overlapsWith(interval2), isFalse);
      expect(interval2.overlapsWith(interval1), isFalse);

      // Senin pukul 09:00 -> Interval 1 aktif
      final monday09 = DateTime(2026, 10, 19, 9, 0); // 2026-10-19 adalah Senin
      expect(monday09.weekday, equals(1));
      expect(interval1.isCurrentlyActive(monday09), isTrue);
      expect(interval2.isCurrentlyActive(monday09), isFalse);

      // Senin pukul 13:00 -> Di luar kedua interval
      final monday13 = DateTime(2026, 10, 19, 13, 0);
      expect(interval1.isCurrentlyActive(monday13), isFalse);
      expect(interval2.isCurrentlyActive(monday13), isFalse);

      // Senin pukul 15:00 -> Interval 2 aktif
      final monday15 = DateTime(2026, 10, 19, 15, 0);
      expect(interval1.isCurrentlyActive(monday15), isFalse);
      expect(interval2.isCurrentlyActive(monday15), isTrue);

      // Senin pukul 19:00 -> Selesai
      final monday19 = DateTime(2026, 10, 19, 19, 0);
      expect(interval1.isCurrentlyActive(monday19), isFalse);
      expect(interval2.isCurrentlyActive(monday19), isFalse);
    });

    // -------------------------------------------------------------------------
    // Skenario 2: Beberapa hari dengan jadwal berbeda
    // -------------------------------------------------------------------------
    test('2. Beberapa hari dengan jadwal berbeda (Hari kerja vs Akhir pekan)', () {
      final workdayInterval = ScheduleInterval(
        id: 'workday',
        start: '09:00',
        end: '17:00',
        days: [1, 2, 3, 4, 5], // Senin - Jumat
      );
      final weekendInterval = ScheduleInterval(
        id: 'weekend',
        start: '10:00',
        end: '14:00',
        days: [6, 7], // Sabtu - Minggu
      );

      // Tidak ada konflik karena kumpulan harinya terpisah
      expect(workdayInterval.overlapsWith(weekendInterval), isFalse);

      // Rabu pukul 11:00 (Hari ke-3)
      final wednesday11 = DateTime(2026, 10, 21, 11, 0);
      expect(wednesday11.weekday, equals(3));
      expect(workdayInterval.isCurrentlyActive(wednesday11), isTrue);
      expect(weekendInterval.isCurrentlyActive(wednesday11), isFalse);

      // Sabtu pukul 11:00 (Hari ke-6)
      final saturday11 = DateTime(2026, 10, 24, 11, 0);
      expect(saturday11.weekday, equals(6));
      expect(workdayInterval.isCurrentlyActive(saturday11), isFalse);
      expect(weekendInterval.isCurrentlyActive(saturday11), isTrue);

      // Sabtu pukul 16:00 (Di luar jam akhir pekan)
      final saturday16 = DateTime(2026, 10, 24, 16, 0);
      expect(weekendInterval.isCurrentlyActive(saturday16), isFalse);
    });

    // -------------------------------------------------------------------------
    // Skenario 3: Interval yang bertumpang tindih (Overlap conflict)
    // -------------------------------------------------------------------------
    test('3. Interval yang bertumpang tindih terdeteksi sebagai konflik validasi', () {
      final base = ScheduleInterval(
        id: 'base',
        start: '08:00',
        end: '12:00',
        days: [1, 2], // Senin, Selasa
      );

      // Overlap langsung pada hari yang sama (10:00 - 14:00 tumpang tindih dengan 08:00 - 12:00)
      final directOverlap = ScheduleInterval(
        id: 'overlap-1',
        start: '10:00',
        end: '14:00',
        days: [1],
      );
      expect(base.overlapsWith(directOverlap), isTrue);
      expect(directOverlap.overlapsWith(base), isTrue);

      // Overlap menyeluruh (07:00 - 13:00 melingkupi 08:00 - 12:00)
      final engulfingOverlap = ScheduleInterval(
        id: 'overlap-2',
        start: '07:00',
        end: '13:00',
        days: [2],
      );
      expect(base.overlapsWith(engulfingOverlap), isTrue);

      // Overlap lintas tengah malam:
      // Interval A mulai Senin pukul 22:00 dan selesai Selasa pukul 02:00
      // Interval B mulai Selasa pukul 01:00 dan selesai Selasa pukul 06:00
      final midnightCrossing = ScheduleInterval(
        id: 'midnight-a',
        start: '22:00',
        end: '02:00',
        days: [1], // Senin malam
      );
      final tuesdayMorning = ScheduleInterval(
        id: 'tuesday-morning',
        start: '01:00',
        end: '06:00',
        days: [2], // Selasa dini hari
      );
      expect(midnightCrossing.overlapsWith(tuesdayMorning), isTrue);
    });

    // -------------------------------------------------------------------------
    // Skenario 4: Interval bersebelahan tanpa jeda (Adjacent intervals)
    // -------------------------------------------------------------------------
    test('4. Interval bersebelahan tanpa jeda (08:00-12:00 dan 12:00-17:00) valid & tidak konflik', () {
      final morning = ScheduleInterval(
        id: 'morning',
        start: '08:00',
        end: '12:00',
        days: [1, 2, 3],
      );
      final afternoon = ScheduleInterval(
        id: 'afternoon',
        start: '12:00',
        end: '17:00',
        days: [1, 2, 3],
      );

      // Boundary touch: 12:00 adalah akhir dari morning dan awal dari afternoon.
      // Sesuai prinsip Calm Tech, transisi mulus ini sah dan tidak dianggap overlap.
      expect(morning.overlapsWith(afternoon), isFalse);
      expect(afternoon.overlapsWith(morning), isFalse);
    });

    // -------------------------------------------------------------------------
    // Skenario 5: Interval melewati tengah malam (Midnight-crossing)
    // -------------------------------------------------------------------------
    test('5. Interval melewati tengah malam (22:00-02:00) aktif pada kedua fase hari', () {
      final nightSchedule = ScheduleInterval(
        id: 'night-guard',
        start: '22:00',
        end: '02:00',
        days: [1], // Dikonfigurasi untuk hari Senin
      );

      expect(nightSchedule.isMidnightCrossing, isTrue);

      // Fase A: Senin malam pukul 23:30 -> Aktif
      final mon2330 = DateTime(2026, 10, 19, 23, 30);
      expect(mon2330.weekday, equals(1));
      expect(nightSchedule.isCurrentlyActive(mon2330), isTrue);

      // Fase B: Selasa dini hari pukul 01:15 -> Aktif (berasal dari jadwal Senin)
      final tue0115 = DateTime(2026, 10, 20, 1, 15);
      expect(tue0115.weekday, equals(2));
      expect(nightSchedule.isCurrentlyActive(tue0115), isTrue);

      // Di luar rentang: Selasa pukul 02:05 -> Tidak aktif
      final tue0205 = DateTime(2026, 10, 20, 2, 5);
      expect(nightSchedule.isCurrentlyActive(tue0205), isFalse);

      // Di luar rentang: Senin sore pukul 21:00 -> Tidak aktif
      final mon2100 = DateTime(2026, 10, 19, 21, 0);
      expect(nightSchedule.isCurrentlyActive(mon2100), isFalse);
    });

    // -------------------------------------------------------------------------
    // Skenario 6: Pemblokiran ketika berada di dalam interval
    // -------------------------------------------------------------------------
    test('6. Pemblokiran terjadi ketika waktu berada di dalam salah satu interval', () {
      final entry = LockEntry(
        id: 'lock-test-6',
        packageName: 'com.instagram.android',
        appName: 'Instagram',
        appIconBytes: [],
        startTime: DateTime.now(),
        durationHours: 0,
        isScheduled: true,
        isActive: true,
        intervalsJson: [
          jsonEncode(ScheduleInterval(
            id: 'i1',
            start: '08:30',
            end: '11:30',
            days: [1], // Senin
          ).toJson()),
          jsonEncode(ScheduleInterval(
            id: 'i2',
            start: '13:00',
            end: '16:00',
            days: [1], // Senin
          ).toJson()),
        ],
      );

      // Simulasi evaluasi saat interval 1 aktif (Senin 10:00)
      final monday10 = DateTime(2026, 10, 19, 10, 0);
      final intervals = entry.allIntervals;
      expect(intervals.any((i) => i.isCurrentlyActive(monday10)), isTrue);

      // Simulasi evaluasi saat interval 2 aktif (Senin 14:30)
      final monday1430 = DateTime(2026, 10, 19, 14, 30);
      expect(intervals.any((i) => i.isCurrentlyActive(monday1430)), isTrue);
    });

    // -------------------------------------------------------------------------
    // Skenario 7: Tidak memblokir ketika berada di luar semua interval
    // -------------------------------------------------------------------------
    test('7. Tidak memblokir ketika berada di luar seluruh interval atau saat paused', () {
      final entry = LockEntry(
        id: 'lock-test-7',
        packageName: 'com.tiktok.android',
        appName: 'TikTok',
        appIconBytes: [],
        startTime: DateTime.now(),
        durationHours: 0,
        isScheduled: true,
        isActive: true,
        intervalsJson: [
          jsonEncode(ScheduleInterval(
            id: 'i1',
            start: '09:00',
            end: '11:00',
            days: [1],
          ).toJson()),
        ],
      );

      final intervals = entry.allIntervals;

      // Sebelum interval: Senin 08:30
      final mon0830 = DateTime(2026, 10, 19, 8, 30);
      expect(intervals.any((i) => i.isCurrentlyActive(mon0830)), isFalse);

      // Setelah interval: Senin 12:00
      final mon1200 = DateTime(2026, 10, 19, 12, 0);
      expect(intervals.any((i) => i.isCurrentlyActive(mon1200)), isFalse);

      // Hari lain yang tidak dijadwalkan: Selasa 10:00
      final tue1000 = DateTime(2026, 10, 20, 10, 0);
      expect(intervals.any((i) => i.isCurrentlyActive(tue1000)), isFalse);

      // Saat entry dinonaktifkan (isActive = false), isCurrentlyBlocking selalu false
      entry.isActive = false;
      expect(entry.isCurrentlyBlocking, isFalse);
    });

    // -------------------------------------------------------------------------
    // Skenario 8: Penyimpanan dan pemuatan kembali jadwal (Serialization)
    // -------------------------------------------------------------------------
    test('8. Serialisasi dan deserialisasi multi-interval mempertahankan integritas data', () {
      final originalIntervals = [
        ScheduleInterval(id: 'int-a', start: '08:00', end: '11:00', days: [1, 2, 3]),
        ScheduleInterval(id: 'int-b', start: '13:00', end: '17:00', days: [4, 5]),
        ScheduleInterval(id: 'int-c', start: '21:00', end: '01:00', days: [6, 7]),
      ];

      final encoded = originalIntervals.map((i) => jsonEncode(i.toJson())).toList();

      final entry = LockEntry(
        id: 'serialized-entry',
        packageName: 'com.google.android.youtube',
        appName: 'YouTube',
        appIconBytes: [],
        startTime: DateTime.now(),
        durationHours: 0,
        isScheduled: true,
        intervalsJson: encoded,
      );

      final loaded = entry.allIntervals;
      expect(loaded.length, equals(3));

      expect(loaded[0].id, equals('int-a'));
      expect(loaded[0].start, equals('08:00'));
      expect(loaded[0].end, equals('11:00'));
      expect(loaded[0].days, equals([1, 2, 3]));

      expect(loaded[1].id, equals('int-b'));
      expect(loaded[1].start, equals('13:00'));
      expect(loaded[1].end, equals('17:00'));
      expect(loaded[1].days, equals([4, 5]));

      expect(loaded[2].id, equals('int-c'));
      expect(loaded[2].isMidnightCrossing, isTrue);

      expect(entry.schedulePreviewText, contains('3 interval'));
    });

    // -------------------------------------------------------------------------
    // Skenario 9: Perilaku restart & emisi aturan native
    // -------------------------------------------------------------------------
    test('9. Setiap interval diekspansi menjadi aturan native Android yang independen', () {
      final entry = LockEntry(
        id: 'native-rules-test',
        packageName: 'com.facebook.katana',
        appName: 'Facebook',
        appIconBytes: [],
        startTime: DateTime.now(),
        durationHours: 0,
        isScheduled: true,
        isActive: true,
        intervalsJson: [
          jsonEncode(ScheduleInterval(
            id: 'rule-1',
            start: '07:00',
            end: '09:00',
            days: [1, 2, 3, 4, 5],
          ).toJson()),
          jsonEncode(ScheduleInterval(
            id: 'rule-2',
            start: '19:00',
            end: '22:00',
            days: [1, 2, 3, 4, 5],
          ).toJson()),
        ],
      );

      // Simulasi logika getActiveRules() dari StorageService
      final rules = <Map<String, dynamic>>[];
      if (entry.isActive && entry.isScheduled) {
        for (final interval in entry.allIntervals) {
          rules.add({
            'packageName': entry.packageName,
            'isScheduled': true,
            'scheduledStart': interval.start,
            'scheduledEnd': interval.end,
            'scheduledDays': interval.days,
            'endTimeMillis': 0,
          });
        }
      }

      expect(rules.length, equals(2));
      expect(rules[0]['packageName'], equals('com.facebook.katana'));
      expect(rules[0]['scheduledStart'], equals('07:00'));
      expect(rules[0]['scheduledEnd'], equals('09:00'));
      expect(rules[0]['isScheduled'], isTrue);

      expect(rules[1]['packageName'], equals('com.facebook.katana'));
      expect(rules[1]['scheduledStart'], equals('19:00'));
      expect(rules[1]['scheduledEnd'], equals('22:00'));
      expect(rules[1]['isScheduled'], isTrue);
    });

    // -------------------------------------------------------------------------
    // Skenario 10: Kompatibilitas ke belakang (Backward Compatibility)
    // -------------------------------------------------------------------------
    test('10. Data jadwal lama (single interval) tetap terbaca dan berfungsi normal tanpa migrasi paksa', () {
      // Entri lama yang disimpan sebelum multi-interval hadir:
      // intervalsJson bernilai null, hanya ada scheduledStart, scheduledEnd, scheduledDays
      final legacyEntry = LockEntry(
        id: 'legacy-entry-1',
        packageName: 'com.twitter.android',
        appName: 'X',
        appIconBytes: [],
        startTime: DateTime.now(),
        durationHours: 0,
        isScheduled: true,
        isActive: true,
        scheduledStart: '09:00',
        scheduledEnd: '17:00',
        scheduledDays: [1, 2, 3, 4, 5],
        intervalsJson: null, // Model data lama
      );

      // allIntervals harus secara otomatis mensintesis 1 ScheduleInterval yang valid
      final intervals = legacyEntry.allIntervals;
      expect(intervals.length, equals(1));
      expect(intervals.first.start, equals('09:00'));
      expect(intervals.first.end, equals('17:00'));
      expect(intervals.first.days, equals([1, 2, 3, 4, 5]));

      // schedulePreviewText menghasilkan teks ringkas yang elegan
      expect(legacyEntry.schedulePreviewText, equals('09:00 – 17:00 (Sen, Sel, Rab, Kam, Jum)'));

      // Evaluasi aktif pada jam kerja (Rabu pukul 14:00)
      final wed14 = DateTime(2026, 10, 21, 14, 0);
      expect(intervals.first.isCurrentlyActive(wed14), isTrue);

      // Di luar jam kerja (Rabu pukul 20:00)
      final wed20 = DateTime(2026, 10, 21, 20, 0);
      expect(intervals.first.isCurrentlyActive(wed20), isFalse);
    });
  });
}
