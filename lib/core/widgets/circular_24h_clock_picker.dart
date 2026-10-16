import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/jeda_colors.dart';
import '../theme/jeda_radii.dart';
import '../theme/jeda_typography.dart';

/// Interactive 24-hour circular clock range picker (hours 1..24)
/// designed with Jeda's Calm Technology & psychological mindfulness aesthetic.
class Circular24HourClockPicker extends StatefulWidget {
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final ValueChanged<TimeOfDay> onStartTimeChanged;
  final ValueChanged<TimeOfDay> onEndTimeChanged;

  const Circular24HourClockPicker({
    super.key,
    required this.startTime,
    required this.endTime,
    required this.onStartTimeChanged,
    required this.onEndTimeChanged,
  });

  @override
  State<Circular24HourClockPicker> createState() => _Circular24HourClockPickerState();
}

enum _ActiveClockHandle { start, end }

class _Circular24HourClockPickerState extends State<Circular24HourClockPicker> {
  _ActiveClockHandle _activeHandle = _ActiveClockHandle.start;

  static const double _clockSize = 276.0;
  static const double _numberRadius = 108.0;
  static const double _arcRadius = 76.0;

  /// Converts TimeOfDay (0..23) to display label (1..24, where 00:xx is shown as 24:xx or 00:xx)
  int _hourTo24Label(int hour) => hour == 0 ? 24 : hour;

  /// Angle in radians for a given hour (0..24) and minute, where 24 (0:00) is at top (-pi/2)
  double _timeToAngle(TimeOfDay time) {
    final totalMinutes = (time.hour % 24) * 60 + time.minute;
    final fraction = totalMinutes / (24 * 60);
    return -math.pi / 2 + fraction * 2 * math.pi;
  }

  /// Calculates total locked duration in minutes
  int get _durationMinutes {
    final startMin = widget.startTime.hour * 60 + widget.startTime.minute;
    final endMin = widget.endTime.hour * 60 + widget.endTime.minute;
    if (endMin > startMin) {
      return endMin - startMin;
    } else if (endMin < startMin) {
      return (24 * 60 - startMin) + endMin;
    }
    return 0;
  }

  String get _formattedDuration {
    final mins = _durationMinutes;
    if (mins <= 0) return '0 Jam';
    final h = mins ~/ 60;
    final m = mins % 60;
    if (m == 0) return '$h Jam Fokus';
    if (h == 0) return '$m Menit Fokus';
    return '$h Jam ${m}m';
  }

  String get _psychologicalCaption {
    final h = _durationMinutes / 60.0;
    if (h >= 8) return 'Istirahat mendalam bagi pikiran 🌱';
    if (h >= 4) return 'Zona kerja & fokus tanpa interupsi ✨';
    return 'Jeda singkat memulihkan kendali diri 🍃';
  }

  void _handleClockTouch(Offset localPosition, Size size, {required bool isDragStart}) {
    final center = Offset(size.width / 2, size.height / 2);
    final dx = localPosition.dx - center.dx;
    final dy = localPosition.dy - center.dy;
    final distance = math.sqrt(dx * dx + dy * dy);

    // Ignore touches right in the dead center
    if (distance < 28) return;

    // On initial touch, if user touches near the opposite handle, switch active handle automatically
    if (isDragStart) {
      final startAngle = _timeToAngle(widget.startTime);
      final endAngle = _timeToAngle(widget.endTime);
      final startPos = Offset(
        center.dx + _arcRadius * math.cos(startAngle),
        center.dy + _arcRadius * math.sin(startAngle),
      );
      final endPos = Offset(
        center.dx + _arcRadius * math.cos(endAngle),
        center.dy + _arcRadius * math.sin(endAngle),
      );
      final distToStart = (localPosition - startPos).distance;
      final distToEnd = (localPosition - endPos).distance;
      if (distToStart < 30 && distToStart <= distToEnd) {
        setState(() => _activeHandle = _ActiveClockHandle.start);
      } else if (distToEnd < 30 && distToEnd < distToStart) {
        setState(() => _activeHandle = _ActiveClockHandle.end);
      }
    }

    // Calculate angle from top (-pi/2) clockwise (0..2*pi)
    double angle = math.atan2(dy, dx) + math.pi / 2;
    if (angle < 0) angle += 2 * math.pi;

    // Snap to nearest hour (1..24) when tapping the outer number ring, or 15-min steps when dragging inner ring
    final rawHours = (angle / (2 * math.pi)) * 24.0;
    int selectedHour = rawHours.round() % 24;

    if (_activeHandle == _ActiveClockHandle.start) {
      final currentMinute = widget.startTime.minute;
      widget.onStartTimeChanged(TimeOfDay(hour: selectedHour, minute: currentMinute));
    } else {
      final currentMinute = widget.endTime.minute;
      widget.onEndTimeChanged(TimeOfDay(hour: selectedHour, minute: currentMinute));
    }
  }

  void _setMinuteForActive(int minute) {
    if (_activeHandle == _ActiveClockHandle.start) {
      widget.onStartTimeChanged(TimeOfDay(hour: widget.startTime.hour, minute: minute));
    } else {
      widget.onEndTimeChanged(TimeOfDay(hour: widget.endTime.hour, minute: minute));
    }
  }

  String _formatTime24(TimeOfDay t) {
    final hLabel = _hourTo24Label(t.hour).toString().padLeft(2, '0');
    final mLabel = t.minute.toString().padLeft(2, '0');
    return '$hLabel:$mLabel';
  }

  @override
  Widget build(BuildContext context) {
    final activeTime = _activeHandle == _ActiveClockHandle.start ? widget.startTime : widget.endTime;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Top Selector Tabs: Jam Mulai vs Jam Selesai
        Row(
          children: [
            Expanded(
              child: _buildTimeTabCard(
                label: 'Mulai Kunci',
                timeText: _formatTime24(widget.startTime),
                subLabel: widget.startTime.hour == 0 ? '24:00 (Tengah Malam)' : 'Jam ${_hourTo24Label(widget.startTime.hour)}',
                isSelected: _activeHandle == _ActiveClockHandle.start,
                accentColor: JedaColors.primaryDark,
                onTap: () => setState(() => _activeHandle = _ActiveClockHandle.start),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Icon(
                Icons.arrow_forward_rounded,
                size: 18,
                color: JedaColors.textTertiary,
              ),
            ),
            Expanded(
              child: _buildTimeTabCard(
                label: 'Selesai Kunci',
                timeText: _formatTime24(widget.endTime),
                subLabel: widget.endTime.hour == 0 ? '24:00 (Tengah Malam)' : 'Jam ${_hourTo24Label(widget.endTime.hour)}',
                isSelected: _activeHandle == _ActiveClockHandle.end,
                accentColor: JedaColors.warning,
                onTap: () => setState(() => _activeHandle = _ActiveClockHandle.end),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // 24-Hour Circular Clock Dial (Hours 1 to 24)
        Center(
          child: SizedBox(
            width: _clockSize,
            height: _clockSize,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanDown: (details) => _handleClockTouch(
                details.localPosition,
                const Size(_clockSize, _clockSize),
                isDragStart: true,
              ),
              onPanUpdate: (details) => _handleClockTouch(
                details.localPosition,
                const Size(_clockSize, _clockSize),
                isDragStart: false,
              ),
              child: CustomPaint(
                size: const Size(_clockSize, _clockSize),
                painter: _Clock24DialPainter(
                  startTime: widget.startTime,
                  endTime: widget.endTime,
                  activeHandle: _activeHandle,
                  numberRadius: _numberRadius,
                  arcRadius: _arcRadius,
                ),
                child: Center(
                  child: Container(
                    width: 112,
                    height: 112,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: JedaColors.surface,
                      border: Border.all(color: JedaColors.border),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _activeHandle == _ActiveClockHandle.start
                              ? Icons.lock_clock_outlined
                              : Icons.flag_outlined,
                          size: 18,
                          color: _activeHandle == _ActiveClockHandle.start
                              ? JedaColors.primaryDark
                              : JedaColors.warning,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formattedDuration,
                          style: JedaTypography.labelBold.copyWith(
                            fontSize: 13,
                            color: JedaColors.textPrimary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _activeHandle == _ActiveClockHandle.start
                              ? 'Pilih Jam Mulai'
                              : 'Pilih Jam Selesai',
                          style: JedaTypography.caption.copyWith(
                            fontSize: 10,
                            color: JedaColors.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Psychological affirmation caption
        Text(
          _psychologicalCaption,
          style: JedaTypography.caption.copyWith(
            color: JedaColors.primaryDark,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),

        // Quick Minute Precision Chips (:00, :15, :30, :45)
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Menit (${_activeHandle == _ActiveClockHandle.start ? "Mulai" : "Selesai"}):',
              style: JedaTypography.caption.copyWith(color: JedaColors.textSecondary),
            ),
            const SizedBox(width: 8),
            ...[0, 15, 30, 45].map((minVal) {
              final isSelected = activeTime.minute == minVal;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: InkWell(
                  onTap: () => _setMinuteForActive(minVal),
                  borderRadius: JedaRadii.borderR8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: isSelected ? JedaColors.primary : JedaColors.surfaceSecondary,
                      borderRadius: JedaRadii.borderR8,
                      border: Border.all(
                        color: isSelected ? JedaColors.primary : JedaColors.border,
                      ),
                    ),
                    child: Text(
                      ':${minVal.toString().padLeft(2, "0")}',
                      style: JedaTypography.caption.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isSelected ? JedaColors.textOnPrimary : JedaColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ],
    );
  }

  Widget _buildTimeTabCard({
    required String label,
    required String timeText,
    required String subLabel,
    required bool isSelected,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: JedaRadii.borderR12,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? accentColor.withValues(alpha: 0.1) : JedaColors.surfaceSecondary,
          borderRadius: JedaRadii.borderR12,
          border: Border.all(
            color: isSelected ? accentColor : JedaColors.border,
            width: isSelected ? 1.6 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  label,
                  style: JedaTypography.caption.copyWith(
                    color: isSelected ? accentColor : JedaColors.textSecondary,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
                if (isSelected)
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accentColor,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              timeText,
              style: JedaTypography.heading3.copyWith(
                color: isSelected ? accentColor : JedaColors.textPrimary,
                fontSize: 20,
              ),
            ),
            Text(
              subLabel,
              style: JedaTypography.caption.copyWith(
                fontSize: 10,
                color: JedaColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Clock24DialPainter extends CustomPainter {
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final _ActiveClockHandle activeHandle;
  final double numberRadius;
  final double arcRadius;

  _Clock24DialPainter({
    required this.startTime,
    required this.endTime,
    required this.activeHandle,
    required this.numberRadius,
    required this.arcRadius,
  });

  double _timeToAngle(TimeOfDay time) {
    final totalMinutes = (time.hour % 24) * 60 + time.minute;
    final fraction = totalMinutes / (24 * 60);
    return -math.pi / 2 + fraction * 2 * math.pi;
  }

  bool _isHourInLockedRange(int hour24) {
    final h = hour24 % 24;
    final startH = startTime.hour;
    final endH = endTime.hour;
    if (startH == endH) return h == startH;
    if (startH < endH) {
      return h >= startH && h <= endH;
    } else {
      // Crosses midnight (e.g. 21..6)
      return h >= startH || h <= endH;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = size.width / 2;

    // 1. Outer soft dial background
    final bgPaint = Paint()
      ..color = JedaColors.surfaceSecondary
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, outerRadius, bgPaint);

    final borderPaint = Paint()
      ..color = JedaColors.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawCircle(center, outerRadius, borderPaint);

    // 2. Inactive track ring
    final trackPaint = Paint()
      ..color = JedaColors.border.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, arcRadius, trackPaint);

    // 3. Active range sweep arc
    final startAngle = _timeToAngle(startTime);
    final endAngle = _timeToAngle(endTime);
    double sweepAngle = endAngle - startAngle;
    if (sweepAngle <= 0) {
      sweepAngle += 2 * math.pi;
    }

    // Soft shaded sector from center to number ring
    final sectorPaint = Paint()
      ..color = JedaColors.primary.withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: numberRadius + 14),
      startAngle,
      sweepAngle,
      true,
      sectorPaint,
    );

    final activeArcPaint = Paint()
      ..color = JedaColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: arcRadius),
      startAngle,
      sweepAngle,
      false,
      activeArcPaint,
    );

    // 4. Hour numbers 1 to 24 around the perimeter
    final textPainter = TextPainter(
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );

    final startHourLabel = startTime.hour == 0 ? 24 : startTime.hour;
    final endHourLabel = endTime.hour == 0 ? 24 : endTime.hour;

    for (int i = 1; i <= 24; i++) {
      final angle = -math.pi / 2 + (i % 24) * (2 * math.pi / 24);
      final pos = Offset(
        center.dx + numberRadius * math.cos(angle),
        center.dy + numberRadius * math.sin(angle),
      );

      final isStartHour = i == startHourLabel;
      final isEndHour = i == endHourLabel;
      final isCardinal = i % 6 == 0; // 6, 12, 18, 24
      final inRange = _isHourInLockedRange(i);

      if (isStartHour || isEndHour) {
        final highlightPaint = Paint()
          ..color = isStartHour ? JedaColors.primaryDark : JedaColors.warning
          ..style = PaintingStyle.fill;
        canvas.drawCircle(pos, 13.5, highlightPaint);
      } else if (inRange) {
        final rangeDotPaint = Paint()
          ..color = JedaColors.primarySoft
          ..style = PaintingStyle.fill;
        canvas.drawCircle(pos, 11, rangeDotPaint);
      }

      // Small tick mark between arc and numbers
      final tickStart = Offset(
        center.dx + (arcRadius + 12) * math.cos(angle),
        center.dy + (arcRadius + 12) * math.sin(angle),
      );
      final tickEnd = Offset(
        center.dx + (arcRadius + (isCardinal ? 17 : 14)) * math.cos(angle),
        center.dy + (arcRadius + (isCardinal ? 17 : 14)) * math.sin(angle),
      );
      final tickPaint = Paint()
        ..color = isCardinal ? JedaColors.textSecondary : JedaColors.border
        ..strokeWidth = isCardinal ? 1.6 : 1.0;
      canvas.drawLine(tickStart, tickEnd, tickPaint);

      Color textColor;
      FontWeight fontWeight;
      if (isStartHour || isEndHour) {
        textColor = Colors.white;
        fontWeight = FontWeight.w700;
      } else if (inRange) {
        textColor = JedaColors.primaryDark;
        fontWeight = FontWeight.w700;
      } else if (isCardinal) {
        textColor = JedaColors.textPrimary;
        fontWeight = FontWeight.w700;
      } else {
        textColor = JedaColors.textSecondary;
        fontWeight = FontWeight.w500;
      }

      textPainter.text = TextSpan(
        text: '$i',
        style: TextStyle(
          fontSize: isCardinal || isStartHour || isEndHour ? 11.5 : 10.5,
          fontWeight: fontWeight,
          color: textColor,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(pos.dx - textPainter.width / 2, pos.dy - textPainter.height / 2),
      );
    }

    // 5. Draw Start Handle & End Handle on the arc ring
    final startKnobPos = Offset(
      center.dx + arcRadius * math.cos(startAngle),
      center.dy + arcRadius * math.sin(startAngle),
    );
    final endKnobPos = Offset(
      center.dx + arcRadius * math.cos(endAngle),
      center.dy + arcRadius * math.sin(endAngle),
    );

    _drawHandleKnob(
      canvas,
      position: startKnobPos,
      color: JedaColors.primaryDark,
      isActive: activeHandle == _ActiveClockHandle.start,
    );
    _drawHandleKnob(
      canvas,
      position: endKnobPos,
      color: JedaColors.warning,
      isActive: activeHandle == _ActiveClockHandle.end,
    );
  }

  void _drawHandleKnob(
    Canvas canvas, {
    required Offset position,
    required Color color,
    required bool isActive,
  }) {
    if (isActive) {
      final haloPaint = Paint()
        ..color = color.withValues(alpha: 0.25)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(position, 15, haloPaint);
    }
    final knobPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(position, 10, knobPaint);

    final innerDotPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(position, 4, innerDotPaint);
  }

  @override
  bool shouldRepaint(covariant _Clock24DialPainter oldDelegate) {
    return oldDelegate.startTime != startTime ||
        oldDelegate.endTime != endTime ||
        oldDelegate.activeHandle != activeHandle;
  }
}
