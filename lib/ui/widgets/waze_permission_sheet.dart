import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../app/app_controller.dart';
import '../waze_theme.dart';

/// Shows the Location & Data Usage permission disclosure sheet.
Future<void> showWazePermissionSheet(
  BuildContext context, {
  required AppController controller,
  bool force = false,
}) async {
  final prefs = await SharedPreferences.getInstance();
  final alreadyAccepted = prefs.getBool('darb.permissions_accepted.v1') ?? false;

  if (!force && alreadyAccepted) {
    // If already accepted, check if location permission is active
    final status = await Geolocator.checkPermission();
    if (status == LocationPermission.whileInUse || status == LocationPermission.always) {
      return; // Already good
    }
  }

  if (!context.mounted) return;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.65),
    builder: (ctx) => WazePermissionSheet(controller: controller),
  );
}

class WazePermissionSheet extends StatefulWidget {
  const WazePermissionSheet({super.key, required this.controller});

  final AppController controller;

  @override
  State<WazePermissionSheet> createState() => _WazePermissionSheetState();
}

class _WazePermissionSheetState extends State<WazePermissionSheet> {
  bool _requesting = false;

  Future<void> _grantPermissions() async {
    setState(() => _requesting = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('darb.permissions_accepted.v1', true);

      // Request location permission from system
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        // Permanently denied, open settings
        await Geolocator.openAppSettings();
      }

      // Initialize GPS location
      await widget.controller.locate();
    } catch (e) {
      debugPrint('Permission request error: $e');
    } finally {
      if (mounted) {
        setState(() => _requesting = false);
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final dark = c.dark;
    final arabic = c.arabic;
    final bg = dark ? const Color(0xFF101722) : Colors.white;
    final textColor = dark ? Colors.white : const Color(0xFF0F172A);
    final subColor = dark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border.all(
          color: dark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.06),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 30,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        14,
        24,
        MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom + 20,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: dark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Top Header Icon & Title
              Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF00D2FF), Color(0xFF007AFF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00D2FF).withValues(alpha: 0.35),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.shield_outlined,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          arabic ? 'أذونات الموقع واستخدام البيانات' : 'Location & Data Permissions',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          arabic
                              ? 'لتشغيل الملاحة الحية وتحديثات السير في العراق'
                              : 'Required for live GPS routing and traffic updates in Iraq',
                          style: TextStyle(
                            fontSize: 12,
                            color: subColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 22),

              // Permission Card 1: Location
              _buildPermissionCard(
                icon: Icons.my_location_rounded,
                iconColor: const Color(0xFF00D2FF),
                iconBg: const Color(0xFF00D2FF).withValues(alpha: 0.12),
                title: arabic ? 'إذن الموقع الدقيق (GPS Location)' : 'Precise Location Access',
                description: arabic
                    ? 'مطلوب لتحديد موقع سيارتك على الخريطة، والتوجيه الصوتي خطوة بخطوة، وتنبيهك بالمطبات والازدحامات القريبة.'
                    : 'Needed to pinpoint vehicle position, provide voice turn guidance, and warn about upcoming speed bumps.',
                dark: dark,
                textColor: textColor,
                subColor: subColor,
              ),

              const SizedBox(height: 12),

              // Permission Card 2: Data Usage
              _buildPermissionCard(
                icon: Icons.wifi_tethering_rounded,
                iconColor: const Color(0xFF00E676),
                iconBg: const Color(0xFF00E676).withValues(alpha: 0.12),
                title: arabic ? 'استخدام بيانات الإنترنت (Data Usage)' : 'Network & Data Usage',
                description: arabic
                    ? 'يستخدم التطبيق الإنترنت لتحميل خرائط الأقمار الصناعية وبيانات حركة السير الحية بأقل استهلاك ممكن وبدون أي إعلانات.'
                    : 'Used to fetch satellite vector tiles and live Baghdad traffic conditions with minimal data bandwidth.',
                dark: dark,
                textColor: textColor,
                subColor: subColor,
              ),

              const SizedBox(height: 24),

              // Action Buttons
              ElevatedButton(
                onPressed: _requesting ? null : _grantPermissions,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00D2FF),
                  foregroundColor: const Color(0xFF070B10),
                  elevation: 4,
                  shadowColor: const Color(0xFF00D2FF).withValues(alpha: 0.4),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _requesting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black),
                      )
                    : Text(
                        arabic ? 'الموافقة ومنح الأذونات' : 'Allow & Continue',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
              ),

              const SizedBox(height: 10),

              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                style: TextButton.styleFrom(
                  foregroundColor: subColor,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                child: Text(
                  arabic ? 'المتابعة بالوضع التجريبي (بدون GPS)' : 'Continue in Demo Mode',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String description,
    required bool dark,
    required Color textColor,
    required Color subColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: dark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: dark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconBg,
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
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.5,
                    color: subColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
