import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';

// ==================== مۆدێل ====================

class QuranSurah {
  final int number;
  final String nameArabic;
  final String nameKurdish;
  final int ayahCount;
  final bool isMakki;
  final int juzStart;

  const QuranSurah({
    required this.number,
    required this.nameArabic,
    required this.nameKurdish,
    required this.ayahCount,
    required this.isMakki,
    required this.juzStart,
  });
}

class QuranReciter {
  final String nameArabic;
  final String nameKurdish;
  final String key;

  const QuranReciter({
    required this.nameArabic,
    required this.nameKurdish,
    required this.key,
  });
}

// ==================== قاریئەکانی یاساییەکان لە EveryAyah ====================

const List<QuranReciter> quranReciters = [
  QuranReciter(
    nameArabic: 'مشاري العفاسي',
    nameKurdish: 'مشاری عەفاسی',
    key: 'Alafasy_128kbps',
  ),
  QuranReciter(
    nameArabic: 'محمود خليل الحصري',
    nameKurdish: 'محموود حوسەری',
    key: 'Husary_128kbps',
  ),
  QuranReciter(
    nameArabic: 'عبد الباسط عبد الصمد (مرتل)',
    nameKurdish: 'عەبدولباسیت (مورەتتەل)',
    key: 'Abdul_Basit_Murattal_192kbps',
  ),
  QuranReciter(
    nameArabic: 'عبد الباسط عبد الصمد (مجود)',
    nameKurdish: 'عەبدولباسیت (موجەووەد)',
    key: 'Abdul_Basit_Mujawwad_128kbps',
  ),
  QuranReciter(
    nameArabic: 'عبد الرحمن السديس',
    nameKurdish: 'عەبدورەحمان سودەیس',
    key: 'Abdurrahmaan_As-Sudais_192kbps',
  ),
  QuranReciter(
    nameArabic: 'محمد صديق المنشاوي',
    nameKurdish: 'محەممەد مینشاوی',
    key: 'Minshawy_Murattal_128kbps',
  ),
  QuranReciter(
    nameArabic: 'أبو بكر الشاطري',
    nameKurdish: 'ئەبوبەکر شاتیری',
    key: 'Abu_Bakr_Ash-Shaatree_128kbps',
  ),
  QuranReciter(
    nameArabic: 'سعد الغامدي',
    nameKurdish: 'سەعد غامیدی',
    key: 'Ghamadi_40kbps',
  ),
  QuranReciter(
    nameArabic: 'هاني الرفاعي',
    nameKurdish: 'هانی ڕیفاعی',
    key: 'Hani_Rifai_192kbps',
  ),
  QuranReciter(
    nameArabic: 'علي الحذيفي',
    nameKurdish: 'علی حوزەیفی',
    key: 'Hudhaify_128kbps',
  ),
  QuranReciter(
    nameArabic: 'أحمد ابن علي العجمي',
    nameKurdish: 'ئەحمەد عەجەمی',
    key: 'ahmed_ibn_ali_al_ajamy_128kbps',
  ),
  QuranReciter(
    nameArabic: 'عبدالله بصفر',
    nameKurdish: 'عەبدوللە بەسفەر',
    key: 'Abdullah_Basfar_192kbps',
  ),
];

// ==================== سێرڤیسی قورئان ====================

class QuranService {
  static Map<String, dynamic>? _quranData;

  static Future<void> _ensureLoaded() async {
    if (_quranData != null) return;
    final String raw = await rootBundle.loadString('assets/quran/quran.json');
    _quranData = json.decode(raw) as Map<String, dynamic>;
  }

  // ── بارکردنی سووردا بەپێی ساختاری جدید ==
  static Future<List<Map<String, dynamic>>> loadSurah(int surahNumber) async {
    await _ensureLoaded();
    final surahs = _quranData!['data']['surahs'] as List<dynamic>;
    final surah = surahs.firstWhere((s) => s['number'] == surahNumber);
    final ayahs = surah['ayahs'] as List<dynamic>;

    return ayahs
        .map<Map<String, dynamic>>((a) => {
              'a': a['numberInSurah'] as int,
              't': a['text'] as String,
              'page': a['page'] as int,
              'juz': a['juz'] as int,
              'sajda': a['sajda'],
            })
        .toList();
  }

  // ── دابەشکردنی ئایەتەکان بەپێی ژمارەی لاپەرەی ڕاستەقینەی مصحف ──
  static List<List<Map<String, dynamic>>> splitIntoPages(
      List<Map<String, dynamic>> ayahs) {
    final Map<int, List<Map<String, dynamic>>> pageMap = {};
    for (final ayah in ayahs) {
      final int page = ayah['page'] as int;
      pageMap.putIfAbsent(page, () => []).add(ayah);
    }
    final sortedKeys = pageMap.keys.toList()..sort();
    return sortedKeys.map((k) => pageMap[k]!).toList();
  }

  // ── URLی دەنگ ──
  static String audioUrl(int surahNumber, int ayahNumber, String reciterKey) {
    final s = surahNumber.toString().padLeft(3, '0');
    final a = ayahNumber.toString().padLeft(3, '0');
    return 'https://everyayah.com/data/$reciterKey/$s$a.mp3';
  }

  static Future<String> _localPath(int s, int a, String key) async {
    final dir = await getApplicationDocumentsDirectory();
    final folder = Directory('${dir.path}/quran_audio/$key');
    await folder.create(recursive: true);
    return '${folder.path}/${s.toString().padLeft(3, '0')}${a.toString().padLeft(3, '0')}.mp3';
  }

  static Future<bool> isDownloaded(int s, int a, String key) async {
    try {
      final path = await _localPath(s, a, key);
      return File(path).exists();
    } catch (_) {
      return false;
    }
  }

  static Future<String> getAudioSource(int s, int a, String key) async {
    final path = await _localPath(s, a, key);
    if (await File(path).exists()) return path;
    return audioUrl(s, a, key);
  }

  static Future<void> downloadAyah(int s, int a, String key) async {
    final path = await _localPath(s, a, key);
    if (await File(path).exists()) return;
    try {
      final resp = await http.get(Uri.parse(audioUrl(s, a, key)));
      if (resp.statusCode == 200) {
        await File(path).writeAsBytes(resp.bodyBytes);
      }
    } catch (_) {}
  }

  static Future<void> deleteReciter(String key) async {
    final dir = await getApplicationDocumentsDirectory();
    final folder = Directory('${dir.path}/quran_audio/$key');
    if (await folder.exists()) await folder.delete(recursive: true);
  }
}

// ==================== سکرینی لیستی سووره ====================

class QuranScreen extends StatefulWidget {
  final Color primaryColor;
  final ThemePalette palette;

  const QuranScreen({
    super.key,
    required this.primaryColor,
    required this.palette,
  });

  @override
  State<QuranScreen> createState() => _QuranScreenState();
}

class _QuranScreenState extends State<QuranScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // جوزئەکان — ٣٠ جوزء
  static const List<String> juzNames = [
    'جوزئی ١',
    'جوزئی ٢',
    'جوزئی ٣',
    'جوزئی ٤',
    'جوزئی ٥',
    'جوزئی ٦',
    'جوزئی ٧',
    'جوزئی ٨',
    'جوزئی ٩',
    'جوزئی ١٠',
    'جوزئی ١١',
    'جوزئی ١٢',
    'جوزئی ١٣',
    'جوزئی ١٤',
    'جوزئی ١٥',
    'جوزئی ١٦',
    'جوزئی ١٧',
    'جوزئی ١٨',
    'جوزئی ١٩',
    'جوزئی ٢٠',
    'جوزئی ٢١',
    'جوزئی ٢٢',
    'جوزئی ٢٣',
    'جوزئی ٢٤',
    'جوزئی ٢٥',
    'جوزئی ٢٦',
    'جوزئی ٢٧',
    'جوزئی ٢٨',
    'جوزئی ٢٩',
    'جوزئی ٣٠',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  static const List<QuranSurah> surahs = [
    QuranSurah(
        number: 1,
        nameArabic: "الفاتحة",
        nameKurdish: "فاتیحە",
        ayahCount: 7,
        isMakki: true,
        juzStart: 1),
    QuranSurah(
        number: 2,
        nameArabic: "البقرة",
        nameKurdish: "بەقەرە",
        ayahCount: 286,
        isMakki: false,
        juzStart: 1),
    QuranSurah(
        number: 3,
        nameArabic: "آل عمران",
        nameKurdish: "ئالی عیمران",
        ayahCount: 200,
        isMakki: false,
        juzStart: 3),
    QuranSurah(
        number: 4,
        nameArabic: "النساء",
        nameKurdish: "نیساء",
        ayahCount: 176,
        isMakki: false,
        juzStart: 4),
    QuranSurah(
        number: 5,
        nameArabic: "المائدة",
        nameKurdish: "مائیدە",
        ayahCount: 120,
        isMakki: false,
        juzStart: 6),
    QuranSurah(
        number: 6,
        nameArabic: "الأنعام",
        nameKurdish: "ئەنعام",
        ayahCount: 165,
        isMakki: true,
        juzStart: 7),
    QuranSurah(
        number: 7,
        nameArabic: "الأعراف",
        nameKurdish: "ئەعراف",
        ayahCount: 206,
        isMakki: true,
        juzStart: 8),
    QuranSurah(
        number: 8,
        nameArabic: "الأنفال",
        nameKurdish: "ئەنفال",
        ayahCount: 75,
        isMakki: false,
        juzStart: 9),
    QuranSurah(
        number: 9,
        nameArabic: "التوبة",
        nameKurdish: "تەوبە",
        ayahCount: 129,
        isMakki: false,
        juzStart: 10),
    QuranSurah(
        number: 10,
        nameArabic: "يونس",
        nameKurdish: "یونس",
        ayahCount: 109,
        isMakki: true,
        juzStart: 11),
    QuranSurah(
        number: 11,
        nameArabic: "هود",
        nameKurdish: "هوود",
        ayahCount: 123,
        isMakki: true,
        juzStart: 11),
    QuranSurah(
        number: 12,
        nameArabic: "يوسف",
        nameKurdish: "یوسف",
        ayahCount: 111,
        isMakki: true,
        juzStart: 12),
    QuranSurah(
        number: 13,
        nameArabic: "الرعد",
        nameKurdish: "ڕەعد",
        ayahCount: 43,
        isMakki: false,
        juzStart: 13),
    QuranSurah(
        number: 14,
        nameArabic: "إبراهيم",
        nameKurdish: "ئیبراهیم",
        ayahCount: 52,
        isMakki: true,
        juzStart: 13),
    QuranSurah(
        number: 15,
        nameArabic: "الحجر",
        nameKurdish: "حیجر",
        ayahCount: 99,
        isMakki: true,
        juzStart: 14),
    QuranSurah(
        number: 16,
        nameArabic: "النحل",
        nameKurdish: "نەحل",
        ayahCount: 128,
        isMakki: true,
        juzStart: 14),
    QuranSurah(
        number: 17,
        nameArabic: "الإسراء",
        nameKurdish: "ئیسراء",
        ayahCount: 111,
        isMakki: true,
        juzStart: 15),
    QuranSurah(
        number: 18,
        nameArabic: "الكهف",
        nameKurdish: "کەهف",
        ayahCount: 110,
        isMakki: true,
        juzStart: 15),
    QuranSurah(
        number: 19,
        nameArabic: "مريم",
        nameKurdish: "مەریەم",
        ayahCount: 98,
        isMakki: true,
        juzStart: 16),
    QuranSurah(
        number: 20,
        nameArabic: "طه",
        nameKurdish: "تاها",
        ayahCount: 135,
        isMakki: true,
        juzStart: 16),
    QuranSurah(
        number: 21,
        nameArabic: "الأنبياء",
        nameKurdish: "ئەنبیاء",
        ayahCount: 112,
        isMakki: true,
        juzStart: 17),
    QuranSurah(
        number: 22,
        nameArabic: "الحج",
        nameKurdish: "حەج",
        ayahCount: 78,
        isMakki: false,
        juzStart: 17),
    QuranSurah(
        number: 23,
        nameArabic: "المؤمنون",
        nameKurdish: "مۆمینون",
        ayahCount: 118,
        isMakki: true,
        juzStart: 18),
    QuranSurah(
        number: 24,
        nameArabic: "النور",
        nameKurdish: "نوور",
        ayahCount: 64,
        isMakki: false,
        juzStart: 18),
    QuranSurah(
        number: 25,
        nameArabic: "الفرقان",
        nameKurdish: "فورقان",
        ayahCount: 77,
        isMakki: true,
        juzStart: 18),
    QuranSurah(
        number: 26,
        nameArabic: "الشعراء",
        nameKurdish: "شوعەراء",
        ayahCount: 227,
        isMakki: true,
        juzStart: 19),
    QuranSurah(
        number: 27,
        nameArabic: "النمل",
        nameKurdish: "نەمل",
        ayahCount: 93,
        isMakki: true,
        juzStart: 19),
    QuranSurah(
        number: 28,
        nameArabic: "القصص",
        nameKurdish: "قەسەس",
        ayahCount: 88,
        isMakki: true,
        juzStart: 20),
    QuranSurah(
        number: 29,
        nameArabic: "العنكبوت",
        nameKurdish: "عەنکەبووت",
        ayahCount: 69,
        isMakki: true,
        juzStart: 20),
    QuranSurah(
        number: 30,
        nameArabic: "الروم",
        nameKurdish: "ڕووم",
        ayahCount: 60,
        isMakki: true,
        juzStart: 21),
    QuranSurah(
        number: 31,
        nameArabic: "لقمان",
        nameKurdish: "لوقمان",
        ayahCount: 34,
        isMakki: true,
        juzStart: 21),
    QuranSurah(
        number: 32,
        nameArabic: "السجدة",
        nameKurdish: "سەجدە",
        ayahCount: 30,
        isMakki: true,
        juzStart: 21),
    QuranSurah(
        number: 33,
        nameArabic: "الأحزاب",
        nameKurdish: "ئەحزاب",
        ayahCount: 73,
        isMakki: false,
        juzStart: 21),
    QuranSurah(
        number: 34,
        nameArabic: "سبأ",
        nameKurdish: "سەبأ",
        ayahCount: 54,
        isMakki: true,
        juzStart: 22),
    QuranSurah(
        number: 35,
        nameArabic: "فاطر",
        nameKurdish: "فاتیر",
        ayahCount: 45,
        isMakki: true,
        juzStart: 22),
    QuranSurah(
        number: 36,
        nameArabic: "يس",
        nameKurdish: "یاسین",
        ayahCount: 83,
        isMakki: true,
        juzStart: 22),
    QuranSurah(
        number: 37,
        nameArabic: "الصافات",
        nameKurdish: "سافات",
        ayahCount: 182,
        isMakki: true,
        juzStart: 23),
    QuranSurah(
        number: 38,
        nameArabic: "ص",
        nameKurdish: "ساد",
        ayahCount: 88,
        isMakki: true,
        juzStart: 23),
    QuranSurah(
        number: 39,
        nameArabic: "الزمر",
        nameKurdish: "زومەر",
        ayahCount: 75,
        isMakki: true,
        juzStart: 23),
    QuranSurah(
        number: 40,
        nameArabic: "غافر",
        nameKurdish: "غافیر",
        ayahCount: 85,
        isMakki: true,
        juzStart: 24),
    QuranSurah(
        number: 41,
        nameArabic: "فصلت",
        nameKurdish: "فوسیلەت",
        ayahCount: 54,
        isMakki: true,
        juzStart: 24),
    QuranSurah(
        number: 42,
        nameArabic: "الشورى",
        nameKurdish: "شووری",
        ayahCount: 53,
        isMakki: true,
        juzStart: 25),
    QuranSurah(
        number: 43,
        nameArabic: "الزخرف",
        nameKurdish: "زوخروف",
        ayahCount: 89,
        isMakki: true,
        juzStart: 25),
    QuranSurah(
        number: 44,
        nameArabic: "الدخان",
        nameKurdish: "دوخان",
        ayahCount: 59,
        isMakki: true,
        juzStart: 25),
    QuranSurah(
        number: 45,
        nameArabic: "الجاثية",
        nameKurdish: "جاسیە",
        ayahCount: 37,
        isMakki: true,
        juzStart: 25),
    QuranSurah(
        number: 46,
        nameArabic: "الأحقاف",
        nameKurdish: "ئەحقاف",
        ayahCount: 35,
        isMakki: true,
        juzStart: 26),
    QuranSurah(
        number: 47,
        nameArabic: "محمد",
        nameKurdish: "محەممەد",
        ayahCount: 38,
        isMakki: false,
        juzStart: 26),
    QuranSurah(
        number: 48,
        nameArabic: "الفتح",
        nameKurdish: "فەتح",
        ayahCount: 29,
        isMakki: false,
        juzStart: 26),
    QuranSurah(
        number: 49,
        nameArabic: "الحجرات",
        nameKurdish: "حوجورات",
        ayahCount: 18,
        isMakki: false,
        juzStart: 26),
    QuranSurah(
        number: 50,
        nameArabic: "ق",
        nameKurdish: "قاف",
        ayahCount: 45,
        isMakki: true,
        juzStart: 26),
    QuranSurah(
        number: 51,
        nameArabic: "الذاريات",
        nameKurdish: "زاریات",
        ayahCount: 60,
        isMakki: true,
        juzStart: 26),
    QuranSurah(
        number: 52,
        nameArabic: "الطور",
        nameKurdish: "تور",
        ayahCount: 49,
        isMakki: true,
        juzStart: 27),
    QuranSurah(
        number: 53,
        nameArabic: "النجم",
        nameKurdish: "نەجم",
        ayahCount: 62,
        isMakki: true,
        juzStart: 27),
    QuranSurah(
        number: 54,
        nameArabic: "القمر",
        nameKurdish: "قەمەر",
        ayahCount: 55,
        isMakki: true,
        juzStart: 27),
    QuranSurah(
        number: 55,
        nameArabic: "الرحمن",
        nameKurdish: "ڕەحمان",
        ayahCount: 78,
        isMakki: false,
        juzStart: 27),
    QuranSurah(
        number: 56,
        nameArabic: "الواقعة",
        nameKurdish: "واقیعە",
        ayahCount: 96,
        isMakki: true,
        juzStart: 27),
    QuranSurah(
        number: 57,
        nameArabic: "الحديد",
        nameKurdish: "حەدید",
        ayahCount: 29,
        isMakki: false,
        juzStart: 27),
    QuranSurah(
        number: 58,
        nameArabic: "المجادلة",
        nameKurdish: "موجادیلە",
        ayahCount: 22,
        isMakki: false,
        juzStart: 28),
    QuranSurah(
        number: 59,
        nameArabic: "الحشر",
        nameKurdish: "حەشر",
        ayahCount: 24,
        isMakki: false,
        juzStart: 28),
    QuranSurah(
        number: 60,
        nameArabic: "الممتحنة",
        nameKurdish: "مومتەحینە",
        ayahCount: 13,
        isMakki: false,
        juzStart: 28),
    QuranSurah(
        number: 61,
        nameArabic: "الصف",
        nameKurdish: "سەف",
        ayahCount: 14,
        isMakki: false,
        juzStart: 28),
    QuranSurah(
        number: 62,
        nameArabic: "الجمعة",
        nameKurdish: "جومعە",
        ayahCount: 11,
        isMakki: false,
        juzStart: 28),
    QuranSurah(
        number: 63,
        nameArabic: "المنافقون",
        nameKurdish: "موناافیقون",
        ayahCount: 11,
        isMakki: false,
        juzStart: 28),
    QuranSurah(
        number: 64,
        nameArabic: "التغابن",
        nameKurdish: "تەغابون",
        ayahCount: 18,
        isMakki: false,
        juzStart: 28),
    QuranSurah(
        number: 65,
        nameArabic: "الطلاق",
        nameKurdish: "تەلاق",
        ayahCount: 12,
        isMakki: false,
        juzStart: 28),
    QuranSurah(
        number: 66,
        nameArabic: "التحريم",
        nameKurdish: "تەحریم",
        ayahCount: 12,
        isMakki: false,
        juzStart: 28),
    QuranSurah(
        number: 67,
        nameArabic: "الملك",
        nameKurdish: "مولک",
        ayahCount: 30,
        isMakki: true,
        juzStart: 29),
    QuranSurah(
        number: 68,
        nameArabic: "القلم",
        nameKurdish: "قەلەم",
        ayahCount: 52,
        isMakki: true,
        juzStart: 29),
    QuranSurah(
        number: 69,
        nameArabic: "الحاقة",
        nameKurdish: "حاقە",
        ayahCount: 52,
        isMakki: true,
        juzStart: 29),
    QuranSurah(
        number: 70,
        nameArabic: "المعارج",
        nameKurdish: "مەعاریج",
        ayahCount: 44,
        isMakki: true,
        juzStart: 29),
    QuranSurah(
        number: 71,
        nameArabic: "نوح",
        nameKurdish: "نووح",
        ayahCount: 28,
        isMakki: true,
        juzStart: 29),
    QuranSurah(
        number: 72,
        nameArabic: "الجن",
        nameKurdish: "جین",
        ayahCount: 28,
        isMakki: true,
        juzStart: 29),
    QuranSurah(
        number: 73,
        nameArabic: "المزمل",
        nameKurdish: "موزەممیل",
        ayahCount: 20,
        isMakki: true,
        juzStart: 29),
    QuranSurah(
        number: 74,
        nameArabic: "المدثر",
        nameKurdish: "موددەسیر",
        ayahCount: 56,
        isMakki: true,
        juzStart: 29),
    QuranSurah(
        number: 75,
        nameArabic: "القيامة",
        nameKurdish: "قیامەت",
        ayahCount: 40,
        isMakki: true,
        juzStart: 29),
    QuranSurah(
        number: 76,
        nameArabic: "الإنسان",
        nameKurdish: "ئینسان",
        ayahCount: 31,
        isMakki: false,
        juzStart: 29),
    QuranSurah(
        number: 77,
        nameArabic: "المرسلات",
        nameKurdish: "مورسەلات",
        ayahCount: 50,
        isMakki: true,
        juzStart: 29),
    QuranSurah(
        number: 78,
        nameArabic: "النبأ",
        nameKurdish: "نەبأ",
        ayahCount: 40,
        isMakki: true,
        juzStart: 30),
    QuranSurah(
        number: 79,
        nameArabic: "النازعات",
        nameKurdish: "نازیعات",
        ayahCount: 46,
        isMakki: true,
        juzStart: 30),
    QuranSurah(
        number: 80,
        nameArabic: "عبس",
        nameKurdish: "عەبەسە",
        ayahCount: 42,
        isMakki: true,
        juzStart: 30),
    QuranSurah(
        number: 81,
        nameArabic: "التكوير",
        nameKurdish: "تەکویر",
        ayahCount: 29,
        isMakki: true,
        juzStart: 30),
    QuranSurah(
        number: 82,
        nameArabic: "الانفطار",
        nameKurdish: "ئینفیتار",
        ayahCount: 19,
        isMakki: true,
        juzStart: 30),
    QuranSurah(
        number: 83,
        nameArabic: "المطففين",
        nameKurdish: "موتەففیفین",
        ayahCount: 36,
        isMakki: true,
        juzStart: 30),
    QuranSurah(
        number: 84,
        nameArabic: "الانشقاق",
        nameKurdish: "ئینشیقاق",
        ayahCount: 25,
        isMakki: true,
        juzStart: 30),
    QuranSurah(
        number: 85,
        nameArabic: "البروج",
        nameKurdish: "بوروج",
        ayahCount: 22,
        isMakki: true,
        juzStart: 30),
    QuranSurah(
        number: 86,
        nameArabic: "الطارق",
        nameKurdish: "تاریق",
        ayahCount: 17,
        isMakki: true,
        juzStart: 30),
    QuranSurah(
        number: 87,
        nameArabic: "الأعلى",
        nameKurdish: "ئەعلا",
        ayahCount: 19,
        isMakki: true,
        juzStart: 30),
    QuranSurah(
        number: 88,
        nameArabic: "الغاشية",
        nameKurdish: "غاشیە",
        ayahCount: 26,
        isMakki: true,
        juzStart: 30),
    QuranSurah(
        number: 89,
        nameArabic: "الفجر",
        nameKurdish: "فەجر",
        ayahCount: 30,
        isMakki: true,
        juzStart: 30),
    QuranSurah(
        number: 90,
        nameArabic: "البلد",
        nameKurdish: "بەلەد",
        ayahCount: 20,
        isMakki: true,
        juzStart: 30),
    QuranSurah(
        number: 91,
        nameArabic: "الشمس",
        nameKurdish: "شەمس",
        ayahCount: 15,
        isMakki: true,
        juzStart: 30),
    QuranSurah(
        number: 92,
        nameArabic: "الليل",
        nameKurdish: "لەیل",
        ayahCount: 21,
        isMakki: true,
        juzStart: 30),
    QuranSurah(
        number: 93,
        nameArabic: "الضحى",
        nameKurdish: "ضوحا",
        ayahCount: 11,
        isMakki: true,
        juzStart: 30),
    QuranSurah(
        number: 94,
        nameArabic: "الشرح",
        nameKurdish: "شەرح",
        ayahCount: 8,
        isMakki: true,
        juzStart: 30),
    QuranSurah(
        number: 95,
        nameArabic: "التين",
        nameKurdish: "تین",
        ayahCount: 8,
        isMakki: true,
        juzStart: 30),
    QuranSurah(
        number: 96,
        nameArabic: "العلق",
        nameKurdish: "عەلەق",
        ayahCount: 19,
        isMakki: true,
        juzStart: 30),
    QuranSurah(
        number: 97,
        nameArabic: "القدر",
        nameKurdish: "قەدر",
        ayahCount: 5,
        isMakki: true,
        juzStart: 30),
    QuranSurah(
        number: 98,
        nameArabic: "البينة",
        nameKurdish: "بەییینە",
        ayahCount: 8,
        isMakki: false,
        juzStart: 30),
    QuranSurah(
        number: 99,
        nameArabic: "الزلزلة",
        nameKurdish: "زەلزەلە",
        ayahCount: 8,
        isMakki: false,
        juzStart: 30),
    QuranSurah(
        number: 100,
        nameArabic: "العاديات",
        nameKurdish: "عادیات",
        ayahCount: 11,
        isMakki: true,
        juzStart: 30),
    QuranSurah(
        number: 101,
        nameArabic: "القارعة",
        nameKurdish: "قارعە",
        ayahCount: 11,
        isMakki: true,
        juzStart: 30),
    QuranSurah(
        number: 102,
        nameArabic: "التكاثر",
        nameKurdish: "تەکاسور",
        ayahCount: 8,
        isMakki: true,
        juzStart: 30),
    QuranSurah(
        number: 103,
        nameArabic: "العصر",
        nameKurdish: "عەسر",
        ayahCount: 3,
        isMakki: true,
        juzStart: 30),
    QuranSurah(
        number: 104,
        nameArabic: "الهمزة",
        nameKurdish: "هومەزە",
        ayahCount: 9,
        isMakki: true,
        juzStart: 30),
    QuranSurah(
        number: 105,
        nameArabic: "الفيل",
        nameKurdish: "فیل",
        ayahCount: 5,
        isMakki: true,
        juzStart: 30),
    QuranSurah(
        number: 106,
        nameArabic: "قريش",
        nameKurdish: "قورەیش",
        ayahCount: 4,
        isMakki: true,
        juzStart: 30),
    QuranSurah(
        number: 107,
        nameArabic: "الماعون",
        nameKurdish: "ماعون",
        ayahCount: 7,
        isMakki: true,
        juzStart: 30),
    QuranSurah(
        number: 108,
        nameArabic: "الكوثر",
        nameKurdish: "کەوسەر",
        ayahCount: 3,
        isMakki: true,
        juzStart: 30),
    QuranSurah(
        number: 109,
        nameArabic: "الكافرون",
        nameKurdish: "کافیرون",
        ayahCount: 6,
        isMakki: true,
        juzStart: 30),
    QuranSurah(
        number: 110,
        nameArabic: "النصر",
        nameKurdish: "نەسر",
        ayahCount: 3,
        isMakki: false,
        juzStart: 30),
    QuranSurah(
        number: 111,
        nameArabic: "المسد",
        nameKurdish: "مەسەد",
        ayahCount: 5,
        isMakki: true,
        juzStart: 30),
    QuranSurah(
        number: 112,
        nameArabic: "الإخلاص",
        nameKurdish: "ئیخلاس",
        ayahCount: 4,
        isMakki: true,
        juzStart: 30),
    QuranSurah(
        number: 113,
        nameArabic: "الفلق",
        nameKurdish: "فەلەق",
        ayahCount: 5,
        isMakki: true,
        juzStart: 30),
    QuranSurah(
        number: 114,
        nameArabic: "الناس",
        nameKurdish: "ناس",
        ayahCount: 6,
        isMakki: true,
        juzStart: 30),
  ];

  void _openSurah(QuranSurah surah) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuranReadScreen(
          surah: surah,
          primaryColor: widget.primaryColor,
          palette: widget.palette,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: widget.palette.background,
        appBar: AppBar(
          backgroundColor: widget.palette.background,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded,
                color: widget.palette.secondary),
            onPressed: () => Navigator.pop(context),
          ),
          title: Row(children: [
            Icon(Icons.menu_book_rounded,
                color: widget.palette.secondary, size: 24),
            const SizedBox(width: 8),
            Text(
              "قورئانی پیرۆز",
              style: TextStyle(
                color: widget.palette.secondary,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
          ]),
          actions: [
            IconButton(
              icon:
                  Icon(Icons.download_rounded, color: widget.palette.secondary),
              tooltip: "داگرتنی دەنگ",
              onPressed: () => _showRecitersSheet(context),
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: widget.primaryColor,
            labelColor: widget.primaryColor,
            unselectedLabelColor: widget.palette.listText.withOpacity(0.5),
            labelStyle:
                const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            tabs: const [
              Tab(text: "سووراتەکان"),
              Tab(text: "جوزئەکان"),
              Tab(text: "قاریئەکان"),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            // تاب ١: سووراتەکان
            _buildSurahList(),
            // تاب ٢: جوزئەکان
            _buildJuzList(),
            // تاب ٣: قاریئەکان
            _buildRecitersTab(),
          ],
        ),
      ),
    );
  }

  // ── لیستی سووراتەکان ──
  Widget _buildSurahList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: surahs.length,
      itemBuilder: (context, index) {
        final surah = surahs[index];
        return _SurahListTile(
          surah: surah,
          primaryColor: widget.primaryColor,
          palette: widget.palette,
          onTap: () => _openSurah(surah),
        );
      },
    );
  }

  // ── لیستی جوزئەکان ──
  Widget _buildJuzList() {
    // دروستکردنی لیستی جوزئەکان بەپێی سووراتەکان
    final Map<int, List<QuranSurah>> juzMap = {};
    for (final s in surahs) {
      juzMap.putIfAbsent(s.juzStart, () => []).add(s);
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: 30,
      itemBuilder: (context, index) {
        final juzNum = index + 1;
        final juzSurahs = juzMap[juzNum] ?? [];
        return _JuzTile(
          juzNumber: juzNum,
          surahs: juzSurahs,
          primaryColor: widget.primaryColor,
          palette: widget.palette,
          onSurahTap: _openSurah,
        );
      },
    );
  }

  // ── تابی قاریئەکان ──
  Widget _buildRecitersTab() {
    return _RecitersSheet(
      primaryColor: widget.primaryColor,
      palette: widget.palette,
      surahs: surahs,
      embedded: true,
    );
  }

  void _showRecitersSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: widget.palette.drawerBg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _RecitersSheet(
        primaryColor: widget.primaryColor,
        palette: widget.palette,
        surahs: surahs,
        embedded: false,
      ),
    );
  }
}

// ==================== تایلی جوزء ====================

class _JuzTile extends StatefulWidget {
  final int juzNumber;
  final List<QuranSurah> surahs;
  final Color primaryColor;
  final ThemePalette palette;
  final void Function(QuranSurah) onSurahTap;

  const _JuzTile({
    required this.juzNumber,
    required this.surahs,
    required this.primaryColor,
    required this.palette,
    required this.onSurahTap,
  });

  @override
  State<_JuzTile> createState() => _JuzTileState();
}

class _JuzTileState extends State<_JuzTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      decoration: BoxDecoration(
        color: widget.palette.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.primaryColor.withOpacity(0.15),
                    border:
                        Border.all(color: widget.primaryColor.withOpacity(0.4)),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${widget.juzNumber}',
                    style: TextStyle(
                      color: widget.primaryColor,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _QuranScreenState.juzNames[widget.juzNumber - 1],
                        style: TextStyle(
                          color: widget.palette.listText,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (widget.surahs.isNotEmpty)
                        Text(
                          'دەست دەکات بە ${widget.surahs.first.nameKurdish}',
                          style: TextStyle(
                            color: widget.palette.listText.withOpacity(0.5),
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                ),
                Icon(
                  _expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: widget.palette.listText.withOpacity(0.5),
                ),
              ]),
            ),
          ),
          if (_expanded && widget.surahs.isNotEmpty)
            Column(
              children: [
                Divider(
                    height: 1, color: widget.primaryColor.withOpacity(0.15)),
                ...widget.surahs.map((s) => GestureDetector(
                      onTap: () => widget.onSurahTap(s),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                        child: Row(children: [
                          Text(
                            '${s.number}.',
                            style: TextStyle(
                              color: widget.primaryColor,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              s.nameKurdish,
                              style: TextStyle(
                                color: widget.palette.listText,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          Text(
                            s.nameArabic,
                            style: TextStyle(
                              color: widget.primaryColor.withOpacity(0.8),
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ]),
                      ),
                    )),
              ],
            ),
        ],
      ),
    );
  }
}

// ==================== شیتی/تابی قاریەکان ====================

class _RecitersSheet extends StatefulWidget {
  final Color primaryColor;
  final ThemePalette palette;
  final List<QuranSurah> surahs;
  final bool embedded;

  const _RecitersSheet({
    required this.primaryColor,
    required this.palette,
    required this.surahs,
    required this.embedded,
  });

  @override
  State<_RecitersSheet> createState() => _RecitersSheetState();
}

class _RecitersSheetState extends State<_RecitersSheet> {
  String? _downloadingKey;
  int _done = 0;
  final int _total = 6236;

  Future<void> _downloadAll(QuranReciter reciter) async {
    setState(() {
      _downloadingKey = reciter.key;
      _done = 0;
    });
    int done = 0;
    for (final s in widget.surahs) {
      for (int a = 1; a <= s.ayahCount; a++) {
        await QuranService.downloadAyah(s.number, a, reciter.key);
        done++;
        if (mounted) setState(() => _done = done);
      }
    }
    if (mounted) {
      setState(() => _downloadingKey = null);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("${reciter.nameKurdish} تەواو داگیرا ✓"),
        backgroundColor: Colors.green.shade700,
      ));
    }
  }

  Future<void> _delete(QuranReciter reciter) async {
    await QuranService.deleteReciter(reciter.key);
    if (mounted) setState(() {});
  }

  Widget _buildContent(ScrollController? ctrl) {
    return Padding(
      padding: EdgeInsets.all(widget.embedded ? 12 : 20),
      child: Column(children: [
        if (!widget.embedded) ...[
          Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
        ],
        Row(children: [
          Icon(Icons.download_rounded, color: widget.primaryColor, size: 20),
          const SizedBox(width: 8),
          Text(
            "قاریئەکان و داگرتنی دەنگ",
            style: TextStyle(
              color: widget.palette.listText,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ]),
        const SizedBox(height: 4),
        Text(
          "دەنگ داگرە بۆ خوێندنەوەی ئۆفلاین — یان ئۆنلاین بیبیستە",
          style: TextStyle(
            color: widget.palette.listText.withOpacity(0.5),
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView(
            controller: ctrl,
            children: quranReciters
                .map((r) => _ReciterTile(
                      reciter: r,
                      primaryColor: widget.primaryColor,
                      palette: widget.palette,
                      isDownloading: _downloadingKey == r.key,
                      done: _downloadingKey == r.key ? _done : 0,
                      total: _total,
                      onDownload: () => _downloadAll(r),
                      onDelete: () async {
                        await _delete(r);
                        setState(() {});
                      },
                    ))
                .toList(),
          ),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.embedded) {
      return _buildContent(null);
    }
    return Directionality(
      textDirection: TextDirection.rtl,
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        builder: (_, ctrl) => _buildContent(ctrl),
      ),
    );
  }
}

class _ReciterTile extends StatefulWidget {
  final QuranReciter reciter;
  final Color primaryColor;
  final ThemePalette palette;
  final bool isDownloading;
  final int done;
  final int total;
  final VoidCallback onDownload;
  final VoidCallback onDelete;

  const _ReciterTile({
    required this.reciter,
    required this.primaryColor,
    required this.palette,
    required this.isDownloading,
    required this.done,
    required this.total,
    required this.onDownload,
    required this.onDelete,
  });

  @override
  State<_ReciterTile> createState() => _ReciterTileState();
}

class _ReciterTileState extends State<_ReciterTile> {
  bool _downloaded = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  @override
  void didUpdateWidget(_ReciterTile old) {
    super.didUpdateWidget(old);
    if (!widget.isDownloading && old.isDownloading) _check();
  }

  Future<void> _check() async {
    final ok = await QuranService.isDownloaded(1, 1, widget.reciter.key);
    if (mounted) setState(() => _downloaded = ok);
  }

  @override
  Widget build(BuildContext context) {
    final progress = widget.total > 0 ? widget.done / widget.total : 0.0;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: widget.palette.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: widget.primaryColor.withOpacity(0.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Icon(Icons.record_voice_over_rounded,
              color: widget.primaryColor, size: 20),
          const SizedBox(width: 10),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(widget.reciter.nameKurdish,
                    style: TextStyle(
                        color: widget.palette.listText,
                        fontSize: 13,
                        fontWeight: FontWeight.bold)),
                Text(widget.reciter.nameArabic,
                    style: TextStyle(
                        color: widget.palette.listText.withOpacity(0.5),
                        fontSize: 11)),
              ])),
          if (widget.isDownloading)
            SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: widget.primaryColor))
          else if (_downloaded)
            Row(children: [
              Icon(Icons.check_circle_rounded,
                  color: Colors.green.shade400, size: 18),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () async {
                  widget.onDelete();
                  await Future.delayed(const Duration(milliseconds: 400));
                  _check();
                },
                child: Icon(Icons.delete_outline_rounded,
                    color: Colors.red.shade300, size: 20),
              ),
            ])
          else
            GestureDetector(
              onTap: widget.onDownload,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: widget.primaryColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border:
                      Border.all(color: widget.primaryColor.withOpacity(0.4)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.download_rounded,
                      color: widget.primaryColor, size: 14),
                  const SizedBox(width: 4),
                  Text("داگرە",
                      style:
                          TextStyle(color: widget.primaryColor, fontSize: 12)),
                ]),
              ),
            ),
        ]),
        if (widget.isDownloading) ...[
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4,
              backgroundColor: widget.palette.listText.withOpacity(0.1),
              valueColor: AlwaysStoppedAnimation<Color>(widget.primaryColor),
            ),
          ),
          const SizedBox(height: 4),
          Text('${widget.done} / ${widget.total} ئایەت',
              style: TextStyle(
                  color: widget.palette.listText.withOpacity(0.5),
                  fontSize: 10),
              textAlign: TextAlign.center),
        ],
      ]),
    );
  }
}

// ==================== تایڵی سووره ====================

class _SurahListTile extends StatelessWidget {
  final QuranSurah surah;
  final Color primaryColor;
  final ThemePalette palette;
  final VoidCallback onTap;

  const _SurahListTile({
    required this.surah,
    required this.primaryColor,
    required this.palette,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: palette.cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.07)),
        ),
        child: Row(children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: primaryColor.withOpacity(0.15),
              border: Border.all(color: primaryColor.withOpacity(0.4)),
            ),
            alignment: Alignment.center,
            child: Text('${surah.number}',
                style: TextStyle(
                    color: primaryColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(surah.nameKurdish,
                    style: TextStyle(
                        color: palette.listText,
                        fontSize: 13,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(
                  '${surah.ayahCount} ئایەت · ${surah.isMakki ? "مەکی" : "مەدەنی"} · جوزئی ${surah.juzStart}',
                  style: TextStyle(
                      color: palette.listText.withOpacity(0.5), fontSize: 10),
                ),
              ])),
          Text(surah.nameArabic,
              style: TextStyle(
                  color: primaryColor,
                  fontSize: 16,
                  fontFamily: 'Uthmanic',
                  fontWeight: FontWeight.bold)),
        ]),
      ),
    );
  }
}

// ==================== سکرینی خوێندنەوە ====================

class QuranReadScreen extends StatefulWidget {
  final QuranSurah surah;
  final Color primaryColor;
  final ThemePalette palette;

  const QuranReadScreen({
    super.key,
    required this.surah,
    required this.primaryColor,
    required this.palette,
  });

  @override
  State<QuranReadScreen> createState() => _QuranReadScreenState();
}

class _QuranReadScreenState extends State<QuranReadScreen> {
  List<Map<String, dynamic>> _ayahs = [];
  List<List<Map<String, dynamic>>> _pages = [];
  bool _loading = true;
  String _error = '';

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  int _currentAyahIdx = -1;
  int _selectedReciterIdx = 0;

  final PageController _pageCtrl = PageController();
  int _currentPage = 0;

  // ژمارەی لاپەرەی مصحف بۆ نیشاندان
  int _currentMushafPage = 0;

  @override
  void initState() {
    super.initState();
    _loadSurah();
    _loadReciter();
    _audioPlayer.onPlayerComplete.listen((_) {
      if (!mounted || !_isPlaying) return;
      _playNext();
    });
  }

  @override
  void dispose() {
    _audioPlayer.stop();
    _audioPlayer.dispose();
    _pageCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadReciter() async {
    final prefs = await SharedPreferences.getInstance();
    final idx = prefs.getInt('quran_reciter_idx') ?? 0;
    if (mounted) {
      setState(
          () => _selectedReciterIdx = idx.clamp(0, quranReciters.length - 1));
    }
  }

  Future<void> _loadSurah() async {
    try {
      final ayahs = await QuranService.loadSurah(widget.surah.number);
      final pages = QuranService.splitIntoPages(ayahs);
      if (mounted) {
        setState(() {
          _ayahs = ayahs;
          _pages = pages;
          _loading = false;
          if (pages.isNotEmpty && pages[0].isNotEmpty) {
            _currentMushafPage = pages[0][0]['page'] as int;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'هەڵە لە بارکردن: $e';
          _loading = false;
        });
      }
    }
  }

  int _globalIdx(int pageIdx, int localIdx) {
    int c = 0;
    for (int p = 0; p < pageIdx; p++) {
      c += _pages[p].length;
    }
    return c + localIdx;
  }

  int _pageOfGlobalIdx(int globalIdx) {
    int c = 0;
    for (int p = 0; p < _pages.length; p++) {
      if (globalIdx < c + _pages[p].length) return p;
      c += _pages[p].length;
    }
    return _pages.length - 1;
  }

  Future<void> _playAyah(int globalIdx) async {
    if (globalIdx < 0 || globalIdx >= _ayahs.length) return;
    setState(() => _currentAyahIdx = globalIdx);

    final pageIdx = _pageOfGlobalIdx(globalIdx);
    if (_currentPage != pageIdx) {
      _currentPage = pageIdx;
      _pageCtrl.animateToPage(pageIdx,
          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }

    await _audioPlayer.stop();
    final ayahNum = _ayahs[globalIdx]['a'] as int;
    final key = quranReciters[_selectedReciterIdx].key;
    final src =
        await QuranService.getAudioSource(widget.surah.number, ayahNum, key);

    if (src.startsWith('/')) {
      await _audioPlayer.play(DeviceFileSource(src));
    } else {
      await _audioPlayer.play(UrlSource(src));
    }
  }

  void _playNext() {
    if (_currentAyahIdx < _ayahs.length - 1) {
      _playAyah(_currentAyahIdx + 1);
    } else {
      setState(() {
        _isPlaying = false;
        _currentAyahIdx = -1;
      });
    }
  }

  Future<void> _togglePlay() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
      setState(() => _isPlaying = false);
    } else {
      setState(() => _isPlaying = true);
      await _playAyah(_currentAyahIdx < 0 ? 0 : _currentAyahIdx);
    }
  }

  Future<void> _stopPlay() async {
    await _audioPlayer.stop();
    setState(() {
      _isPlaying = false;
      _currentAyahIdx = -1;
    });
  }

  // ── بنای لاپەرە — تەکستی مصحف بەشێوەی فلۆی بەردەوام ──
  Widget _buildPage(int pageIdx) {
    final pageAyahs = _pages[pageIdx];
    if (pageAyahs.isEmpty) return const SizedBox();

    // ژمارەی لاپەرەی مصحف
    final mushafPage = pageAyahs[0]['page'] as int;
    // ژمارەی جوزئ
    final juzNum = pageAyahs[0]['juz'] as int;

    final List<InlineSpan> spans = [];

    for (int li = 0; li < pageAyahs.length; li++) {
      final int gi = _globalIdx(pageIdx, li);
      final ayah = pageAyahs[li];
      final int ayahNum = ayah['a'] as int;
      final String text = ayah['t'] as String;
      final bool isActive = _currentAyahIdx == gi;
      final bool isSajda = ayah['sajda'] == true;

      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: GestureDetector(
            onTap: () async {
              setState(() => _isPlaying = true);
              await _playAyah(gi);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 1, vertical: 1),
              padding: isActive
                  ? const EdgeInsets.symmetric(horizontal: 4, vertical: 2)
                  : EdgeInsets.zero,
              decoration: isActive
                  ? BoxDecoration(
                      color: widget.primaryColor.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: widget.primaryColor.withOpacity(0.5),
                        width: 1,
                      ),
                    )
                  : null,
              child: RichText(
                textDirection: TextDirection.rtl,
                text: TextSpan(children: [
                  TextSpan(
                    text: text,
                    style: TextStyle(
                      fontSize: 22,
                      fontFamily: 'Uthmanic',
                      color: isActive ? widget.primaryColor : Colors.white,
                      fontWeight:
                          isActive ? FontWeight.w600 : FontWeight.normal,
                      height: 2.5,
                    ),
                  ),
                  // ژمارەی ئایەت
                  TextSpan(
                    text: ' \u06dd$ayahNum\u06dd ',
                    style: TextStyle(
                      fontSize: 16,
                      fontFamily: 'Uthmanic',
                      color:
                          widget.primaryColor.withOpacity(isActive ? 1.0 : 0.7),
                      height: 2.5,
                    ),
                  ),
                  // نیشانەی سەجدە
                  if (isSajda)
                    TextSpan(
                      text: ' ۩ ',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.amber.withOpacity(0.8),
                        height: 2.5,
                      ),
                    ),
                ]),
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        // سەری لاپەرە — جوزء و ناوی سوورە
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          color: widget.palette.cardBg,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'جوزئی $juzNum',
                style: TextStyle(
                  color: widget.primaryColor,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                widget.surah.nameArabic,
                style: TextStyle(
                  color: widget.primaryColor,
                  fontSize: 13,
                  fontFamily: 'Uthmanic',
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        // ناوەرۆکی لاپەرە
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Text.rich(
              TextSpan(children: spans),
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.justify,
            ),
          ),
        ),
        // ژمارەی لاپەرەی مصحف
        Container(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(
            '— $mushafPage —',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: widget.palette.listText.withOpacity(0.4),
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: widget.palette.background,
        appBar: AppBar(
          backgroundColor: widget.palette.background,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded,
                color: widget.palette.secondary),
            onPressed: () => Navigator.pop(context),
          ),
          title:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              widget.surah.nameArabic,
              style: TextStyle(
                color: widget.palette.secondary,
                fontSize: 16,
                fontFamily: 'Uthmanic',
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              widget.surah.nameKurdish,
              style: TextStyle(
                color: widget.palette.listText.withOpacity(0.6),
                fontSize: 11,
              ),
            ),
          ]),
          actions: [
            // هەڵبژاردنی قاریئ
            PopupMenuButton<int>(
              icon: Icon(Icons.person_outline_rounded,
                  color: widget.palette.secondary),
              color: widget.palette.cardBg,
              onSelected: (i) async {
                await _audioPlayer.stop();
                setState(() {
                  _selectedReciterIdx = i;
                  _isPlaying = false;
                });
                final prefs = await SharedPreferences.getInstance();
                await prefs.setInt('quran_reciter_idx', i);
              },
              itemBuilder: (_) => List.generate(
                quranReciters.length,
                (i) => PopupMenuItem(
                  value: i,
                  child: Row(children: [
                    if (i == _selectedReciterIdx)
                      Icon(Icons.check, color: widget.primaryColor, size: 16)
                    else
                      const SizedBox(width: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        quranReciters[i].nameKurdish,
                        style: TextStyle(
                            color: widget.palette.listText, fontSize: 12),
                      ),
                    ),
                  ]),
                ),
              ),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(height: 1, color: Colors.white24),
          ),
        ),
        body: _loading
            ? Center(
                child: CircularProgressIndicator(color: widget.primaryColor))
            : _error.isNotEmpty
                ? Center(
                    child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_error,
                          style: const TextStyle(color: Colors.white70),
                          textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _loading = true;
                            _error = '';
                          });
                          _loadSurah();
                        },
                        child: const Text("دووبارە هەوڵ بدەرەوە"),
                      ),
                    ],
                  ))
                : Column(children: [
                    // ── لاپەرەکان ──
                    Expanded(
                      child: PageView.builder(
                        controller: _pageCtrl,
                        reverse: true,
                        itemCount: _pages.length,
                        onPageChanged: (p) {
                          setState(() {
                            _currentPage = p;
                            if (_pages[p].isNotEmpty) {
                              _currentMushafPage = _pages[p][0]['page'] as int;
                            }
                          });
                        },
                        itemBuilder: (_, pageIdx) => _buildPage(pageIdx),
                      ),
                    ),

                    // ── پلەیەر ──
                    _buildPlayer(),
                  ]),
      ),
    );
  }

  Widget _buildPlayer() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: widget.palette.cardBg,
          border: Border(
              top: BorderSide(color: widget.primaryColor.withOpacity(0.2))),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // ناوی قاریئ + ژمارەی لاپەرە
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    quranReciters[_selectedReciterIdx].nameKurdish,
                    style: TextStyle(
                      color: widget.palette.listText.withOpacity(0.7),
                      fontSize: 10,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'لاپەرەی $_currentMushafPage',
                    style: TextStyle(
                      color: widget.primaryColor.withOpacity(0.8),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),

            // دوگمەکان
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _btn(Icons.stop_rounded, _stopPlay, 20),
                const SizedBox(width: 8),
                _btn(Icons.skip_previous_rounded, () {
                  if (_currentAyahIdx > 0) {
                    _playAyah(_currentAyahIdx - 1);
                  }
                }, 24),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _togglePlay,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.primaryColor.withOpacity(0.2),
                      border: Border.all(
                          color: widget.primaryColor.withOpacity(0.6),
                          width: 1.5),
                    ),
                    child: Icon(
                      _isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: widget.primaryColor,
                      size: 28,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _btn(Icons.skip_next_rounded, () {
                  if (_currentAyahIdx < _ayahs.length - 1) {
                    _playAyah(_currentAyahIdx + 1);
                  }
                }, 24),
              ],
            ),

            // ئایەتی ئێستا
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_currentAyahIdx >= 0)
                    Text(
                      'ئایەتی ${_ayahs[_currentAyahIdx]['a']}',
                      style: TextStyle(
                        color: widget.primaryColor.withOpacity(0.8),
                        fontSize: 10,
                      ),
                    ),
                  Text(
                    '${_currentPage + 1} / ${_pages.length}',
                    style: TextStyle(
                      color: widget.palette.listText.withOpacity(0.4),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _btn(IconData icon, VoidCallback onTap, double size) {
    return GestureDetector(
      onTap: onTap,
      child: Icon(icon, color: widget.palette.secondary, size: size),
    );
  }
}
