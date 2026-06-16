class QuranWord {
  final int id;
  final String location;
  final int surah;
  final int ayah;
  final int wordIndex;
  final String text;

  QuranWord({
    required this.id,
    required this.location,
    required this.surah,
    required this.ayah,
    required this.wordIndex,
    required this.text,
  });

  factory QuranWord.fromMap(Map<String, dynamic> map) {
    return QuranWord(
      id: map['id'] as int,
      location: map['location'] as String,
      surah: map['surah'] as int,
      ayah: map['ayah'] as int,
      wordIndex: map['word'] as int,
      text: map['text'] as String,
    );
  }
}

class QuranPageLine {
  final int pageNumber;
  final int lineNumber;
  final String lineType; // 'ayah', 'surah_name', 'basmallah'
  final bool isCentered;
  final int? firstWordId;
  final int? lastWordId;
  final int? surahNumber;

  QuranPageLine({
    required this.pageNumber,
    required this.lineNumber,
    required this.lineType,
    required this.isCentered,
    this.firstWordId,
    this.lastWordId,
    this.surahNumber,
  });

  factory QuranPageLine.fromMap(Map<String, dynamic> map) {
    int toInt(dynamic v) {
      if (v == null) return 0;
      final s = v.toString().trim();
      if (s.isEmpty || s == 'null') return 0;
      return int.tryParse(s) ?? 0;
    }

    int? toIntOrNull(dynamic v) {
      if (v == null) return null;
      final s = v.toString().trim();
      if (s.isEmpty || s == 'null') return null;
      return int.tryParse(s);
    }

    return QuranPageLine(
      pageNumber: toInt(map['page_number']),
      lineNumber: toInt(map['line_number']),
      lineType: map['line_type'] as String,
      isCentered: toInt(map['is_centered']) == 1,
      firstWordId: toIntOrNull(map['first_word_id']),
      lastWordId: toIntOrNull(map['last_word_id']),
      surahNumber: toIntOrNull(map['surah_number']),
    );
  }
}

class QuranAyahGlyph {
  final int id;
  final String verseKey;
  final int surah;
  final int ayah;
  final String text;
  final int pageNumber;

  QuranAyahGlyph({
    required this.id,
    required this.verseKey,
    required this.surah,
    required this.ayah,
    required this.text,
    required this.pageNumber,
  });

  factory QuranAyahGlyph.fromMap(Map<String, dynamic> map) {
    return QuranAyahGlyph(
      id: map['id'] as int,
      verseKey: map['verse_key'] as String,
      surah: map['surah'] as int,
      ayah: map['ayah'] as int,
      text: map['text'] as String,
      pageNumber: map['page_number'] as int,
    );
  }
}

class SurahInfo {
  final int id;
  final String name;
  final String nameSimple;
  final String nameArabic;
  final int revelationOrder;
  final String revelationPlace;
  final int versesCount;
  final bool bismillahPre;

  SurahInfo({
    required this.id,
    required this.name,
    required this.nameSimple,
    required this.nameArabic,
    required this.revelationOrder,
    required this.revelationPlace,
    required this.versesCount,
    required this.bismillahPre,
  });

  factory SurahInfo.fromMap(Map<String, dynamic> map) {
    return SurahInfo(
      id: map['id'] as int,
      name: map['name'] as String,
      nameSimple: map['name_simple'] as String,
      nameArabic: map['name_arabic'] as String,
      revelationOrder: map['revelation_order'] as int,
      revelationPlace: map['revelation_place'] as String,
      versesCount: map['verses_count'] as int,
      bismillahPre: (map['bismillah_pre'] as int) == 1,
    );
  }

  bool get isMakki => revelationPlace == 'makkah';
}

class JuzInfo {
  final int juzNumber;
  final int versesCount;
  final String firstVerseKey;
  final String lastVerseKey;
  final Map<String, String> verseMapping;

  JuzInfo({
    required this.juzNumber,
    required this.versesCount,
    required this.firstVerseKey,
    required this.lastVerseKey,
    required this.verseMapping,
  });

  factory JuzInfo.fromMap(Map<String, dynamic> map) {
    Map<String, String> mapping = {};
    try {
      final raw = map['verse_mapping'] as String;
      final decoded =
          raw.replaceAll('{', '').replaceAll('}', '').replaceAll('"', '');
      for (final part in decoded.split(',')) {
        final kv = part.split(':');
        if (kv.length == 2) mapping[kv[0].trim()] = kv[1].trim();
      }
    } catch (_) {}
    return JuzInfo(
      juzNumber: map['juz_number'] as int,
      versesCount: map['verses_count'] as int,
      firstVerseKey: map['first_verse_key'] as String,
      lastVerseKey: map['last_verse_key'] as String,
      verseMapping: mapping,
    );
  }
}

class HizbInfo {
  final int hizbNumber;
  final int versesCount;
  final String firstVerseKey;
  final String lastVerseKey;

  HizbInfo({
    required this.hizbNumber,
    required this.versesCount,
    required this.firstVerseKey,
    required this.lastVerseKey,
  });

  factory HizbInfo.fromMap(Map<String, dynamic> map) {
    return HizbInfo(
      hizbNumber: map['hizb_number'] as int,
      versesCount: map['verses_count'] as int,
      firstVerseKey: map['first_verse_key'] as String,
      lastVerseKey: map['last_verse_key'] as String,
    );
  }
}

class AyahSegment {
  final int wordIndex;
  final int startMs;
  final int endMs;

  AyahSegment({
    required this.wordIndex,
    required this.startMs,
    required this.endMs,
  });

  factory AyahSegment.fromList(List<dynamic> list) {
    return AyahSegment(
      wordIndex: list[0] as int,
      startMs: list[1] as int,
      endMs: list[2] as int,
    );
  }
}

class AyahRecitation {
  final int surahNumber;
  final int ayahNumber;
  final String audioUrl;
  final int? duration;
  final List<AyahSegment> segments;

  AyahRecitation({
    required this.surahNumber,
    required this.ayahNumber,
    required this.audioUrl,
    this.duration,
    required this.segments,
  });

  factory AyahRecitation.fromMap(Map<String, dynamic> map) {
    final segList = (map['segments'] as List<dynamic>)
        .map((s) => AyahSegment.fromList(s as List<dynamic>))
        .toList();
    return AyahRecitation(
      surahNumber: map['surah_number'] as int,
      ayahNumber: map['ayah_number'] as int,
      audioUrl: map['audio_url'] as String,
      duration: map['duration'] as int?,
      segments: segList,
    );
  }

  String get verseKey => '$surahNumber:$ayahNumber';
}

class ReciterInfo {
  final String id;
  final String name;
  final String nameArabic;
  final String jsonFileName;
  final bool isDownloaded;

  ReciterInfo({
    required this.id,
    required this.name,
    required this.nameArabic,
    required this.jsonFileName,
    this.isDownloaded = false,
  });
}

const List<Map<String, String>> kAllReciters = [
  {
    'id': '959',
    'nameArabic': 'محمد صديق المنشاوي (مرتّل)',
    'file':
        'ayah-recitation-muhammad-siddiq-al-minshawi-murattal-hafs-959.json',
    'slug': 'Minshawy_Murattal_128kbps',
  },
  {
    'id': '950',
    'nameArabic': 'عبد الباسط عبد الصمد (مرتّل)',
    'file': 'ayah-recitation-abdul-basit-abdul-samad-murattal-hafs-950.json',
    'slug': 'Abdul_Basit_Murattal_192kbps',
  },
  {
    'id': '962',
    'nameArabic': 'محمد صديق المنشاوي (مجوّد)',
    'file':
        'ayah-recitation-muhammad-siddiq-al-minshawi-murattal-hafs-959.json',
    'slug': 'Minshawy_Mujawwad_192kbps',
  },
  {
    'id': '960',
    'nameArabic': 'عبد الباسط عبد الصمد (مجوّد)',
    'file': 'ayah-recitation-abdul-basit-abdul-samad-murattal-hafs-950.json',
    'slug': 'Abdul_Basit_Mujawwad_128kbps',
  },
  {
    'id': '954',
    'nameArabic': 'سعد الغامدي',
    'file': 'ayah-recitation-saad-al-ghamdi-murattal-hafs-954.json',
    'slug': 'Ghamadi_40kbps',
  },
  {
    'id': '963',
    'nameArabic': 'أحمد بن علي العجمي',
    'file':
        'ayah-recitation-mishari-rashid-al-afasy-murattal-hafs-953.json',
    'slug': 'Ahmed_ibn_Ali_al-Ajamy_128kbps_ketaballah.net',
  },
  {
    'id': '948',
    'nameArabic': 'ماهر المعيقلي',
    'file': 'ayah-recitation-maher-al-mu-aiqly-murattal-hafs-948.json',
    'slug': 'MaherAlMuaiqly128kbps',
  },
  {
    'id': '953',
    'nameArabic': 'مشاري راشد العفاسي',
    'file': 'ayah-recitation-mishari-rashid-al-afasy-murattal-hafs-953.json',
    'slug': 'Alafasy_128kbps',
  },
  {
    'id': '952',
    'nameArabic': 'أبو بكر الشاطري',
    'file': 'ayah-recitation-abu-bakr-al-shatri-murattal-hafs-952.json',
    'slug': 'Abu_Bakr_Ash-Shaatree_128kbps',
  },
  {
    'id': '958',
    'nameArabic': 'خليفة الطنيجي',
    'file': 'ayah-recitation-khalifa-al-tunaiji-murattal-hafs-958.json',
    'slug': 'khalefa_al_tunaiji_64kbps',
  },
  {
    'id': '957',
    'nameArabic': 'محمود خليل الحصري',
    'file': 'ayah-recitation-mahmoud-khalil-al-husary-murattal-hafs-957.json',
    'slug': 'Husary_128kbps',
  },
  {
    'id': '961',
    'nameArabic': 'ياسر الدوسري',
    'file': 'ayah-recitation-yasser-al-dosari-murattal-hafs-961.json',
    'slug': 'Yasser_Ad-Dussary_128kbps',
  },
];
