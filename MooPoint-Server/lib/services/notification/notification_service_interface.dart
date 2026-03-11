/// Abstract interface for platform-specific notification implementations.
abstract class NotificationServiceInterface {
  Future<void> init();
  void show({required String title, required String body});
}
