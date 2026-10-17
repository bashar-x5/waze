import 'package:flutter/material.dart';
import '../../domain/models.dart';
import '../waze_theme.dart';

class WazeIncidentPopup extends StatelessWidget {
  const WazeIncidentPopup({
    super.key,
    required this.report,
    required this.arabic,
    required this.dark,
    required this.isConfirmed,
    required this.onConfirm,
  });

  final RoadReport report;
  final bool arabic;
  final bool dark;
  final bool isConfirmed;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final bg = dark ? WazeColors.darkSurface : Colors.white;
    final textColor = dark ? Colors.white : Colors.black87;
    final color = WazeColors.reportColor(report.type);
    final icon = WazeColors.reportIcon(report.type);
    final title = WazeColors.reportTitle(report.type, arabic);

    final diff = DateTime.now().difference(report.createdAt).inMinutes;
    final String timeAgo;
    if (diff <= 0) {
      timeAgo = arabic ? 'الآن' : 'Just now';
    } else if (diff >= 60) {
      final h = diff ~/ 60;
      final m = diff % 60;
      if (m > 0) {
        timeAgo = arabic ? 'منذ $h س $m د' : '${h}h ${m}min ago';
      } else {
        timeAgo = arabic ? 'منذ $h س' : '${h}h ago';
      }
    } else {
      timeAgo = arabic ? 'منذ $diff دقيقة' : '$diff min ago';
    }

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 28),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: dark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time_filled,
                            size: 13,
                            color: dark ? Colors.white60 : Colors.black54,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            timeAgo,
                            style: TextStyle(
                              fontSize: 12,
                              color: dark ? Colors.white60 : Colors.black54,
                            ),
                          ),
                          if (report.confirmations > 0) ...[
                            const SizedBox(width: 12),
                            Icon(
                              Icons.thumb_up_alt_rounded,
                              size: 13,
                              color: WazeColors.cyan,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              arabic
                                  ? '${report.confirmations} تأكيدات'
                                  : '${report.confirmations} confirmed',
                              style: const TextStyle(
                                fontSize: 12,
                                color: WazeColors.cyan,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(
                    Icons.close,
                    color: dark ? Colors.white54 : Colors.black45,
                  ),
                ),
              ],
            ),
            if (report.description.isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: dark ? WazeColors.darkCard : const Color(0xFFF0F3F6),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  report.description,
                  style: TextStyle(
                    fontSize: 14,
                    color: dark ? Colors.white70 : Colors.black87,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 22),
            // Waze "Still there?" confirmation
            Text(
              arabic ? 'هل لا يزال هذا التنبيه في الطريق؟' : 'Is this alert still there?',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, size: 18),
                    label: Text(arabic ? 'غير موجود' : 'Not there'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: isConfirmed
                        ? null
                        : () {
                            onConfirm();
                            Navigator.of(context).pop();
                          },
                    icon: Icon(
                      isConfirmed ? Icons.check : Icons.thumb_up_alt_rounded,
                      size: 18,
                    ),
                    label: Text(
                      isConfirmed
                          ? (arabic ? 'تم التأكيد' : 'Confirmed')
                          : (arabic ? 'لا يزال موجوداً' : 'Still there'),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: WazeColors.cyan,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
