import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../app/app_controller.dart';
import '../waze_theme.dart';

/// Shows the Developer Profile ("About Me") modal bottom sheet.
void showWazeDeveloperSheet(BuildContext context, {required AppController controller}) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => WazeDeveloperSheet(controller: controller),
  );
}

class WazeDeveloperSheet extends StatelessWidget {
  const WazeDeveloperSheet({super.key, required this.controller});

  final AppController controller;

  static const String developerNameAr = 'بشار محمود لفته';
  static const String developerNameEn = 'Bashar Mahmoud Lafta';
  static const String developerPhone = '07718239496';
  static const String developerPhoneIntl = '+9647718239496';
  static const String developerEmail = 'extra.jassim@gmail.com';
  static const String projectGithub = 'https://github.com/bashar-x5/waze';

  Future<void> _launch(BuildContext context, String urlString) async {
    final uri = Uri.parse(urlString);
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && context.mounted) {
        _copyToClipboard(context, urlString, controller.arabic ? 'تعذر الفتح التلقائي، تم نسخ الرابط' : 'Could not launch, copied to clipboard');
      }
    } catch (_) {
      if (context.mounted) {
        _copyToClipboard(context, urlString, controller.arabic ? 'تم نسخ الرابط للحافظة' : 'Copied to clipboard');
      }
    }
  }

  void _copyToClipboard(BuildContext context, String text, String message) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message, style: const TextStyle(fontWeight: FontWeight.w700))),
          ],
        ),
        backgroundColor: const Color(0xFF00C853),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = controller.dark;
    final arabic = controller.arabic;
    final bg = dark ? WazeColors.darkSurface : Colors.white;
    final textColor = dark ? Colors.white : Colors.black87;
    final cardBg = dark ? WazeColors.darkCard : const Color(0xFFF1F5F9);
    final borderColor = dark ? Colors.white12 : Colors.black12;

    final mediaQuery = MediaQuery.of(context);
    final bottomInset = mediaQuery.viewInsets.bottom;
    final bottomPadding = mediaQuery.padding.bottom;
    final safeBottom = bottomInset + max(bottomPadding, 16.0) + 16.0;

    return Material(
      color: bg,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: mediaQuery.size.height * 0.90,
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            // Handle bar
            Container(
              width: 44,
              height: 4.5,
              decoration: BoxDecoration(
                color: dark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 14),

            // Header title & close
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
                      Icons.person_pin_rounded,
                      color: WazeColors.cyan,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      arabic ? 'عن المطور • ملف المطور' : 'About Developer • Profile',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: textColor,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                    color: textColor.withValues(alpha: 0.7),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Content List
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(20, 16, 20, safeBottom),
                children: [
                  // Profile Hero Card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: dark
                            ? [
                                const Color(0xFF132338),
                                const Color(0xFF0C1724),
                              ]
                            : [
                                const Color(0xFFE0F7FA),
                                const Color(0xFFE8F5E9),
                              ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: WazeColors.cyan.withValues(alpha: 0.35),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: WazeColors.cyan.withValues(alpha: 0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Avatar Circle
                        Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            Container(
                              width: 86,
                              height: 86,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  colors: [WazeColors.cyan, WazeColors.blue],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: WazeColors.cyan.withValues(alpha: 0.4),
                                    blurRadius: 18,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.person_rounded,
                                  size: 52,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Color(0xFF00E676),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.verified_rounded,
                                color: Colors.black,
                                size: 16,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Developer Name
                        Text(
                          developerNameAr,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: textColor,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          developerNameEn,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: textColor.withValues(alpha: 0.6),
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Role Tag
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: WazeColors.cyan.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: WazeColors.cyan.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            arabic
                                ? 'مطور ومؤسس تطبيق دَرب للملاحة'
                                : 'Creator & Lead Developer of Darb Navigation',
                            style: const TextStyle(
                              color: WazeColors.cyan,
                              fontWeight: FontWeight.w800,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Iraq Flag & Location
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('🇮🇶', style: TextStyle(fontSize: 16)),
                            const SizedBox(width: 6),
                            Text(
                              arabic ? 'العراق • بغداد' : 'Baghdad, Iraq',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: textColor.withValues(alpha: 0.8),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 22),

                  // Section Title: Contact Channels
                  _buildSectionTitle(
                    arabic ? 'قنوات التواصل المباشر' : 'Direct Contact Channels',
                    Icons.contact_phone_rounded,
                    textColor,
                  ),
                  const SizedBox(height: 12),

                  // Phone Card (Call & Copy)
                  _buildContactCard(
                    context: context,
                    icon: Icons.phone_in_talk_rounded,
                    iconColor: const Color(0xFF00E676),
                    title: arabic ? 'رقم الهاتف (مكالمة مباشرة)' : 'Phone Number (Direct Call)',
                    value: developerPhone,
                    textColor: textColor,
                    cardBg: cardBg,
                    borderColor: borderColor,
                    actions: [
                      IconButton.filledTonal(
                        onPressed: () => _launch(context, 'tel:$developerPhone'),
                        icon: const Icon(Icons.call_rounded, size: 20),
                        tooltip: arabic ? 'اتصال الآن' : 'Call Now',
                        style: IconButton.styleFrom(
                          backgroundColor: const Color(0xFF00E676).withValues(alpha: 0.2),
                          foregroundColor: const Color(0xFF00E676),
                        ),
                      ),
                      IconButton.filledTonal(
                        onPressed: () => _copyToClipboard(
                          context,
                          developerPhone,
                          arabic ? 'تم نسخ رقم الهاتف بنجاح' : 'Phone number copied',
                        ),
                        icon: const Icon(Icons.copy_rounded, size: 18),
                        tooltip: arabic ? 'نسخ الرقم' : 'Copy',
                        style: IconButton.styleFrom(
                          backgroundColor: textColor.withValues(alpha: 0.08),
                          foregroundColor: textColor,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // WhatsApp Card
                  _buildContactCard(
                    context: context,
                    icon: Icons.chat_rounded,
                    iconColor: const Color(0xFF25D366),
                    title: arabic ? 'محادثة واتساب سريعة' : 'WhatsApp Direct Chat',
                    value: developerPhone,
                    textColor: textColor,
                    cardBg: cardBg,
                    borderColor: borderColor,
                    actions: [
                      ElevatedButton.icon(
                        onPressed: () {
                          final msg = arabic
                              ? 'السلام عليكم أستاذ بشار، بخصوص تطبيق دَرب (Darb)...'
                              : 'Hello Bashar, regarding Darb Navigation app...';
                          _launch(
                            context,
                            'https://wa.me/9647718239496?text=${Uri.encodeComponent(msg)}',
                          );
                        },
                        icon: const Icon(Icons.send_rounded, size: 16),
                        label: Text(arabic ? 'مراسلة' : 'Chat'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF25D366),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Email Card
                  _buildContactCard(
                    context: context,
                    icon: Icons.email_rounded,
                    iconColor: const Color(0xFF00C8F8),
                    title: arabic ? 'البريد الإلكتروني' : 'Email Address',
                    value: developerEmail,
                    textColor: textColor,
                    cardBg: cardBg,
                    borderColor: borderColor,
                    actions: [
                      IconButton.filledTonal(
                        onPressed: () {
                          final subject = arabic ? 'استفسار حول تطبيق دَرب' : 'Darb Navigation Inquiry';
                          _launch(
                            context,
                            'mailto:$developerEmail?subject=${Uri.encodeComponent(subject)}',
                          );
                        },
                        icon: const Icon(Icons.open_in_new_rounded, size: 20),
                        tooltip: arabic ? 'إرسال بريد' : 'Send Email',
                        style: IconButton.styleFrom(
                          backgroundColor: WazeColors.cyan.withValues(alpha: 0.2),
                          foregroundColor: WazeColors.cyan,
                        ),
                      ),
                      IconButton.filledTonal(
                        onPressed: () => _copyToClipboard(
                          context,
                          developerEmail,
                          arabic ? 'تم نسخ البريد الإلكتروني' : 'Email copied',
                        ),
                        icon: const Icon(Icons.copy_rounded, size: 18),
                        tooltip: arabic ? 'نسخ' : 'Copy',
                        style: IconButton.styleFrom(
                          backgroundColor: textColor.withValues(alpha: 0.08),
                          foregroundColor: textColor,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // GitHub Card
                  _buildContactCard(
                    context: context,
                    icon: Icons.code_rounded,
                    iconColor: const Color(0xFFAB47BC),
                    title: arabic ? 'مستودع المشروع المفتوح المصدر' : 'Open-Source GitHub Repository',
                    value: 'github.com/bashar-x5/waze',
                    textColor: textColor,
                    cardBg: cardBg,
                    borderColor: borderColor,
                    actions: [
                      ElevatedButton.icon(
                        onPressed: () => _launch(context, projectGithub),
                        icon: const Icon(Icons.launch_rounded, size: 16),
                        label: Text(arabic ? 'زيارة' : 'Visit'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFAB47BC),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 22),

                  // Mission & Vision Card
                  _buildSectionTitle(
                    arabic ? 'رسالة ورؤية التطبيق' : 'Mission & Purpose',
                    Icons.lightbulb_rounded,
                    textColor,
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.favorite_rounded, color: Color(0xFFFF5252), size: 20),
                            const SizedBox(width: 8),
                            Text(
                              arabic ? 'مشروع وطني عراقي مجاني 100%' : '100% Free Iraqi National Project',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                                color: textColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          arabic
                              ? 'صُمم وطُوّر تطبيق دَرب (Darb) بجهد وطني خالص لتقديم نظام ملاحة ذكي ومجتمعي بديل في العراق، يعتمد على الخرائط المتجهة ثلاثية الأبعاد ومحرك التوجيه المفتوح بدون أي تكاليف API سحابية أو إعلانات تجارية. إهداء إلى أهلنا وسائقي السيارات في بغداد وجميع محافظات العراق الحبيب.'
                              : 'Darb was built locally in Iraq as a 100% free, community-powered navigation alternative. Utilizing 3D vector mapping and local routing with zero cloud API fees or ads. Dedicated to drivers across Baghdad and all Iraqi governorates.',
                          style: TextStyle(
                            fontSize: 12.5,
                            height: 1.6,
                            color: textColor.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 22),

                  // Technical Badges
                  _buildSectionTitle(
                    arabic ? 'المواصفات التقنية للنظام' : 'Technical Specifications',
                    Icons.tune_rounded,
                    textColor,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildTechChip(
                        label: arabic ? 'الإصدار: v1.0.6 (Build 6)' : 'Version: v1.0.6 (6)',
                        color: WazeColors.cyan,
                        dark: dark,
                      ),
                      _buildTechChip(
                        label: 'MapLibre GL 3D Vector',
                        color: const Color(0xFF00E676),
                        dark: dark,
                      ),
                      _buildTechChip(
                        label: 'Local OSRM Engine',
                        color: const Color(0xFFFFB300),
                        dark: dark,
                      ),
                      _buildTechChip(
                        label: 'ASP.NET Core 9 + PostGIS',
                        color: const Color(0xFFAB47BC),
                        dark: dark,
                      ),
                      _buildTechChip(
                        label: arabic ? 'أندرويد + شاشات Auto' : 'Android & Auto',
                        color: const Color(0xFF29B6F6),
                        dark: dark,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon, Color textColor) {
    return Row(
      children: [
        Icon(icon, size: 18, color: WazeColors.cyan),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: textColor,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }

  Widget _buildContactCard({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    required Color textColor,
    required Color cardBg,
    required Color borderColor,
    required List<Widget> actions,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    color: textColor.withValues(alpha: 0.6),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: textColor,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: actions,
          ),
        ],
      ),
    );
  }

  Widget _buildTechChip({
    required String label,
    required Color color,
    required bool dark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: dark ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
