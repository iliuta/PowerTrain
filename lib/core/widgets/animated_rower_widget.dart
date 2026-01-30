import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:ftms/core/config/live_data_field_format_strategy.dart';
import 'package:ftms/core/config/live_data_field_config.dart';
import 'package:ftms/core/utils/i18n_utils.dart';
import 'package:ftms/core/utils/responsive_utils.dart';
import '../models/live_data_field_value.dart';
import 'live_data_icon_registry.dart';
import '../../l10n/app_localizations.dart';

/// Widget for displaying stroke rate with an animated rower on a scull.
/// The rower is animated in rhythm with the current stroke rate.
/// View is from the rear of the scull, showing the athlete's face and hands pulling oars.
class AnimatedRowerWidget extends StatefulWidget {
  final LiveDataFieldConfig displayField;
  final LiveDataFieldValue? param;
  final Color color;
  final ({double lower, double upper})? targetInterval;

  const AnimatedRowerWidget({
    super.key,
    required this.displayField,
    this.param,
    this.color = Colors.blue,
    this.targetInterval,
  });

  @override
  State<AnimatedRowerWidget> createState() => _AnimatedRowerWidgetState();
}

class _AnimatedRowerWidgetState extends State<AnimatedRowerWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _rowingAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _calculateStrokeDuration(),
    );

    // Rowing animation: 0.0 = catch (arms extended), 1.0 = finish (arms pulled in)
    // We use a custom curve to simulate the rowing motion:
    // - Quick drive phase (pulling)
    // - Slower recovery phase (extending arms back)
    _rowingAnimation = CurvedAnimation(
      parent: _controller,
      curve: const _RowingCurve(),
    );

    if (widget.param != null) {
      _controller.repeat();
    }
  }

  Duration _calculateStrokeDuration() {
    if (widget.param == null) {
      return const Duration(seconds: 2); // Default when no data
    }
    final strokeRate = widget.param!.getScaledValue().toDouble();
    if (strokeRate <= 0) {
      return const Duration(seconds: 2);
    }
    // Stroke rate is in strokes per minute, so duration = 60/strokeRate seconds
    final durationMs = (60000 / strokeRate).round();
    return Duration(milliseconds: durationMs.clamp(1000, 6000));
  }

  @override
  void didUpdateWidget(AnimatedRowerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Update animation duration when stroke rate changes
    final newDuration = _calculateStrokeDuration();
    if (_controller.duration != newDuration) {
      _controller.duration = newDuration;
      if (widget.param != null && widget.param!.getScaledValue() > 0) {
        if (!_controller.isAnimating) {
          _controller.repeat();
        }
      } else {
        _controller.stop();
        _controller.value = 0.3; // Rest position
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scale = ResponsiveUtils.scaleFactor(context);
    IconData? iconData = getLiveDataIcon(widget.displayField.icon);

    if (widget.param == null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                getFieldLabel(widget.displayField,
                    Localizations.localeOf(context).languageCode),
                style:
                    TextStyle(fontWeight: FontWeight.bold, fontSize: 10 * scale),
              ),
              if (iconData != null)
                Padding(
                  padding: EdgeInsets.only(left: 6.0 * scale),
                  child:
                      Icon(iconData, size: 16 * scale, color: Colors.grey[600]),
                ),
            ],
          ),
          Text(
            AppLocalizations.of(context)!.noData,
            style: TextStyle(color: Colors.grey, fontSize: 10 * scale),
          ),
        ],
      );
    }

    final scaledValue = widget.param!.getScaledValue();

    // Format the value
    String formattedValue =
        '${scaledValue.toStringAsFixed(0)} ${widget.displayField.unit}';
    if (widget.displayField.formatter != null) {
      final formatterStrategy =
          LiveDataFieldFormatter.getStrategy(widget.displayField.formatter!);
      if (formatterStrategy != null) {
        formattedValue = formatterStrategy.format(
            field: widget.displayField, paramValue: scaledValue);
      }
    }

    // Determine if within target range
    bool isInTarget = false;
    if (widget.targetInterval != null) {
      isInTarget = scaledValue >= widget.targetInterval!.lower &&
          scaledValue <= widget.targetInterval!.upper;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              getFieldLabel(widget.displayField,
                  Localizations.localeOf(context).languageCode),
              style:
                  TextStyle(fontWeight: FontWeight.bold, fontSize: 10 * scale),
            ),
            if (iconData != null)
              Padding(
                padding: EdgeInsets.only(left: 6.0 * scale),
                child:
                    Icon(iconData, size: 16 * scale, color: Colors.grey[600]),
              ),
          ],
        ),
        SizedBox(height: 4 * scale),
        SizedBox(
          width: 140 * scale,
          height: 80 * scale,
          child: AnimatedBuilder(
            animation: _rowingAnimation,
            builder: (context, child) {
              return CustomPaint(
                painter: _RowerPainter(
                  rowingPhase: _rowingAnimation.value,
                  color: widget.color,
                  isInTarget: isInTarget,
                  scale: scale,
                ),
              );
            },
          ),
        ),
        SizedBox(height: 2 * scale),
        Text(
          formattedValue,
          style: TextStyle(fontSize: 16 * scale, color: widget.color),
        ),
      ],
    );
  }
}

/// Custom curve for rowing animation.
/// Drive phase (0.0 to 0.5): faster, more power
/// Recovery phase (0.5 to 1.0): slower, relaxed return
class _RowingCurve extends Curve {
  const _RowingCurve();

  @override
  double transformInternal(double t) {
    if (t < 0.4) {
      // Drive phase: faster (40% of time for the pull)
      return Curves.easeOut.transform(t / 0.4);
    } else {
      // Recovery phase: slower (60% of time for the return)
      return 1.0 - Curves.easeInOut.transform((t - 0.4) / 0.6);
    }
  }
}

/// CustomPainter for the animated rower.
/// Shows a scull viewed from behind with the athlete facing the viewer.
class _RowerPainter extends CustomPainter {
  final double rowingPhase; // 0.0 = catch (extended), 1.0 = finish (pulled in)
  final Color color;
  final bool isInTarget;
  final double scale;

  _RowerPainter({
    required this.rowingPhase,
    required this.color,
    required this.isInTarget,
    required this.scale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;

    // Colors
    final boatColor = Colors.brown[700]!;
    final oarColor = Colors.brown[400]!;
    final skinColor = const Color(0xFFE0B0A0);
    final shirtColor = isInTarget ? Colors.green : color;
    final waterColor = Colors.blue[200]!;

    // Draw water
    _drawWater(canvas, size, waterColor);

    // Draw the scull (boat)
    _drawScull(canvas, size, centerX, centerY, boatColor);

    // Draw oars with animation
    _drawOars(canvas, size, centerX, centerY, oarColor);

    // Draw the athlete
    _drawAthlete(canvas, size, centerX, centerY, skinColor, shirtColor);

    // Draw stroke rate indicator arc
    _drawStrokeIndicator(canvas, size, centerX);
  }

  void _drawWater(Canvas canvas, Size size, Color waterColor) {
    final waterPaint = Paint()
      ..color = waterColor.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;

    // Simple water representation at the bottom
    final waterPath = Path()
      ..moveTo(0, size.height * 0.75)
      ..quadraticBezierTo(
        size.width * 0.25,
        size.height * 0.72,
        size.width * 0.5,
        size.height * 0.75,
      )
      ..quadraticBezierTo(
        size.width * 0.75,
        size.height * 0.78,
        size.width,
        size.height * 0.75,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(waterPath, waterPaint);
  }

  void _drawScull(
      Canvas canvas, Size size, double centerX, double centerY, Color color) {
    final boatPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final boatOutline = Paint()
      ..color = Colors.brown[900]!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5 * scale;

    // Boat hull - viewed from behind, it's a curved shape
    final boatPath = Path();
    final boatY = size.height * 0.7;
    final boatWidth = size.width * 0.3;
    final boatHeight = size.height * 0.08;

    boatPath.moveTo(centerX - boatWidth / 2, boatY);
    boatPath.quadraticBezierTo(
      centerX,
      boatY + boatHeight,
      centerX + boatWidth / 2,
      boatY,
    );
    boatPath.quadraticBezierTo(
      centerX,
      boatY - boatHeight * 0.3,
      centerX - boatWidth / 2,
      boatY,
    );

    canvas.drawPath(boatPath, boatPaint);
    canvas.drawPath(boatPath, boatOutline);
  }

  void _drawOars(
      Canvas canvas, Size size, double centerX, double centerY, Color color) {
    final oarPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3 * scale
      ..strokeCap = StrokeCap.round;

    final bladePaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Oar angle changes based on rowing phase
    // At catch (0.0): oars are extended out, more horizontal
    // At finish (1.0): oars are pulled in, more vertical/angled
    final baseAngle = math.pi * 0.15; // Base angle from horizontal
    final angleRange = math.pi * 0.25; // How much the angle changes

    // Left oar - extends to the left
    final leftOarAngle = baseAngle + (angleRange * rowingPhase);
    final oarLength = size.width * 0.35 * (1.0 - rowingPhase * 0.15);

    final leftOarStart = Offset(centerX - size.width * 0.1, size.height * 0.55);
    final leftOarEnd = Offset(
      leftOarStart.dx - oarLength * math.cos(leftOarAngle),
      leftOarStart.dy + oarLength * math.sin(leftOarAngle),
    );

    canvas.drawLine(leftOarStart, leftOarEnd, oarPaint);

    // Left blade
    _drawOarBlade(canvas, leftOarEnd, -leftOarAngle - math.pi / 2, bladePaint);

    // Right oar - extends to the right (mirror)
    final rightOarStart =
        Offset(centerX + size.width * 0.1, size.height * 0.55);
    final rightOarEnd = Offset(
      rightOarStart.dx + oarLength * math.cos(leftOarAngle),
      rightOarStart.dy + oarLength * math.sin(leftOarAngle),
    );

    canvas.drawLine(rightOarStart, rightOarEnd, oarPaint);

    // Right blade
    _drawOarBlade(canvas, rightOarEnd, leftOarAngle + math.pi / 2, bladePaint);
  }

  void _drawOarBlade(Canvas canvas, Offset position, double angle, Paint paint) {
    final bladeWidth = 12 * scale;
    final bladeHeight = 6 * scale;

    canvas.save();
    canvas.translate(position.dx, position.dy);
    canvas.rotate(angle);

    final bladePath = Path()
      ..addOval(Rect.fromCenter(
        center: Offset.zero,
        width: bladeWidth,
        height: bladeHeight,
      ));

    canvas.drawPath(bladePath, paint);
    canvas.restore();
  }

  void _drawAthlete(Canvas canvas, Size size, double centerX, double centerY,
      Color skinColor, Color shirtColor) {
    // Body position changes with rowing phase
    // At catch: leaning forward slightly, arms extended
    // At finish: leaning back slightly, arms pulled in

    final bodyLean = (rowingPhase - 0.5) * 0.1; // Lean back at finish

    // Torso
    final torsoPaint = Paint()
      ..color = shirtColor
      ..style = PaintingStyle.fill;

    final torsoY = size.height * 0.45 + bodyLean * size.height * 0.2;
    final torsoWidth = size.width * 0.15;
    final torsoHeight = size.height * 0.25;

    // Draw torso (rounded rectangle)
    final torsoRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(centerX, torsoY),
        width: torsoWidth,
        height: torsoHeight,
      ),
      Radius.circular(5 * scale),
    );
    canvas.drawRRect(torsoRect, torsoPaint);

    // Head
    final headPaint = Paint()
      ..color = skinColor
      ..style = PaintingStyle.fill;

    final headY = torsoY - torsoHeight / 2 - size.height * 0.08;
    final headRadius = size.width * 0.055;

    canvas.drawCircle(Offset(centerX, headY), headRadius, headPaint);

    // Simple face features
    final facePaint = Paint()
      ..color = Colors.brown[800]!
      ..style = PaintingStyle.fill;

    // Eyes
    final eyeY = headY - headRadius * 0.15;
    final eyeSpacing = headRadius * 0.4;
    canvas.drawCircle(
        Offset(centerX - eyeSpacing, eyeY), headRadius * 0.12, facePaint);
    canvas.drawCircle(
        Offset(centerX + eyeSpacing, eyeY), headRadius * 0.12, facePaint);

    // Simple mouth
    final mouthPaint = Paint()
      ..color = Colors.brown[600]!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1 * scale;

    final mouthY = headY + headRadius * 0.35;
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(centerX, mouthY),
        width: headRadius * 0.5,
        height: headRadius * 0.3,
      ),
      0,
      math.pi,
      false,
      mouthPaint,
    );

    // Arms
    final armPaint = Paint()
      ..color = skinColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4 * scale
      ..strokeCap = StrokeCap.round;

    // Arm position based on rowing phase
    // At catch: arms extended forward and out
    // At finish: arms bent and pulled back

    final shoulderY = torsoY - torsoHeight * 0.35;
    final shoulderOffset = torsoWidth * 0.5;

    // Left arm
    final leftShoulderX = centerX - shoulderOffset;
    final leftElbowX =
        leftShoulderX - size.width * 0.06 * (1 + rowingPhase * 0.5);
    final leftElbowY = shoulderY + size.height * 0.05 * rowingPhase;
    final leftHandX = leftShoulderX - size.width * 0.1 * (1 - rowingPhase * 0.3);
    final leftHandY = shoulderY + size.height * 0.08 * (1 - rowingPhase * 0.5);

    // Draw arm segments
    canvas.drawLine(
      Offset(leftShoulderX, shoulderY),
      Offset(leftElbowX, leftElbowY),
      armPaint,
    );
    canvas.drawLine(
      Offset(leftElbowX, leftElbowY),
      Offset(leftHandX, leftHandY),
      armPaint,
    );

    // Right arm (mirror)
    final rightShoulderX = centerX + shoulderOffset;
    final rightElbowX =
        rightShoulderX + size.width * 0.06 * (1 + rowingPhase * 0.5);
    final rightElbowY = shoulderY + size.height * 0.05 * rowingPhase;
    final rightHandX =
        rightShoulderX + size.width * 0.1 * (1 - rowingPhase * 0.3);
    final rightHandY = shoulderY + size.height * 0.08 * (1 - rowingPhase * 0.5);

    canvas.drawLine(
      Offset(rightShoulderX, shoulderY),
      Offset(rightElbowX, rightElbowY),
      armPaint,
    );
    canvas.drawLine(
      Offset(rightElbowX, rightElbowY),
      Offset(rightHandX, rightHandY),
      armPaint,
    );

    // Hands
    final handPaint = Paint()
      ..color = skinColor
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(leftHandX, leftHandY), 3 * scale, handPaint);
    canvas.drawCircle(Offset(rightHandX, rightHandY), 3 * scale, handPaint);
  }

  void _drawStrokeIndicator(Canvas canvas, Size size, double centerX) {
    // Small arc at the top showing stroke phase
    final indicatorPaint = Paint()
      ..color = color.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3 * scale
      ..strokeCap = StrokeCap.round;

    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3 * scale
      ..strokeCap = StrokeCap.round;

    final rect = Rect.fromCenter(
      center: Offset(centerX, size.height * 0.1),
      width: size.width * 0.4,
      height: size.height * 0.15,
    );

    // Background arc
    canvas.drawArc(rect, math.pi, math.pi, false, indicatorPaint);

    // Progress arc
    canvas.drawArc(rect, math.pi, math.pi * rowingPhase, false, progressPaint);
  }

  @override
  bool shouldRepaint(covariant _RowerPainter oldDelegate) {
    return oldDelegate.rowingPhase != rowingPhase ||
        oldDelegate.color != color ||
        oldDelegate.isInTarget != isInTarget;
  }
}
