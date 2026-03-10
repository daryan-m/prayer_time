import 'package:flutter/material.dart';
import '../services/prayer_service.dart';
import '../utils/constants.dart';

// ==================== WIDGETS ====================

// ── کاتژمێر ──────────────────────────────────────
class ClockWidget extends StatelessWidget {
  final DateTime now;
  final TimeService timeService;
  final ThemePalette palette;

  const ClockWidget({
    super.key,
    required this.now,
    required this.timeService,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              timeService.toKu(
                "${(now.hour % 12 == 0 ? 12 : now.hour % 12).toString().padLeft(2, '0')}"
                ":${now.minute.toString().padLeft(2, '0')}"
                ":${now.second.toString().padLeft(2, '0')}",
              ),
              style: const TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              now.hour >= 12 ? "د.ن" : "پ.ن",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        _buildGlowDivider(palette),
      ],
    );
  }
}

// ── بەروارەکان ───────────────────────────────────
class DatesWidget extends StatelessWidget {
  final TimeService timeService;
  final DateTime now;
  final String gregorianDate;
  final ThemePalette palette;

  const DatesWidget({
    super.key,
    required this.timeService,
    required this.now,
    required this.gregorianDate,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 10),
        Text(
          timeService.hijriDateString(),
          style: TextStyle(
            color: palette.secondary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        const SizedBox(height: 10),
        _buildGlowDivider(palette),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "میلادی: ${timeService.toKu(timeService.gregorianDateString(now))}",
              style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 14),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text("|", style: TextStyle(color: palette.primary)),
            ),
            Text(
              "کوردی: ${timeService.kurdishDateString(now)}",
              style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 14),
            ),
          ],
        ),
        const SizedBox(height: 10),
      ],
    );
  }
}

// ── بارێکی ماوە بۆ بانگی داهاتوو ────────────────
class NextPrayerBar extends StatelessWidget {
  final String remainingTime;
  final String nextPrayerName;
  final ThemePalette palette;

  const NextPrayerBar({
    super.key,
    required this.remainingTime,
    required this.nextPrayerName,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(35),
        border: Border(
          top: BorderSide(color: palette.primary.withOpacity(0.6), width: 1.0),
          bottom:
              BorderSide(color: palette.primary.withOpacity(0.6), width: 1.0),
          left: BorderSide(color: palette.primary.withOpacity(0.6), width: 8.0),
          right:
              BorderSide(color: palette.primary.withOpacity(0.6), width: 8.0),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 20),
        decoration: BoxDecoration(
          color: palette.cardBg,
          borderRadius: BorderRadius.circular(15),
          border: Border(
            left: BorderSide(color: palette.border, width: 8.0),
            right: BorderSide(color: palette.border, width: 8.0),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              remainingTime,
              style: TextStyle(
                color: palette.secondary,
                fontSize: 23,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 20),
            Text(
              nextPrayerName == "خۆرهەڵاتن"
                  ? "ماوە بۆ خۆرهەڵاتن"
                  : "ماوە بۆ بانگی $nextPrayerName",
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}

// ── کارتی بانگ ───────────────────────────────────
class PrayerCard extends StatelessWidget {
  final String name;
  final String time;
  final bool isSun;
  final bool isActive;
  final Animation<double>? sunAnimation;
  final Future<void> Function() onTap;
  final TimeService timeService;
  final ThemePalette palette;

  const PrayerCard({
    super.key,
    required this.name,
    required this.time,
    required this.isSun,
    required this.isActive,
    this.sunAnimation,
    required this.onTap,
    required this.timeService,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    final List<Shadow>? embossedShadow = isActive
        ? null
        : const [
            Shadow(offset: Offset(1, 1), blurRadius: 2, color: Colors.black),
            Shadow(
                offset: Offset(-0.5, -0.5), blurRadius: 1, color: Colors.black),
          ];

    return GestureDetector(
      onTap: isSun ? null : () async => await onTap(),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 7),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: isActive ? palette.cardBgActive : palette.cardBg,
          borderRadius: BorderRadius.circular(15),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: palette.glow.withOpacity(0.5),
                    blurRadius: 10,
                    spreadRadius: 2,
                  )
                ]
              : [
                  const BoxShadow(
                    color: Colors.black26,
                    offset: Offset(5, 5),
                    blurRadius: 10,
                  ),
                  BoxShadow(
                    color: Colors.black26.withOpacity(0.9),
                    offset: const Offset(-3, -3),
                    blurRadius: 6,
                    spreadRadius: 2.5,
                  ),
                ],
          border: Border.all(
            color: isActive
                ? Colors.white.withOpacity(0.50)
                : Colors.white.withOpacity(0.09),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                _buildLeadingIcon(),
                const SizedBox(width: 15),
                Text(
                  isSun ? name : "بانگی $name",
                  style: TextStyle(
                    color: isSun
                        ? Colors.orange
                        : (isActive ? palette.primary : Colors.white),
                    fontSize: 16,
                    shadows: embossedShadow,
                  ),
                ),
              ],
            ),
            Text(
              timeService.formatTo12Hr(time),
              style: TextStyle(
                fontSize: 18,
                color: isSun
                    ? Colors.orange
                    : (isActive ? palette.primary : Colors.white70),
                shadows: embossedShadow,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeadingIcon() {
    if (isSun && sunAnimation != null) {
      return RepaintBoundary(
        child: AnimatedBuilder(
          animation: sunAnimation!,
          builder: (context, child) => Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.orange.withOpacity(sunAnimation!.value * 0.7),
                  blurRadius: 10,
                  spreadRadius: sunAnimation!.value * 8,
                ),
              ],
            ),
            child: const Icon(Icons.wb_sunny, color: Colors.orange, size: 28),
          ),
        ),
      );
    }

    return Icon(
      isActive ? Icons.volume_up : Icons.volume_off,
      color: isActive ? palette.icon : Colors.blueGrey,
      size: 24,
    );
  }
}

// ── یارمەتیدەر: خەتی گلۆ ────────────────────────
Widget _buildGlowDivider(ThemePalette palette) {
  return Container(
    width: 330,
    height: 2,
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [Colors.transparent, palette.primary, Colors.transparent],
      ),
      boxShadow: [
        BoxShadow(
          color: palette.glow.withOpacity(0.8),
          blurRadius: 12,
        ),
      ],
    ),
  );
}
