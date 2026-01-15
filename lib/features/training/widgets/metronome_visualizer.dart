import 'package:flutter/material.dart';

/// A visual metronome representation showing a circle moving left-right
/// synchronized with the audio metronome ticks.
/// The circle moves from left (pull phase - faster) to right (recovery phase - slower).
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

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: SizedBox(
          height: 40,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final trackWidth = constraints.maxWidth;
              final circleRadius = 12.0;
              
              // Calculate horizontal offset for the circle
              // Position 0.0 = left, 1.0 = right
              final offset = (trackWidth - circleRadius * 2) * position;

              return Stack(
                children: [
                  // Track bar
                  Positioned(
                    left: circleRadius,
                    right: circleRadius,
                    top: 18,
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.blue[200],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  // End markers
                  Positioned(
                    left: 0,
                    top: 14,
                    child: Container(
                      width: circleRadius * 2,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.blue[300],
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    top: 14,
                    child: Container(
                      width: circleRadius * 2,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.blue[300],
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                  // Animated circle with smooth transition
                  // Use different curves for pull (faster, explosive) vs recovery (slower, smooth)
                  AnimatedPositioned(
                    duration: Duration(milliseconds: animationDuration),
                    curve: isPullPhase ? Curves.easeOutCubic : Curves.easeInOutSine,
                    left: offset,
                    top: 8,
                    child: Container(
                      width: circleRadius * 2,
                      height: circleRadius * 2,
                      decoration: BoxDecoration(
                        color: Colors.blue[700],
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withValues(alpha: 0.5),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
