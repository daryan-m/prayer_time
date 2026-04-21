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
    primary: Color(0xFF4ADE80),
    secondary: Color(0xFFA3E635),
    glow: Color(0xFF22C55E),
    icon: Color(0xFF4ADE80),
    border: Color(0xFF166534),
    background: Color(0xFF021A0A),
    cardBg: Color(0xFF052E16),
    cardBgActive: Color(0xFF03200F),
    drawerBg: Color(0xFF021A0A),
    drawerBorder: Color(0xFF4ADE80),
    headerText: Color(0xFF4ADE80),
    listText: Color(0xFFDCFCE7),
    clockText: Color(0xFF4ADE80),
    divider: Color(0xFF4ADE80),
  ),

  // ── پرتەقاڵی ─────────────────────────────────────
  "پرتەقاڵی": ThemePalette(
    primary: Color(0xFFFB923C),
    secondary: Color(0xFFFACC15),
    glow: Color(0xFFF97316),
    icon: Color(0xFFFB923C),
    border: Color(0xFF9A3412),
    background: Color(0xFF1A0A02),
    cardBg: Color(0xFF2D1609),
    cardBgActive: Color(0xFF200F06),
    drawerBg: Color(0xFF1A0A02),
    drawerBorder: Color(0xFFFB923C),
    headerText: Color(0xFFFB923C),
    listText: Color(0xFFFFEDD5),
    clockText: Color(0xFFFB923C),
    divider: Color(0xFFFB923C),
  ),

  // ── ئاڵتونی ──────────────────────────────────────
  "ئاڵتونی": ThemePalette(
    primary: Color(0xFFFFD700),
    secondary: Color(0xFFFBBF24),
    glow: Color(0xFFD97706),
    icon: Color(0xFFFFD700),
    border: Color(0xFF78350F),
    background: Color(0xFF12100A),
    cardBg: Color(0xFF1C1810),
    cardBgActive: Color(0xFF14120A),
    drawerBg: Color(0xFF12100A),
    drawerBorder: Color(0xFFFFD700),
    headerText: Color(0xFFFFD700),
    listText: Color(0xFFFEF9C3),
    clockText: Color(0xFFFFD700),
    divider: Color(0xFFFFD700),
  ),

  // ── ڕۆشن ───────────────────────────────────────
  "ڕەساسی": ThemePalette(
    primary: Color(0xFF94B8A3),
    secondary: Color(0xFFCBD5E1),
    glow: Color(0xFF007A47),
    icon: Color(0xFFFAFFCD),
    border: Color(0xFF00D335),
    background: Color(0xFFFFFFFF),
    cardBg: Color(0xFFEAEBEC),
    cardBgActive: Color(0xFFC1FFE5),
    drawerBg: Color(0xFFFFFFFF),
    drawerBorder: Color(0xFF00D335),
    headerText: Color(0xFFF4FFD5),
    listText: Color(0xFF000000),
    clockText: Color(0xFF000000),
    divider: Color(0xFF94A3B8),
  ),

  // ── شەمامەیی ─────────────────────────────────────
  "پیرۆزەیى": ThemePalette(
    primary: Color(0xFF2DD4BF),
    secondary: Color(0xFF5EEAD4),
    glow: Color(0xFF0D9488),
    icon: Color(0xFF2DD4BF),
    border: Color(0xFF134E4A),
    background: Color(0xFF021A18),
    cardBg: Color(0xFF042F2E),
    cardBgActive: Color(0xFF032220),
    drawerBg: Color(0xFF021A18),
    drawerBorder: Color(0xFF2DD4BF),
    headerText: Color(0xFF2DD4BF),
    listText: Color(0xFFCCFBF1),
    clockText: Color(0xFF2DD4BF),
    divider: Color(0xFF2DD4BF),
  ),

  // ── ئەسمەری ──────────────────────────────────────
  "مۆر": ThemePalette(
    primary: Color(0xFFE879F9),
    secondary: Color(0xFFF0ABFC),
    glow: Color(0xFFD946EF),
    icon: Color(0xFF820B94),
    border: Color(0xFF701A75),
    background: Color(0xFF8F36AD),
    cardBg: Color(0xFFAB5AC2),
    cardBgActive: Color(0xFF9900FF),
    drawerBg: Color(0xFF120018),
    drawerBorder: Color(0xFFE879F9),
    headerText: Color(0xFFE879F9),
    listText: Color(0xFFFAE8FF),
    clockText: Color(0xFFE879F9),
    divider: Color(0xFFE879F9),
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
const String currentAppVersion = "1.1.4";
