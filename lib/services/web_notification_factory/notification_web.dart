import 'dart:html' as html;

Future<void> requestWebNotificationPermission() async {
  try {
    if (html.Notification.permission != 'granted') {
      await html.Notification.requestPermission();
    }
  } catch (_) {}
}

Future<void> showWebNotification(String title, String body) async {
  try {
    if (html.Notification.permission == 'granted') {
      html.Notification(title, body: body, icon: 'icons/Icon-192.png');
    }
  } catch (_) {}
}
