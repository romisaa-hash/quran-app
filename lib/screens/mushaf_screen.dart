import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import '../app_state.dart';
import '../data/surahs.dart';
import '../services/audio_service.dart';
import '../utils.dart';
import '../widgets/key_scroll.dart';

/// ذاكرة تخزين صفحات المصحف (تبقى على الجهاز)
final CacheManager mushafCache = CacheManager(
  Config(
    'mushafPages',
    stalePeriod: const Duration(days: 3650),
    maxNrOfCacheObjects: 700,
  ),
);

/// الشاشة الرئيسية للمصحف: الفهرس
class MushafHome extends StatefulWidget {
  const MushafHome({super.key});

  @override
  State<MushafHome> createState() => _MushafHomeState();
}

class _MushafHomeState extends State<MushafHome> {
  final st = AppState.instance;
  bool _downloading = false;
  int _downloaded = 0;
  bool _cancel = false;

  void _open(int page) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => MushafReader(initialPage: page)))
        .then((_) => setState(() {}));
  }

  Future<void> _downloadAll() async {
    setState(() {
      _downloading = true;
      _downloaded = 0;
      _cancel = false;
    });
    int failed = 0;
    for (int p = 1; p <= totalPages; p++) {
      if (_cancel || !mounted) break;
      try {
        final f = await mushafCache.getFileFromCache(pageImageUrl(p));
        if (f == null) {
          await mushafCache.downloadFile(pageImageUrl(p));
        }
      } catch (_) {
        failed++;
      }
      if (mounted) setState(() => _downloaded = p);
    }
    if (!mounted) return;
    setState(() => _downloading = false);
    if (!_cancel) {
      showSnack(
          context,
          failed == 0
              ? 'تم تحميل المصحف كاملًا ✅ تقدر تقرأ بدون إنترنت'
              : 'تم التحميل مع ${ar(failed)} صفحة لم تُحمّل، أعد المحاولة');
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('المصحف الشريف'),
          actions: [
            IconButton(
              tooltip: 'تحميل المصحف للقراءة بدون إنترنت',
              icon: const Icon(Icons.download_for_offline_outlined),
              onPressed: _downloading ? null : _downloadAll,
            ),
          ],
          bottom: const TabBar(
            labelColor: kGold,
            unselectedLabelColor: Colors.white70,
            indicatorColor: kGold,
            tabs: [
              Tab(text: 'السور'),
              Tab(text: 'الأجزاء'),
              Tab(text: 'العلامات'),
            ],
          ),
        ),
        body: Column(
          children: [
            if (_downloading)
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              'جارِ تحميل المصحف... ${ar(_downloaded)} / ${ar(totalPages)}'),
                          const SizedBox(height: 6),
                          LinearProgressIndicator(
                            value: _downloaded / totalPages,
                            color: kGreen,
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () => setState(() => _cancel = true),
                      child: const Text('إيقاف'),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: kGold,
                    foregroundColor: Colors.black87,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () => _open(st.lastPage),
                  icon: const Icon(Icons.auto_stories),
                  label: Text(
                    'متابعة القراءة - صفحة ${ar(st.lastPage)} (${surahNames[surahForPage(st.lastPage) - 1]})',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _surahList(),
                  _juzList(),
                  _bookmarks(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _surahList() {
    return KeyScroll(
          tab: 1,
          builder: (context, sc) => ListView.separated(
          controller: sc,
      itemCount: 114,
      separatorBuilder: (_, __) => const Divider(height: 1, indent: 70),
      itemBuilder: (context, i) {
        final n = i + 1;
        return ListTile(
          leading: _numberBadge(n),
          title: Text('سورة ${surahNames[i]}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          subtitle: Text(
              '${medinanSurahs.contains(n) ? 'مدنية' : 'مكية'} • ${ar(surahAyahCounts[i])} آية'),
          trailing: Text('ص ${ar(surahStartPages[i])}',
              style: const TextStyle(color: kGreen)),
          onTap: () => _open(surahStartPages[i]),
        );
      },
    ));
  }

  Widget _juzList() {
    return KeyScroll(
          tab: 1,
          builder: (context, sc) => ListView.separated(
          controller: sc,
      itemCount: 30,
      separatorBuilder: (_, __) => const Divider(height: 1, indent: 70),
      itemBuilder: (context, i) {
        final page = juzStartPages[i];
        return ListTile(
          leading: _numberBadge(i + 1),
          title: Text('الجزء ${juzNames[i]}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          subtitle: Text('يبدأ من سورة ${surahNames[surahForPage(page) - 1]}'),
          trailing:
              Text('ص ${ar(page)}', style: const TextStyle(color: kGreen)),
          onTap: () => _open(page),
        );
      },
    ));
  }

  Widget _bookmarks() {
    return ListenableBuilder(
      listenable: st,
      builder: (context, _) {
        if (st.bookmarks.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text(
                'لا توجد علامات بعد.\nأثناء القراءة اضغط على الصفحة ثم على أيقونة العلامة 🔖',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ),
          );
        }
        return ListView(
          children: st.bookmarks
              .map((p) => ListTile(
                    leading: const Icon(Icons.bookmark, color: kGold),
                    title: Text('صفحة ${ar(p)}'),
                    subtitle: Text(
                        'سورة ${surahNames[surahForPage(p) - 1]} • الجزء ${juzNames[juzForPage(p) - 1]}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => st.toggleBookmark(p),
                    ),
                    onTap: () => _open(p),
                  ))
              .toList(),
        );
      },
    );
  }

  Widget _numberBadge(int n) {
    return Container(
      width: 42,
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: kGold, width: 2),
        color: kGreen.withValues(alpha: 0.06),
      ),
      child: Text(ar(n),
          style: const TextStyle(fontWeight: FontWeight.bold, color: kGreen)),
    );
  }
}

/// قارئ المصحف: صفحات مصحف المدينة
class MushafReader extends StatefulWidget {
  final int initialPage;
  const MushafReader({super.key, required this.initialPage});

  @override
  State<MushafReader> createState() => _MushafReaderState();
}

class _MushafReaderState extends State<MushafReader> {
  late final PageController _ctrl;
  late int _page;
  bool _zoomed = false;

  /// أسهم الكيبورد تقلّب الصفحات دائمًا (حتى بعد الضغط بالماوس)
  bool _onKey(KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) return false;
    if (!mounted || !(ModalRoute.of(context)?.isCurrent ?? true)) return false;
    final k = e.logicalKey;
    // في المصحف: الصفحة التالية على اليسار
    if (k == LogicalKeyboardKey.arrowLeft ||
        k == LogicalKeyboardKey.arrowDown ||
        k == LogicalKeyboardKey.pageDown) {
      _next();
      return true;
    }
    if (k == LogicalKeyboardKey.arrowRight ||
        k == LogicalKeyboardKey.arrowUp ||
        k == LogicalKeyboardKey.pageUp) {
      _prev();
      return true;
    }
    return false;
  }
  final st = AppState.instance;

  void _next() {
    if (_page < totalPages) {
      _ctrl.nextPage(
          duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    }
  }

  void _prev() {
    if (_page > 1) {
      _ctrl.previousPage(
          duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    }
  }

  @override
  void initState() {
    super.initState();
    _page = widget.initialPage.clamp(1, totalPages);
    _ctrl = PageController(initialPage: _page - 1);
    st.setLastPage(_page);
    HardwareKeyboard.instance.addHandler(_onKey);
    WidgetsBinding.instance.addPostFrameCallback((_) => _precache(_page));
  }

  void _precache(int page) {
    for (final p in [page + 1, page + 2, page - 1]) {
      if (p >= 1 && p <= totalPages && mounted) {
        precacheImage(
          CachedNetworkImageProvider(pageImageUrl(p), cacheManager: mushafCache),
          context,
        ).catchError((_) {});
      }
    }
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    _ctrl.dispose();
    super.dispose();
  }

  void _goTo(int page) {
    _ctrl.jumpToPage(page - 1);
  }

  Future<void> _pickSurah() async {
    final s = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => ListView.builder(
        itemCount: 114,
        itemBuilder: (_, i) => ListTile(
          title: Text('${ar(i + 1)}. سورة ${surahNames[i]}'),
          trailing: Text('ص ${ar(surahStartPages[i])}'),
          onTap: () => Navigator.pop(ctx, i),
        ),
      ),
    );
    if (s != null) _goTo(surahStartPages[s]);
  }

  Future<void> _pickPage() async {
    final ctrl = TextEditingController();
    final p = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('انتقل إلى صفحة'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'من 1 إلى 604'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () {
              final v = int.tryParse(_toLatinDigits(ctrl.text.trim()));
              Navigator.pop(ctx, v);
            },
            child: const Text('انتقال'),
          ),
        ],
      ),
    );
    if (p != null && p >= 1 && p <= totalPages) _goTo(p);
  }

  String _toLatinDigits(String s) {
    const arabic = '٠١٢٣٤٥٦٧٨٩';
    final b = StringBuffer();
    for (final ch in s.split('')) {
      final i = arabic.indexOf(ch);
      b.write(i >= 0 ? '$i' : ch);
    }
    return b.toString();
  }

  @override
  Widget build(BuildContext context) {
    final surah = surahForPage(_page);
    final juz = juzForPage(_page);
    final bookmarked = st.bookmarks.contains(_page);

    return Scaffold(
      backgroundColor: const Color(0xFFFFFDF7),
      body: Column(
        children: [
          // الشريط العلوي
          Material(
            color: kGreen,
            elevation: 4,
            child: SafeArea(
              bottom: false,
              child: SizedBox(
                height: 56,
                child: Row(
                  children: [
                    const BackButton(color: Colors.white),
                    Expanded(
                      child: InkWell(
                        onTap: _pickSurah,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('سورة ${surahNames[surah - 1]}',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold)),
                            Text('الجزء ${juzNames[juz - 1]}',
                                style:
                                    const TextStyle(color: kGold, fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                          bookmarked ? Icons.bookmark : Icons.bookmark_border,
                          color: kGold),
                      tooltip: 'علامة',
                      onPressed: () async {
                        await st.toggleBookmark(_page);
                        if (!context.mounted) return;
                        setState(() {});
                        showSnack(
                            context,
                            st.bookmarks.contains(_page)
                                ? 'تم حفظ العلامة على صفحة ${ar(_page)}'
                                : 'تم حذف العلامة');
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: PageView.builder(
              controller: _ctrl,
              itemCount: totalPages,
              physics: _zoomed
                  ? const NeverScrollableScrollPhysics()
                  : const PageScrollPhysics(),
              onPageChanged: (i) {
                setState(() {
                  _page = i + 1;
                  _zoomed = false;
                });
                st.setLastPage(i + 1);
                _precache(i + 1);
              },
              itemBuilder: (context, i) => _PageImage(
                page: i + 1,
                onZoomChanged: (z) {
                  if (z != _zoomed) setState(() => _zoomed = z);
                },
              ),
            ),
          ),
          // الشريط السفلي
          Material(
              color: kGreen,
              elevation: 4,
              child: SafeArea(
                top: false,
                child: SizedBox(
                  height: 56,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      TextButton.icon(
                        onPressed: _pickSurah,
                        icon: const Icon(Icons.list, color: Colors.white),
                        label: const Text('الفهرس',
                            style: TextStyle(color: Colors.white)),
                      ),
                      IconButton(
                        tooltip: 'الصفحة السابقة',
                        onPressed: _prev,
                        icon: const Icon(Icons.chevron_right,
                            color: Colors.white, size: 30),
                      ),
                      TextButton(
                        onPressed: _pickPage,
                        child: Text('صفحة ${ar(_page)}',
                            style: const TextStyle(
                                color: kGold,
                                fontSize: 16,
                                fontWeight: FontWeight.bold)),
                      ),
                      IconButton(
                        tooltip: 'الصفحة التالية',
                        onPressed: _next,
                        icon: const Icon(Icons.chevron_left,
                            color: Colors.white, size: 30),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          final audio = QuranAudio.instance;
                          if (st.reciterServer == null) {
                            showSnack(context,
                                'اختار القارئ من شاشة "استماع" الأول');
                            return;
                          }
                          audio.playSurah(surah);
                          showSnack(context,
                              'جارِ تشغيل سورة ${surahNames[surah - 1]} - ${st.reciterName}');
                        },
                        icon: const Icon(Icons.play_circle_outline,
                            color: Colors.white),
                        label: const Text('استماع',
                            style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PageImage extends StatefulWidget {
  final int page;
  final ValueChanged<bool> onZoomChanged;
  const _PageImage({required this.page, required this.onZoomChanged});

  @override
  State<_PageImage> createState() => _PageImageState();
}

class _PageImageState extends State<_PageImage> {
  final TransformationController _tc = TransformationController();
  bool _zoomed = false;

  void _setZoom(bool z) {
    if (z == _zoomed) return;
    setState(() => _zoomed = z);
    widget.onZoomChanged(z);
  }

  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

  Widget _image(int page) => CachedNetworkImage(
        imageUrl: pageImageUrl(page),
        cacheManager: mushafCache,
        fit: BoxFit.contain,
        width: double.infinity,
        height: double.infinity,
        placeholder: (_, __) => Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: kGreen),
            const SizedBox(height: 12),
            Text('جارِ تحميل صفحة ${ar(page)}...'),
          ],
        ),
        errorWidget: (_, __, ___) => const Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off, size: 48, color: Colors.grey),
            SizedBox(height: 12),
            Text(
              'تعذّر تحميل الصفحة.\nاتصل بالإنترنت أول مرة، وبعدها تتحفظ على جهازك.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final page = widget.page;
    final img = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: _image(page),
    );
    // ضغطتين: تكبير / رجوع للحجم الطبيعي
    void toggleZoom() {
      if (_zoomed) {
        _tc.value = Matrix4.identity();
        _setZoom(false);
      } else {
        final size = context.size ?? Size.zero;
        _tc.value = Matrix4.diagonal3Values(2, 2, 1)
          ..setTranslationRaw(-size.width / 2, -size.height / 4, 0);
        _setZoom(true);
      }
    }

    if (!_zoomed) {
      // بدون تكبير: صورة عادية علشان السحب يقلّب الصفحات
      return GestureDetector(onDoubleTap: toggleZoom, child: img);
    }
    return GestureDetector(
      onDoubleTap: toggleZoom,
      child: InteractiveViewer(
        transformationController: _tc,
        minScale: 1,
        maxScale: 4,
        onInteractionEnd: (_) {
          if (_tc.value.getMaxScaleOnAxis() <= 1.05) {
            _tc.value = Matrix4.identity();
            _setZoom(false);
          }
        },
        child: img,
      ),
    );
  }
}
