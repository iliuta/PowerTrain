import 'package:flutter/material.dart';

/// A visual metronome representation showing a circle moving left-right
/// synchronized with the audio metronome ticks.
/// The circle moves from left (tick 0) to right (tick 1) and back.
class MetronomeVisualizer extends StatelessWidget {
  final double targetCadence;
  final int tickCount;

  const MetronomeVisualizer({
    super.key,
    required this.targetCadence,
    required this.tickCount,
  });

  @override
  Widget build(BuildContext context) {
    // Calculate position: tickCount alternates between odd (right) and even (left)
    // We want smooth animation from left to right when odd, right to left when even
    final isMovingRight = tickCount.isEven;
    final position = isMovingRight ? 0.0 : 1.0;

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
                  AnimatedPositioned(
                    duration: Duration(
                      milliseconds: (60 / targetCadence * 500).round(),
                    ),
                    curve: Curves.easeInOut,
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
