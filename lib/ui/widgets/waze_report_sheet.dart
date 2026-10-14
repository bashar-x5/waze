import 'package:flutter/material.dart';
import '../../domain/models.dart';
import '../waze_theme.dart';

class WazeReportSheet extends StatefulWidget {
  const WazeReportSheet({
    super.key,
    required this.arabic,
    required this.dark,
    required this.onSubmit,
  });

  final bool arabic;
  final bool dark;
  final Future<void> Function(ReportType type, String description) onSubmit;

  @override
  State<WazeReportSheet> createState() => _WazeReportSheetState();
}

class _WazeReportSheetState extends State<WazeReportSheet> {
  ReportType? _selectedType;
  final TextEditingController _textController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _onPick(ReportType type) {
    setState(() {
      _selectedType = type;
    });
  }

  Future<void> _send() async {
    if (_selectedType == null || _submitting) return;
    setState(() => _submitting = true);
    await widget.onSubmit(_selectedType!, _textController.text.trim());
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = widget.dark;
    final arabic = widget.arabic;
    final bg = dark ? WazeColors.darkSurface : Colors.white;
    final textColor = dark ? Colors.white : Colors.black87;

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
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: dark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 16),

            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: WazeColors.orange,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.campaign_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        arabic ? 'شارك بلاغاً مع السائقين' : 'Share a Road Alert',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: textColor,
                        ),
                      ),
                      Text(
                        arabic
                            ? 'ساعد المجتمع بمعرفة حالة الطريق فوراً'
                            : 'Help other Wazers know real-time conditions',
                        style: TextStyle(
                          fontSize: 12,
                          color: dark ? Colors.white60 : Colors.black54,
                        ),
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
            const SizedBox(height: 18),

            if (_selectedType == null) ...[
              // Grid of 9 Waze Report Types
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 3,
                mainAxisSpacing: 14,
                crossAxisSpacing: 12,
                childAspectRatio: 0.95,
                children: ReportType.values.map((type) {
                  final color = WazeColors.reportColor(type);
                  final icon = WazeColors.reportIcon(type);
                  final title = WazeColors.reportTitle(type, arabic);

                  return InkWell(
                    onTap: () => _onPick(type),
                    borderRadius: BorderRadius.circular(16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: color.withValues(alpha: 0.4),
                              width: 2,
                            ),
                          ),
                          child: Center(
                            child: Icon(icon, color: color, size: 26),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ] else ...[
              // Detail / Comment entry for selected report
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: WazeColors.reportColor(_selectedType!),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      WazeColors.reportIcon(_selectedType!),
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      WazeColors.reportTitle(_selectedType!, arabic),
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _selectedType = null),
                    child: Text(arabic ? 'تغيير' : 'Change'),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _textController,
                autofocus: true,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  hintText: arabic
                      ? 'ملاحظة إضافية (اختياري، مثلاً: في المسار الأيمن)'
                      : 'Add comment (optional, e.g. right lane blocked)',
                  hintStyle: TextStyle(
                    color: dark ? Colors.white38 : Colors.black38,
                    fontSize: 13,
                  ),
                  filled: true,
                  fillColor: dark ? WazeColors.darkCard : const Color(0xFFF0F3F6),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _submitting ? null : _send,
                  style: FilledButton.styleFrom(
                    backgroundColor: WazeColors.orange,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          arabic ? 'إرسال البلاغ الآن' : 'Send Alert Now',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ],
          ],
        ),
      ),
      ),
    );
  }
}
