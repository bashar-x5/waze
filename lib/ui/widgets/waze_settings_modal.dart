import 'package:flutter/material.dart';
import '../../app/app_controller.dart';
import '../../domain/models.dart';
import '../waze_theme.dart';
import 'waze_offline_modal.dart';

class WazeSettingsModal extends StatelessWidget {
  const WazeSettingsModal({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final dark = c.dark;
    final arabic = c.arabic;
    final bg = dark ? WazeColors.darkSurface : Colors.white;
    final textColor = dark ? Colors.white : Colors.black87;

    return Material(
      color: bg,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.85,
        child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: dark ? Colors.white24 : Colors.black12,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: WazeColors.cyan.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.settings_rounded,
                    color: WazeColors.blue,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    arabic ? 'الإعدادات والتفضيلات' : 'Settings & Preferences',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: textColor,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                // 100% Free Open Badge
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        WazeColors.cyan.withValues(alpha: 0.2),
                        WazeColors.blue.withValues(alpha: 0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: WazeColors.cyan.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.verified_rounded,
                        color: WazeColors.blue,
                        size: 32,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              arabic
                                  ? 'تطبيق ملاحة حر ومجاني 100%'
                                  : '100% Free & Open-Source Waze Alternative',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              arabic
                                  ? 'يعتمد كلياً على خرائط OpenStreetMap ومحرك OSRM المفتوح دون أي اشتراكات أو رسوم خفية.'
                                  : 'Powered entirely by OpenStreetMap & OSRM routing with zero API fees or paid subscriptions.',
                              style: TextStyle(
                                fontSize: 12,
                                color: dark ? Colors.white70 : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // General section
                _buildSectionHeader(
                  arabic ? 'العرض واللغة' : 'Display & Language',
                  textColor,
                ),
                SwitchListTile(
                  title: Text(
                    arabic ? 'اللغة العربية' : 'Arabic Language (العربية)',
                    style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    arabic ? 'التبديل بين العربية والإنجليزية' : 'Switch between Arabic and English',
                    style: TextStyle(color: dark ? Colors.white60 : Colors.black54, fontSize: 12),
                  ),
                  value: c.arabic,
                  activeThumbColor: WazeColors.cyan,
                  onChanged: (val) => c.setLanguage(val),
                ),
                SwitchListTile(
                  title: Text(
                    arabic ? 'الوضع الليلي (Dark Mode)' : 'Dark Theme',
                    style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    arabic ? 'مظهر داكن مريح أثناء القيادة الليلية' : 'High-contrast dark map and UI for night drives',
                    style: TextStyle(color: dark ? Colors.white60 : Colors.black54, fontSize: 12),
                  ),
                  value: c.dark,
                  activeThumbColor: WazeColors.cyan,
                  onChanged: (val) => c.setDark(val),
                ),
                SwitchListTile(
                  title: Text(
                    arabic ? 'عرض القمر الصناعي ثلاثي الأبعاد (3D Satellite)' : '3D Satellite View',
                    style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    arabic ? 'صور فضائية عالية الدقة مع أسماء الشوارع والمباني' : 'High-resolution satellite view with road and place labels',
                    style: TextStyle(color: dark ? Colors.white60 : Colors.black54, fontSize: 12),
                  ),
                  value: c.satellite,
                  activeThumbColor: Colors.amber,
                  secondary: const Icon(Icons.satellite_alt_rounded, color: Colors.amber),
                  onChanged: (val) => c.setSatellite(val),
                ),
                SwitchListTile(
                  title: Text(
                    arabic ? 'وحدة القياس بالميل' : 'Miles (Imperial)',
                    style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    arabic ? 'افتراضي: كيلومترات (كم)' : 'Default: Kilometers (km)',
                    style: TextStyle(color: dark ? Colors.white60 : Colors.black54, fontSize: 12),
                  ),
                  value: c.miles,
                  activeThumbColor: WazeColors.cyan,
                  onChanged: (val) => c.setMiles(val),
                ),

                const Divider(),
                _buildSectionHeader(
                  arabic ? 'التوجيه الصوتي والملاحة' : 'Voice Guidance',
                  textColor,
                ),
                SwitchListTile(
                  title: Text(
                    arabic ? 'التوجيه الصوتي (Voice)' : 'Voice Guidance',
                    style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    arabic ? 'نطق توجيهات الانعطاف صوتياً بدون رسوم' : 'Spoken turn instructions via device TTS',
                    style: TextStyle(color: dark ? Colors.white60 : Colors.black54, fontSize: 12),
                  ),
                  value: c.voice,
                  activeThumbColor: WazeColors.cyan,
                  onChanged: (val) => c.setVoice(val),
                ),
                SwitchListTile(
                  title: Text(
                    arabic ? 'تنبيهات أقل (Less Chatty)' : 'Alerts Only / Less Chatty',
                    style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    arabic ? 'نطق التنبيهات والانعطافات الضرورية فقط' : 'Only speak critical turns and hazard alerts',
                    style: TextStyle(color: dark ? Colors.white60 : Colors.black54, fontSize: 12),
                  ),
                  value: c.lessChatty,
                  activeThumbColor: WazeColors.cyan,
                  onChanged: (val) => c.setLessChatty(val),
                ),

                const Divider(),
                _buildSectionHeader(
                  arabic ? 'الخرائط والمجتمع' : 'Maps & Community',
                  textColor,
                ),
                ListTile(
                  leading: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: WazeColors.cyan.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.download_for_offline_rounded, color: WazeColors.cyan),
                  ),
                  title: Text(
                    arabic ? 'خرائط بغداد بدون إنترنت' : 'Offline Maps (Baghdad)',
                    style: TextStyle(color: textColor, fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    arabic
                        ? 'تحميل خريطة بغداد للاستخدام بدون اتصال بالإنترنت'
                        : 'Download Baghdad map tiles for offline navigation',
                    style: TextStyle(color: dark ? Colors.white60 : Colors.black54, fontSize: 12),
                  ),
                  trailing: ElevatedButton.icon(
                    icon: const Icon(Icons.download_rounded, size: 16),
                    label: Text(arabic ? 'إدارة' : 'Manage'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: WazeColors.cyan,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      Navigator.of(context).pop();
                      showWazeOfflineModal(
                        context,
                        arabic: arabic,
                        dark: dark,
                      );
                    },
                  ),
                ),
                SwitchListTile(
                  title: Text(
                    arabic ? 'مشاركة البلاغات مع السائقين' : 'Share Live Reports',
                    style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    c.backendConfigured
                        ? (arabic ? 'متصل بسحابة المجتمع الحية' : 'Connected to live community cloud')
                        : (arabic ? 'الوضع المحلي مجاني 100% (يعمل بدون أي مفتاح API)' : '100% Free local storage (works with zero API keys)'),
                    style: TextStyle(color: dark ? Colors.white60 : Colors.black54, fontSize: 12),
                  ),
                  value: c.sharing,
                  activeThumbColor: WazeColors.cyan,
                  onChanged: (val) => c.setSharing(val),
                ),

                const Divider(),
                _buildSectionHeader(
                  arabic ? 'تصفية التنبيهات المسموعة والمرئية' : 'Alert Filters',
                  textColor,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ReportType.values.map((type) {
                      final isMuted = c.muted.contains(type);
                      return FilterChip(
                        selected: !isMuted,
                        avatar: Icon(
                          WazeColors.reportIcon(type),
                          size: 16,
                          color: !isMuted ? Colors.white : Colors.grey,
                        ),
                        label: Text(WazeColors.reportTitle(type, arabic)),
                        labelStyle: TextStyle(
                          fontSize: 12,
                          color: !isMuted ? Colors.white : (dark ? Colors.white70 : Colors.black87),
                        ),
                        selectedColor: WazeColors.reportColor(type),
                        onSelected: (val) => c.setAlert(type, val),
                      );
                    }).toList(),
                  ),
                ),

                const SizedBox(height: 24),
                // Privacy / Clear Data
                OutlinedButton.icon(
                  onPressed: () async {
                    await c.clearPrivateData();
                    if (context.mounted) {
                      Navigator.of(context).pop();
                    }
                  },
                  icon: const Icon(Icons.delete_outline, color: WazeColors.red),
                  label: Text(
                    arabic ? 'مسح السجل والبيانات المحفوظة' : 'Clear Trip History & Saved Data',
                    style: const TextStyle(color: WazeColors.red, fontWeight: FontWeight.bold),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: WazeColors.red),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color textColor) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 6),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: WazeColors.cyan,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
