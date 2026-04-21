import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import '../utils/constants.dart';

// ==================== مۆدێل ====================

class QuranSurah {
  final int number;
  final String nameArabic;
  final String nameKurdish;
  final int ayahCount;
  final bool isMakki;

  const QuranSurah({
    required this.number,
    required this.nameArabic,
    required this.nameKurdish,
    required this.ayahCount,
    required this.isMakki,
  });
}

// ==================== سکرینی لیستی سووره ====================

class QuranScreen extends StatelessWidget {
  final Color primaryColor;
  final ThemePalette palette;

  const QuranScreen({
    super.key,
    required this.primaryColor,
    required this.palette,
  });

  static const List<QuranSurah> surahs = [
    QuranSurah(
        number: 1,
        nameArabic: "الفاتحة",
        nameKurdish: "فاتیحە",
        ayahCount: 7,
        isMakki: true),
    QuranSurah(
        number: 2,
        nameArabic: "البقرة",
        nameKurdish: "بەقەرە",
        ayahCount: 286,
        isMakki: false),
    QuranSurah(
        number: 3,
        nameArabic: "آل عمران",
        nameKurdish: "ئالی عیمران",
        ayahCount: 200,
        isMakki: false),
    QuranSurah(
        number: 4,
        nameArabic: "النساء",
        nameKurdish: "نیساء",
        ayahCount: 176,
        isMakki: false),
    QuranSurah(
        number: 5,
        nameArabic: "المائدة",
        nameKurdish: "مائیدە",
        ayahCount: 120,
        isMakki: false),
    QuranSurah(
        number: 6,
        nameArabic: "الأنعام",
        nameKurdish: "ئەنعام",
        ayahCount: 165,
        isMakki: true),
    QuranSurah(
        number: 7,
        nameArabic: "الأعراف",
        nameKurdish: "ئەعراف",
        ayahCount: 206,
        isMakki: true),
    QuranSurah(
        number: 8,
        nameArabic: "الأنفال",
        nameKurdish: "ئەنفال",
        ayahCount: 75,
        isMakki: false),
    QuranSurah(
        number: 9,
        nameArabic: "التوبة",
        nameKurdish: "تەوبە",
        ayahCount: 129,
        isMakki: false),
    QuranSurah(
        number: 10,
        nameArabic: "يونس",
        nameKurdish: "یونس",
        ayahCount: 109,
        isMakki: true),
    QuranSurah(
        number: 11,
        nameArabic: "هود",
        nameKurdish: "هوود",
        ayahCount: 123,
        isMakki: true),
    QuranSurah(
        number: 12,
        nameArabic: "يوسف",
        nameKurdish: "یوسف",
        ayahCount: 111,
        isMakki: true),
    QuranSurah(
        number: 13,
        nameArabic: "الرعد",
        nameKurdish: "ڕەعد",
        ayahCount: 43,
        isMakki: false),
    QuranSurah(
        number: 14,
        nameArabic: "إبراهيم",
        nameKurdish: "ئیبراهیم",
        ayahCount: 52,
        isMakki: true),
    QuranSurah(
        number: 15,
        nameArabic: "الحجر",
        nameKurdish: "حیجر",
        ayahCount: 99,
        isMakki: true),
    QuranSurah(
        number: 16,
        nameArabic: "النحل",
        nameKurdish: "نەحل",
        ayahCount: 128,
        isMakki: true),
    QuranSurah(
        number: 17,
        nameArabic: "الإسراء",
        nameKurdish: "ئیسراء",
        ayahCount: 111,
        isMakki: true),
    QuranSurah(
        number: 18,
        nameArabic: "الكهف",
        nameKurdish: "کەهف",
        ayahCount: 110,
        isMakki: true),
    QuranSurah(
        number: 19,
        nameArabic: "مريم",
        nameKurdish: "مەریەم",
        ayahCount: 98,
        isMakki: true),
    QuranSurah(
        number: 20,
        nameArabic: "طه",
        nameKurdish: "تاها",
        ayahCount: 135,
        isMakki: true),
    QuranSurah(
        number: 21,
        nameArabic: "الأنبياء",
        nameKurdish: "ئەنبیاء",
        ayahCount: 112,
        isMakki: true),
    QuranSurah(
        number: 22,
        nameArabic: "الحج",
        nameKurdish: "حەج",
        ayahCount: 78,
        isMakki: false),
    QuranSurah(
        number: 23,
        nameArabic: "المؤمنون",
        nameKurdish: "مۆمینون",
        ayahCount: 118,
        isMakki: true),
    QuranSurah(
        number: 24,
        nameArabic: "النور",
        nameKurdish: "نوور",
        ayahCount: 64,
        isMakki: false),
    QuranSurah(
        number: 25,
        nameArabic: "الفرقان",
        nameKurdish: "فورقان",
        ayahCount: 77,
        isMakki: true),
    QuranSurah(
        number: 26,
        nameArabic: "الشعراء",
        nameKurdish: "شوعەراء",
        ayahCount: 227,
        isMakki: true),
    QuranSurah(
        number: 27,
        nameArabic: "النمل",
        nameKurdish: "نەمل",
        ayahCount: 93,
        isMakki: true),
    QuranSurah(
        number: 28,
        nameArabic: "القصص",
        nameKurdish: "قەسەس",
        ayahCount: 88,
        isMakki: true),
    QuranSurah(
        number: 29,
        nameArabic: "العنكبوت",
        nameKurdish: "عەنکەبووت",
        ayahCount: 69,
        isMakki: true),
    QuranSurah(
        number: 30,
        nameArabic: "الروم",
        nameKurdish: "ڕووم",
        ayahCount: 60,
        isMakki: true),
    QuranSurah(
        number: 31,
        nameArabic: "لقمان",
        nameKurdish: "لوقمان",
        ayahCount: 34,
        isMakki: true),
    QuranSurah(
        number: 32,
        nameArabic: "السجدة",
        nameKurdish: "سەجدە",
        ayahCount: 30,
        isMakki: true),
    QuranSurah(
        number: 33,
        nameArabic: "الأحزاب",
        nameKurdish: "ئەحزاب",
        ayahCount: 73,
        isMakki: false),
    QuranSurah(
        number: 34,
        nameArabic: "سبأ",
        nameKurdish: "سەبأ",
        ayahCount: 54,
        isMakki: true),
    QuranSurah(
        number: 35,
        nameArabic: "فاطر",
        nameKurdish: "فاتیر",
        ayahCount: 45,
        isMakki: true),
    QuranSurah(
        number: 36,
        nameArabic: "يس",
        nameKurdish: "یاسین",
        ayahCount: 83,
        isMakki: true),
    QuranSurah(
        number: 37,
        nameArabic: "الصافات",
        nameKurdish: "سافات",
        ayahCount: 182,
        isMakki: true),
    QuranSurah(
        number: 38,
        nameArabic: "ص",
        nameKurdish: "ساد",
        ayahCount: 88,
        isMakki: true),
    QuranSurah(
        number: 39,
        nameArabic: "الزمر",
        nameKurdish: "زومەر",
        ayahCount: 75,
        isMakki: true),
    QuranSurah(
        number: 40,
        nameArabic: "غافر",
        nameKurdish: "غافیر",
        ayahCount: 85,
        isMakki: true),
    QuranSurah(
        number: 41,
        nameArabic: "فصلت",
        nameKurdish: "فوسیلەت",
        ayahCount: 54,
        isMakki: true),
    QuranSurah(
        number: 42,
        nameArabic: "الشورى",
        nameKurdish: "شووری",
        ayahCount: 53,
        isMakki: true),
    QuranSurah(
        number: 43,
        nameArabic: "الزخرف",
        nameKurdish: "زوخروف",
        ayahCount: 89,
        isMakki: true),
    QuranSurah(
        number: 44,
        nameArabic: "الدخان",
        nameKurdish: "دوخان",
        ayahCount: 59,
        isMakki: true),
    QuranSurah(
        number: 45,
        nameArabic: "الجاثية",
        nameKurdish: "جاسیە",
        ayahCount: 37,
        isMakki: true),
    QuranSurah(
        number: 46,
        nameArabic: "الأحقاف",
        nameKurdish: "ئەحقاف",
        ayahCount: 35,
        isMakki: true),
    QuranSurah(
        number: 47,
        nameArabic: "محمد",
        nameKurdish: "محەممەد",
        ayahCount: 38,
        isMakki: false),
    QuranSurah(
        number: 48,
        nameArabic: "الفتح",
        nameKurdish: "فەتح",
        ayahCount: 29,
        isMakki: false),
    QuranSurah(
        number: 49,
        nameArabic: "الحجرات",
        nameKurdish: "حوجورات",
        ayahCount: 18,
        isMakki: false),
    QuranSurah(
        number: 50,
        nameArabic: "ق",
        nameKurdish: "قاف",
        ayahCount: 45,
        isMakki: true),
    QuranSurah(
        number: 51,
        nameArabic: "الذاريات",
        nameKurdish: "زاریات",
        ayahCount: 60,
        isMakki: true),
    QuranSurah(
        number: 52,
        nameArabic: "الطور",
        nameKurdish: "تور",
        ayahCount: 49,
        isMakki: true),
    QuranSurah(
        number: 53,
        nameArabic: "النجم",
        nameKurdish: "نەجم",
        ayahCount: 62,
        isMakki: true),
    QuranSurah(
        number: 54,
        nameArabic: "القمر",
        nameKurdish: "قەمەر",
        ayahCount: 55,
        isMakki: true),
    QuranSurah(
        number: 55,
        nameArabic: "الرحمن",
        nameKurdish: "ڕەحمان",
        ayahCount: 78,
        isMakki: false),
    QuranSurah(
        number: 56,
        nameArabic: "الواقعة",
        nameKurdish: "واقیعە",
        ayahCount: 96,
        isMakki: true),
    QuranSurah(
        number: 57,
        nameArabic: "الحديد",
        nameKurdish: "حەدید",
        ayahCount: 29,
        isMakki: false),
    QuranSurah(
        number: 58,
        nameArabic: "المجادلة",
        nameKurdish: "موجادیلە",
        ayahCount: 22,
        isMakki: false),
    QuranSurah(
        number: 59,
        nameArabic: "الحشر",
        nameKurdish: "حەشر",
        ayahCount: 24,
        isMakki: false),
    QuranSurah(
        number: 60,
        nameArabic: "الممتحنة",
        nameKurdish: "مومتەحینە",
        ayahCount: 13,
        isMakki: false),
    QuranSurah(
        number: 61,
        nameArabic: "الصف",
        nameKurdish: "سەف",
        ayahCount: 14,
        isMakki: false),
    QuranSurah(
        number: 62,
        nameArabic: "الجمعة",
        nameKurdish: "جومعە",
        ayahCount: 11,
        isMakki: false),
    QuranSurah(
        number: 63,
        nameArabic: "المنافقون",
        nameKurdish: "موناافیقون",
        ayahCount: 11,
        isMakki: false),
    QuranSurah(
        number: 64,
        nameArabic: "التغابن",
        nameKurdish: "تەغابون",
        ayahCount: 18,
        isMakki: false),
    QuranSurah(
        number: 65,
        nameArabic: "الطلاق",
        nameKurdish: "تەلاق",
        ayahCount: 12,
        isMakki: false),
    QuranSurah(
        number: 66,
        nameArabic: "التحريم",
        nameKurdish: "تەحریم",
        ayahCount: 12,
        isMakki: false),
    QuranSurah(
        number: 67,
        nameArabic: "الملك",
        nameKurdish: "مولک",
        ayahCount: 30,
        isMakki: true),
    QuranSurah(
        number: 68,
        nameArabic: "القلم",
        nameKurdish: "قەلەم",
        ayahCount: 52,
        isMakki: true),
    QuranSurah(
        number: 69,
        nameArabic: "الحاقة",
        nameKurdish: "حاقە",
        ayahCount: 52,
        isMakki: true),
    QuranSurah(
        number: 70,
        nameArabic: "المعارج",
        nameKurdish: "مەعاریج",
        ayahCount: 44,
        isMakki: true),
    QuranSurah(
        number: 71,
        nameArabic: "نوح",
        nameKurdish: "نووح",
        ayahCount: 28,
        isMakki: true),
    QuranSurah(
        number: 72,
        nameArabic: "الجن",
        nameKurdish: "جین",
        ayahCount: 28,
        isMakki: true),
    QuranSurah(
        number: 73,
        nameArabic: "المزمل",
        nameKurdish: "موزەممیل",
        ayahCount: 20,
        isMakki: true),
    QuranSurah(
        number: 74,
        nameArabic: "المدثر",
        nameKurdish: "موددەسیر",
        ayahCount: 56,
        isMakki: true),
    QuranSurah(
        number: 75,
        nameArabic: "القيامة",
        nameKurdish: "قیامەت",
        ayahCount: 40,
        isMakki: true),
    QuranSurah(
        number: 76,
        nameArabic: "الإنسان",
        nameKurdish: "ئینسان",
        ayahCount: 31,
        isMakki: false),
    QuranSurah(
        number: 77,
        nameArabic: "المرسلات",
        nameKurdish: "مورسەلات",
        ayahCount: 50,
        isMakki: true),
    QuranSurah(
        number: 78,
        nameArabic: "النبأ",
        nameKurdish: "نەبأ",
        ayahCount: 40,
        isMakki: true),
    QuranSurah(
        number: 79,
        nameArabic: "النازعات",
        nameKurdish: "نازیعات",
        ayahCount: 46,
        isMakki: true),
    QuranSurah(
        number: 80,
        nameArabic: "عبس",
        nameKurdish: "عەبەسە",
        ayahCount: 42,
        isMakki: true),
    QuranSurah(
        number: 81,
        nameArabic: "التكوير",
        nameKurdish: "تەکویر",
        ayahCount: 29,
        isMakki: true),
    QuranSurah(
        number: 82,
        nameArabic: "الانفطار",
        nameKurdish: "ئینفیتار",
        ayahCount: 19,
        isMakki: true),
    QuranSurah(
        number: 83,
        nameArabic: "المطففين",
        nameKurdish: "موتەففیفین",
        ayahCount: 36,
        isMakki: true),
    QuranSurah(
        number: 84,
        nameArabic: "الانشقاق",
        nameKurdish: "ئینشیقاق",
        ayahCount: 25,
        isMakki: true),
    QuranSurah(
        number: 85,
        nameArabic: "البروج",
        nameKurdish: "بوروج",
        ayahCount: 22,
        isMakki: true),
    QuranSurah(
        number: 86,
        nameArabic: "الطارق",
        nameKurdish: "تاریق",
        ayahCount: 17,
        isMakki: true),
    QuranSurah(
        number: 87,
        nameArabic: "الأعلى",
        nameKurdish: "ئەعلا",
        ayahCount: 19,
        isMakki: true),
    QuranSurah(
        number: 88,
        nameArabic: "الغاشية",
        nameKurdish: "غاشیە",
        ayahCount: 26,
        isMakki: true),
    QuranSurah(
        number: 89,
        nameArabic: "الفجر",
        nameKurdish: "فەجر",
        ayahCount: 30,
        isMakki: true),
    QuranSurah(
        number: 90,
        nameArabic: "البلد",
        nameKurdish: "بەلەد",
        ayahCount: 20,
        isMakki: true),
    QuranSurah(
        number: 91,
        nameArabic: "الشمس",
        nameKurdish: "شەمس",
        ayahCount: 15,
        isMakki: true),
    QuranSurah(
        number: 92,
        nameArabic: "الليل",
        nameKurdish: "لەیل",
        ayahCount: 21,
        isMakki: true),
    QuranSurah(
        number: 93,
        nameArabic: "الضحى",
        nameKurdish: "ضوحا",
        ayahCount: 11,
        isMakki: true),
    QuranSurah(
        number: 94,
        nameArabic: "الشرح",
        nameKurdish: "شەرح",
        ayahCount: 8,
        isMakki: true),
    QuranSurah(
        number: 95,
        nameArabic: "التين",
        nameKurdish: "تین",
        ayahCount: 8,
        isMakki: true),
    QuranSurah(
        number: 96,
        nameArabic: "العلق",
        nameKurdish: "عەلەق",
        ayahCount: 19,
        isMakki: true),
    QuranSurah(
        number: 97,
        nameArabic: "القدر",
        nameKurdish: "قەدر",
        ayahCount: 5,
        isMakki: true),
    QuranSurah(
        number: 98,
        nameArabic: "البينة",
        nameKurdish: "بەییینە",
        ayahCount: 8,
        isMakki: false),
    QuranSurah(
        number: 99,
        nameArabic: "الزلزلة",
        nameKurdish: "زەلزەلە",
        ayahCount: 8,
        isMakki: false),
    QuranSurah(
        number: 100,
        nameArabic: "العاديات",
        nameKurdish: "عادیات",
        ayahCount: 11,
        isMakki: true),
    QuranSurah(
        number: 101,
        nameArabic: "القارعة",
        nameKurdish: "قارعە",
        ayahCount: 11,
        isMakki: true),
    QuranSurah(
        number: 102,
        nameArabic: "التكاثر",
        nameKurdish: "تەکاسور",
        ayahCount: 8,
        isMakki: true),
    QuranSurah(
        number: 103,
        nameArabic: "العصر",
        nameKurdish: "عەسر",
        ayahCount: 3,
        isMakki: true),
    QuranSurah(
        number: 104,
        nameArabic: "الهمزة",
        nameKurdish: "هومەزە",
        ayahCount: 9,
        isMakki: true),
    QuranSurah(
        number: 105,
        nameArabic: "الفيل",
        nameKurdish: "فیل",
        ayahCount: 5,
        isMakki: true),
    QuranSurah(
        number: 106,
        nameArabic: "قريش",
        nameKurdish: "قورەیش",
        ayahCount: 4,
        isMakki: true),
    QuranSurah(
        number: 107,
        nameArabic: "الماعون",
        nameKurdish: "ماعون",
        ayahCount: 7,
        isMakki: true),
    QuranSurah(
        number: 108,
        nameArabic: "الكوثر",
        nameKurdish: "کەوسەر",
        ayahCount: 3,
        isMakki: true),
    QuranSurah(
        number: 109,
        nameArabic: "الكافرون",
        nameKurdish: "کافیرون",
        ayahCount: 6,
        isMakki: true),
    QuranSurah(
        number: 110,
        nameArabic: "النصر",
        nameKurdish: "نەسر",
        ayahCount: 3,
        isMakki: false),
    QuranSurah(
        number: 111,
        nameArabic: "المسد",
        nameKurdish: "مەسەد",
        ayahCount: 5,
        isMakki: true),
    QuranSurah(
        number: 112,
        nameArabic: "الإخلاص",
        nameKurdish: "ئیخلاس",
        ayahCount: 4,
        isMakki: true),
    QuranSurah(
        number: 113,
        nameArabic: "الفلق",
        nameKurdish: "فەلەق",
        ayahCount: 5,
        isMakki: true),
    QuranSurah(
        number: 114,
        nameArabic: "الناس",
        nameKurdish: "ناس",
        ayahCount: 6,
        isMakki: true),
  ];

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: palette.background,
        appBar: AppBar(
          backgroundColor: palette.background,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded,
                color: palette.secondary),
            onPressed: () => Navigator.pop(context),
          ),
          title: Row(children: [
            Icon(Icons.menu_book_rounded, color: palette.secondary, size: 26),
            const SizedBox(width: 10),
            Text("قورئانی پیرۆز",
                style: TextStyle(
                    color: palette.secondary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
          ]),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(height: 1, color: Colors.white24),
          ),
        ),
        body: ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: surahs.length,
          itemBuilder: (context, index) {
            final surah = surahs[index];
            return _SurahListTile(
              surah: surah,
              primaryColor: primaryColor,
              palette: palette,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => QuranReadScreen(
                    surah: surah,
                    primaryColor: primaryColor,
                    palette: palette,
                  ),
                ),
              ),
            );
          },
        ),
      ),
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
        child: Row(
          children: [
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
                    '${surah.ayahCount} ئایەت · ${surah.isMakki ? "مەکی" : "مەدەنی"}',
                    style: TextStyle(
                        color: palette.listText.withOpacity(0.5), fontSize: 11),
                  ),
                ],
              ),
            ),
            Text(surah.nameArabic,
                style: TextStyle(
                    color: primaryColor,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
          ],
        ),
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
  // ── داتا ──────────────────────────────────────────
  List<Map<String, dynamic>> _ayahs = [];
  bool _loading = true;
  String _error = '';

  // ── پلەیەر ────────────────────────────────────────
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  int _currentAyahIdx = -1;

  // ── قاریەکان ──────────────────────────────────────
  static const List<Map<String, String>> _reciters = [
    {'name': 'مشاری عفاسی', 'key': 'afs'},
    {'name': 'الحصری', 'key': 'husary'},
    {'name': 'عبدالباسط', 'key': 'Abdul_Basit_Murattal_64kbps'},
    {'name': 'السدیس', 'key': 'Saud_Al-Shuraim_128kbps'},
  ];
  int _selectedReciterIdx = 0;

  // ── سکرۆڵ ─────────────────────────────────────────
  final ScrollController _scrollCtrl = ScrollController();

  // ── GlobalKey بۆ هەر ئایەتێک ──────────────────────
  final Map<int, GlobalKey> _ayahKeys = {};

  @override
  void initState() {
    super.initState();
    _loadSurah();
    _audioPlayer.onPlayerComplete.listen((_) {
      if (!mounted || !_isPlaying) return;
      _playNext();
    });
  }

  @override
  void dispose() {
    _audioPlayer.stop();
    _audioPlayer.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ── بارکردن لە JSON ────────────────────────────────
  Future<void> _loadSurah() async {
    try {
      final String raw = await rootBundle.loadString('assets/quran/quran.json');
      final List<dynamic> all = json.decode(raw);
      final int s = widget.surah.number;

      final filtered = all
          .where((v) => v['s'] == s)
          .map<Map<String, dynamic>>((v) => {
                'a': v['a'] as int,
                't': v['t'] as String,
                'b': v['b'], // بسملە ئەگەر هەبوو
              })
          .toList();

      // دروست کردنی GlobalKey بۆ هەر ئایەتێک
      for (final ay in filtered) {
        _ayahKeys[ay['a'] as int] = GlobalKey();
      }

      if (mounted) {
        setState(() {
          _ayahs = filtered;
          _loading = false;
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

  // ── ئادرێسی MP3 ────────────────────────────────────
  String _audioUrl(int ayahNumber) {
    final key = _reciters[_selectedReciterIdx]['key']!;
    final s = widget.surah.number.toString().padLeft(3, '0');
    final a = ayahNumber.toString().padLeft(3, '0');
    return 'https://server8.mp3quran.net/$key/$s$a.mp3';
  }

  // ── پلەی کردن ─────────────────────────────────────
  Future<void> _playAyah(int index) async {
    if (index < 0 || index >= _ayahs.length) return;
    setState(() => _currentAyahIdx = index);
    _scrollToAyah(index);
    await _audioPlayer.stop();
    await _audioPlayer.play(UrlSource(_audioUrl(_ayahs[index]['a'] as int)));
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
      final start = _currentAyahIdx < 0 ? 0 : _currentAyahIdx;
      await _playAyah(start);
    }
  }

  Future<void> _stopPlay() async {
    await _audioPlayer.stop();
    setState(() {
      _isPlaying = false;
      _currentAyahIdx = -1;
    });
  }

  // ── سکرۆڵ بۆ ئایەتی دەنگدراو ─────────────────────
  void _scrollToAyah(int index) {
    if (index < 0 || index >= _ayahs.length) return;
    final ayahNum = _ayahs[index]['a'] as int;
    final key = _ayahKeys[ayahNum];
    if (key?.currentContext == null) return;
    Scrollable.ensureVisible(
      key!.currentContext!,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
      alignment: 0.3,
    );
  }

  // ── بنای تێکستی بەردەوام ──────────────────────────
  Widget _buildContinuousText() {
    final List<InlineSpan> spans = [];

    // بسملە:
    // سووره ٢ تا ١١٤ (جگە لە ٩): لە فیێڵدی b ی ئایەتی یەکەم دێت
    // سووره ١: بسملە ئایەتی a:1 ی خۆیەتی، پێویستی بە زیادکردنی جیا نییە
    // سووره ٩: بسملەی نییە
    if (_ayahs.isNotEmpty && _ayahs[0]['b'] != null) {
      spans.add(
        TextSpan(
          text: '${_ayahs[0]['b']}\n\n',
          style: TextStyle(
            fontSize: 20,
            color: widget.primaryColor,
            fontWeight: FontWeight.bold,
            height: 2.2,
          ),
        ),
      );
    }

    for (int i = 0; i < _ayahs.length; i++) {
      final ayah = _ayahs[i];
      final int ayahNum = ayah['a'] as int;
      final String text = ayah['t'] as String;
      final bool isActive = _currentAyahIdx == i;

      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: GestureDetector(
            onTap: () async {
              setState(() => _isPlaying = true);
              await _playAyah(i);
            },
            child: Container(
              key: _ayahKeys[ayahNum],
              // پاددینگی کەمێک بۆ ئەوەی هایلایت دیاربێت
              padding: isActive
                  ? const EdgeInsets.symmetric(horizontal: 5, vertical: 3)
                  : const EdgeInsets.symmetric(horizontal: 1, vertical: 1),
              decoration: isActive
                  ? BoxDecoration(
                      color: widget.primaryColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: widget.primaryColor.withOpacity(0.5),
                          width: 1),
                    )
                  : null,
              child: RichText(
                textDirection: TextDirection.rtl,
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: text,
                      style: TextStyle(
                        fontSize: 22,
                        color: isActive ? widget.primaryColor : Colors.white,
                        fontWeight:
                            isActive ? FontWeight.w600 : FontWeight.normal,
                        height: 2.1,
                      ),
                    ),
                    // ژمارەی ئایەت بە عەرەبی
                    TextSpan(
                      text: ' ﴿$ayahNum﴾ ',
                      style: TextStyle(
                        fontSize: 15,
                        color: isActive
                            ? widget.primaryColor
                            : widget.primaryColor.withOpacity(0.65),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
      child: Text.rich(
        TextSpan(children: spans),
        textDirection: TextDirection.rtl,
        textAlign: TextAlign.right,
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
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.surah.nameArabic,
                  style: TextStyle(
                      color: widget.palette.secondary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
              Text(widget.surah.nameKurdish,
                  style: TextStyle(
                      color: widget.palette.listText.withOpacity(0.6),
                      fontSize: 11)),
            ],
          ),
          actions: [
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
              },
              itemBuilder: (_) => List.generate(
                _reciters.length,
                (i) => PopupMenuItem(
                  value: i,
                  child: Row(children: [
                    if (i == _selectedReciterIdx)
                      Icon(Icons.check, color: widget.primaryColor, size: 16)
                    else
                      const SizedBox(width: 16),
                    const SizedBox(width: 8),
                    Text(_reciters[i]['name']!,
                        style: TextStyle(color: widget.palette.listText)),
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

        // ── بادی ──────────────────────────────────────
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
                    ),
                  )
                : Column(
                    children: [
                      // تێکستی بەردەوامی ئایەتەکان
                      Expanded(
                        child: SingleChildScrollView(
                          controller: _scrollCtrl,
                          child: _buildContinuousText(),
                        ),
                      ),

                      // ژمارەی ئایەتی هەڵبژێردراو
                      if (_currentAyahIdx >= 0 &&
                          _currentAyahIdx < _ayahs.length)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 6),
                          color: widget.palette.cardBg,
                          child: Text(
                            'ئایەتی ${_ayahs[_currentAyahIdx]['a']} لە سووره ${widget.surah.nameKurdish}',
                            style: TextStyle(
                                color:
                                    widget.palette.listText.withOpacity(0.55),
                                fontSize: 11),
                            textAlign: TextAlign.right,
                          ),
                        ),

                      // پلەیەر
                      _buildPlayer(),
                    ],
                  ),
      ),
    );
  }

  // ── پلەیەر ────────────────────────────────────────
  Widget _buildPlayer() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: widget.palette.cardBg,
        border: Border(
            top: BorderSide(color: widget.primaryColor.withOpacity(0.2))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _playerBtn(icon: Icons.stop_rounded, onTap: _stopPlay, size: 22),
          _playerBtn(
            icon: Icons.skip_previous_rounded,
            onTap: () {
              if (_currentAyahIdx > 0) _playAyah(_currentAyahIdx - 1);
            },
            size: 26,
          ),
          GestureDetector(
            onTap: _togglePlay,
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.primaryColor.withOpacity(0.2),
                border: Border.all(
                    color: widget.primaryColor.withOpacity(0.6), width: 1.5),
              ),
              child: Icon(
                _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: widget.primaryColor,
                size: 30,
              ),
            ),
          ),
          _playerBtn(
            icon: Icons.skip_next_rounded,
            onTap: () {
              if (_currentAyahIdx < _ayahs.length - 1) {
                _playAyah(_currentAyahIdx + 1);
              }
            },
            size: 26,
          ),
          Text(
            _reciters[_selectedReciterIdx]['name']!,
            style: TextStyle(
                color: widget.palette.listText.withOpacity(0.6), fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _playerBtn(
      {required IconData icon, required VoidCallback onTap, double size = 22}) {
    return GestureDetector(
      onTap: onTap,
      child: Icon(icon, color: widget.palette.secondary, size: size),
    );
  }
}
