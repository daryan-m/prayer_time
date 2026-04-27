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
  CityConfig(displayName: "هەولێر", jsonFile: "hawler_prayer_times"),
  CityConfig(displayName: "سلێمانى", jsonFile: "slemany_prayer_times"),
  CityConfig(displayName: "دهۆک", jsonFile: "duhok_prayer_times"),
  CityConfig(displayName: "کەرکووک", jsonFile: "kirkuk_prayer_times"),
  CityConfig(displayName: "هەلەبجە", jsonFile: "halabja_prayer_times"),
  CityConfig(displayName: "کەلار", jsonFile: "kalar_prayer_times"),
  CityConfig(displayName: "ڕانیە", jsonFile: "ranya_prayer_times"),
  CityConfig(displayName: "کۆیە", jsonFile: "koya_prayer_times"),
  CityConfig(displayName: "سۆران", jsonFile: "soran_prayer_times"),
  CityConfig(displayName: "زاخۆ", jsonFile: "zaxo_prayer_times"),
  CityConfig(displayName: "خانەقین", jsonFile: "xanaqin_prayer_times"),
  CityConfig(displayName: "چەمچەماڵ", jsonFile: "chamchamal_prayer_times"),
  CityConfig(displayName: "پێنجوێن", jsonFile: "penjuin_prayer_times"),
  CityConfig(displayName: "هەلەبجەى تازە", jsonFile: "halabjan_prayer_times"),
  CityConfig(displayName: "سیدصادق", jsonFile: "saidsadiq_prayer_times"),
  CityConfig(displayName: "دەربەندیخان", jsonFile: "darbandixan_prayer_times"),
  CityConfig(displayName: "کفرى", jsonFile: "kfri_prayer_times"),
  CityConfig(displayName: "قەڵادزێ", jsonFile: "qaladze_prayer_times"),
  CityConfig(displayName: "قەرەداغ", jsonFile: "qaradax_prayer_times"),
  CityConfig(displayName: "قەسرێ", jsonFile: "qasre_prayer_times"),
  CityConfig(displayName: "قادرکەرەم", jsonFile: "qadirkaram_prayer_times"),
  CityConfig(displayName: "چوارتا", jsonFile: "chwarta_prayer_times"),
  CityConfig(displayName: "بازیان", jsonFile: "bazyan_prayer_times"),
  CityConfig(displayName: "بەرزنجە", jsonFile: "barznja_prayer_times"),
  CityConfig(displayName: "عەربەت", jsonFile: "arbat_prayer_times"),
  CityConfig(displayName: "ئاکرێ", jsonFile: "akre_prayer_times"),
  CityConfig(displayName: "ئامێدى", jsonFile: "amedi_prayer_times"),
  CityConfig(displayName: "پیرەمەگرون", jsonFile: "piramagrun_prayer_times"),
  CityConfig(displayName: "تەکیە", jsonFile: "takya_prayer_times"),
  CityConfig(displayName: "تەق تەق", jsonFile: "taqtaq_prayer_times"),
  CityConfig(displayName: "تاسڵوجە", jsonFile: "tasluja_prayer_times"),
  CityConfig(displayName: "دوزخورماتو", jsonFile: "tuzxurmatu_prayer_times"),
  CityConfig(displayName: "دوکان", jsonFile: "dukan_prayer_times"),
  CityConfig(displayName: "حاجیاوا", jsonFile: "hajiawa_prayer_times"),
  CityConfig(displayName: "خەلەکان", jsonFile: "xalakan_prayer_times"),
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
// هەر ڕووکار: هەموو رەنگەکانی پێویست بۆ گۆڕینی تەواوی ئەپ
class ThemePalette {
  final Color primary; // ڕەنگی سەرەکی — کاتژمێر، دیڤایدەر، ناوی بانگی چالاک
  final Color secondary; // ڕەنگی دووەم — هیجری، NextPrayerBar کات
  final Color glow; // گلۆی دیڤایدەر و کارت
  final Color icon; // ئایکۆنی چالاک
  final Color border; // بەردەری NextPrayerBar

  // ── رەنگەکانی نوێ — بۆ گۆڕینی تەواوی ئەپ ──
  final Color background; // باکگراوندی سەرەکی
  final Color cardBg; // باکگراوندی کارتەکانی بانگ
  final Color cardBgActive; // باکگراوندی کارتی چالاک
  final Color drawerBg; // باکگراوندی درا
  final Color drawerBorder; // بەردەری درا
  final Color headerText; // تێکستی هیدەر و ناوی شار
  final Color listText; // تێکستی لیستەکان
  final Color clockText; // تێکستی کاتژمێر
  final Color divider; // رەنگی خەتی دیڤایدەر

  const ThemePalette({
    required this.primary,
    required this.secondary,
    required this.glow,
    required this.icon,
    required this.border,
    required this.background,
    required this.cardBg,
    required this.cardBgActive,
    required this.drawerBg,
    required this.drawerBorder,
    required this.headerText,
    required this.listText,
    required this.clockText,
    required this.divider,
  });
}

const Map<String, ThemePalette> appThemePalettes = {
  // ── شین (ئەسڵی) ──────────────────────────────────
  "شین": ThemePalette(
    primary: Color(0xFF22D3EE),
    secondary: Color(0xFF10B981),
    glow: Color(0xFF22EED3),
    icon: Color(0xFF10B981),
    border: Color(0xFF0E7490),
    background: Color(0xFF020617),
    cardBg: Color(0xFF0F172A),
    cardBgActive: Color(0xFF080D1A),
    drawerBg: Color(0xFF020617),
    drawerBorder: Color(0xFF22D3EE),
    headerText: Color(0xFF22D3EE),
    listText: Colors.white,
    clockText: Color(0xFF22D3EE),
    divider: Color(0xFFFFAB00),
  ),

  // ── سەوز ─────────────────────────────────────────
  "سەوز": ThemePalette(
    primary: Color(0xFF34D399),
    secondary: Color(0xFF86EFAC),
    glow: Color(0xFF10B981),
    icon: Color(0xFF6EE7B7),
    border: Color(0xFF14532D),
    background: Color(0xFF04130B),
    cardBg: Color(0xFF0B2217),
    cardBgActive: Color(0xFF133024),
    drawerBg: Color(0xFF05180E),
    drawerBorder: Color(0xFF34D399),
    headerText: Color(0xFF6EE7B7),
    listText: Color(0xFFE7F9EE),
    clockText: Color(0xFF86EFAC),
    divider: Color(0xFF34D399),
  ),

  // ── پرتەقاڵی ─────────────────────────────────────
  "پرتەقاڵی": ThemePalette(
    primary: Color(0xFFFB8C3A),
    secondary: Color(0xFFFBBF24),
    glow: Color(0xFFEA580C),
    icon: Color(0xFFF97316),
    border: Color(0xFF7C2D12),
    background: Color(0xFF160A04),
    cardBg: Color(0xFF2A160C),
    cardBgActive: Color(0xFF3A2012),
    drawerBg: Color(0xFF1C0D05),
    drawerBorder: Color(0xFFFB8C3A),
    headerText: Color(0xFFFFB36B),
    listText: Color(0xFFFFEAD6),
    clockText: Color(0xFFFFB36B),
    divider: Color(0xFFFB8C3A),
  ),

  // ── ئاڵتونی ──────────────────────────────────────
  "ئاڵتونی": ThemePalette(
    primary: Color(0xFFF4C95D),
    secondary: Color(0xFFFCD34D),
    glow: Color(0xFFD4A017),
    icon: Color(0xFFF4C95D),
    border: Color(0xFF6B4F1D),
    background: Color(0xFF12100A),
    cardBg: Color(0xFF231C11),
    cardBgActive: Color(0xFF302515),
    drawerBg: Color(0xFF181209),
    drawerBorder: Color(0xFFF4C95D),
    headerText: Color(0xFFF9D87D),
    listText: Color(0xFFFFF3CF),
    clockText: Color(0xFFF9D87D),
    divider: Color(0xFFF4C95D),
  ),

  // ── ڕۆشن ───────────────────────────────────────
  "ڕەساسی": ThemePalette(
    primary: Color(0xFF0F766E),
    secondary: Color(0xFF475569),
    glow: Color(0xFF14B8A6),
    icon: Color(0xFF0F766E),
    border: Color(0xFF94A3B8),
    background: Color(0xFFFFFFFF),
    cardBg: Color(0xFFF8FAFC),
    cardBgActive: Color(0xFFEFF6FF),
    drawerBg: Color(0xFFFFFFFF),
    drawerBorder: Color(0xFFCBD5E1),
    headerText: Color(0xFF0F172A),
    listText: Color(0xFF1E293B),
    clockText: Color(0xFF0F172A),
    divider: Color(0xFFCBD5E1),
  ),

  // ── شەمامەیی ─────────────────────────────────────
  "پیرۆزەیى": ThemePalette(
    primary: Color(0xFF22D3EE),
    secondary: Color(0xFF67E8F9),
    glow: Color(0xFF06B6D4),
    icon: Color(0xFF22D3EE),
    border: Color(0xFF155E75),
    background: Color(0xFF03141C),
    cardBg: Color(0xFF0A2732),
    cardBgActive: Color(0xFF103545),
    drawerBg: Color(0xFF041924),
    drawerBorder: Color(0xFF22D3EE),
    headerText: Color(0xFF7DEBFA),
    listText: Color(0xFFDDF9FF),
    clockText: Color(0xFF7DEBFA),
    divider: Color(0xFF22D3EE),
  ),

  // ── ئەسمەری ──────────────────────────────────────
  "مۆر": ThemePalette(
    primary: Color(0xFFC084FC),
    secondary: Color(0xFFD8B4FE),
    glow: Color(0xFFA855F7),
    icon: Color(0xFFC084FC),
    border: Color(0xFF6B21A8),
    background: Color(0xFF160A22),
    cardBg: Color(0xFF241238),
    cardBgActive: Color(0xFF31174C),
    drawerBg: Color(0xFF1B0D2B),
    drawerBorder: Color(0xFFC084FC),
    headerText: Color(0xFFE2C7FF),
    listText: Color(0xFFF5ECFF),
    clockText: Color(0xFFE2C7FF),
    divider: Color(0xFFC084FC),
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
const String currentAppVersion = "1.1.11";
