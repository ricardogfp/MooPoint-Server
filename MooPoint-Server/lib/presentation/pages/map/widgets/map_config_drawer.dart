import 'package:flutter/material.dart';
import 'package:moo_point/data/models/node_model.dart';
import 'package:moo_point/app/theme/app_theme.dart';
import 'package:moo_point/l10n/l10n_helper.dart';
import 'package:moo_point/l10n/app_localizations.dart';
import 'package:moo_point/services/api/node_backend_admin_service.dart';

class MapConfigDrawer extends StatefulWidget {
  final NodeModel node;
  final VoidCallback onClose;

  const MapConfigDrawer({super.key, required this.node, required this.onClose});

  @override
  State<MapConfigDrawer> createState() => _MapConfigDrawerState();
}

class _MapConfigDrawerState extends State<MapConfigDrawer>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Fence voltage/alert state
  double _voltageThreshold = 0.5; // 0→1 maps to 1 kV→9 kV (default 5.0 kV)
  int _outageDetectionIndex = 1;  // Instant/2s/5s/10s
  int _restorationIndex = 2;      // Instant/5s/10s/30s
  bool _alertFenceOutage = true;
  bool _alertLowVoltage = true;
  bool _alertPowerRestored = true;
  bool _alertNodeOffline = true;

  // Power profile state — [Normal, PowerSave, LowBattery, Critical]
  // Battery threshold: 0→1 maps to 0%→100%
  final List<double> _profileBatterySlider = [1.0, 0.4, 0.2, 0.1];
  // Sleep time: 0→1 maps to 10s→3600s
  final List<double> _profileSleepSlider = [0.3, 0.5, 0.7, 0.9];
  // GPS timeout: slider * 200 = seconds (0.3→60s, 0.45→90s, 0.6→120s, 0.9→180s)
  final List<double> _profileGpsSlider = [0.3, 0.45, 0.6, 0.9];

  // Cattle GPS state
  double _hdopValue = 0.25;
  int _selectedSatIndex = 2; // index into [3,4,5,6,7,8,'9+']

  // UI state
  bool _isApplying = false;

  static String _sleepLabel(double v) {
    final secs = (10 + v * 3590).round();
    if (secs < 60) return '$secs sec';
    final mins = (secs / 60).round();
    return '$mins min';
  }

  static String _batteryLabel(double v) => '${(v * 100).round()}%';

  static String _gpsTimeoutLabel(double v) {
    final secs = (v * 200).round();
    if (secs < 60) return '$secs sec';
    final mins = secs ~/ 60;
    final rem = secs % 60;
    return rem == 0 ? '$mins min' : '$mins min $rem sec';
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _applyConfig() async {
    setState(() => _isApplying = true);
    try {
      final isFence = widget.node.nodeType == NodeType.fence;
      final profileNames = ['normal', 'power_save', 'low_battery', 'critical'];
      final powerProfiles = {
        for (int i = 0; i < 4; i++)
          profileNames[i]: {
            'battery_threshold_pct': (_profileBatterySlider[i] * 100).round(),
            'sleep_time_s': (10 + _profileSleepSlider[i] * 3590).round(),
            'gps_timeout_s': (_profileGpsSlider[i] * 200).round(),
          }
      };
      final Map<String, dynamic> config = isFence
          ? {
              'voltage_threshold_kv': 1.0 + _voltageThreshold * 8.0,
              'outage_detection_s': [0, 2, 5, 10][_outageDetectionIndex],
              'restoration_confirm_s': [0, 5, 10, 30][_restorationIndex],
              'alert_fence_outage': _alertFenceOutage,
              'alert_low_voltage': _alertLowVoltage,
              'alert_power_restored': _alertPowerRestored,
              'alert_node_offline': _alertNodeOffline,
              'power_profiles': powerProfiles,
            }
          : {
              'max_hdop': 1.0 + _hdopValue * 9.0,
              'min_satellites': [3, 4, 5, 6, 7, 8, 9][_selectedSatIndex],
              'power_profiles': powerProfiles,
            };

      await NodeBackendAdminService().pushConfig(
        [widget.node.nodeId],
        [1], // default gateway ID; can be extended later
        config,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Configuration sent to device.'),
            backgroundColor: Color(0xFF16A34A),
          ),
        );
        widget.onClose();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to apply config: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isApplying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isFence = widget.node.nodeType == NodeType.fence;

    return Container(
      width: 400,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : MooColors.surfaceLight,
        borderRadius: const BorderRadius.horizontal(left: Radius.circular(24)),
        border: Border(
            left: BorderSide(
                color: isDark ? const Color(0xFF334155) : MooColors.borderLight)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 30,
            offset: const Offset(-8, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: MooColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.settings,
                      color: MooColors.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Remote Configuration',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                      const SizedBox(height: 2),
                      Text(
                          '${widget.node.getName()} · Node #${widget.node.nodeId}',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade400)),
                    ],
                  ),
                ),
                IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.close_rounded, size: 20),
                    color: Colors.grey.shade500,
                    onPressed: widget.onClose),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFF334155)),
          
          // Tabs
          TabBar(
            controller: _tabController,
            labelColor: MooColors.primary,
            unselectedLabelColor: Colors.grey,
            indicatorColor: MooColors.primary,
            indicatorWeight: 3,
            labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            tabs: [
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.battery_charging_full, size: 16),
                    const SizedBox(width: 4),
                    Text(l10n.power),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(isFence ? Icons.electric_bolt : Icons.gps_fixed, size: 16),
                    const SizedBox(width: 4),
                    Text(isFence ? 'Voltage' : 'GPS'),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.system_update, size: 16),
                    const SizedBox(width: 4),
                    Text(l10n.firmware),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 1, color: Color(0xFF334155)),
          
          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildPowerTab(l10n, isFence),
                _buildTuningTab(l10n, isFence),
                _buildFirmwareTab(l10n),
              ],
            ),
          ),

          // Footer
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFF1E293B),
              border: Border(top: BorderSide(color: Color(0xFF334155))),
            ),
            child: Column(
              children: [
                ElevatedButton(
                  onPressed: _isApplying ? null : _applyConfig,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    backgroundColor: MooColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isApplying
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Text(l10n.applyChanges,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPowerTab(AppLocalizations l10n, bool isFence) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildProfileCard(
          profileIndex: 0,
          title: 'Normal',
          threshold: '≥ 60%',
          color1: const Color(0xFF16A34A),
          color2: const Color(0xFF15803D),
          dotColor: const Color(0xFF86EFAC),
          isFence: isFence,
        ),
        _buildProfileCard(
          profileIndex: 1,
          title: 'Power Save',
          threshold: '≥ 40%',
          color1: const Color(0xFF2563EB),
          color2: const Color(0xFF1D4ED8),
          dotColor: const Color(0xFF93C5FD),
          isFence: isFence,
        ),
        _buildProfileCard(
          profileIndex: 2,
          title: 'Low Battery',
          threshold: '≥ 20%',
          color1: const Color(0xFFEA580C),
          color2: const Color(0xFFC2410C),
          dotColor: const Color(0xFFFDBA74),
          isFence: isFence,
        ),
        _buildProfileCard(
          profileIndex: 3,
          title: 'Critical',
          threshold: '≥ 10%',
          color1: const Color(0xFFDC2626),
          color2: const Color(0xFFB91C1C),
          dotColor: const Color(0xFFFCA5A5),
          isFence: isFence,
          borderColor: Colors.red.withValues(alpha: 0.4),
          isCritical: true,
        ),

        // Cascade Bar
        Container(
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B).withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF334155)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Battery Level Cascade',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey)),
              const SizedBox(height: 10),
              Container(
                height: 8,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFDC2626),
                      Color(0xFFEA580C),
                      Color(0xFFEA580C),
                      Color(0xFF2563EB),
                      Color(0xFF16A34A)
                    ],
                    stops: [0.0, 0.1, 0.2, 0.4, 0.6],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('0% Critical',
                      style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Colors.redAccent)),
                  Text('10%',
                      style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Colors.orangeAccent)),
                  Text('20% Low',
                      style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Colors.orangeAccent)),
                  Text('40% Save',
                      style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Colors.blueAccent)),
                  Text('100% Normal',
                      style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Colors.greenAccent)),
                ],
              ),
              const SizedBox(height: 8),
              const Center(
                child: Text('Profiles activate in order as battery drains',
                    style: TextStyle(
                        fontSize: 10, fontStyle: FontStyle.italic, color: Colors.grey)),
              )
            ],
          ),
        )
      ],
    );
  }

  Widget _buildProfileCard({
    required int profileIndex,
    required String title,
    required String threshold,
    required Color color1,
    required Color color2,
    required Color dotColor,
    required bool isFence,
    Color? borderColor,
    bool isCritical = false,
  }) {
    final batterySlider = _profileBatterySlider[profileIndex];
    final sleepSlider = _profileSleepSlider[profileIndex];
    final gpsSlider = _profileGpsSlider[profileIndex];

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor ?? const Color(0xFF334155)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
              gradient: LinearGradient(
                colors: [color1, color2],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: dotColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(title,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                  ],
                ),
                Text(threshold,
                    style: const TextStyle(
                        fontSize: 12,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                        color: Colors.white70)),
              ],
            ),
          ),
          // Body
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildSliderField(
                  icon: Icons.battery_charging_full,
                  iconColor: dotColor,
                  label: 'Battery Threshold',
                  valueLabel: _batteryLabel(batterySlider),
                  valueBg: color2.withValues(alpha: 0.4),
                  valueTextColor: dotColor,
                  sliderValue: batterySlider,
                  onChanged: (v) => setState(() => _profileBatterySlider[profileIndex] = v),
                  helpText: batterySlider < 1.0
                      ? 'Activates when battery falls below this level'
                      : null,
                ),
                const SizedBox(height: 16),
                _buildSliderField(
                  icon: Icons.bedtime,
                  iconColor: Colors.grey.shade400,
                  label: 'Sleep Time',
                  valueLabel: _sleepLabel(sleepSlider),
                  valueBg: const Color(0xFF334155),
                  valueTextColor: Colors.grey.shade300,
                  sliderValue: sleepSlider,
                  onChanged: (v) => setState(() => _profileSleepSlider[profileIndex] = v),
                ),
                if (!isFence) ...[
                  const SizedBox(height: 16),
                  _buildSliderField(
                    icon: Icons.gps_fixed,
                    iconColor: Colors.grey.shade400,
                    label: 'GPS Timeout',
                    valueLabel: _gpsTimeoutLabel(gpsSlider),
                    valueBg: const Color(0xFF334155),
                    valueTextColor: Colors.grey.shade300,
                    sliderValue: gpsSlider,
                    onChanged: (v) => setState(() => _profileGpsSlider[profileIndex] = v),
                    helpText: isCritical
                        ? 'GPS updates minimized to preserve power.'
                        : null,
                    helpTextColor: isCritical ? Colors.redAccent.withValues(alpha: 0.8) : null,
                  ),
                ]
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildSliderField({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String valueLabel,
    required Color valueBg,
    required Color valueTextColor,
    required double sliderValue,
    ValueChanged<double>? onChanged,
    String? helpText,
    Color? helpTextColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: iconColor),
                const SizedBox(width: 6),
                Text(label,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: valueBg,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: valueTextColor.withValues(alpha: 0.3)),
              ),
              child: Text(valueLabel,
                  style: TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                      color: valueTextColor)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 20,
          child: Slider(
            value: sliderValue,
            onChanged: onChanged,
            activeColor: MooColors.primary,
            inactiveColor: const Color(0xFF334155),
          ),
        ),
        if (helpText != null)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 4),
            child: Text(helpText,
                style: TextStyle(
                    fontSize: 10,
                    color: helpTextColor ?? Colors.grey.shade500,
                    fontStyle: helpTextColor != null ? FontStyle.italic : FontStyle.normal)),
          ),
      ],
    );
  }

  Widget _buildTuningTab(AppLocalizations l10n, bool isFence) {
    if (isFence) {
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B).withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Low Voltage Alert Threshold',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
                const SizedBox(height: 4),
                const Text('Alert sent when voltage drops below this value.',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 16),
                SizedBox(
                  height: 20,
                  child: Slider(
                      value: _voltageThreshold,
                      onChanged: (v) => setState(() => _voltageThreshold = v),
                      activeColor: Colors.orangeAccent,
                      inactiveColor: const Color(0xFF334155)),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('1.0 kV',
                        style: TextStyle(fontSize: 10, color: Colors.grey)),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade900.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: Colors.orange.shade800.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                          '${(1.0 + _voltageThreshold * 8.0).toStringAsFixed(1)} kV',
                          style: const TextStyle(
                              fontSize: 14,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.bold,
                              color: Colors.orangeAccent)),
                    ),
                    const Text('9.0 kV',
                        style: TextStyle(fontSize: 10, color: Colors.grey)),
                  ],
                ),
                const SizedBox(height: 24),
                const Text('Outage Detection',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
                const SizedBox(height: 8),
                _buildSegmentedControl(['Instant', '2s', '5s', '10s'],
                    _outageDetectionIndex,
                    (i) => setState(() => _outageDetectionIndex = i)),
                const SizedBox(height: 6),
                const Text('Prevents false alerts from brief fluctuations',
                    style: TextStyle(fontSize: 10, color: Colors.grey)),
                const SizedBox(height: 24),
                const Text('Restoration Confirmation',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
                const SizedBox(height: 8),
                _buildSegmentedControl(['Instant', '5s', '10s', '30s'],
                    _restorationIndex,
                    (i) => setState(() => _restorationIndex = i)),
                const SizedBox(height: 6),
                const Text('Confirms stable restore before alerting',
                    style: TextStyle(fontSize: 10, color: Colors.grey)),
                const SizedBox(height: 24),
                const Divider(color: Color(0xFF334155)),
                const SizedBox(height: 16),
                const Text('ALERTS',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                        letterSpacing: 1)),
                const SizedBox(height: 12),
                _buildAlertToggle(Icons.bolt, 'Fence Outage', _alertFenceOutage,
                    (v) => setState(() => _alertFenceOutage = v)),
                _buildAlertToggle(Icons.trending_down, 'Low Voltage', _alertLowVoltage,
                    (v) => setState(() => _alertLowVoltage = v)),
                _buildAlertToggle(Icons.bolt, 'Power Restored', _alertPowerRestored,
                    (v) => setState(() => _alertPowerRestored = v)),
                _buildAlertToggle(Icons.wifi_off, 'Node Offline', _alertNodeOffline,
                    (v) => setState(() => _alertNodeOffline = v)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: MooColors.primary.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: MooColors.primary.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.map, color: MooColors.primary, size: 18),
                    const SizedBox(width: 8),
                    const Text('Placed on Map',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: MooColors.primary)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green.shade900.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Colors.green.shade800.withValues(alpha: 0.3)),
                      ),
                      child: const Text('Located',
                          style: TextStyle(
                              fontSize: 10, color: Colors.greenAccent)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '${widget.node.latitude.toStringAsFixed(4)} · ${widget.node.longitude.toStringAsFixed(4)}',
                  style: const TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      color: Colors.grey),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.edit_location_alt, size: 16),
                  label: const Text('Edit Placement'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: MooColors.primary,
                    side: BorderSide(
                        color: MooColors.primary.withValues(alpha: 0.4)),
                    minimumSize: const Size.fromHeight(40),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          )
        ],
      );
    } else {
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B).withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Max HDOP Value',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
                const SizedBox(height: 4),
                const Text(
                    'Lower values require higher accuracy before accepting a fix. Recommended: 2.0 – 5.0',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 16),
                SizedBox(
                  height: 20,
                  child: Slider(
                      value: _hdopValue,
                      onChanged: (v) => setState(() => _hdopValue = v),
                      activeColor: MooColors.primary,
                      inactiveColor: const Color(0xFF334155)),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        _buildHDOPChip('1.0 Excellent', Colors.green),
                        const SizedBox(width: 6),
                        _buildHDOPChip('5.0 Good', Colors.blue),
                        const SizedBox(width: 6),
                        _buildHDOPChip('10.0 Poor', Colors.red),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: MooColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: MooColors.primary.withValues(alpha: 0.2)),
                      ),
                      child: Text(
                          (1.0 + _hdopValue * 9.0).toStringAsFixed(1),
                          style: const TextStyle(
                              fontSize: 14,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.bold,
                              color: MooColors.primary)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B).withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Min. Satellites Required',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
                const SizedBox(height: 4),
                const Text(
                    'Higher values improve accuracy but may increase fix time and power consumption.',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(
                    7,
                    (i) => GestureDetector(
                      onTap: () => setState(() => _selectedSatIndex = i),
                      child: _buildSatBox(
                          ['3','4','5','6','7','8','9+'][i],
                          _selectedSatIndex == i),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('← Faster fix',
                        style: TextStyle(fontSize: 10, color: Colors.grey)),
                    Text('More accurate →',
                        style: TextStyle(fontSize: 10, color: Colors.grey)),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade900.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: Colors.blue.shade800.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                      '${['3','4','5','6','7','8','9+'][_selectedSatIndex]} satellites selected',
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Colors.blueAccent)),
                )
              ],
            ),
          )
        ],
      );
    }
  }

  Widget _buildFirmwareTab(AppLocalizations l10n) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B).withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF334155)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('v2.4.1',
                          style: TextStyle(
                              fontSize: 18,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                      const SizedBox(height: 2),
                      Text('Released Jan 15, 2026',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
                    ],
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.shade900.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: Colors.green.shade800.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Colors.greenAccent,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text('Up to date',
                            style: TextStyle(
                                fontSize: 12, color: Colors.greenAccent)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.system_update, size: 18),
                label: const Text('Check for Updates'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.grey.shade300,
                  side: const BorderSide(color: Color(0xFF334155)),
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSegmentedControl(
      List<String> options, int selectedIndex, ValueChanged<int> onChanged) {
    return Row(
      children: List.generate(options.length, (index) {
        final isSelected = index == selectedIndex;
        return Expanded(
          child: GestureDetector(
            onTap: () => onChanged(index),
            child: Container(
              margin: EdgeInsets.only(right: index < options.length - 1 ? 4 : 0),
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF334155) : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: isSelected
                    ? Border.all(color: const Color(0xFF475569))
                    : Border.all(color: Colors.transparent),
              ),
              alignment: Alignment.center,
              child: Text(options[index],
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : Colors.grey.shade500)),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildAlertToggle(
      IconData icon, String label, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: Colors.grey.shade300),
              const SizedBox(width: 8),
              Text(label,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade300)),
            ],
          ),
          SizedBox(
            height: 24,
            child: Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: MooColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHDOPChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label, style: TextStyle(fontSize: 10, color: color)),
    );
  }

  Widget _buildSatBox(String label, bool isSelected) {
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isSelected ? MooColors.primary : const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: isSelected ? MooColors.primary : const Color(0xFF334155)),
      ),
      child: Text(label,
          style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.white : Colors.grey)),
    );
  }
}
