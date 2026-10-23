import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../app_state.dart';
import '../data/azkar.dart';
import '../utils.dart';

class AzkarScreen extends StatelessWidget {
  const AzkarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الأذكار')),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: azkarCategories.length,
        itemBuilder: (context, i) {
          final c = azkarCategories[i];
          return Card(
            color: Colors.white,
            elevation: 0,
            margin: const EdgeInsets.symmetric(vertical: 6),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(color: kGold.withValues(alpha: 0.4)),
            ),
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              leading: Text(c.icon, style: const TextStyle(fontSize: 32)),
              title: Text(c.title,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold, color: kGreen)),
              subtitle: Text('${ar(c.items.length)} ذكر'),
              trailing: const Icon(Icons.chevron_left, color: kGold),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => AzkarListScreen(category: c))),
            ),
          );
        },
      ),
    );
  }
}

class AzkarListScreen extends StatefulWidget {
  final AzkarCategory category;
  const AzkarListScreen({super.key, required this.category});

  @override
  State<AzkarListScreen> createState() => _AzkarListScreenState();
}

class _AzkarListScreenState extends State<AzkarListScreen> {
  late List<int> _remaining;
  final st = AppState.instance;

  @override
  void initState() {
    super.initState();
    _reset();
  }

  void _reset() {
    _remaining = widget.category.items.map((z) => z.count).toList();
  }

  void _tap(int i) {
    if (_remaining[i] <= 0) return;
    HapticFeedback.lightImpact();
    setState(() => _remaining[i]--);
    if (_remaining[i] == 0) {
      HapticFeedback.mediumImpact();
      if (_remaining.every((r) => r == 0)) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('تقبّل الله 🤍', textAlign: TextAlign.center),
            content: Text('أتممت ${widget.category.title}',
                textAlign: TextAlign.center),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('الحمد لله')),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final done = _remaining.where((r) => r == 0).length;
    final total = _remaining.length;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.category.title),
        actions: [
          IconButton(
            tooltip: 'تصغير الخط',
            icon: const Icon(Icons.text_decrease),
            onPressed: () {
              st.setAzkarFont((st.azkarFontSize - 2).clamp(14, 40).toDouble());
              setState(() {});
            },
          ),
          IconButton(
            tooltip: 'تكبير الخط',
            icon: const Icon(Icons.text_increase),
            onPressed: () {
              st.setAzkarFont((st.azkarFontSize + 2).clamp(14, 40).toDouble());
              setState(() {});
            },
          ),
          IconButton(
            tooltip: 'إعادة',
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(_reset),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: total == 0 ? 0 : done / total,
            color: kGold,
            backgroundColor: Colors.white24,
          ),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        itemCount: widget.category.items.length,
        itemBuilder: (context, i) {
          final z = widget.category.items[i];
          final rem = _remaining[i];
          final finished = rem == 0;
          return AnimatedOpacity(
            duration: const Duration(milliseconds: 250),
            opacity: finished ? 0.55 : 1,
            child: Card(
              color: finished ? const Color(0xFFEFF6F2) : Colors.white,
              elevation: finished ? 0 : 1,
              margin: const EdgeInsets.symmetric(vertical: 6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: BorderSide(
                    color: finished ? kGreen.withValues(alpha: 0.3) : kGold.withValues(alpha: 0.35)),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => _tap(i),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        z.text,
                        textAlign: TextAlign.justify,
                        style: GoogleFonts.amiri(
                          fontSize: st.azkarFontSize,
                          height: 1.9,
                          color: Colors.black87,
                        ),
                      ),
                      if (z.source.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(z.source,
                            style: TextStyle(
                                fontSize: 13, color: Colors.grey.shade600)),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Text(
                            z.count > 1 ? 'التكرار: ${ar(z.count)}' : 'مرة واحدة',
                            style: const TextStyle(color: kGreen),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 18, vertical: 8),
                            decoration: BoxDecoration(
                              color: finished ? kGreen : kGold,
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: finished
                                ? const Icon(Icons.check,
                                    color: Colors.white, size: 20)
                                : Text(ar(rem),
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
