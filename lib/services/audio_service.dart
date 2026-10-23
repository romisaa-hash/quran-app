import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';

import '../app_state.dart';
import '../data/surahs.dart';

class Reciter {
  final String name;
  final String server;
  final String moshafName;
  final Set<int> surahs;
  Reciter(this.name, this.server, this.moshafName, this.surahs);
}

/// مشغل التلاوة
class QuranAudio extends ChangeNotifier {
  QuranAudio._() {
    player.playerStateStream.listen((s) {
      if (s.processingState == ProcessingState.completed) {
        _onCompleted();
      }
      notifyListeners();
    });
  }
  static final QuranAudio instance = QuranAudio._();

  final AudioPlayer player = AudioPlayer();
  int? currentSurah;
  String? currentReciter;
  String? _server;
  Set<int> _available = {};
  bool autoNext = true;
  String? error;

  static List<Reciter>? _cache;

  /// جلب قائمة القراء من mp3quran.net (رواية حفص)
  static Future<List<Reciter>> fetchReciters() async {
    if (_cache != null) return _cache!;
    final uri = Uri.parse(
        'https://mp3quran.net/api/v3/reciters?language=ar&rewaya=1');
    final res = await http.get(uri).timeout(const Duration(seconds: 25));
    if (res.statusCode != 200) {
      throw Exception('HTTP ${res.statusCode}');
    }
    final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final list = <Reciter>[];
    for (final r in (data['reciters'] as List)) {
      final name = (r['name'] ?? '').toString();
      final moshafs = (r['moshaf'] as List?) ?? [];
      for (final m in moshafs) {
        final server = (m['server'] ?? '').toString();
        final listStr = (m['surah_list'] ?? '').toString();
        final set = listStr
            .split(',')
            .map((e) => int.tryParse(e.trim()))
            .whereType<int>()
            .toSet();
        if (server.isEmpty || set.isEmpty) continue;
        list.add(Reciter(name, server, (m['name'] ?? '').toString(), set));
      }
    }
    // القراء أصحاب المصاحف الكاملة أولاً
    list.sort((a, b) {
      final c = (b.surahs.length == 114 ? 1 : 0)
          .compareTo(a.surahs.length == 114 ? 1 : 0);
      if (c != 0) return c;
      return a.name.compareTo(b.name);
    });
    _cache = list;
    return list;
  }

  String _url(String server, int surah) {
    final s = server.endsWith('/') ? server : '$server/';
    return '$s${surah.toString().padLeft(3, '0')}.mp3';
  }

  Future<void> playSurah(int surah, {Reciter? reciter}) async {
    error = null;
    final st = AppState.instance;
    if (reciter != null) {
      await st.setReciter(reciter.name, reciter.server);
      _available = reciter.surahs;
    }
    _server = st.reciterServer;
    currentReciter = st.reciterName;
    if (_server == null) {
      error = 'اختار القارئ الأول من شاشة الاستماع';
      notifyListeners();
      return;
    }
    if (_available.isNotEmpty && !_available.contains(surah)) {
      error = 'السورة دي مش متاحة بصوت القارئ ده';
      notifyListeners();
      return;
    }
    currentSurah = surah;
    notifyListeners();
    try {
      await player.setUrl(_url(_server!, surah));
      player.play();
    } catch (e) {
      error = 'تعذّر تشغيل التلاوة. اتأكد من اتصال الإنترنت.';
      notifyListeners();
    }
  }

  Future<void> _onCompleted() async {
    if (!autoNext || currentSurah == null) return;
    int next = currentSurah! + 1;
    while (next <= 114 && _available.isNotEmpty && !_available.contains(next)) {
      next++;
    }
    if (next <= 114) {
      await playSurah(next);
    }
  }

  Future<void> next() async {
    if (currentSurah != null && currentSurah! < 114) {
      await playSurah(currentSurah! + 1);
    }
  }

  Future<void> previous() async {
    if (currentSurah != null && currentSurah! > 1) {
      await playSurah(currentSurah! - 1);
    }
  }

  Future<void> toggle() async {
    if (player.playing) {
      await player.pause();
    } else {
      await player.play();
    }
    notifyListeners();
  }

  Future<void> stop() async {
    await player.stop();
    currentSurah = null;
    notifyListeners();
  }

  String get title =>
      currentSurah == null ? '' : 'سورة ${surahNames[currentSurah! - 1]}';
}
