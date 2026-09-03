import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/lock_entry.dart';
import '../models/blocked_domain.dart';
import '../models/quota_entry.dart';

final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService();
});

class StorageService {
  static const String _lockBoxName = 'lock_entries';
  static const String _domainBoxName = 'blocked_domains';
  static const String _statsBoxName = 'user_stats';
  static const String _quotaBoxName = 'quota_entries';

  late Box<LockEntry> _lockBox;
  late Box<BlockedDomain> _domainBox;
  late Box _statsBox;
  late Box<QuotaEntry> _quotaBox;

  Future<void> init() async {
    _lockBox = await Hive.openBox<LockEntry>(_lockBoxName);
    _domainBox = await Hive.openBox<BlockedDomain>(_domainBoxName);
    _statsBox = await Hive.openBox(_statsBoxName);
    _quotaBox = await Hive.openBox<QuotaEntry>(_quotaBoxName);
  }

  Future<void> addLock(LockEntry entry) async {
    await _lockBox.put(entry.id, entry);
  }

  Future<void> removeLock(String id) async {
    await _lockBox.delete(id);
  }

  Future<List<LockEntry>> getActiveLocks() async {
    return _lockBox.values.where((entry) => entry.isActive && !entry.isExpired).toList();
  }

  Future<void> cleanExpiredLocks() async {
    final expiredLocks = _lockBox.values
        .where((entry) => entry.isActive && !entry.isScheduled && entry.isExpired)
        .toList();
    for (var lock in expiredLocks) {
      lock.isActive = false;
      await _lockBox.put(lock.id, lock);
      await incrementHoursSaved(lock.durationHours);
    }
  }

  // Quota Entry Methods
  Future<void> addQuota(QuotaEntry entry) async {
    await _quotaBox.put(entry.id, entry);
  }

  Future<void> removeQuota(String id) async {
    await _quotaBox.delete(id);
  }

  Future<List<QuotaEntry>> getAllQuotas() async {
    final list = _quotaBox.values.toList();
    for (var entry in list) {
      await _checkAndResetQuota(entry);
    }
    return list;
  }

  Future<void> _checkAndResetQuota(QuotaEntry entry) async {
    final now = DateTime.now();
    bool needsSave = false;

    // Reset daily quota if new day
    if (entry.lastResetDate.year != now.year ||
        entry.lastResetDate.month != now.month ||
        entry.lastResetDate.day != now.day) {
      entry.usedTodaySeconds = 0;
      entry.lastResetDate = now;
      needsSave = true;
    }

    // Reset weekly emergency tickets (every 7 days)
    if (now.difference(entry.lastTicketResetDate).inDays >= 7) {
      entry.emergencyTickets = 2;
      entry.lastTicketResetDate = now;
      needsSave = true;
    }

    if (needsSave) {
      await _quotaBox.put(entry.id, entry);
    }
  }

  Future<void> addQuotaUsage(String packageName, int seconds) async {
    for (var entry in _quotaBox.values) {
      if (entry.packageNames.contains(packageName)) {
        await _checkAndResetQuota(entry);
        entry.usedTodaySeconds += seconds;
        await _quotaBox.put(entry.id, entry);
      }
    }
  }

  Future<bool> useEmergencyTicket(String quotaId, int durationMinutes) async {
    final entry = _quotaBox.get(quotaId);
    if (entry != null && entry.emergencyTickets > 0) {
      entry.emergencyTickets -= 1;
      entry.activeEmergencyUntil = DateTime.now().add(Duration(minutes: durationMinutes));
      await _quotaBox.put(quotaId, entry);
      return true;
    }
    return false;
  }

  List<Map<String, dynamic>> getActiveRules() {
    final rules = <Map<String, dynamic>>[];

    // 1. LockEntry rules
    final lockRules = _lockBox.values
        .where((entry) => entry.isActive && !entry.isExpired)
        .map((entry) {
          if (entry.isScheduled) {
            List<int> javaDays = entry.scheduledDays!.map((d) => d == 7 ? 1 : d + 1).toList();
            return {
              "packageName": entry.packageName,
              "isScheduled": true,
              "startHour": int.parse(entry.scheduledStart!.split(':')[0]),
              "startMinute": int.parse(entry.scheduledStart!.split(':')[1]),
              "endHour": int.parse(entry.scheduledEnd!.split(':')[0]),
              "endMinute": int.parse(entry.scheduledEnd!.split(':')[1]),
              "days": javaDays,
            };
          } else {
            return {
              "packageName": entry.packageName,
              "isScheduled": false,
              "endTimeMillis": entry.endTime.millisecondsSinceEpoch,
            };
          }
        });
    rules.addAll(lockRules);

    // 2. QuotaEntry rules
    for (var entry in _quotaBox.values) {
      _checkAndResetQuota(entry);
      for (var pkg in entry.packageNames) {
        rules.add({
          "packageName": pkg,
          "isScheduled": false,
          "isQuota": true,
          "quotaId": entry.id,
          "groupName": entry.groupName,
          "dailyQuotaSeconds": entry.dailyQuotaMinutes * 60,
          "usedTodaySeconds": entry.usedTodaySeconds,
          "emergencyTickets": entry.emergencyTickets,
          "isEmergencyActive": entry.isEmergencyActive,
          "emergencyUntilMillis": entry.activeEmergencyUntil?.millisecondsSinceEpoch ?? 0,
        });
      }
    }

    return rules;
  }

  Future<void> addBlockedDomain(BlockedDomain domain) async {
    await _domainBox.put(domain.id, domain);
  }

  Future<void> toggleDomain(String id, bool enabled) async {
    final domain = _domainBox.get(id);
    if (domain != null) {
      domain.isEnabled = enabled;
      await _domainBox.put(id, domain);
    }
  }

  Future<List<BlockedDomain>> getAllDomains() async {
    return _domainBox.values.toList();
  }

  Future<void> incrementHoursSaved(int hours) async {
    final currentHours = _statsBox.get('hours_saved', defaultValue: 0) as int;
    await _statsBox.put('hours_saved', currentHours + hours);
  }

  Future<int> getTotalHoursSaved() async {
    return _statsBox.get('hours_saved', defaultValue: 0) as int;
  }

  Future<int> getStreakDays() async {
    return _statsBox.get('streak_days', defaultValue: 0) as int;
  }

  bool isOnboardingDone() {
    return _statsBox.get('onboarding_done', defaultValue: false) as bool;
  }

  Future<void> setOnboardingDone(bool done) async {
    await _statsBox.put('onboarding_done', done);
  }
}
