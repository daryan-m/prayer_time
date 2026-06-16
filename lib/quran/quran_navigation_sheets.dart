import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'quran_models.dart';
import 'quran_audio_service.dart';
import 'quran_database_helper.dart';
import 'quran_page_builder.dart';

// ─── Sheet Container ─────────────────────────────────────────────────────────

class _QuranSheetContainer extends StatelessWidget {
  final String title;
  final Widget child;
  final double heightFactor;

  const _QuranSheetContainer({
    required this.title,
    required this.child,
    this.heightFactor = 0.75,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * heightFactor,
      decoration: const BoxDecoration(
        color: Color(0xFF1A2E14),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            decoration: const BoxDecoration(
              color: Color(0xFF2D5016),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close, color: Colors.white54, size: 20),
                ),
              ],
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

// ─── Surah List Sheet ─────────────────────────────────────────────────────────

void showSurahListSheet({
  required BuildContext context,
  required List<SurahInfo> surahs,
  required SurahInfo? currentSurah,
  required QuranDatabaseHelper db,
  required QuranAudioService audio,
  required void Function(int page) goToPage,
}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => _QuranSheetContainer(
      title: 'سورەکان',
      child: ListView.separated(
        itemCount: surahs.length,
        separatorBuilder: (_, __) => Divider(
          height: 1,
          color: Colors.white.withOpacity(0.08),
          indent: 56,
        ),
        itemBuilder: (_, i) {
          final surah = surahs[i];
          final isCurrent = currentSurah?.id == surah.id;
          return ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            leading: CircleAvatar(
              radius: 18,
              backgroundColor: isCurrent
                  ? const Color(0xFF4A7C59)
                  : Colors.white.withOpacity(0.1),
              child: Text(
                toKNum(surah.id),
                style: TextStyle(
                  color: isCurrent ? Colors.white : Colors.white60,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              surah.nameArabic,
              style: TextStyle(
                fontFamily: 'Notonaskh',
                fontSize: 16,
                color: isCurrent ? const Color(0xFFB8D4A8) : Colors.white,
                fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
              ),
              textDirection: TextDirection.rtl,
            ),
            subtitle: Text(
              '${surah.isMakki ? "مکی" : "مدنی"} / ${toKNum(surah.versesCount)} ئایە',
              textDirection: TextDirection.rtl,
              style: TextStyle(
                color: Colors.white.withOpacity(0.45),
                fontSize: 11,
              ),
            ),
            trailing: isCurrent
                ? const Icon(Icons.bookmark, color: Color(0xFF8BC34A), size: 18)
                : null,
            onTap: () async {
              Navigator.pop(ctx);
              final page = await db.getPageForAyah(surah.id, 1);
              goToPage(page);
              if (audio.isPlaying || audio.isPaused) {
                await audio.playFromSurahStart(surah.id);
              }
            },
          );
        },
      ),
    ),
  );
}

// ─── Juz List Sheet ───────────────────────────────────────────────────────────

void showJuzListSheet({
  required BuildContext context,
  required List<JuzInfo> juzList,
  required int currentJuz,
  required QuranDatabaseHelper db,
  required QuranAudioService audio,
  required void Function(int page) goToPage,
}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => _QuranSheetContainer(
      title: 'جزء',
      child: ListView.separated(
        itemCount: juzList.length,
        separatorBuilder: (_, __) => Divider(
          height: 1,
          color: Colors.white.withOpacity(0.08),
          indent: 56,
        ),
        itemBuilder: (_, i) {
          final juz = juzList[i];
          final isCurrent = currentJuz == juz.juzNumber;
          return ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            leading: CircleAvatar(
              radius: 18,
              backgroundColor: isCurrent
                  ? const Color(0xFF4A7C59)
                  : Colors.white.withOpacity(0.1),
              child: Text(
                toKNum(juz.juzNumber),
                style: TextStyle(
                  color: isCurrent ? Colors.white : Colors.white60,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              'جزء ${toKNum(juz.juzNumber)}',
              style: TextStyle(
                fontSize: 15,
                color: isCurrent ? const Color(0xFFB8D4A8) : Colors.white,
                fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            subtitle: Text(
              'دەستپێک: ${juz.firstVerseKey}',
              textDirection: TextDirection.rtl,
              style: TextStyle(
                color: Colors.white.withOpacity(0.45),
                fontSize: 11,
              ),
            ),
            trailing: isCurrent
                ? const Icon(Icons.bookmark, color: Color(0xFF8BC34A), size: 18)
                : null,
            onTap: () async {
              Navigator.pop(ctx);
              final parts = juz.firstVerseKey.split(':');
              final surah = int.parse(parts[0]);
              final ayah = int.parse(parts[1]);
              final page = await db.getPageForAyah(surah, ayah);
              goToPage(page);
              if (audio.isPlaying || audio.isPaused) {
                if (ayah == 1 && surah != 1 && surah != 9) {
                  await audio.playFromSurahStart(surah);
                } else {
                  await audio.playAyah(surah, ayah);
                }
              }
            },
          );
        },
      ),
    ),
  );
}

// ─── Page Jump Dialog ─────────────────────────────────────────────────────────

void showPageJumpDialog({
  required BuildContext context,
  required int currentPage,
  required void Function(int page) goToPage,
}) {
  final controller = TextEditingController(text: '$currentPage');
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF000000),
      title: const Text(
        'بڕۆ بۆ لاپەرە',
        style: TextStyle(color: Colors.white),
      ),
      content: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        style: const TextStyle(color: Colors.white),
        decoration: const InputDecoration(
          labelText: 'ژمارەی لاپەرە (1-604)',
          labelStyle: TextStyle(color: Colors.white54),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          style: TextButton.styleFrom(foregroundColor: Colors.white),
          child: const Text('پاشگەزبوونەوە'),
        ),
        TextButton(
          onPressed: () {
            final page = int.tryParse(controller.text) ?? 1;
            Navigator.pop(ctx);
            goToPage(page.clamp(1, 604));
          },
          style: TextButton.styleFrom(foregroundColor: Colors.white),
          child: const Text('بڕۆ'),
        ),
      ],
    ),
  );
}

// ─── Reciter Sheet ────────────────────────────────────────────────────────────

void showReciterSheet({
  required BuildContext context,
  required QuranAudioService audio,
}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => _QuranSheetContainer(
      title: 'دەنگەکان',
      heightFactor: 0.65,
      child: ListenableBuilder(
        listenable: audio,
        builder: (_, __) => ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: kAllReciters.length,
          separatorBuilder: (_, __) => Divider(
            height: 1,
            color: Colors.white.withOpacity(0.07),
            indent: 60,
          ),
          itemBuilder: (_, i) {
            final r = kAllReciters[i];
            final id = r['id']!;
            final isSelected = audio.currentReciterId == id;
            final isDone = audio.downloadedReciters.contains(id);
            final isDownloading = audio.downloadProgress.containsKey(id);
            final isPaused = audio.pausedReciters.contains(id);
            final progress = audio.downloadProgress[id];
            final pausedPct = audio.pausedProgress[id] ?? 0.0;

            return Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  // بازنەی هەڵبژاردن
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(ctx);
                      audio.switchReciter(id, r['file']!);
                      SharedPreferences.getInstance()
                          .then((p) => p.setString('quran_last_reciter', id));
                    },
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF8BC34A)
                              : Colors.white24,
                          width: isSelected ? 2.5 : 1.5,
                        ),
                        color: isSelected
                            ? const Color(0xFF4A7C59)
                            : Colors.transparent,
                      ),
                      child: isSelected
                          ? const Icon(Icons.check,
                              color: Colors.white, size: 17)
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // ناو + پرۆگرەس
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r['nameArabic']!,
                          style: TextStyle(
                            color: isSelected
                                ? const Color(0xFFB8D4A8)
                                : Colors.white,
                            fontSize: 14,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                          textDirection: TextDirection.rtl,
                        ),
                        if (isDownloading || isPaused) ...[
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: isDownloading ? progress : pausedPct,
                              minHeight: 4,
                              backgroundColor: Colors.white10,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                isDownloading
                                    ? const Color(0xFF8BC34A)
                                    : Colors.orange,
                              ),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            isDownloading
                                ? '${toKNum((progress! * 100).toInt())}٪ دادەبەزێت'
                                : '${toKNum((pausedPct * 100).toInt())}٪ — وەستێنراوە',
                            style: TextStyle(
                              color: isDownloading
                                  ? const Color(0xFF8BC34A)
                                  : Colors.orange,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),

                  // دوگمەکانی عەمەلیات
                  if (isDownloading) ...[
                    _DownloadIconButton(
                      icon: Icons.pause_circle_outline,
                      color: const Color(0xFF8BC34A),
                      onTap: () => audio.pauseDownload(id),
                    ),
                    const SizedBox(width: 6),
                    _DownloadIconButton(
                      icon: Icons.cancel_outlined,
                      color: Colors.white38,
                      onTap: () => audio.cancelDownload(id),
                    ),
                  ] else if (isPaused) ...[
                    _DownloadIconButton(
                      icon: Icons.play_circle_outline,
                      color: Colors.orange,
                      onTap: () => audio.resumeDownload(id),
                    ),
                    const SizedBox(width: 6),
                    _DownloadIconButton(
                      icon: Icons.cancel_outlined,
                      color: Colors.white38,
                      onTap: () => audio.cancelDownload(id),
                    ),
                  ] else if (isDone) ...[
                    _DownloadIconButton(
                      icon: Icons.delete_outline,
                      color: Colors.white30,
                      onTap: () => audio.deleteDownloadedReciter(id),
                    ),
                  ] else ...[
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => audio.downloadReciter(id),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFF4A7C59)),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.download,
                                color: Color(0xFF8BC34A), size: 15),
                            SizedBox(width: 4),
                            Text(
                              'داگرتن',
                              style: TextStyle(
                                color: Color(0xFF8BC34A),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    ),
  );
}

// ─── Download Icon Button ─────────────────────────────────────────────────────

class _DownloadIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _DownloadIconButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Icon(icon, color: color, size: 26),
    );
  }
}
