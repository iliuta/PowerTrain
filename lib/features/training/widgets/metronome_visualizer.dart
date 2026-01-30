import 'package:flutter/material.dart';

/// A compact version of the metronome visualizer for use in the app bar.
/// Shows a smaller horizontal track with a moving circle.
class MetronomeVisualizer extends StatelessWidget {
  final double targetCadence;
  final int tickCount;
  final bool isPullPhase;

  const MetronomeVisualizer({
    super.key,
    required this.targetCadence,
    required this.tickCount,
    required this.isPullPhase,
  });

  @override
  Widget build(BuildContext context) {
    // Calculate position based on phase:
    // Pull phase (isPullPhase = true): moving from left (0.0) to right (1.0)
    // Recovery phase (isPullPhase = false): moving from right (1.0) to left (0.0)
    final position = isPullPhase ? 1.0 : 0.0;
    
    // Calculate animation duration based on phase
    // Pull is 1/3 of cycle, recovery is 2/3 of cycle
    final cycleSeconds = 60 / targetCadence;
    final animationDuration = isPullPhase 
        ? (cycleSeconds / 3 * 1000).round()  // Pull: 1/3 of cycle
        : (cycleSeconds * 2 / 3 * 1000).round(); // Recovery: 2/3 of cycle

    return SizedBox(
      height: 20,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final trackWidth = constraints.maxWidth;
          const circleRadius = 7.0;
          
          // Calculate horizontal offset for the circle
          // Position 0.0 = left, 1.0 = right
          final offset = (trackWidth - circleRadius * 2) * position;

          return Stack(
            children: [
              // Track bar
              Positioned(
                left: circleRadius,
                right: circleRadius,
                top: 9,
                child: Container(
                  height: 2,
                  decoration: BoxDecoration(
                    color: Colors.blue[200],
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ),
              // Animated circle with smooth transition
              AnimatedPositioned(
                duration: Duration(milliseconds: animationDuration),
                curve: isPullPhase ? Curves.easeOutCubic : Curves.easeInOutSine,
                left: offset,
                top: 3,
                child: Container(
                  width: circleRadius * 2,
                  height: circleRadius * 2,
                  decoration: BoxDecoration(
                    color: Colors.blue[700],
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withValues(alpha: 0.4),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
