import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../app/app_controller.dart';
import '../waze_theme.dart';

void showWazeAndroidAutoModal(BuildContext context, {required AppController controller}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => WazeAndroidAutoModal(controller: controller),
  );
}

class WazeAndroidAutoModal extends StatelessWidget {
  const WazeAndroidAutoModal({super.key, required this.controller});

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
        height: MediaQuery.of(context).size.height * 0.88,
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
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.directions_car_filled_rounded,
                      color: WazeColors.blue,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          arabic ? 'الملاحة في السيارة (Android Auto)' : 'Android Auto Car Navigation',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: textColor,
                          ),
                        ),
                        Text(
                          arabic ? 'تشغيل درب على شاشة سيارتك فوراً' : 'Run Darb directly on your car screen',
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
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                children: [
                  // Active Ready Banner
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          WazeColors.cyan.withValues(alpha: 0.25),
                          WazeColors.blue.withValues(alpha: 0.15),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: WazeColors.cyan.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.check_circle_rounded,
                          color: WazeColors.cyan,
                          size: 32,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                arabic
                                    ? 'درب جاهز تماماً لشاشات أندرويد أوتو'
                                    : 'Darb is 100% Android Auto Ready',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                arabic
                                    ? 'يدعم التوجيه على الشاشة، البحث الصوتي العراقي، استعراض الوجهات، ومزامنة الرحلة الحية.'
                                    : 'Supports car HUD turn-by-turn routing, voice navigation, saved places, and live updates.',
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
                  const SizedBox(height: 20),

                  // Quick Launch Settings Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final ok = await c.openAndroidAutoSettings();
                        if (!ok && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                arabic
                                    ? 'تعذر فتح الإعدادات تلقائياً، يمكنك البحث عن "Android Auto" في إعدادات الهاتف.'
                                    : 'Could not open settings automatically. Search for "Android Auto" in Phone Settings.',
                              ),
                              backgroundColor: WazeColors.red,
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.settings_suggest_rounded, size: 22),
                      label: Text(
                        arabic ? 'فتح إعدادات Android Auto بالهاتف' : 'Open Android Auto Settings on Phone',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: WazeColors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Step-by-Step Guide
                  Text(
                    arabic ? 'خطوات التفعيل السريع (تُجرى لمرة واحدة فقط):' : 'One-Time Setup Steps:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 12),

                  _buildStepTile(
                    step: '1',
                    title: arabic ? 'افتح إعدادات أندرويد أوتو' : 'Open Android Auto Settings',
                    desc: arabic
                        ? 'اضغط على الزر الأزرق في الأعلى لفتح صفحة إعدادات أندرويد أوتو على هاتفك.'
                        : 'Tap the blue button above to open Android Auto settings on your device.',
                    icon: Icons.launch_rounded,
                    dark: dark,
                  ),
                  _buildStepTile(
                    step: '2',
                    title: arabic ? 'تفعيل وضع المطور (10 نقرات)' : 'Enable Developer Mode (10 Taps)',
                    desc: arabic
                        ? 'انزل لأسفل الصفحة حتى تصل إلى خانة "الإصدار" (Version)، واضغط عليها 10 مرات متتالية حتى تظهر رسالة تفعيل وضع المطور واضغط "موافق".'
                        : 'Scroll to the bottom, tap "Version" 10 times consecutively until the developer mode prompt appears, then tap OK.',
                    icon: Icons.touch_app_rounded,
                    dark: dark,
                  ),
                  _buildStepTile(
                    step: '3',
                    title: arabic ? 'تفعيل المصادر غير المعروفة' : 'Check "Unknown Sources"',
                    desc: arabic
                        ? 'اضغط على النقاط الثلاث (⋮) بأعلى اليمين -> اختر "إعدادات المطور" (Developer settings) -> ضع إشارة صح على "مصادر غير معروفة" (Unknown sources).'
                        : 'Tap top 3-dots (⋮) -> Select "Developer settings" -> Enable the checkbox for "Unknown sources".',
                    icon: Icons.security_rounded,
                    dark: dark,
                  ),
                  _buildStepTile(
                    step: '4',
                    title: arabic ? 'التأكد من تفعيل درب في المشغل' : 'Check Customize Launcher',
                    desc: arabic
                        ? 'ارجع للإعدادات الرئيسية واضغط "تخصيص المشغل" (Customize launcher) وتأكد من وجود علامة صح بجانب تطبيق "درب".'
                        : 'Go back to settings, tap "Customize launcher", and ensure "Darb" is checked.',
                    icon: Icons.apps_rounded,
                    dark: dark,
                  ),
                  _buildStepTile(
                    step: '5',
                    title: arabic ? 'اشبك الهاتف بالسيارة' : 'Plug In & Drive!',
                    desc: arabic
                        ? 'اشبك هاتفك بشاشة السيارة (عبر الكيبل أو اللاسلكي)، ستجد أيقونة "درب" تظهر فوراً على شاشة السيارة!'
                        : 'Connect your phone to your car via USB cable or wireless projection. Darb will appear immediately on the car display!',
                    icon: Icons.cable_rounded,
                    dark: dark,
                    isLast: true,
                  ),

                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 10),

                  // Power User / Developer Hack Section (Fooling Android Auto)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: dark ? WazeColors.darkCard : const Color(0xFFF8FAFC),
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
                            const Icon(Icons.terminal_rounded, color: Colors.orange, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              arabic ? 'خدعة التثبيت الذاتي (لتجاوز الفحص كلياً):' : 'Bypass Google Check via ADB:',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          arabic
                              ? 'إذا أردت جعل أندرويد يعتبر تطبيق درب قادماً من متجر جوجل بلاي الرسمي بدون أي تنبيهات، يمكنك تثبيته عبر أمر ADB:'
                              : 'To make Android register Darb as an official Play Store package automatically, install via ADB:',
                          style: TextStyle(
                            fontSize: 12,
                            color: dark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: dark ? Colors.black45 : const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'adb install -i com.android.vending darb.apk',
                                  style: TextStyle(
                                    color: Colors.lightGreenAccent,
                                    fontFamily: 'monospace',
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.copy_rounded, color: Colors.white70, size: 16),
                                onPressed: () {
                                  Clipboard.setData(const ClipboardData(
                                    text: 'adb install -i com.android.vending darb.apk',
                                  ));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(arabic ? 'تم نسخ الأمر' : 'Command copied'),
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          arabic
                              ? 'الوسم "-i com.android.vending" يخبر النظام أن مثبت التطبيق هو متجر جوجل بلاي، مما يجعله يظهر فوراً في السيارة دون الحاجة حتى لخيارات المطور!'
                              : 'The "-i com.android.vending" flag tricks the system into trusting the app as a verified Play Store package.',
                          style: TextStyle(
                            fontSize: 11,
                            color: dark ? Colors.white54 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepTile({
    required String step,
    required String title,
    required String desc,
    required IconData icon,
    required bool dark,
    bool isLast = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: WazeColors.cyan,
            ),
            alignment: Alignment.center,
            child: Text(
              step,
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w900,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: dark ? WazeColors.darkCard : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(icon, size: 16, color: WazeColors.blue),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: dark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    desc,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: dark ? Colors.white70 : Colors.black87,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
