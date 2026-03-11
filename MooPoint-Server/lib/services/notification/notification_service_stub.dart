import 'package:moo_point/services/notification/notification_service_interface.dart';

/// Stub implementation for non-web platforms (Android, iOS, desktop).
/// Replace with firebase_messaging / flutter_local_notifications when ready.
NotificationServiceInterface create() => _StubNotificationService();

class _StubNotificationService implements NotificationServiceInterface {
  @override
  Future<void> init() async {
    // Android FCM init would go here.
  }

  @override
  void show({required String title, required String body}) {
    // Android local notification would go here.
  }
}
