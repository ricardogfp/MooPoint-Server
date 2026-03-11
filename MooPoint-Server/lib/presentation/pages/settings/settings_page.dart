import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:moo_point/app/theme/app_theme.dart';
import 'package:moo_point/services/notification/notification_service.dart';
import 'package:moo_point/presentation/providers/settings_provider.dart';
import 'package:moo_point/presentation/providers/herd_state.dart';
import 'package:moo_point/services/api/node_backend_auth_service.dart';
import 'package:moo_point/main.dart' show AuthGate;

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late TextEditingController _urlController;
  late TextEditingController _intervalController;
  bool? _connectionTestResult;
  bool _testingConnection = false;
  String? _intervalError;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsProvider>();
    _urlController = TextEditingController(text: settings.backendUrl);
    _intervalController =
        TextEditingController(text: settings.refreshInterval.toString());
  }

  @override
  void dispose() {
    _urlController.dispose();
    _intervalController.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    setState(() {
      _testingConnection = true;
      _connectionTestResult = null;
    });
    final result = await context.read<HerdState>().testConnection();
    if (mounted) {
      setState(() {
        _testingConnection = false;
        _connectionTestResult = result;
      });
    }
  }

  Future<void> _logout() async {
    final auth = NodeBackendAuthService();
    try {
      await auth.logout();
    } catch (e) {
      debugPrint('Logout error: $e');
    }
    auth.dispose();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthGate()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        // --- Appearance ---
        _SectionHeader(title: 'Appearance'),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                _ThemeTile(
                  title: 'System default',
                  icon: Icons.brightness_auto,
                  selected: settings.themeMode == ThemeMode.system,
                  onTap: () => settings.setThemeMode(ThemeMode.system),
                ),
                const Divider(height: 1, indent: 56),
                _ThemeTile(
                  title: 'Light',
                  icon: Icons.light_mode,
                  selected: settings.themeMode == ThemeMode.light,
                  onTap: () => settings.setThemeMode(ThemeMode.light),
                ),
                const Divider(height: 1, indent: 56),
                _ThemeTile(
                  title: 'Dark',
                  icon: Icons.dark_mode,
                  selected: settings.themeMode == ThemeMode.dark,
                  onTap: () => settings.setThemeMode(ThemeMode.dark),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 20),

        // --- Connection ---
        _SectionHeader(title: 'Connection'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _urlController,
                  decoration: const InputDecoration(
                    labelText: 'Backend URL',
                    hintText: 'Leave empty for default',
                    prefixIcon: Icon(Icons.link),
                  ),
                  onSubmitted: (v) => settings.setBackendUrl(v),
                ),
                const SizedBox(height: 6),
                Text(
                  'Changes take effect after restarting the app.',
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _intervalController,
                  decoration: InputDecoration(
                    labelText: 'Refresh interval (seconds)',
                    prefixIcon: const Icon(Icons.timer_outlined),
                    errorText: _intervalError,
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (v) {
                    final n = int.tryParse(v);
                    setState(() {
                      _intervalError = (n == null || n < 5 || n > 300)
                          ? 'Enter a value between 5 and 300 seconds'
                          : null;
                    });
                  },
                  onSubmitted: (v) {
                    final n = int.tryParse(v);
                    if (n != null && n >= 5 && n <= 300) {
                      settings.setRefreshInterval(n);
                    }
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Test connection
                    OutlinedButton.icon(
                      onPressed: _testingConnection ? null : _testConnection,
                      icon: _testingConnection
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              _connectionTestResult == null
                                  ? Icons.wifi_find_rounded
                                  : (_connectionTestResult!
                                      ? Icons.check_circle_outline
                                      : Icons.cancel_outlined),
                              color: _connectionTestResult == null
                                  ? null
                                  : (_connectionTestResult!
                                      ? Colors.green
                                      : Colors.red),
                            ),
                      label: Text(_connectionTestResult == null
                          ? 'Test Connection'
                          : (_connectionTestResult! ? 'Connected' : 'Failed')),
                    ),
                    FilledButton.tonal(
                      onPressed: _intervalError != null
                          ? null
                          : () {
                              settings.setBackendUrl(_urlController.text);
                              final n =
                                  int.tryParse(_intervalController.text);
                              if (n != null && n >= 5 && n <= 300) {
                                settings.setRefreshInterval(n);
                              }
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Settings saved')),
                              );
                            },
                      child: const Text('Save'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 20),

        // --- Notifications ---
        _SectionHeader(title: 'Notifications'),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                SwitchListTile(
                  secondary: Icon(Icons.fence,
                      color: settings.notifyGeofenceExit
                          ? MooColors.primary
                          : Colors.grey),
                  title: const Text('Geofence exit alerts'),
                  subtitle: const Text(
                      'Push notification when a node exits a geofence'),
                  value: settings.notifyGeofenceExit,
                  onChanged: (v) async {
                    await settings.setNotifyGeofenceExit(v);
                    if (v) {
                      await NotificationService().init();
                    }
                  },
                ),
                const Divider(height: 1, indent: 56),
                SwitchListTile(
                  secondary: Icon(Icons.battery_alert,
                      color: settings.notifyLowBattery
                          ? MooColors.primary
                          : Colors.grey),
                  title: const Text('Low battery alerts'),
                  subtitle: const Text(
                      'Push notification when battery drops below 20%'),
                  value: settings.notifyLowBattery,
                  onChanged: (v) async {
                    await settings.setNotifyLowBattery(v);
                    if (v) {
                      await NotificationService().init();
                    }
                  },
                ),
                const Divider(height: 1, indent: 56),
                SwitchListTile(
                  secondary: Icon(Icons.bolt_rounded,
                      color: settings.notifyFenceVoltage
                          ? MooColors.primary
                          : Colors.grey),
                  title: const Text('Fence voltage alerts'),
                  subtitle: const Text(
                      'Notification when fence voltage drops below threshold'),
                  value: settings.notifyFenceVoltage,
                  onChanged: (v) async {
                    await settings.setNotifyFenceVoltage(v);
                    if (v) {
                      await NotificationService().init();
                    }
                  },
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 20),

        // --- Account ---
        _SectionHeader(title: 'Account'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Session',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Sign Out'),
                          content: const Text(
                              'Are you sure you want to sign out?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Sign Out'),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true) await _logout();
                    },
                    icon: const Icon(Icons.logout_rounded, color: Colors.red),
                    label: const Text('Sign Out',
                        style: TextStyle(color: Colors.red)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 20),

        // --- About ---
        _SectionHeader(title: 'About'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const MooLogo(height: 32),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('MooPoint',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w700)),
                        Text('v$kAppVersion',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[500])),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Livestock tracking and monitoring system.',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

class _ThemeTile extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeTile({
    required this.title,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: selected ? MooColors.primary : Colors.grey),
      title: Text(title),
      trailing: selected
          ? const Icon(Icons.check_circle, color: MooColors.primary)
          : null,
      onTap: onTap,
    );
  }
}
