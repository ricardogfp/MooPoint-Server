import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persisted app settings exposed as a ChangeNotifier.
class SettingsProvider extends ChangeNotifier {
  static const _keyThemeMode = 'theme_mode'; // 'light', 'dark', 'system'
  static const _keyBackendUrl = 'backend_url';
  static const _keyRefreshInterval = 'refresh_interval'; // seconds
  static const _keyNotifyGeofenceExit = 'notify_geofence_exit';
  static const _keyNotifyLowBattery = 'notify_low_battery';
  static const _keyNotifyFenceVoltage = 'notify_fence_voltage';
  static const _keyLocale = 'locale'; // 'en', 'es', or '' for system
  static const _keySidebarExpanded = 'sidebar_expanded';
  static const _keyUsername = 'username';

  SharedPreferences? _prefs;

  // --- Theme ---
  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  // --- Backend URL override (empty = use default) ---
  String _backendUrl = '';
  String get backendUrl => _backendUrl;

  // --- Refresh interval in seconds ---
  int _refreshInterval = 30;
  int get refreshInterval => _refreshInterval;

  // --- Notification preferences ---
  bool _notifyGeofenceExit = true;
  bool get notifyGeofenceExit => _notifyGeofenceExit;

  bool _notifyLowBattery = true;
  bool get notifyLowBattery => _notifyLowBattery;

  bool _notifyFenceVoltage = true;
  bool get notifyFenceVoltage => _notifyFenceVoltage;

  // --- Locale ('' = system default) ---
  String _locale = '';
  String get locale => _locale;

  // --- Sidebar expanded state (desktop) ---
  bool _sidebarExpanded = false;
  bool get sidebarExpanded => _sidebarExpanded;

  // --- Logged-in username ---
  String _username = '';
  String get username => _username;

  /// Call once at app startup.
  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final mode = _prefs!.getString(_keyThemeMode) ?? 'system';
    _themeMode = _themeModeFromString(mode);
    _backendUrl = _prefs!.getString(_keyBackendUrl) ?? '';
    _refreshInterval = _prefs!.getInt(_keyRefreshInterval) ?? 30;
    _notifyGeofenceExit = _prefs!.getBool(_keyNotifyGeofenceExit) ?? true;
    _notifyLowBattery = _prefs!.getBool(_keyNotifyLowBattery) ?? true;
    _notifyFenceVoltage = _prefs!.getBool(_keyNotifyFenceVoltage) ?? true;
    _locale = _prefs!.getString(_keyLocale) ?? '';
    _sidebarExpanded = _prefs!.getBool(_keySidebarExpanded) ?? false;
    _username = _prefs!.getString(_keyUsername) ?? '';
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    await _prefs?.setString(_keyThemeMode, _themeModeToString(mode));
    notifyListeners();
  }

  Future<void> setBackendUrl(String url) async {
    _backendUrl = url.trim();
    await _prefs?.setString(_keyBackendUrl, _backendUrl);
    notifyListeners();
  }

  Future<void> setRefreshInterval(int seconds) async {
    _refreshInterval = seconds.clamp(5, 300);
    await _prefs?.setInt(_keyRefreshInterval, _refreshInterval);
    notifyListeners();
  }

  Future<void> setNotifyGeofenceExit(bool v) async {
    _notifyGeofenceExit = v;
    await _prefs?.setBool(_keyNotifyGeofenceExit, v);
    notifyListeners();
  }

  Future<void> setNotifyLowBattery(bool v) async {
    _notifyLowBattery = v;
    await _prefs?.setBool(_keyNotifyLowBattery, v);
    notifyListeners();
  }

  Future<void> setNotifyFenceVoltage(bool v) async {
    _notifyFenceVoltage = v;
    await _prefs?.setBool(_keyNotifyFenceVoltage, v);
    notifyListeners();
  }

  Future<void> setLocale(String code) async {
    _locale = code;
    await _prefs?.setString(_keyLocale, code);
    notifyListeners();
  }

  Future<void> setSidebarExpanded(bool v) async {
    _sidebarExpanded = v;
    await _prefs?.setBool(_keySidebarExpanded, v);
    notifyListeners();
  }

  Future<void> setUsername(String name) async {
    _username = name;
    await _prefs?.setString(_keyUsername, name);
    notifyListeners();
  }

  // --- helpers ---
  static ThemeMode _themeModeFromString(String s) {
    switch (s) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  static String _themeModeToString(ThemeMode m) {
    switch (m) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }
}
