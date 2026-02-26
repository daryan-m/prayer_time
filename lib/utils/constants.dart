import 'package:flutter/material.dart';

// ==================== CONSTANTS ====================

// لیستی شارەکان
final List<String> kurdistanCitiesData = ["پێنجوێن", "سلێمانی"];

// ناوەکانی بانگەکان
final List<String> prayerNames = [
  "بەیانی",
  "خۆرهەڵاتن",
  "نیوەڕۆ",
  "عەسر",
  "ئێوارە",
  "خەوتنان"
];

// ڕووکارەکان
final Map<String, Color> appThemes = {
  "پرتەقاڵی": Colors.orange,
  "ڕەساسی": Colors.grey,
  "سەوز": Colors.green,
  "مۆر": Colors.purple,
  "شین": Colors.blue,
  "سوور": Colors.red,
  "ئاڵتونی": const Color(0xFFFFD700),
};

// ڕەنگەکان
class AppColors {
  static const Color background = Color(0xFF020617);
  static const Color cardBackground = Color(0xFF0F172A);
  static const Color cardBackgroundActive = Color(0xFF080D1A);
  static const Color primary = Color(0xFF22D3EE);
  static const Color secondary = Color(0xFF10B981);
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFFCBD5E1);
  static const Color nily = Color(0xFF020617);
}

// وەشان
const String currentAppVersion = "1.0.0";
