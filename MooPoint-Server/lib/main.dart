import 'package:flutter/material.dart';
import 'package:moo_point/l10n/app_localizations.dart';
import 'l10n/l10n_helper.dart';

import 'package:flutter/services.dart';

import 'package:provider/provider.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import 'package:moo_point/services/storage/app_config.dart';
import 'package:moo_point/app/theme/app_theme.dart';
import 'package:moo_point/presentation/pages/dashboard/dashboard_page.dart';
import 'package:moo_point/services/api/node_backend_config.dart';
import 'package:moo_point/services/notification/notification_service.dart';
import 'package:moo_point/data/models/geofence_event_model.dart';
import 'package:moo_point/presentation/providers/herd_state.dart';
import 'package:moo_point/presentation/pages/map/map_page.dart';
import 'package:moo_point/presentation/pages/herd/herd_page.dart';
import 'package:moo_point/presentation/pages/geofences/geofences_page.dart';
import 'package:moo_point/presentation/pages/alerts/alerts_page.dart';
import 'package:moo_point/presentation/pages/analytics/analytics_page.dart';

import 'package:moo_point/services/api/node_backend_auth_service.dart';

import 'package:moo_point/presentation/pages/settings/settings_page.dart';

import 'package:moo_point/presentation/providers/settings_provider.dart';
import 'package:moo_point/presentation/providers/navigation_provider.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'dart:convert';
import 'dart:async';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await AppConfig.load();

  final settingsProvider = SettingsProvider();

  await settingsProvider.load();

  // Init push notifications

  await NotificationService().init();

  // Ensure system UI (navigation bar) doesn't overlap Flutter UI

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settingsProvider),
        ChangeNotifierProvider(create: (context) => HerdState(settings: context.read<SettingsProvider>())),
        ChangeNotifierProvider(create: (_) => NavigationIndexProvider()),
      ],
      child: const MooPointApp(),
    ),
  );
}

class MooPointApp extends StatelessWidget {
  const MooPointApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final themeMode = settings.themeMode;
    final localeCode = settings.locale;

    return MaterialApp(
      title: 'MooPoint',
      theme: mooLightTheme(),
      darkTheme: mooDarkTheme(),
      themeMode: themeMode,
      locale: localeCode.isEmpty ? null : Locale(localeCode),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: const AuthGate(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate();

  @override
  State<AuthGate> createState() => AuthGateState();
}

class AuthGateState extends State<AuthGate> {
  final _auth = NodeBackendAuthService();

  Future<String?>? _future;

  @override
  void initState() {
    super.initState();

    _future = _auth.me();
  }

  @override
  void dispose() {
    _auth.dispose();

    super.dispose();
  }

  void _onLoggedIn() {
    setState(() {
      _future = _auth.me();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }

        final username = snap.data;

        final isAuthed = username != null && username.isNotEmpty;

        if (!isAuthed) {
          return _LoginPage(onLoggedIn: _onLoggedIn);
        }

        // Store username for display in dashboard
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            context.read<SettingsProvider>().setUsername(username!);
          }
        });

        return const HomePage();
      },
    );
  }
}

class _LoginPage extends StatefulWidget {
  final VoidCallback onLoggedIn;

  const _LoginPage({required this.onLoggedIn});

  @override
  State<_LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<_LoginPage> {
  final _auth = NodeBackendAuthService();

  final _usernameController = TextEditingController();

  final _passwordController = TextEditingController();

  bool _isSubmitting = false;

  String? _error;

  @override
  void dispose() {
    _auth.dispose();

    _usernameController.dispose();

    _passwordController.dispose();

    super.dispose();
  }

  Future<void> _login() async {
    setState(() {
      _isSubmitting = true;

      _error = null;
    });

    try {
      await _auth.login(
        username: _usernameController.text.trim(),
        password: _passwordController.text,
      );

      final me = await _auth.me();

      if (me == null || me.isEmpty) {
        throw Exception('Login succeeded but session is not established.');
      }

      if (!mounted) return;

      // Store username for display across the app
      context.read<SettingsProvider>().setUsername(me!);

      widget.onLoggedIn();
    } catch (e) {
      if (!mounted) return;

      String errorMsg = e.toString();
      // Clean up common technical prefix
      if (errorMsg.startsWith('Exception: ')) {
        errorMsg = errorMsg.substring(11);
      }

      // Map technical errors to friendly messages
      if (errorMsg.contains('401') ||
          errorMsg.toLowerCase().contains('invalid credentials')) {
        errorMsg = 'Invalid username or password. Please try again.';
      } else if (errorMsg.contains('502') ||
          errorMsg.toLowerCase().contains('connection') ||
          errorMsg.toLowerCase().contains('socket')) {
        errorMsg =
            'Cannot connect to server. Please check your internet connection or try again later.';
      }

      setState(() {
        _error = errorMsg;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: MooColors.brandGradient),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const MooLogo(height: 80),
                    const SizedBox(height: 16),
                    const Text(
                      'MooPoint',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Livestock Tracking System',
                      style: TextStyle(
                          fontSize: 14, color: Colors.white.withOpacity(0.8)),
                    ),
                    const SizedBox(height: 32),
                    Card(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                      elevation: 8,
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Sign In',
                              style: TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 20),
                            TextField(
                              controller: _usernameController,
                              enabled: !_isSubmitting,
                              decoration: const InputDecoration(
                                labelText: 'Username',
                                prefixIcon: Icon(Icons.person_outline),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _passwordController,
                              enabled: !_isSubmitting,
                              obscureText: true,
                              decoration: const InputDecoration(
                                labelText: 'Password',
                                prefixIcon: Icon(Icons.lock_outline),
                              ),
                            ),
                            if (_error != null && _error!.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.error_outline,
                                        color: Colors.red, size: 18),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(_error!,
                                          style: const TextStyle(
                                              color: Colors.red, fontSize: 13)),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _isSubmitting ? null : _login,
                                child: _isSubmitting
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white),
                                      )
                                    : const Text('Sign In'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'v$kAppVersion',
                      style: TextStyle(
                          fontSize: 12, color: Colors.white.withOpacity(0.6)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

// HomePage — bottom navigation shell with Map / Herd / Events / Admin tabs

// ---------------------------------------------------------------------------

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  static final GlobalKey<MapPageState> mapKey = GlobalKey<MapPageState>();

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final NodeBackendAuthService _auth = NodeBackendAuthService();
  int _currentIndex = 0;
  WebSocketChannel? _ws;
  NavigationIndexProvider? _navProvider;

  @override
  void initState() {
    super.initState();
    _connectWs();
    // Kick off the initial data load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = context.read<HerdState>();
      state.loadNodesAndGeofences();
      state.loadAlerts();
      // Listen for tab navigation requests from child pages
      _navProvider = context.read<NavigationIndexProvider>();
      _navProvider!.addListener(_onNavIndexChanged);
    });
  }

  void _onNavIndexChanged() {
    if (!mounted) return;
    final requestedIndex = _navProvider?.index ?? 0;
    if (_currentIndex != requestedIndex) {
      _onTabTapped(requestedIndex);
    }
  }

  @override
  void dispose() {
    _navProvider?.removeListener(_onNavIndexChanged);
    try {
      _ws?.sink.close();
    } catch (e) {
      debugPrint('WebSocket close error: $e');
    }
    _auth.dispose();
    super.dispose();
  }

  void _connectWs() {
    try {
      _ws?.sink.close();
    } catch (e) {
      debugPrint('WebSocket close error: $e');
    }
    try {
      final url = NodeBackendConfig.wsUrl();
      _ws = WebSocketChannel.connect(Uri.parse(url));
      _ws!.stream.listen(
        (msg) {
          try {
            final decoded = jsonDecode(msg);
            if (decoded is! Map<String, dynamic>) return;
            if (!mounted) return;
            final type = decoded['type'];

            if (type == 'position_update') {
              final nodes = decoded['nodes'] ?? decoded['cows'];
              if (nodes is List) {
                context.read<HerdState>().applyPositionUpdate(
                      nodes.cast<Map<String, dynamic>>(),
                    );
              }
              return;
            }
            // Fence nodes report battery/voltage only (no GPS).
            // Server broadcasts this instead of position_update for fence nodes.
            if (type == 'telemetry_update') {
              context.read<HerdState>().applyTelemetryUpdate(
                decoded.cast<String, dynamic>(),
              );
              return;
            }
            if (type == 'node_alert') {
              final nodeId = decoded['nodeId'] as int;
              final nodeName = decoded['nodeName'] ?? 'Node $nodeId';
              final message = decoded['message'] ?? 'Alert received';
              final alertType = decoded['alertType'];

              // Persist alert in HerdState
              context.read<HerdState>().addAlertFromNodeEvent(decoded);

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('⚡ $message'),
                  backgroundColor: alertType == 'voltage_low'
                      ? Colors.orange.shade800
                      : Colors.blue,
                  duration: const Duration(seconds: 10),
                  action: SnackBarAction(
                    label: 'ALERTS',
                    textColor: Colors.white,
                    onPressed: () => _onTabTapped(4),
                  ),
                ),
              );

              if (context.read<SettingsProvider>().notifyGeofenceExit) {
                NotificationService().show(
                  title: 'Device Alert: $nodeName',
                  body: message,
                );
              }
              return;
            }

            if (type == 'geofence_exit') {
              final ev = GeofenceEvent.fromJson(decoded);
              final herd = context.read<HerdState>();
              // Track for geofence coloring + persist as alert
              herd.recordGeofenceExit(ev.nodeId, ev.geofenceId);
              herd.addAlertFromGeofenceExit(ev);
              final fence = ev.geofenceName ?? 'Geofence ${ev.geofenceId}';
              final node = ev.nodeName ?? 'Node ${ev.nodeId}';
              // In-app snackbar
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('⚠️ $node exited $fence'),
                  backgroundColor: Colors.red,
                  duration: const Duration(seconds: 8),
                  action: SnackBarAction(
                    label: 'ALERTS',
                    textColor: Colors.white,
                    onPressed: () => _onTabTapped(4),
                  ),
                ),
              );
              // Push notification
              final settings = context.read<SettingsProvider>();
              if (settings.notifyGeofenceExit) {
                NotificationService().show(
                  title: 'Geofence Alert',
                  body: '$node exited $fence',
                );
              }
              return;
            }
          } catch (e) {
            debugPrint('WebSocket message error: $e');
          }
        },
        onError: (e) => debugPrint('WebSocket error: $e'),
        onDone: () {
          // Auto-reconnect after 3 seconds
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted) _connectWs();
          });
        },
      );
    } catch (e) {
      debugPrint('WebSocket connect error: $e');
      _ws = null;
    }
  }

  Future<void> _logout() async {
    try {
      await _auth.logout();
    } catch (e) {
      debugPrint('Logout error: $e');
    }
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const AuthGate()),
      (_) => false,
    );
  }

  void _onTabTapped(int index) {
    if (index == _currentIndex) return;
    setState(() => _currentIndex = index);
    // Refresh when switching to data tabs
    if (index == 3) {
      context.read<HerdState>().loadNodesAndGeofences();
    }
    if (index == 4) {
      context.read<HerdState>().loadAlerts();
    }
  }

  List<({IconData icon, String label, int index})> _getNavItems(
          AppLocalizations l10n) =>
      [
        (icon: Icons.dashboard_outlined, label: l10n.dashboard, index: 0),
        (icon: Icons.map_outlined, label: l10n.map, index: 1),
        (icon: MdiIcons.cow, label: l10n.herd, index: 2),
        (icon: MdiIcons.fence, label: 'Geofences', index: 3),
        (icon: Icons.notifications_rounded, label: 'Alerts', index: 4),
        (icon: Icons.bar_chart_rounded, label: 'Analytics', index: 5),
        (icon: Icons.settings_outlined, label: l10n.settings, index: 6),
      ];

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final isWide = MediaQuery.sizeOf(context).width >= 900;
    final navItems = _getNavItems(l10n);
    final settings = context.watch<SettingsProvider>();

    final body = IndexedStack(
      index: _currentIndex,
      children: [
        const DashboardPage(),
        MapPage(key: HomePage.mapKey),
        const HerdPage(),
        const GeofencesPage(),
        const AlertsPage(),
        const AnalyticsPage(),
        const SettingsPage(),
      ],
    );

    final navShell = Row(
      children: [
        if (isWide)
          _CollapsibleSidebar(
            currentIndex: _currentIndex,
            onTap: _onTabTapped,
            navItems: navItems,
            expanded: settings.sidebarExpanded,
            onToggle: () =>
                settings.setSidebarExpanded(!settings.sidebarExpanded),
          ),
        Expanded(
          child: Column(
            children: [
              // Custom Header (replaces AppBar for full-height sidebar look)
              Container(
                height: 70,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Theme.of(context).appBarTheme.backgroundColor,
                  border: Border(
                    bottom: BorderSide(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? MooColors.borderDark
                          : MooColors.borderLight,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    if (!isWide)
                      IconButton(
                        icon: const Icon(Icons.menu),
                        onPressed: () {
                          // TODO: Implement mobile drawer if needed
                        },
                      ),

                    // --- Search Bar ---
                    Expanded(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 400),
                        child: Container(
                          height: 40,
                          decoration: BoxDecoration(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? MooColors.bgDark
                                    : MooColors.bgLight,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? MooColors.borderDark
                                  : MooColors.borderLight,
                            ),
                          ),
                          child: TextField(
                            decoration: InputDecoration(
                              hintText: l10n.searchDevices,
                              hintStyle: const TextStyle(
                                  fontSize: 13, color: Colors.grey),
                              prefixIcon: const Icon(Icons.search,
                                  size: 18, color: Colors.grey),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              filled: false,
                              contentPadding:
                                  const EdgeInsets.symmetric(vertical: 10),
                            ),
                            onSubmitted: (val) {
                              if (val.isEmpty) return;
                              final state = context.read<HerdState>();
                              final match = state.nodes
                                  .where((n) =>
                                      n.nodeId
                                          .toString()
                                          .toLowerCase()
                                          .contains(val.toLowerCase()) ||
                                      n
                                          .getName()
                                          .toLowerCase()
                                          .contains(val.toLowerCase()) ||
                                      (n.deviceId
                                              ?.toString()
                                              .toLowerCase()
                                              .contains(val.toLowerCase()) ??
                                          false))
                                  .firstOrNull;

                              if (match != null) {
                                setState(() => _currentIndex = 1);
                                Future.delayed(
                                    const Duration(milliseconds: 100), () {
                                  HomePage.mapKey.currentState
                                      ?.selectNode(match);
                                });
                              }
                            },
                          ),
                        ),
                      ),
                    ),

                    const Spacer(),

                    // Actions
                    IconButton(
                      icon: Icon(
                        Theme.of(context).brightness == Brightness.dark
                            ? Icons.light_mode_outlined
                            : Icons.dark_mode_outlined,
                      ),
                      onPressed: () {
                        settings.setThemeMode(
                          Theme.of(context).brightness == Brightness.dark
                              ? ThemeMode.light
                              : ThemeMode.dark,
                        );
                      },
                      tooltip: l10n.theme,
                    ),
                    Stack(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.notifications_none_rounded),
                          onPressed: () => _onTabTapped(4),
                          tooltip: l10n.notifications,
                        ),
                        Positioned(
                          right: 8,
                          top: 8,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.logout_rounded),
                      onPressed: _logout,
                      tooltip: l10n.logout,
                    ),
                  ],
                ),
              ),
              Expanded(child: body),
            ],
          ),
        ),
      ],
    );

    return Scaffold(
      body: navShell,
      bottomNavigationBar: isWide
          ? null
          : NavigationBar(
              selectedIndex: _currentIndex,
              onDestinationSelected: _onTabTapped,
              destinations: navItems
                  .map((n) => NavigationDestination(
                        icon: Icon(n.icon),
                        label: n.label,
                      ))
                  .toList(),
            ),
    );
  }
}

class _CollapsibleSidebar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final List<({IconData icon, String label, int index})> navItems;
  final bool expanded;
  final VoidCallback onToggle;

  const _CollapsibleSidebar({
    required this.currentIndex,
    required this.onTap,
    required this.navItems,
    required this.expanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final width = expanded ? 240.0 : 70.0;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: width,
      decoration: BoxDecoration(
        color: isDark ? MooColors.surfaceDark : MooColors.surfaceLight,
        border: Border(
          right: BorderSide(
            color: isDark ? MooColors.borderDark : MooColors.borderLight,
          ),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 20),
          // Logo & Branding
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const MooLogo(height: 32),
                if (expanded) ...[
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'MooPoint',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'v4.2.0',
                          style: TextStyle(fontSize: 10, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 40),
          // Main Nav
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                ...navItems.map((item) => _SidebarItem(
                      item: item,
                      isSelected: currentIndex == item.index,
                      expanded: expanded,
                      onTap: () => onTap(item.index),
                    )),
              ],
            ),
          ),
          // Toggle Button
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: InkWell(
              onTap: onToggle,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isDark
                      ? MooColors.bgDark.withOpacity(0.5)
                      : MooColors.bgLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  expanded
                      ? Icons.keyboard_double_arrow_left_rounded
                      : Icons.keyboard_double_arrow_right_rounded,
                  size: 20,
                  color: Colors.grey,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final ({IconData icon, String label, int index}) item;
  final bool isSelected;
  final bool expanded;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.item,
    required this.isSelected,
    required this.expanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? MooColors.primary : Colors.grey.shade500;
    final bgColor =
        isSelected ? MooColors.primary.withOpacity(0.1) : Colors.transparent;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisAlignment:
                expanded ? MainAxisAlignment.start : MainAxisAlignment.center,
            children: [
              Icon(item.icon, color: color, size: 22),
              if (expanded) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected
                          ? (Theme.of(context).brightness == Brightness.dark
                              ? Colors.white
                              : Colors.black)
                          : color,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}


// NodeMapPage public alias

// Keep CowMapPage as a public alias for backward compatibility (AdminPage references it)

class NodeMapPage extends StatelessWidget {
  const NodeMapPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => HerdState(settings: context.read<SettingsProvider>()),
      child: const HomePage(),
    );
  }
}
