import 'package:flutter/material.dart';

import '../services/audio_service.dart';
import '../utils.dart';
import 'azkar_screen.dart';
import 'listen_screen.dart';
import 'mushaf_screen.dart';
import 'prayer_screen.dart';
import 'qibla_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  final _pages = const [
    PrayerScreen(),
    MushafHome(),
    ListenScreen(),
    AzkarScreen(),
    QiblaScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const MiniPlayer(),
          NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            backgroundColor: Colors.white,
            indicatorColor: kGold.withValues(alpha: 0.3),
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            destinations: const [
              NavigationDestination(
                  icon: Icon(Icons.access_time), label: 'المواقيت'),
              NavigationDestination(
                  icon: Icon(Icons.menu_book), label: 'المصحف'),
              NavigationDestination(
                  icon: Icon(Icons.headphones), label: 'استماع'),
              NavigationDestination(
                  icon: Icon(Icons.auto_awesome), label: 'الأذكار'),
              NavigationDestination(
                  icon: Icon(Icons.explore), label: 'القبلة'),
            ],
          ),
        ],
      ),
    );
  }
}

/// شريط التشغيل المصغر يظهر أثناء التلاوة
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final audio = QuranAudio.instance;
    return ListenableBuilder(
      listenable: audio,
      builder: (context, _) {
        if (audio.currentSurah == null) return const SizedBox.shrink();
        return Material(
          color: kGreen,
          child: SafeArea(
            top: false,
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  const Icon(Icons.graphic_eq, color: kGold),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(audio.title,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                        Text(audio.currentReciter ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                  ),
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          onPressed: audio.previous,
                          icon: const Icon(Icons.skip_previous,
                              color: Colors.white),
                          tooltip: 'السورة السابقة',
                        ),
                        IconButton(
                          onPressed: audio.toggle,
                          icon: Icon(
                              audio.player.playing
                                  ? Icons.pause_circle_filled
                                  : Icons.play_circle_filled,
                              color: kGold,
                              size: 36),
                        ),
                        IconButton(
                          onPressed: audio.next,
                          icon:
                              const Icon(Icons.skip_next, color: Colors.white),
                          tooltip: 'السورة التالية',
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: audio.stop,
                    icon: const Icon(Icons.close, color: Colors.white70),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
