import 'package:flutter/material.dart';
import '../domain/models.dart';

class WazeColors {
  // Iconic Waze Colors
  static const Color cyan = Color(0xFF00C8F8);
  static const Color blue = Color(0xFF0870D8);
  static const Color darkBlue = Color(0xFF0D253F);
  static const Color orange = Color(0xFFFF6D00);
  static const Color green = Color(0xFF00D166);
  static const Color red = Color(0xFFFF3B30);
  static const Color yellow = Color(0xFFFFC107);
  static const Color purple = Color(0xFF8E44AD);

  // Surface & backgrounds
  static const Color lightBackground = Color(0xFFF4F6F9);
  static const Color darkBackground = Color(0xFF141923);
  static const Color darkSurface = Color(0xFF1E2532);
  static const Color darkCard = Color(0xFF283142);

  // Route colors
  static const Color activeRoute = Color(0xFF00C8F8);
  static const Color activeRouteBorder = Color(0xFF0564A2);
  static const Color altRoute = Color(0xFF90A4AE);
  static const Color altRouteBorder = Color(0xFF546E7A);

  static Color reportColor(ReportType type) {
    switch (type) {
      case ReportType.police:
        return const Color(0xFF1E88E5);
      case ReportType.traffic:
        return const Color(0xFFE53935);
      case ReportType.hazard:
        return const Color(0xFFFBC02D);
      case ReportType.crash:
        return const Color(0xFFD32F2F);
      case ReportType.camera:
        return const Color(0xFF8E24AA);
      case ReportType.closure:
        return const Color(0xFFC62828);
      case ReportType.construction:
        return const Color(0xFFFB8C00);
      case ReportType.weather:
        return const Color(0xFF00ACC1);
      case ReportType.bump:
        return const Color(0xFFEF6C00);
    }
  }

  static IconData reportIcon(ReportType type) {
    switch (type) {
      case ReportType.police:
        return Icons.local_police;
      case ReportType.traffic:
        return Icons.traffic;
      case ReportType.hazard:
        return Icons.warning_amber_rounded;
      case ReportType.crash:
        return Icons.car_crash;
      case ReportType.camera:
        return Icons.camera_alt;
      case ReportType.closure:
        return Icons.do_not_disturb_on;
      case ReportType.construction:
        return Icons.construction;
      case ReportType.weather:
        return Icons.cloudy_snowing;
      case ReportType.bump:
        return Icons.vibration_rounded;
    }
  }

  static String reportTitle(ReportType type, bool arabic) {
    switch (type) {
      case ReportType.police:
        return arabic ? 'شرطة وسيطرة' : 'Police';
      case ReportType.traffic:
        return arabic ? 'ازدحام' : 'Traffic';
      case ReportType.hazard:
        return arabic ? 'خطر على الطريق' : 'Hazard';
      case ReportType.crash:
        return arabic ? 'حادث سير' : 'Car Crash';
      case ReportType.camera:
        return arabic ? 'كاميرا رادار' : 'Speed Camera';
      case ReportType.closure:
        return arabic ? 'طريق مغلق' : 'Road Closure';
      case ReportType.construction:
        return arabic ? 'أعمال صيانة' : 'Construction';
      case ReportType.weather:
        return arabic ? 'طقس سيء' : 'Weather Hazard';
      case ReportType.bump:
        return arabic ? 'مطب اصطناعي' : 'Speed Bump';
    }
  }

  static IconData maneuverIcon(String stepType) {
    final lower = stepType.toLowerCase();
    if (lower.contains('left')) {
      if (lower.contains('sharp') || lower.contains('slight') == false) {
        return Icons.turn_left;
      }
      return Icons.turn_slight_left;
    }
    if (lower.contains('right')) {
      if (lower.contains('sharp') || lower.contains('slight') == false) {
        return Icons.turn_right;
      }
      return Icons.turn_slight_right;
    }
    if (lower.contains('u-turn') || lower.contains('uturn')) {
      return Icons.u_turn_left;
    }
    if (lower.contains('roundabout') || lower.contains('rotary')) {
      return Icons.roundabout_left;
    }
    if (lower.contains('merge')) {
      return Icons.merge_type;
    }
    if (lower.contains('fork')) {
      return Icons.call_split;
    }
    if (lower.contains('arrive') || lower.contains('destination')) {
      return Icons.sports_score;
    }
    return Icons.straight;
  }
}
