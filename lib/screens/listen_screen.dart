import 'package:flutter/material.dart';

import '../app_state.dart';
import '../data/surahs.dart';
import '../services/audio_service.dart';
import '../utils.dart';

class ListenScreen extends StatefulWidget {
  const ListenScreen({super.key});

  @override
  State<ListenScreen> createState() => _ListenScreenState();
}

class _ListenScreenState extends State<ListenScreen> {
  List<Reciter>? _all;
  String? _error;
  String _query = '';
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await QuranAudio.fetchReciters();
      if (mounted) setState(() => _all = list);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'تعذّر تحميل قائمة القراء. اتأكد من الإنترنت.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final st = AppState.instance;
    final filtered = (_all ?? [])
        .where((r) => _query.isEmpty || r.name.contains(_query))
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('الاستماع للقرآن')),
      body: Column(
        children: [
          const _PlayerCard(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'ابحث عن قارئ...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (v) => setState(() => _query = v.trim()),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: kGreen))
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.wifi_off,
                                size: 48, color: Colors.grey),
                            const SizedBox(height: 8),
                            Text(_error!, textAlign: TextAlign.center),
                            const SizedBox(height: 8),
                            FilledButton(
                                onPressed: _load,
                                child: const Text('إعادة المحاولة')),
                          ],
                        ),
                      )
                    : ListenableBuilder(
                        listenable: st,
                        builder: (context, _) => ListView.builder(
                          itemCount: filtered.length,
                          itemBuilder: (context, i) {
                            final r = filtered[i];
                            final selected = st.reciterServer == r.server;
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor:
                                    selected ? kGold : kGreen.withValues(alpha: 0.1),
                                child: Icon(Icons.person,
                                    color: selected ? Colors.white : kGreen),
                              ),
                              title: Text(r.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600)),
                              subtitle: Text(
                                  '${r.moshafName} • ${ar(r.surahs.length)} سورة',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                              trailing: selected
                                  ? const Icon(Icons.check_circle, color: kGold)
                                  : const Icon(Icons.chevron_left),
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (_) =>
                                        ReciterSurahsScreen(reciter: r)),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _PlayerCard extends StatelessWidget {
  const _PlayerCard();

  @override
  Widget build(BuildContext context) {
    final audio = QuranAudio.instance;
    return ListenableBuilder(
      listenable: audio,
      builder: (context, _) {
        if (audio.error != null) {
          return Container(
            width: double.infinity,
            color: Colors.red.shade50,
            padding: const EdgeInsets.all(12),
            child: Text(audio.error!, textAlign: TextAlign.center),
          );
        }
        if (audio.currentSurah == null) return const SizedBox.shrink();
        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [kGreen, kGreenLight]),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              Text(audio.title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold)),
              Text(audio.currentReciter ?? '',
                  style: const TextStyle(color: kGold)),
              StreamBuilder<Duration>(
                stream: audio.player.positionStream,
                builder: (context, snap) {
                  final pos = snap.data ?? Duration.zero;
                  final dur = audio.player.duration ?? Duration.zero;
                  final max = dur.inMilliseconds.toDouble();
                  final val =
                      pos.inMilliseconds.clamp(0, dur.inMilliseconds).toDouble();
                  return Directionality(
                    textDirection: TextDirection.ltr,
                    child: Column(
                      children: [
                        Slider(
                          value: max > 0 ? val : 0,
                          max: max > 0 ? max : 1,
                          activeColor: kGold,
                          inactiveColor: Colors.white24,
                          onChanged: max > 0
                              ? (v) => audio.player
                                  .seek(Duration(milliseconds: v.round()))
                              : null,
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(formatMediaDuration(pos),
                                  style:
                                      const TextStyle(color: Colors.white70)),
                              Text(formatMediaDuration(dur),
                                  style:
                                      const TextStyle(color: Colors.white70)),
                            ],
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              iconSize: 36,
                              onPressed: audio.previous,
                              icon: const Icon(Icons.skip_previous,
                                  color: Colors.white),
                            ),
                            IconButton(
                              iconSize: 56,
                              onPressed: audio.toggle,
                              icon: Icon(
                                  audio.player.playing
                                      ? Icons.pause_circle_filled
                                      : Icons.play_circle_filled,
                                  color: kGold),
                            ),
                            IconButton(
                              iconSize: 36,
                              onPressed: audio.next,
                              icon: const Icon(Icons.skip_next,
                                  color: Colors.white),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class ReciterSurahsScreen extends StatelessWidget {
  final Reciter reciter;
  const ReciterSurahsScreen({super.key, required this.reciter});

  @override
  Widget build(BuildContext context) {
    final audio = QuranAudio.instance;
    return Scaffold(
      appBar: AppBar(title: Text(reciter.name)),
      body: ListenableBuilder(
        listenable: audio,
        builder: (context, _) => ListView.builder(
          itemCount: 114,
          itemBuilder: (context, i) {
            final n = i + 1;
            final available = reciter.surahs.contains(n);
            final playing = audio.currentSurah == n &&
                audio.currentReciter == reciter.name;
            return ListTile(
              enabled: available,
              leading: CircleAvatar(
                backgroundColor:
                    playing ? kGold : kGreen.withValues(alpha: 0.08),
                child: Text(ar(n),
                    style: TextStyle(
                        color: playing ? Colors.white : kGreen,
                        fontWeight: FontWeight.bold)),
              ),
              title: Text('سورة ${surahNames[i]}',
                  style: const TextStyle(fontSize: 17)),
              subtitle: available ? null : const Text('غير متاحة'),
              trailing: Icon(
                  playing ? Icons.graphic_eq : Icons.play_arrow_rounded,
                  color: kGreen),
              onTap: available
                  ? () => audio.playSurah(n, reciter: reciter)
                  : null,
            );
          },
        ),
      ),
    );
  }
}
