import 'dart:convert';
import 'package:hive/hive.dart';
import 'schedule_interval.dart';

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

  // Legacy single-interval fields (maintained for 100% backward compatibility)
  @HiveField(8)
  final String? scheduledStart; // "HH:mm"

  @HiveField(9)
  final String? scheduledEnd; // "HH:mm"

  @HiveField(10, defaultValue: [])
  final List<int>? scheduledDays; // 1=Monday, ..., 7=Sunday

  // Multi-interval serialization
  @HiveField(11, defaultValue: [])
  final List<String>? intervalsJson;

  // Psychological intention / focus goal & personal reminder description
  @HiveField(12)
  final String? focusGoal;

  @HiveField(13)
  final String? description;

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
    this.intervalsJson,
    this.focusGoal,
    this.description,
  });

  DateTime get endTime => startTime.add(Duration(hours: durationHours));

  bool get isExpired => isScheduled ? false : DateTime.now().isAfter(endTime);

  Duration get remaining => isScheduled ? Duration.zero : endTime.difference(DateTime.now());

  /// Returns all intervals configured for this lock entry.
  /// Seamlessly bridges multi-interval entries and legacy single-interval entries.
  List<ScheduleInterval> get allIntervals {
    if (!isScheduled) return const [];

    if (intervalsJson != null && intervalsJson!.isNotEmpty) {
      final list = <ScheduleInterval>[];
      for (final str in intervalsJson!) {
        try {
          final map = jsonDecode(str) as Map<String, dynamic>;
          list.add(ScheduleInterval.fromJson(map));
        } catch (_) {}
      }
      if (list.isNotEmpty) return list;
    }

    // Graceful backward compatibility fallback for existing single-interval rules
    if (scheduledStart != null && scheduledEnd != null) {
      return [
        ScheduleInterval(
          id: 'legacy-$id',
          start: scheduledStart!,
          end: scheduledEnd!,
          days: scheduledDays != null && scheduledDays!.isNotEmpty
              ? scheduledDays!
              : const [1, 2, 3, 4, 5],
        ),
      ];
    }

    return const [];
  }

  /// True if currently within ANY of the scheduled intervals.
  bool get isScheduledActiveNow {
    if (!isScheduled || !isActive) return false;
    final intervals = allIntervals;
    if (intervals.isEmpty) return false;
    return intervals.any((i) => i.isCurrentlyActive());
  }

  /// True if the entry is currently enforcing a block right now.
  bool get isCurrentlyBlocking {
    if (!isActive) return false;
    if (isScheduled) {
      return isScheduledActiveNow;
    } else {
      return !isExpired;
    }
  }

  /// Formatted schedule preview for UI display.
  String get schedulePreviewText {
    if (!isScheduled) return '';
    final intervals = allIntervals;
    if (intervals.isEmpty) return 'Tidak ada interval aktif';
    if (intervals.length == 1) {
      final first = intervals.first;
      return '${first.start} – ${first.end} (${first.formattedDays})';
    }
    return '${intervals.length} interval (${intervals.map((i) => i.formattedRange).join(', ')})';
  }
}
