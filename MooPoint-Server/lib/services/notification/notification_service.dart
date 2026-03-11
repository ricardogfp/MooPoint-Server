import 'package:moo_point/services/notification/notification_service_interface.dart';
import 'notification_service_stub.dart'
    if (dart.library.js_interop) 'notification_service_web.dart' as platform;

/// Cross-platform notification service.
/// - Web: browser Notification API.
/// - Android: placeholder for Firebase FCM (requires native config).
class NotificationService implements NotificationServiceInterface {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final NotificationServiceInterface _delegate = platform.create();

  @override
  Future<void> init() => _delegate.init();

  @override
  void show({required String title, required String body}) =>
      _delegate.show(title: title, body: body);
}
