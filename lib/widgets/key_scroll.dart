import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// رقم التبويب الظاهر حاليًا في الشاشة الرئيسية
final ValueNotifier<int> currentTab = ValueNotifier<int>(0);

/// يخلّي أسهم الكيبورد (↑ ↓) و PageUp/PageDown تحرّك القائمة لفوق ولتحت.
/// يشتغل بغض النظر عن مكان الضغط بالماوس.
class KeyScroll extends StatefulWidget {
  /// رقم التبويب (للشاشات الرئيسية)، أو null للشاشات المفتوحة فوقها
  final int? tab;
  final Widget Function(BuildContext context, ScrollController controller)
      builder;
  const KeyScroll({super.key, this.tab, required this.builder});

  @override
  State<KeyScroll> createState() => _KeyScrollState();
}

class _KeyScrollState extends State<KeyScroll> {
  final ScrollController _ctrl = ScrollController();

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    _ctrl.dispose();
    super.dispose();
  }

  bool get _active {
    if (!mounted || !_ctrl.hasClients) return false;
    if (widget.tab != null && currentTab.value != widget.tab) return false;
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) return false;
    return true;
  }

  bool _onKey(KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) return false;
    if (!_active) return false;
    // لا نتدخل لو المستخدم بيكتب في خانة نص
    final focusCtx = FocusManager.instance.primaryFocus?.context;
    if (focusCtx != null &&
        (focusCtx.widget is EditableText ||
            focusCtx.findAncestorWidgetOfExactType<EditableText>() != null)) {
      return false;
    }
    final pos = _ctrl.position;
    final page = pos.viewportDimension * 0.85;
    double? delta;
    final k = e.logicalKey;
    if (k == LogicalKeyboardKey.arrowDown) delta = 90;
    if (k == LogicalKeyboardKey.arrowUp) delta = -90;
    if (k == LogicalKeyboardKey.pageDown) delta = page;
    if (k == LogicalKeyboardKey.pageUp) delta = -page;
    if (k == LogicalKeyboardKey.home) delta = -pos.pixels;
    if (k == LogicalKeyboardKey.end) delta = pos.maxScrollExtent - pos.pixels;
    if (delta == null) return false;
    final target =
        (pos.pixels + delta).clamp(pos.minScrollExtent, pos.maxScrollExtent);
    _ctrl.animateTo(target.toDouble(),
        duration: const Duration(milliseconds: 150), curve: Curves.easeOut);
    return true;
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _ctrl);
}
