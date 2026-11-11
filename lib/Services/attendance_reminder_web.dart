import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

Timer? _reminderTimer;

Future<void> scheduleBrowserAttendanceReminder({
  required DateTime scheduledAt,
  required String title,
  required String body,
}) async {
  _reminderTimer?.cancel();
  if (scheduledAt.isBefore(DateTime.now())) return;

  if (web.Notification.permission != 'granted') {
    await web.Notification.requestPermission().toDart;
  }
  if (web.Notification.permission != 'granted') return;

  _reminderTimer = Timer(scheduledAt.difference(DateTime.now()), () {
    web.Notification(title, web.NotificationOptions(body: body));
  });
}

Future<void> cancelBrowserAttendanceReminder() async {
  _reminderTimer?.cancel();
  _reminderTimer = null;
}
