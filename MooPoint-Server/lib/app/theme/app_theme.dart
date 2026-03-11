import 'package:flutter/material.dart';
import 'package:moo_point/data/models/node_model.dart';

// ---------------------------------------------------------------------------
// MooPoint brand colours
// ---------------------------------------------------------------------------
class MooColors {
  MooColors._();

  static const Color primary = Color(0xFF276FD8);
  static const Color primaryDark = Color(0xFF1A5BBF);
  static const Color secondary = Color(0xFF3727D8);
  static const Color accent = Color(0xFF27C8D8);

  // Status
  static const Color active = Color(0xFF22C55E);
  static const Color offline = Color(0xFF9E9E9E);
  static const Color lowBattery = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);

  // Battery
  static const Color battGood = Color(0xFF22C55E);
  static const Color battMedium = Color(0xFFF59E0B);
  static const Color battLow = Color(0xFFFF5722);
  static const Color battCritical = Color(0xFFEF4444);

  // Dark theme surfaces (slate palette from HTML)
  static const Color bgDark = Color(0xFF0F172A);
  static const Color surfaceDark = Color(0xFF1E293B);
  static const Color borderDark = Color(0xFF334155);

  // Light theme surfaces
  static const Color bgLight = Color(0xFFF8FAFC);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color borderLight = Color(0xFFE2E8F0);

  // Fence accent
  static const Color fenceBrown = Color(0xFF8B4513);

  // Gradient used on login & splash
  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, secondary, accent],
  );
}

// ---------------------------------------------------------------------------
// Light theme
// ---------------------------------------------------------------------------
ThemeData mooLightTheme() {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: MooColors.primary,
    primary: MooColors.primary,
    secondary: MooColors.secondary,
    tertiary: MooColors.accent,
    brightness: Brightness.light,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    fontFamily: 'Inter',
    scaffoldBackgroundColor: MooColors.bgLight,
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: MooColors.borderLight),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: MooColors.surfaceLight,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: MooColors.surfaceLight,
      foregroundColor: colorScheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      shape: const Border(bottom: BorderSide(color: MooColors.borderLight)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: MooColors.surfaceLight,
      indicatorColor: MooColors.primary.withValues(alpha: 0.15),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: MooColors.primary,
          );
        }
        return TextStyle(fontSize: 12, color: Colors.grey.shade600);
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: MooColors.primary);
        }
        return IconThemeData(color: Colors.grey.shade600);
      }),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: MooColors.surfaceLight,
      indicatorColor: MooColors.primary.withValues(alpha: 0.15),
      selectedIconTheme: const IconThemeData(color: MooColors.primary),
      unselectedIconTheme: IconThemeData(color: Colors.grey.shade600),
      selectedLabelTextStyle: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: MooColors.primary,
      ),
      unselectedLabelTextStyle: TextStyle(
        fontSize: 12,
        color: Colors.grey.shade600,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: MooColors.borderLight),
      ),
      filled: true,
      fillColor: MooColors.bgLight,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: MooColors.primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: MooColors.primary,
        side: const BorderSide(color: MooColors.borderLight),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      ),
    ),
    dividerTheme:
        const DividerThemeData(color: MooColors.borderLight, thickness: 1),
    tabBarTheme: const TabBarThemeData(
      labelColor: MooColors.primary,
      indicatorColor: MooColors.primary,
    ),
  );
}

// ---------------------------------------------------------------------------
// Dark theme
// ---------------------------------------------------------------------------
ThemeData mooDarkTheme() {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: MooColors.primary,
    primary: MooColors.primary,
    secondary: MooColors.secondary,
    tertiary: MooColors.accent,
    brightness: Brightness.dark,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    fontFamily: 'Inter',
    scaffoldBackgroundColor: MooColors.bgDark,
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: MooColors.borderDark),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: MooColors.surfaceDark,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: MooColors.surfaceDark,
      foregroundColor: colorScheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      shape: const Border(bottom: BorderSide(color: MooColors.borderDark)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: MooColors.surfaceDark,
      indicatorColor: MooColors.primary.withValues(alpha: 0.25),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: MooColors.primary,
          );
        }
        return const TextStyle(fontSize: 12, color: Color(0xFF64748B));
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: MooColors.primary);
        }
        return const IconThemeData(color: Color(0xFF64748B));
      }),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: MooColors.surfaceDark,
      indicatorColor: MooColors.primary.withValues(alpha: 0.25),
      selectedIconTheme: const IconThemeData(color: MooColors.primary),
      unselectedIconTheme: const IconThemeData(color: Color(0xFF64748B)),
      selectedLabelTextStyle: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: MooColors.primary,
      ),
      unselectedLabelTextStyle: const TextStyle(
        fontSize: 12,
        color: Color(0xFF64748B),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: MooColors.borderDark),
      ),
      filled: true,
      fillColor: MooColors.surfaceDark,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: MooColors.primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF94A3B8),
        side: const BorderSide(color: MooColors.borderDark),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      ),
    ),
    dividerTheme:
        const DividerThemeData(color: MooColors.borderDark, thickness: 1),
    tabBarTheme: const TabBarThemeData(
      labelColor: MooColors.primary,
      indicatorColor: MooColors.primary,
    ),
  );
}

// ---------------------------------------------------------------------------
// Status pill widget — unified across the app
// ---------------------------------------------------------------------------
class StatusPill extends StatefulWidget {
  final String label;
  final Color color;
  final IconData? icon;
  final bool pulse;

  const StatusPill({
    super.key,
    required this.label,
    required this.color,
    this.icon,
    this.pulse = false,
  });

  /// Convenience: build from a Node's overallStatus string
  factory StatusPill.fromStatus(String status) {
    switch (status) {
      case 'Active':
        return const StatusPill(
          label: 'Active',
          color: MooColors.active,
          icon: Icons.check_circle_outline,
          pulse: true,
        );
      case 'Offline':
        return const StatusPill(
          label: 'Offline',
          color: MooColors.offline,
          icon: Icons.cloud_off,
        );
      case 'Low Battery':
        return const StatusPill(
          label: 'Low Battery',
          color: MooColors.lowBattery,
          icon: Icons.battery_alert,
        );
      default:
        return StatusPill(label: status, color: Colors.grey);
    }
  }

  /// Convenience: battery pill
  factory StatusPill.battery(int level) {
    Color c;
    if (level >= 80) {
      c = MooColors.battGood;
    } else if (level >= 50) {
      c = MooColors.battMedium;
    } else if (level >= 20) {
      c = MooColors.battLow;
    } else {
      c = MooColors.battCritical;
    }
    return StatusPill(
      label: '$level%',
      color: c,
      icon: Icons.battery_std,
    );
  }

  @override
  State<StatusPill> createState() => _StatusPillState();
}

class _StatusPillState extends State<StatusPill>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: widget.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: widget.color.withValues(alpha: 0.2), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.pulse)
            ScaleTransition(
              scale: Tween(begin: 0.8, end: 1.2).animate(
                CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
              ),
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: widget.color,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: widget.color.withValues(alpha: 0.5),
                      blurRadius: 4,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
            )
          else if (widget.icon != null)
            Icon(widget.icon, size: 14, color: widget.color),
          const SizedBox(width: 6),
          Text(
            widget.label,
            style: TextStyle(
              color: widget.color,
              fontWeight: FontWeight.w700,
              fontSize: 11,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state illustration widget
// ---------------------------------------------------------------------------
class EmptyStateWidget extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onAction;
  final String? actionLabel;

  const EmptyStateWidget({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onAction,
    this.actionLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    MooColors.primary.withValues(alpha: 0.10),
                    MooColors.accent.withValues(alpha: 0.10),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(icon,
                  size: 48, color: MooColors.primary.withValues(alpha: 0.6)),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
            ],
            if (onAction != null && actionLabel != null) ...[
              const SizedBox(height: 20),
              ElevatedButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Node avatar — shows photo if available, otherwise status-colored icon
// ---------------------------------------------------------------------------
class NodeAvatar extends StatelessWidget {
  final NodeModel node;
  final double radius;

  const NodeAvatar({super.key, required this.node, this.radius = 20});

  @override
  Widget build(BuildContext context) {
    if (node.photoUrl != null && node.photoUrl!.isNotEmpty) {
      return Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [
              Color(node.statusColor),
              Color(node.statusColor).withValues(alpha: 0.5),
            ],
          ),
        ),
        child: CircleAvatar(
          radius: radius,
          backgroundImage: NetworkImage(node.photoUrl!),
          backgroundColor: Colors.white,
          onBackgroundImageError: (_, __) {},
        ),
      );
    }
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        color: Color(node.statusColor),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Color(node.statusColor).withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(
        node.nodeType == NodeType.fence ? Icons.bolt : Icons.agriculture,
        color: Colors.white,
        size: radius * 0.9,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Logo widget — reusable across AppBar, login, etc.
// ---------------------------------------------------------------------------
class MooLogo extends StatelessWidget {
  final double height;
  const MooLogo({super.key, this.height = 32});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/logo.png',
      height: height,
      errorBuilder: (_, __, ___) => Icon(
        Icons.pets,
        size: height,
        color: MooColors.primary,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// App version constant
// ---------------------------------------------------------------------------
const String kAppVersion = '1.0.0';
