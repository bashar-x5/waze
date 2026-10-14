import 'package:flutter/material.dart';
import '../../domain/models.dart';
import '../../domain/navigation_engine.dart';
import '../waze_theme.dart';

class WazeNavHud extends StatelessWidget {
  const WazeNavHud({
    super.key,
    required this.route,
    required this.progress,
    required this.arabic,
    required this.miles,
    required this.onTapList,
  });

  final DriveRoute route;
  final NavigationProgress progress;
  final bool arabic;
  final bool miles;
  final VoidCallback onTapList;

  String _formatDistance(double meters) {
    if (miles) {
      final mi = meters / 1609.344;
      return mi < 0.1
          ? '${(meters * 3.28084).round()} ft'
          : '${mi.toStringAsFixed(1)} mi';
    }
    if (meters < 1000) {
      return arabic ? '${meters.round()} م' : '${meters.round()} m';
    }
    return arabic
        ? '${(meters / 1000).toStringAsFixed(1)} كم'
        : '${(meters / 1000).toStringAsFixed(1)} km';
  }

  @override
  Widget build(BuildContext context) {
    if (route.steps.isEmpty) return const SizedBox.shrink();

    final stepIdx = progress.stepIndex.clamp(0, route.steps.length - 1);
    final currentStep = route.steps[stepIdx];
    final nextStep = (stepIdx + 1 < route.steps.length)
        ? route.steps[stepIdx + 1]
        : null;

    final maneuverIcon = WazeColors.maneuverIcon(currentStep.type);
    final instruction = currentStep.label(arabic);

    // Distance to this maneuver or remaining to next step
    final distanceText = _formatDistance(currentStep.distanceMeters);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTapList,
            borderRadius: BorderRadius.circular(22),
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF005C8A), Color(0xFF007DAF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(22),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black38,
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  // Maneuver Icon
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 6,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        maneuverIcon,
                        size: 34,
                        color: const Color(0xFF006B9E),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Distance & Instruction
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          distanceText,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          instruction,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            height: 1.2,
                          ),
                        ),
                        if (nextStep != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                WazeColors.maneuverIcon(nextStep.type),
                                size: 14,
                                color: Colors.white70,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  arabic
                                      ? 'ثم: ${nextStep.label(arabic)}'
                                      : 'Then: ${nextStep.label(arabic)}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.white70,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  // List icon
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.format_list_bulleted_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

void showWazeTurnsSheet(
  BuildContext context, {
  required DriveRoute route,
  required NavigationProgress progress,
  required bool arabic,
  required bool miles,
  required bool dark,
}) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) {
      final bg = dark ? WazeColors.darkSurface : Colors.white;
      final textColor = dark ? Colors.white : Colors.black87;

      return Container(
        height: MediaQuery.of(ctx).size.height * 0.7,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
        child: Column(
          children: [
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: dark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Text(
                    arabic ? 'خطوات المسار بالتفصيل' : 'Turn-by-Turn Directions',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: textColor,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const Divider(),
            Expanded(
              child: ListView.separated(
                itemCount: route.steps.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final step = route.steps[i];
                  final isCurrent = i == progress.stepIndex;
                  final isPassed = i < progress.stepIndex;

                  return Container(
                    color: isCurrent
                        ? WazeColors.cyan.withValues(alpha: 0.12)
                        : Colors.transparent,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 14,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          WazeColors.maneuverIcon(step.type),
                          size: 26,
                          color: isCurrent
                              ? WazeColors.blue
                              : (isPassed
                                  ? (dark ? Colors.white24 : Colors.black26)
                                  : (dark ? Colors.white70 : Colors.black87)),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                step.label(arabic),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: isCurrent
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                  color: isPassed
                                      ? (dark ? Colors.white38 : Colors.black38)
                                      : textColor,
                                  decoration: isPassed
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                              ),
                              if (step.roadName.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  step.roadName,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: dark
                                        ? Colors.white54
                                        : Colors.black54,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          step.distanceMeters < 1000
                              ? '${step.distanceMeters.round()} ${arabic ? 'م' : 'm'}'
                              : '${(step.distanceMeters / 1000).toStringAsFixed(1)} ${arabic ? 'كم' : 'km'}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: dark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      );
    },
  );
}

