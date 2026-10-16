import 'package:flutter_test/flutter_test.dart';
import 'package:jeda/core/models/lock_entry.dart';
import 'package:jeda/core/models/quota_entry.dart';

void main() {
  group('LockEntry Logic & Midnight Crossing', () {
    test('Non-scheduled lock correctly calculates expiration and remaining time', () {
      final now = DateTime.now();
      final activeLock = LockEntry(
        id: '1',
        packageName: 'com.instagram.android',
        appName: 'Instagram',
        appIconBytes: [],
        startTime: now.subtract(const Duration(minutes: 30)),
        durationHours: 2, // 2 hours total, 90 mins remaining
        isScheduled: false,
      );

      expect(activeLock.isExpired, isFalse);
      expect(activeLock.isCurrentlyBlocking, isTrue);
      expect(activeLock.remaining.inMinutes, inInclusiveRange(89, 90));

      final expiredLock = LockEntry(
        id: '2',
        packageName: 'com.zhiliaoapp.musically',
        appName: 'TikTok',
        appIconBytes: [],
        startTime: now.subtract(const Duration(hours: 3)),
        durationHours: 2, // 2 hours total, expired 1 hour ago
        isScheduled: false,
      );

      expect(expiredLock.isExpired, isTrue);
      expect(expiredLock.isCurrentlyBlocking, isFalse);
      expect(expiredLock.remaining.isNegative, isTrue);
    });

    test('Scheduled lock isExpired is always false', () {
      final scheduledLock = LockEntry(
        id: '3',
        packageName: 'com.twitter.android',
        appName: 'X',
        appIconBytes: [],
        startTime: DateTime.now(),
        durationHours: 0,
        isScheduled: true,
        scheduledStart: '09:00',
        scheduledEnd: '17:00',
        scheduledDays: [1, 2, 3, 4, 5],
      );

      expect(scheduledLock.isExpired, isFalse);
    });
  });

  group('QuotaEntry Logic & Emergency Pass', () {
    test('Quota exhaust and remaining seconds calculation', () {
      final entry = QuotaEntry(
        id: 'quota-1',
        groupName: 'Media Sosial',
        packageNames: ['com.instagram.android', 'com.zhiliaoapp.musically'],
        appNames: ['Instagram', 'TikTok'],
        dailyQuotaMinutes: 60,
        usedTodaySeconds: 1800, // 30 minutes used
        lastResetDate: DateTime.now(),
        lastTicketResetDate: DateTime.now(),
      );

      expect(entry.isQuotaExhausted, isFalse);
      expect(entry.remainingSeconds, 1800);
      expect(entry.isCurrentlyBlocking, isFalse);

      // Exhaust quota
      entry.usedTodaySeconds = 3600;
      expect(entry.isQuotaExhausted, isTrue);
      expect(entry.remainingSeconds, 0);
      expect(entry.isCurrentlyBlocking, isTrue);
    });

    test('Emergency ticket pass temporarily unblocks exhausted quota', () {
      final entry = QuotaEntry(
        id: 'quota-2',
        groupName: 'Games',
        packageNames: ['com.dts.freefireth'],
        appNames: ['Free Fire'],
        dailyQuotaMinutes: 30,
        usedTodaySeconds: 2000, // Exhausted
        lastResetDate: DateTime.now(),
        emergencyTickets: 2,
        lastTicketResetDate: DateTime.now(),
        activeEmergencyUntil: DateTime.now().add(const Duration(minutes: 5)),
      );

      expect(entry.isQuotaExhausted, isTrue);
      expect(entry.isEmergencyActive, isTrue);
      // Emergency pass is active, so it should NOT be currently blocking
      expect(entry.isCurrentlyBlocking, isFalse);
    });
  });
}
