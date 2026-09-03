import 'package:hive/hive.dart';

part 'lock_entry.g.dart';

@HiveType(typeId: 0)
class LockEntry {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String packageName;

  @HiveField(2)
  final String appName;

  @HiveField(3)
  final List<int> appIconBytes;

  @HiveField(4)
  final DateTime startTime;

  @HiveField(5)
  final int durationHours;

  @HiveField(6, defaultValue: true)
  bool isActive;

  @HiveField(7, defaultValue: false)
  final bool isScheduled;

  @HiveField(8)
  final String? scheduledStart; // "HH:mm"

  @HiveField(9)
  final String? scheduledEnd; // "HH:mm"

  @HiveField(10, defaultValue: [])
  final List<int>? scheduledDays; // 1=Monday, ..., 7=Sunday

  LockEntry({
    required this.id,
    required this.packageName,
    required this.appName,
    required this.appIconBytes,
    required this.startTime,
    required this.durationHours,
    this.isActive = true,
    this.isScheduled = false,
    this.scheduledStart,
    this.scheduledEnd,
    this.scheduledDays,
  });

  DateTime get endTime => startTime.add(Duration(hours: durationHours));

  bool get isExpired => isScheduled ? false : DateTime.now().isAfter(endTime);

  Duration get remaining => isScheduled ? Duration.zero : endTime.difference(DateTime.now());
}
