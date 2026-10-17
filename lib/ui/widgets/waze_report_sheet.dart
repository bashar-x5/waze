import 'dart:math' as math;
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
  bool _submitting = false;

  void _onPick(ReportType type) {
    setState(() {
      _selectedType = type;
    });
  }

  Future<void> _send() async {
    if (_selectedType == null || _submitting) return;
    setState(() => _submitting = true);
    final desc = WazeColors.reportTitle(_selectedType!, widget.arabic);
    await widget.onSubmit(_selectedType!, desc);
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

    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    final effectiveBottom = bottomInset + math.max(bottomPadding, 16.0) + 14.0;

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
      padding: EdgeInsets.fromLTRB(20, 12, 20, effectiveBottom),
      child: SafeArea(
        top: false,
        bottom: true,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: dark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 14),

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
                      size: 20,
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
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: textColor,
                          ),
                        ),
                        Text(
                          arabic
                              ? 'اختر نوع البلاغ واضغط إرسال فوراً'
                              : 'Select alert type and tap send immediately',
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
              const SizedBox(height: 14),

              // Grid of 9 Waze Report Types
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 3,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                mainAxisExtent: 84,
                children: ReportType.values.map((type) {
                  final color = WazeColors.reportColor(type);
                  final icon = WazeColors.reportIcon(type);
                  final title = WazeColors.reportTitle(type, arabic);
                  final isSelected = _selectedType == type;

                  return InkWell(
                    onTap: () {
                      if (_selectedType == type) {
                        // Second tap triggers instant send
                        _send();
                      } else {
                        _onPick(type);
                      }
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? color.withValues(alpha: dark ? 0.22 : 0.15)
                            : (dark
                                ? Colors.white.withValues(alpha: 0.04)
                                : Colors.black.withValues(alpha: 0.02)),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? color
                              : (dark ? Colors.white12 : Colors.black12),
                          width: isSelected ? 2.5 : 1.0,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: color.withValues(alpha: 0.35),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                )
                              ]
                            : null,
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          if (isSelected)
                            Positioned(
                              top: 5,
                              right: 5,
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: 11,
                                ),
                              ),
                            ),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: color.withValues(
                                      alpha: isSelected ? 0.25 : 0.14),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: color.withValues(
                                        alpha: isSelected ? 0.95 : 0.4),
                                    width: 1.5,
                                  ),
                                ),
                                child: Center(
                                  child: Icon(icon, color: color, size: 20),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: Text(
                                  title,
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: isSelected
                                        ? FontWeight.w800
                                        : FontWeight.w600,
                                    color: isSelected
                                        ? (dark ? Colors.white : color)
                                        : textColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),

              // Safe Area Submit Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  onPressed: (_selectedType == null || _submitting) ? null : _send,
                  style: FilledButton.styleFrom(
                    backgroundColor: _selectedType != null
                        ? WazeColors.reportColor(_selectedType!)
                        : (dark ? Colors.white12 : Colors.black12),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        dark ? Colors.white10 : Colors.black12,
                    disabledForegroundColor:
                        dark ? Colors.white38 : Colors.black38,
                    elevation: _selectedType != null ? 3 : 0,
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
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (_selectedType != null) ...[
                              Icon(
                                WazeColors.reportIcon(_selectedType!),
                                size: 20,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 8),
                            ],
                            Text(
                              _selectedType == null
                                  ? (arabic
                                      ? 'اختر نوع البلاغ أعلاه'
                                      : 'Select Alert Type Above')
                                  : (arabic
                                      ? 'إرسال البلاغ الآن'
                                      : 'Send Alert Now'),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
