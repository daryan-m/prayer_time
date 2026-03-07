import 'package:flutter/material.dart';

// ==================== CONSTANTS ====================

// ── لیستی شارەکان ──────────────────────────────────
class CityConfig {
  final String displayName;
  final String jsonFile;
  final bool hasFile;

  const CityConfig({
    required this.displayName,
    required this.jsonFile,
    this.hasFile = true,
  });
}

const List<CityConfig> kurdistanCities = [
  CityConfig(displayName: "پێنجوێن", jsonFile: "penjwen_prayer_times_2026"),
  CityConfig(
      displayName: "سلێمانی", jsonFile: "sulaymaniyah_prayer_times_2026"),
  CityConfig(
      displayName: "سەید صادق", jsonFile: "said_sadiq_prayer_times_2026"),
  CityConfig(displayName: "هەولێر", jsonFile: "hawler_prayer_times_2026"),
  CityConfig(displayName: "دهۆک", jsonFile: "duhok_prayer_times_2026"),
  CityConfig(
      displayName: "کەرکووک",
      jsonFile: "kirkuk_prayer_times_2026",
      hasFile: false),
  CityConfig(
      displayName: "هەڵەبجە",
      jsonFile: "halabja_prayer_times_2026",
      hasFile: false),
  CityConfig(
      displayName: "ڕانیە",
      jsonFile: "rania_prayer_times_2026",
      hasFile: false),
  CityConfig(
      displayName: "دەربەندیخان",
      jsonFile: "darbandikhan_prayer_times_2026",
      hasFile: false),
];

final List<String> kurdistanCitiesData =
    kurdistanCities.map((c) => c.displayName).toList();

CityConfig? getCityConfig(String displayName) {
  try {
    return kurdistanCities.firstWhere((c) => c.displayName == displayName);
  } catch (_) {
    return null;
  }
}

// ── ناوەکانی بانگەکان ──────────────────────────────
final List<String> prayerNames = [
  "بەیانی",
  "خۆرهەڵاتن",
  "نیوەڕۆ",
  "عەسر",
  "ئێوارە",
  "خەوتنان",
];

// ==================== THEME PALETTE ====================
// هەر ڕووکار: primary (ڕەنگی سەرەکی) + secondary + glow + icon
class ThemePalette {
  final Color primary; // ڕەنگی سەرەکی — کاتژمێر، دیڤایدەر، ناوی بانگی چالاک
  final Color secondary; // ڕەنگی دووەم — هیجری، NextPrayerBar کات
  final Color glow; // گلۆی دیڤایدەر و کارت
  final Color icon; // ئایکۆنی چالاک
  final Color border; // بەردەری NextPrayerBar

  const ThemePalette({
    required this.primary,
    required this.secondary,
    required this.glow,
    required this.icon,
    required this.border,
  });
}

const Map<String, ThemePalette> appThemePalettes = {
  "شین": ThemePalette(
    primary: Color(0xFF22D3EE), // cyan
    secondary: Color(0xFF10B981), // emerald
    glow: Color(0xFF22D3EE),
    icon: Color(0xFF22D3EE),
    border: Color(0xFF0E7490), // teal dark
  ),
  "سەوز": ThemePalette(
    primary: Color(0xFF4ADE80), // green-400
    secondary: Color(0xFFA3E635), // lime-400
    glow: Color(0xFF22C55E), // green-500
    icon: Color(0xFF4ADE80),
    border: Color(0xFF166534), // green-900
  ),
  "مۆر": ThemePalette(
    primary: Color(0xFFC084FC), // purple-400
    secondary: Color(0xFFE879F9), // fuchsia-400
    glow: Color(0xFFA855F7), // purple-500
    icon: Color(0xFFC084FC),
    border: Color(0xFF6B21A8), // purple-900
  ),
  "پرتەقاڵی": ThemePalette(
    primary: Color(0xFFFB923C), // orange-400
    secondary: Color(0xFFFACC15), // yellow-400
    glow: Color(0xFFF97316), // orange-500
    icon: Color(0xFFFB923C),
    border: Color(0xFF9A3412), // orange-900
  ),
  "سوور": ThemePalette(
    primary: Color(0xFFFFFFFF), // سپی — بۆ ڕووکاری سوور
    secondary: Color(0xFFFFFFFF),
    glow: Color(0xFFFFFFFF),
    icon: Color(0xFFFFFFFF),
    border: Color(0xFF7F1D1D), // red-900
  ),
  "ئاڵتونی": ThemePalette(
    primary: Color(0xFFFFD700), // gold
    secondary: Color(0xFFFBBF24), // amber-400
    glow: Color(0xFFD97706), // amber-600
    icon: Color(0xFFFFD700),
    border: Color(0xFF78350F), // amber-900
  ),
  "ڕەساسی": ThemePalette(
    primary: Color(0xFF94A3B8), // slate-400
    secondary: Color(0xFFCBD5E1), // slate-300
    glow: Color(0xFF64748B), // slate-500
    icon: Color(0xFF94A3B8),
    border: Color(0xFF1E293B), // slate-800
  ),
};

// بۆ بەکارهێنانی ئاسان لە drawer رادیۆبتن
final Map<String, Color> appThemes = appThemePalettes.map(
  (k, v) => MapEntry(k, v.primary),
);

// دۆزینەوەی palette — ئەگەر نەدۆزرایەوە شین دەگەڕێتەوە
ThemePalette getThemePalette(String themeName) =>
    appThemePalettes[themeName] ?? appThemePalettes["شین"]!;

// ── ڕەنگە ثابتەکان (background هتد) ────────────────
class AppColors {
  static const Color background = Color(0xFF020617);
  static const Color cardBackground = Color(0xFF0F172A);
  static const Color cardBackgroundActive = Color(0xFF080D1A);
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFFCBD5E1);
  static const Color nily = Color(0xFF020617);
  // ڕەنگی سەرەتایی (کاتی بارکردن پێشەوەتر)
  static const Color primary = Color(0xFF22D3EE);
  static const Color secondary = Color(0xFF10B981);
}

// ── وەشان ──────────────────────────────────────────
const String currentAppVersion = "1.0.0";
