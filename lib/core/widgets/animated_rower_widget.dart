import 'package:flutter/material.dart';
import 'package:ftms/core/config/live_data_field_format_strategy.dart';
import 'package:ftms/core/config/live_data_field_config.dart';
import 'package:ftms/core/utils/i18n_utils.dart';
import 'package:ftms/core/utils/responsive_utils.dart';
import '../models/live_data_field_value.dart';
import 'live_data_icon_registry.dart';
import '../../l10n/app_localizations.dart';

/// Animation frames for the rowing animation.
/// Frame order represents the rowing cycle:
/// 1. Finish position (arms pulled in)
/// 2. Start of recovery (arms extending)
/// 3. Catch position (arms fully extended, body forward)
/// 4. Start of drive (pulling back)
/// 5. Mid drive (arms coming in)
/// Then back to frame 1.
const List<String> _rowerFrames = [
  'assets/rower/frame_1.png',
  'assets/rower/frame_2.png',
  'assets/rower/frame_3.png',
  'assets/rower/frame_4.png',
  'assets/rower/frame_5.png',
  'assets/rower/frame_6.png',
];

/// Widget for displaying stroke rate with an animated rower on a scull.
/// Uses sprite-based animation with pre-rendered frames.
/// The rower is animated in rhythm with the current stroke rate.
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
  
  // Preloaded images for smooth animation
  final List<ImageProvider> _imageProviders = [];
  bool _imagesPreloaded = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _calculateStrokeDuration(),
    );

    if (widget.param != null && widget.param!.getScaledValue() > 0) {
      _controller.repeat();
    }
    
    // Initialize image providers
    for (final frame in _rowerFrames) {
      _imageProviders.add(AssetImage(frame));
    }
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Precache images for smooth animation
    if (!_imagesPreloaded) {
      for (final provider in _imageProviders) {
        precacheImage(provider, context);
      }
      _imagesPreloaded = true;
    }
  }

  Duration _calculateStrokeDuration() {
    if (widget.param == null) {
      return const Duration(seconds: 2);
    }
    final strokeRate = widget.param!.getScaledValue().toDouble();
    if (strokeRate <= 0) {
      return const Duration(seconds: 2);
    }
    // Stroke rate is in strokes per minute
    final durationMs = (60000 / strokeRate).round();
    return Duration(milliseconds: durationMs.clamp(1000, 6000));
  }

  @override
  void didUpdateWidget(AnimatedRowerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    final newDuration = _calculateStrokeDuration();
    if (_controller.duration != newDuration) {
      _controller.duration = newDuration;
      if (widget.param != null && widget.param!.getScaledValue() > 0) {
        if (!_controller.isAnimating) {
          _controller.repeat();
        }
      } else {
        _controller.stop();
        _controller.value = 0.0;
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Gets the current frame index based on animation progress.
  /// The animation cycles through all frames smoothly.
  int _getCurrentFrameIndex(double animationValue) {
    // Map animation value (0.0 to 1.0) to frame index
    final frameCount = _rowerFrames.length;
    final index = (animationValue * frameCount).floor();
    return index.clamp(0, frameCount - 1);
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
        // Animated rower image
        SizedBox(
          width: 180 * scale,
          height: 120 * scale,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final frameIndex = _getCurrentFrameIndex(_controller.value);
              return Stack(
                alignment: Alignment.center,
                children: [
                  // Rower image
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8 * scale),
                    child: Image(
                      image: _imageProviders[frameIndex],
                      fit: BoxFit.contain,
                      width: 180 * scale,
                      height: 120 * scale,
                      // Add color filter when in target
                      color: isInTarget 
                          ? Colors.green.withValues(alpha: 0.15)
                          : null,
                      colorBlendMode: isInTarget 
                          ? BlendMode.srcATop 
                          : null,
                      errorBuilder: (context, error, stackTrace) {
                        // Fallback if images not found
                        return _FallbackRowerWidget(
                          phase: _controller.value,
                          color: widget.color,
                          isInTarget: isInTarget,
                          scale: scale,
                        );
                      },
                    ),
                  ),
                  // Target indicator overlay
                  if (isInTarget)
                    Positioned(
                      top: 4 * scale,
                      right: 4 * scale,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 6 * scale,
                          vertical: 2 * scale,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(4 * scale),
                        ),
                        child: Icon(
                          Icons.check,
                          size: 12 * scale,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
        SizedBox(height: 2 * scale),
        Text(
          formattedValue,
          style: TextStyle(
            fontSize: 16 * scale,
            color: isInTarget ? Colors.green : widget.color,
            fontWeight: isInTarget ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}

/// Fallback widget shown if the rower images are not available.
/// Provides a simple animated representation.
class _FallbackRowerWidget extends StatelessWidget {
  final double phase;
  final Color color;
  final bool isInTarget;
  final double scale;

  const _FallbackRowerWidget({
    required this.phase,
    required this.color,
    required this.isInTarget,
    required this.scale,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8 * scale),
        border: Border.all(
          color: isInTarget ? Colors.green : color,
          width: 2,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.rowing,
              size: 40 * scale,
              color: isInTarget ? Colors.green : color,
            ),
            SizedBox(height: 4 * scale),
            Text(
              'Rowing',
              style: TextStyle(
                fontSize: 12 * scale,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
