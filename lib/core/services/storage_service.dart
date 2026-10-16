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
    return getActiveLocksSync();
  }

  List<LockEntry> getActiveLocksSync() {
    try {
      return _lockBox.values.where((entry) => entry.isActive && !entry.isExpired).toList();
    } catch (_) {
      return [];
    }
  }

  List<QuotaEntry> getAllQuotasSync() {
    try {
      return _quotaBox.values.toList();
    } catch (_) {
      return [];
    }
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

  Future<bool> _checkAndResetQuota(QuotaEntry entry) async {
    final now = DateTime.now();
    bool needsSave = false;
    bool wasReset = false;

    // Reset daily quota if new day
    if (entry.lastResetDate.year != now.year ||
        entry.lastResetDate.month != now.month ||
        entry.lastResetDate.day != now.day) {
      entry.usedTodaySeconds = 0;
      entry.lastResetDate = now;
      needsSave = true;
      wasReset = true;
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
    return wasReset;
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

  Future<void> syncNativeQuotaUsage(Map<String, int> nativeUsage) async {
    for (var entry in _quotaBox.values) {
      final wasReset = await _checkAndResetQuota(entry);
      if (wasReset) {
        // If quota was reset for the new day in Flutter, keep usedTodaySeconds at 0
        continue;
      }
      int maxUsed = entry.usedTodaySeconds;
      for (var pkg in entry.packageNames) {
        if (nativeUsage.containsKey(pkg)) {
          final nativeSec = nativeUsage[pkg] ?? 0;
          if (nativeSec > maxUsed) {
            maxUsed = nativeSec;
          }
        }
      }
      if (maxUsed != entry.usedTodaySeconds) {
        entry.usedTodaySeconds = maxUsed;
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
    for (final entry in _lockBox.values.where((entry) => entry.isActive && !entry.isExpired)) {
      if (entry.isScheduled) {
        for (final interval in entry.allIntervals) {
          final javaDays = interval.days.map((d) => d == 7 ? 1 : d + 1).toList();
          final startParts = interval.start.split(':');
          final endParts = interval.end.split(':');
          rules.add({
            "packageName": entry.packageName,
            "groupName": entry.appName,
            "isScheduled": true,
            "intervalId": interval.id,
            "startHour": int.parse(startParts[0]),
            "startMinute": int.parse(startParts[1]),
            "endHour": int.parse(endParts[0]),
            "endMinute": int.parse(endParts[1]),
            "days": javaDays,
            if (entry.focusGoal != null && entry.focusGoal!.isNotEmpty) "focusGoal": entry.focusGoal!,
            if (entry.description != null && entry.description!.isNotEmpty) "description": entry.description!,
          });
        }
      } else {
        rules.add({
          "packageName": entry.packageName,
          "groupName": entry.appName,
          "isScheduled": false,
          "endTimeMillis": entry.endTime.millisecondsSinceEpoch,
          if (entry.focusGoal != null && entry.focusGoal!.isNotEmpty) "focusGoal": entry.focusGoal!,
          if (entry.description != null && entry.description!.isNotEmpty) "description": entry.description!,
        });
      }
    }

    // 2. QuotaEntry rules
    final now = DateTime.now();
    final todayStr = "${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
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
          "lastResetDate": todayStr,
          "emergencyTickets": entry.emergencyTickets,
          "isEmergencyActive": entry.isEmergencyActive,
          "emergencyUntilMillis": entry.activeEmergencyUntil?.millisecondsSinceEpoch ?? 0,
          if (entry.focusGoal != null && entry.focusGoal!.isNotEmpty) "focusGoal": entry.focusGoal!,
          if (entry.description != null && entry.description!.isNotEmpty) "description": entry.description!,
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

  int getTotalHoursSavedSync() {
    try {
      return _statsBox.get('hours_saved', defaultValue: 0) as int;
    } catch (_) {
      return 0;
    }
  }

  Future<int> getTotalHoursSaved() async {
    return getTotalHoursSavedSync();
  }

  int getStreakDaysSync() {
    try {
      return _statsBox.get('streak_days', defaultValue: 0) as int;
    } catch (_) {
      return 0;
    }
  }

  Future<int> getStreakDays() async {
    return getStreakDaysSync();
  }

  Future<void> saveStreakDays(int days) async {
    await _statsBox.put('streak_days', days);
  }

  bool isOnboardingDone() {
    try {
      return _statsBox.get('onboarding_done', defaultValue: false) as bool;
    } catch (_) {
      return false;
    }
  }

  Future<void> setOnboardingDone(bool done) async {
    await _statsBox.put('onboarding_done', done);
  }

  // =========================================================================
  // PSYCHOLOGICAL COMMITMENT: 4-DAY DELETION COOLDOWN (1 DELETE PER 4 DAYS)
  // =========================================================================
  static const Duration deletionCooldownDuration = Duration(days: 4);

  DateTime? getLastDeletionTime() {
    try {
      final millis = _statsBox.get('last_lock_deletion_millis') as int?;
      if (millis == null || millis <= 0) return null;
      return DateTime.fromMillisecondsSinceEpoch(millis);
    } catch (_) {
      return null;
    }
  }

  bool canDeleteLockNow() {
    final lastDeletion = getLastDeletionTime();
    if (lastDeletion == null) return true;
    return DateTime.now().difference(lastDeletion) >= deletionCooldownDuration;
  }

  Duration getRemainingDeletionCooldown() {
    final lastDeletion = getLastDeletionTime();
    if (lastDeletion == null) return Duration.zero;
    final unlockTime = lastDeletion.add(deletionCooldownDuration);
    final diff = unlockTime.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  Future<void> recordLockDeletion() async {
    await _statsBox.put('last_lock_deletion_millis', DateTime.now().millisecondsSinceEpoch);
  }
}
