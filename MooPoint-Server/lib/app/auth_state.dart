import 'package:flutter/foundation.dart';

/// Signals the root AuthGate to re-check authentication status.
/// Used by SettingsPage to trigger logout without importing main.dart.
class AuthState extends ChangeNotifier {
  bool _needsReAuth = false;
  bool get needsReAuth => _needsReAuth;

  void triggerReAuth() {
    _needsReAuth = true;
    notifyListeners();
  }

  void reset() {
    _needsReAuth = false;
  }
}
