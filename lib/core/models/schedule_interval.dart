import 'package:uuid/uuid.dart';

/// Represents a single time interval in a recurring schedule.
class ScheduleInterval {
  final String id;
  final String start; // Format "HH:mm" (24-hour)
  final String end;   // Format "HH:mm" (24-hour)
  final List<int> days; // 1 = Monday ... 7 = Sunday (Dart DateTime convention)

  ScheduleInterval({
    String? id,
    required this.start,
    required this.end,
    required List<int> days,
  })  : id = id ?? const Uuid().v4(),
        days = List<int>.unmodifiable(List<int>.from(days)..sort());

  Map<String, dynamic> toJson() => {
        'id': id,
        'start': start,
        'end': end,
        'days': days,
      };

  factory ScheduleInterval.fromJson(Map<String, dynamic> json) => ScheduleInterval(
        id: json['id'] as String?,
        start: json['start'] as String,
        end: json['end'] as String,
        days: (json['days'] as List).cast<int>(),
      );

  ScheduleInterval copyWith({
    String? id,
    String? start,
    String? end,
    List<int>? days,
  }) {
    return ScheduleInterval(
      id: id ?? this.id,
      start: start ?? this.start,
      end: end ?? this.end,
      days: days ?? this.days,
    );
  }

  int get startMinutes => _toMinutes(start);
  int get endMinutes => _toMinutes(end);

  /// True if the interval crosses midnight (e.g. 22:00 to 02:00)
  bool get isMidnightCrossing => startMinutes > endMinutes;

  /// Evaluates whether this interval is currently active at [referenceTime].
  bool isCurrentlyActive([DateTime? referenceTime]) {
    final time = referenceTime ?? DateTime.now();
    final currentDay = time.weekday; // 1 = Monday ... 7 = Sunday
    final currentMin = time.hour * 60 + time.minute;

    final sMin = startMinutes;
    final eMin = endMinutes;

    if (sMin <= eMin) {
      // Normal same-day interval: e.g. 08:00 - 17:00
      return days.contains(currentDay) && (currentMin >= sMin && currentMin <= eMin);
    } else {
      // Midnight-crossing interval: e.g. 22:00 - 02:00
      // Phase A: Started today before midnight
      if (days.contains(currentDay) && currentMin >= sMin) {
        return true;
      }
      // Phase B: Started yesterday and active today after midnight
      final prevDay = currentDay == 1 ? 7 : currentDay - 1;
      if (days.contains(prevDay) && currentMin <= eMin) {
        return true;
      }
      return false;
    }
  }

  /// Checks if this interval conflicts (overlaps) with [other] on any shared day.
  bool overlapsWith(ScheduleInterval other) {
    if (id == other.id) return false;

    // Check direct common days
    final commonDays = days.where((d) => other.days.contains(d)).toList();

    // Check if intervals overlap on any of the common days
    for (final _ in commonDays) {
      if (_rangesOverlap(startMinutes, endMinutes, other.startMinutes, other.endMinutes)) {
        return true;
      }
    }

    // Also check cross-day spillover if one or both cross midnight!
    // If interval A starts on Day D and crosses to Day D+1:
    // It can conflict on Day D+1 with interval B that runs on Day D+1!
    if (isMidnightCrossing) {
      for (final d in days) {
        final nextDay = d == 7 ? 1 : d + 1;
        if (other.days.contains(nextDay)) {
          // Compare A's morning part [0, endMinutes] with B's start on nextDay
          final bStart = other.startMinutes;
          final bEnd = other.endMinutes;
          // A is active from 0 to endMinutes on nextDay
          if (bStart <= bEnd) {
            if (0 < bEnd && bStart < endMinutes) return true;
          } else {
            // Both cross midnight
            if (0 < bEnd || bStart < 1440) return true;
          }
        }
      }
    }

    if (other.isMidnightCrossing) {
      for (final d in other.days) {
        final nextDay = d == 7 ? 1 : d + 1;
        if (days.contains(nextDay)) {
          final aStart = startMinutes;
          final aEnd = endMinutes;
          if (aStart <= aEnd) {
            if (0 < aEnd && aStart < other.endMinutes) return true;
          } else {
            if (0 < aEnd || aStart < 1440) return true;
          }
        }
      }
    }

    return false;
  }

  static int _toMinutes(String time) {
    final parts = time.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

  static bool _rangesOverlap(int s1, int e1, int s2, int e2) {
    // Standard single-day ranges
    if (s1 <= e1 && s2 <= e2) {
      // Strictly overlapping if start of one is before end of other,
      // and end of one is after start of other.
      // Adjacent intervals without gap (e.g. 08:00-12:00 and 12:00-17:00) do NOT overlap.
      return s1 < e2 && s2 < e1;
    }

    // Decompose into day chunks
    final p1 = s1 <= e1 ? [[s1, e1]] : [[s1, 1440], [0, e1]];
    final p2 = s2 <= e2 ? [[s2, e2]] : [[s2, 1440], [0, e2]];

    for (final r1 in p1) {
      for (final r2 in p2) {
        if (r1[0] < r2[1] && r2[0] < r1[1]) {
          return true;
        }
      }
    }
    return false;
  }

  static String dayName(int day) {
    switch (day) {
      case 1:
        return 'Sen';
      case 2:
        return 'Sel';
      case 3:
        return 'Rab';
      case 4:
        return 'Kam';
      case 5:
        return 'Jum';
      case 6:
        return 'Sab';
      case 7:
        return 'Min';
      default:
        return '';
    }
  }

  String get formattedDays => days.map(dayName).join(', ');
  String get formattedRange => '$start – $end';
}
