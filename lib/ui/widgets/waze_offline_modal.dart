import 'package:flutter/material.dart';
import '../../services/offline_map_service.dart';
import '../waze_theme.dart';

class WazeOfflineModal extends StatelessWidget {
  const WazeOfflineModal({
    super.key,
    required this.service,
    required this.arabic,
    required this.dark,
  });

  final OfflineMapService service;
  final bool arabic;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final bg = dark ? WazeColors.darkSurface : Colors.white;
    final textColor = dark ? Colors.white : Colors.black87;

    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        return Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 18,
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
                const SizedBox(height: 18),

                // Header
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: WazeColors.cyan.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.download_for_offline_rounded,
                          color: WazeColors.cyan,
                          size: 28,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            arabic
                                ? 'خريطة بغداد بدون إنترنت'
                                : 'Baghdad Offline Map',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            arabic
                                ? 'تصفح وتنقل بدون الحاجة لبيانات الهاتف'
                                : 'Navigate without mobile data or internet',
                            style: TextStyle(
                              fontSize: 12,
                              color: dark ? Colors.white60 : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Map coverage card
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: dark ? WazeColors.darkCard : const Color(0xFFF2F5F8),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: dark ? Colors.white12 : Colors.black12,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.location_city_rounded,
                            color: WazeColors.blue,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            arabic
                                ? 'نطاق التغطية: بغداد الكبرى (الكرخ والرصافة)'
                                : 'Coverage: Greater Baghdad (Karkh & Rusafa)',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: textColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            arabic ? 'الحالة:' : 'Status:',
                            style: TextStyle(
                              fontSize: 12,
                              color: dark ? Colors.white60 : Colors.black54,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: service.isOfflineReady
                                  ? WazeColors.green.withValues(alpha: 0.15)
                                  : (service.isDownloading
                                      ? WazeColors.cyan.withValues(alpha: 0.15)
                                      : Colors.grey.withValues(alpha: 0.15)),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  service.isOfflineReady
                                      ? Icons.check_circle_rounded
                                      : (service.isDownloading
                                          ? Icons.sync_rounded
                                          : Icons.info_outline_rounded),
                                  size: 14,
                                  color: service.isOfflineReady
                                      ? WazeColors.green
                                      : (service.isDownloading
                                          ? WazeColors.cyan
                                          : Colors.grey),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  service.isOfflineReady
                                      ? (arabic
                                          ? 'جاهزة بدون إنترنت (${service.diskSizeFormatted})'
                                          : 'Offline Ready (${service.diskSizeFormatted})')
                                      : (service.isDownloading
                                          ? (arabic
                                              ? 'جاري التحميل...'
                                              : 'Downloading...')
                                          : (arabic
                                              ? 'غير محملة'
                                              : 'Not Downloaded')),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: service.isOfflineReady
                                        ? WazeColors.green
                                        : (service.isDownloading
                                            ? WazeColors.cyan
                                            : Colors.grey),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Download Progress (if downloading)
                if (service.isDownloading) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${(service.progress * 100).round()}%',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: WazeColors.cyan,
                        ),
                      ),
                      Text(
                        '${service.downloadedCount} / ${service.totalCount} ${arabic ? 'مربع خريطة' : 'tiles'}',
                        style: TextStyle(
                          fontSize: 12,
                          color: dark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: service.progress,
                      minHeight: 8,
                      backgroundColor:
                          dark ? Colors.white12 : Colors.black12,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        WazeColors.cyan,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Action Buttons
                if (service.isDownloading)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => service.cancelDownload(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        arabic ? 'إلغاء التحميل' : 'Cancel Download',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  )
                else if (service.isOfflineReady)
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => service.downloadBaghdadTiles(),
                          icon: const Icon(Icons.refresh_rounded, size: 20),
                          label: Text(
                            arabic ? 'تحديث الخريطة' : 'Update Map',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: WazeColors.cyan,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: () => service.deleteOfflineMap(),
                        icon: const Icon(Icons.delete_outline_rounded,
                            size: 18, color: Colors.red),
                        label: Text(
                          arabic ? 'حذف' : 'Delete',
                          style: const TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.red),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => service.downloadBaghdadTiles(),
                      icon: const Icon(Icons.download_rounded, size: 22),
                      label: Text(
                        arabic
                            ? 'تحميل خريطة بغداد (استخدام أوفلاين)'
                            : 'Download Baghdad Map (Offline Use)',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: WazeColors.cyan,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

void showWazeOfflineModal(
  BuildContext context, {
  OfflineMapService? service,
  required bool arabic,
  required bool dark,
}) {
  final s = service ?? OfflineMapService();
  s.init();
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => WazeOfflineModal(
      service: s,
      arabic: arabic,
      dark: dark,
    ),
  );
}
