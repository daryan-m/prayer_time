import 'package:flutter/material.dart';
import '../services/prayer_service.dart';
import '../utils/constants.dart';

// ==================== WIDGETS ====================

// کاتژمێر
class ClockWidget extends StatelessWidget {
  final DateTime now;
  final TimeService timeService;

  const ClockWidget({
    super.key,
    required this.now,
    required this.timeService,
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
                "${(now.hour % 12 == 0 ? 12 : now.hour % 12).toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}",
              ),
              style: const TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
            ),
            const SizedBox(width: 12),
            Text(
              now.hour >= 12 ? "د.ن" : "پ.ن",
              style: const TextStyle(
                  color: Color(0xFFFFFFFF),
                  fontSize: 20,
                  fontWeight: FontWeight.bold),
            ),
          ],
        ),
        Container(
          width: 330,
          height: 2,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [
              Colors.transparent,
              Color(0xFF22D3EE),
              Colors.transparent
            ]),
            boxShadow: [
              BoxShadow(
                  color: const Color(0xFF22D3EE).withOpacity(0.8),
                  blurRadius: 12)
            ],
          ),
        ),
      ],
    );
  }
}

// بەروارەکان
class DatesWidget extends StatelessWidget {
  final TimeService timeService;
  final DateTime now;
  final String gregorianDate;
  const DatesWidget({
    super.key,
    required this.timeService,
    required this.now,
    required this.gregorianDate,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 10),
        Text(
          timeService.hijriDateString(),
          style: const TextStyle(
              color: Color(0xFF10B981),
              fontWeight: FontWeight.bold,
              fontSize: 18),
        ),
        const SizedBox(height: 10),
        Container(
          width: 330,
          height: 2,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [
              Colors.transparent,
              Color(0xFF22D3EE),
              Colors.transparent
            ]),
            boxShadow: [
              BoxShadow(
                  color: const Color(0xFF22D3EE).withOpacity(0.8),
                  blurRadius: 12)
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
                "میلادی: ${timeService.toKu(timeService.gregorianDateString(now))}",
                style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 14)),
            const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text("|", style: TextStyle(color: Color(0xFF22D3EE)))),
            Text("کوردی: ${timeService.kurdishDateString(now)}",
                style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 14)),
          ],
        ),
        const SizedBox(height: 10),
      ],
    );
  }
}

// بارێکی ماوە بۆ بانگی داهاتوو
class NextPrayerBar extends StatelessWidget {
  final String remainingTime;
  final String nextPrayerName;

  const NextPrayerBar({
    super.key,
    required this.remainingTime,
    required this.nextPrayerName,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF22D3EE).withOpacity(0.9),
            blurRadius: 15,
            spreadRadius: 3,
            offset: const Offset(0, 0),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 10,
            offset: const Offset(4, 4),
          ),
        ],
        border: Border.all(
          color: const Color(0xFF22D3EE).withOpacity(1.0),
          width: 1.4,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            remainingTime,
            style: const TextStyle(
              color: Color(0xFF10B981),
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
    );
  }
}

// کارتی بانگ
class PrayerCard extends StatelessWidget {
  final String name;
  final String time;
  final bool isSun;
  final bool isActive;
  final Animation<double>? sunAnimation;
  final VoidCallback onTap;
  final TimeService timeService;

  const PrayerCard({
    super.key,
    required this.name,
    required this.time,
    required this.isSun,
    required this.isActive,
    this.sunAnimation,
    required this.onTap,
    required this.timeService,
  });

  @override
  Widget build(BuildContext context) {
    List<Shadow>? embossedShadow = isActive
        ? null
        : const [
            Shadow(offset: Offset(1, 1), blurRadius: 2, color: Colors.green),
            Shadow(
                offset: Offset(-0.5, -0.5),
                blurRadius: 1,
                color: Colors.white10),
          ];

    var list = [
      const BoxShadow(
          color: Colors.teal, offset: Offset(5, 5), blurRadius: 10),
      BoxShadow(
          color: Colors.teal.withOpacity(0.9),
          offset: const Offset(-3, -3),
          blurRadius: 7,
          spreadRadius: 2.5),
    ];

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 7),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFF080D1A) : const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(15),
        boxShadow: isActive
            ? [
                BoxShadow(
                    color: const Color(0xFF22D3EE).withOpacity(0.7),
                    blurRadius: 10,
                    spreadRadius: 3)
              ]
            : list,
        border: Border.all(
          color: isActive
              ? const Color(0xFF22D3EE).withOpacity(0.50)
              : Colors.white.withOpacity(0.09),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              isSun && sunAnimation != null
                  ? RepaintBoundary(
                      child: AnimatedBuilder(
                        animation: sunAnimation!,
                        builder: (context, child) => Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.orange
                                    .withOpacity(sunAnimation!.value * 0.7),
                                blurRadius: 15,
                                spreadRadius: sunAnimation!.value * 5,
                              )
                            ],
                          ),
                          child: const Icon(
                            Icons.wb_sunny,
                            color: Colors.orange,
                            size: 28,
                          ),
                        ),
                      ),
                    )
                  : GestureDetector(
                      onTap: onTap,
                      child: Icon(
                        isActive ? Icons.volume_up : Icons.volume_off,
                        color: isActive
                            ? const Color(0xFF22D3EE)
                            : Colors.blueGrey,
                        size: 24,
                      ),
                    ),
              const SizedBox(width: 15),
              Text(isSun ? name : "بانگی $name",
                  style: TextStyle(
                      color: isSun
                          ? Colors.orange
                          : (isActive ? const Color(0xFF22D3EE) : Colors.white),
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      shadows: embossedShadow)),
            ],
          ),
          Text(timeService.formatTo12Hr(time),
              style: TextStyle(
                  fontSize: 18,
                  color: isSun
                      ? Colors.orange
                      : (isActive ? const Color(0xFF22D3EE) : Colors.white70),
                  shadows: embossedShadow,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
