import 'package:hive/hive.dart';

part 'quota_entry.g.dart';

@HiveType(typeId: 2)
class QuotaEntry {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String groupName;

  @HiveField(2)
  final List<String> packageNames;

  @HiveField(3)
  final List<String> appNames;

  @HiveField(4)
  final int dailyQuotaMinutes;

  @HiveField(5)
  int usedTodaySeconds;

  @HiveField(6)
  DateTime lastResetDate;

  @HiveField(7, defaultValue: 2)
  int emergencyTickets;

  @HiveField(8)
  DateTime lastTicketResetDate;

  @HiveField(9)
  DateTime? activeEmergencyUntil;

  QuotaEntry({
    required this.id,
    required this.groupName,
    required this.packageNames,
    required this.appNames,
    required this.dailyQuotaMinutes,
    this.usedTodaySeconds = 0,
    required this.lastResetDate,
    this.emergencyTickets = 2,
    required this.lastTicketResetDate,
    this.activeEmergencyUntil,
  });

  bool get isQuotaExhausted => usedTodaySeconds >= (dailyQuotaMinutes * 60);

  bool get isEmergencyActive {
    if (activeEmergencyUntil == null) return false;
    return DateTime.now().isBefore(activeEmergencyUntil!);
  }

  int get remainingSeconds {
    final remaining = (dailyQuotaMinutes * 60) - usedTodaySeconds;
    return remaining > 0 ? remaining : 0;
  }
}
