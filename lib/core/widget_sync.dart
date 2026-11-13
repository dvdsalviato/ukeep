import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

/// Aggiorna il widget sulla schermata Home del telefono.
class WidgetSync {
  WidgetSync._();
  static String _last = '';

  static Future<void> update({
    required String together,
    required List<String> today,
    required String next,
  }) async {
    final count = today.isEmpty
        ? 'Oggi niente da fare 🎉'
        : (today.length == 1 ? '1 cosa da fare oggi' : '${today.length} cose da fare oggi');
    final tasks = today.take(4).map((t) => '•  $t').join('\n');
    final sig = '$together|$count|$tasks|$next';
    if (sig == _last) return;
    _last = sig;
    try {
      await HomeWidget.saveWidgetData<String>('together', together);
      await HomeWidget.saveWidgetData<String>('count', count);
      await HomeWidget.saveWidgetData<String>('tasks', tasks);
      await HomeWidget.saveWidgetData<String>('next', next);
      await HomeWidget.updateWidget(androidName: 'UkeepWidget');
    } catch (e) {
      debugPrint('Widget: $e');
    }
  }
}
