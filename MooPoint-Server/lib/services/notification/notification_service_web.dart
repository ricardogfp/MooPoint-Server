import 'dart:js_interop';
import 'package:web/web.dart' as web;
import 'package:moo_point/services/notification/notification_service_interface.dart';

@JS('Notification')
external JSObject? get _notificationClass;

NotificationServiceInterface create() => _WebNotificationService();

class _WebNotificationService implements NotificationServiceInterface {
  bool _granted = false;

  @override
  Future<void> init() async {
    try {
      // Check if browser supports notifications (WASM safe check)
      if (_notificationClass == null) {
        _granted = false;
        return;
      }

      final perm = web.Notification.permission;
      if (perm == 'granted') {
        _granted = true;
        return;
      }
      if (perm == 'denied') return;

      final result = await web.Notification.requestPermission().toDart;
      _granted = result.toDart == 'granted';
    } catch (_) {
      _granted = false;
    }
  }

  @override
  void show({required String title, required String body}) {
    if (!_granted) return;
    try {
      if (_notificationClass == null) return;

      final options = web.NotificationOptions(body: body);
      web.Notification(title, options);
    } catch (_) {}
  }
}
