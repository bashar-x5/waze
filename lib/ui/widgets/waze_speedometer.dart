import 'package:flutter/material.dart';
import '../waze_theme.dart';

class WazeSpeedometer extends StatelessWidget {
  const WazeSpeedometer({
    super.key,
    required this.speedKph,
    required this.miles,
    required this.dark,
  });

  final double speedKph;
  final bool miles;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final speed = miles ? (speedKph * 0.621371).round() : speedKph.round();
    final unit = miles ? 'mph' : 'km/h';
    final isFast = speed > 100;

    return Container(
      width: 68,
      height: 68,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: dark ? WazeColors.darkSurface : Colors.white,
        border: Border.all(
          color: isFast ? WazeColors.red : (dark ? Colors.white24 : Colors.black12),
          width: 3.5,
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$speed',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: isFast
                    ? WazeColors.red
                    : (dark ? Colors.white : Colors.black87),
                height: 1.0,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              unit,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: dark ? Colors.white60 : Colors.black54,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
