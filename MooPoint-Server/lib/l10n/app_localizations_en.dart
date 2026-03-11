// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'MooPoint';

  @override
  String get dashboard => 'Dashboard';

  @override
  String get map => 'Map';

  @override
  String get mapView => 'Map View';

  @override
  String get herd => 'Herd';

  @override
  String get events => 'Events';

  @override
  String get admin => 'Admin';

  @override
  String get settings => 'Settings';

  @override
  String get searchDevices => 'Search devices...';

  @override
  String welcomeBack(String name) {
    return 'Welcome back, $name. Here\'s what\'s happening on your ranch.';
  }

  @override
  String get systemStatusStable => 'System Status: Stable';

  @override
  String get totalAnimals => 'Total Animals';

  @override
  String get onlineNow => 'Online Now';

  @override
  String get activeAlerts => 'Active Alerts';

  @override
  String get batteryCritical => 'Battery Critical';

  @override
  String get fenceAlerts => 'Fence Alerts';

  @override
  String get recentActivity => 'Recent Activity';

  @override
  String get viewAll => 'View all';

  @override
  String get cattleEvent => 'Cattle Event';

  @override
  String get fenceEvent => 'Fence Event';

  @override
  String get activeAlertsTitle => 'Active Alerts';

  @override
  String get active => 'Active';

  @override
  String get offline => 'Offline';

  @override
  String get lowBattery => 'Low Battery';

  @override
  String get requiresAttention => 'Requires attention';

  @override
  String get rechargeNeeded => 'Recharge needed';

  @override
  String get breachDetected => 'Breach detected';

  @override
  String get acknowledge => 'Acknowledge';

  @override
  String get viewMap => 'View Map';

  @override
  String get notifyTeam => 'Notify Team';

  @override
  String get viewNodes => 'View Nodes';

  @override
  String get dismiss => 'Dismiss';

  @override
  String connectivity(String percent) {
    return '$percent% connectivity';
  }

  @override
  String get livePosition => 'Live Position';

  @override
  String get positionHeatmap => 'Position Heatmap';

  @override
  String get coverageView => 'Coverage View';

  @override
  String get positionHistory => 'Position History';

  @override
  String get liveView => 'Live View';

  @override
  String get battery => 'Battery';

  @override
  String get signal => 'Signal';

  @override
  String get strong => 'Strong';

  @override
  String get good => 'Good';

  @override
  String get weak => 'Weak';

  @override
  String lastSeen(String time) {
    return 'Last seen $time';
  }

  @override
  String get lastUpdate => 'Last Update';

  @override
  String get justNow => 'just now';

  @override
  String minutesAgo(int count) {
    return '${count}m ago';
  }

  @override
  String hoursAgo(int count) {
    return '${count}h ago';
  }

  @override
  String daysAgo(int count) {
    return '${count}d ago';
  }

  @override
  String get fenceNode => 'Fence Node';

  @override
  String get cattleNode => 'Cattle Node';

  @override
  String get fenceStatus => 'Fence Status';

  @override
  String get energized => 'Energized';

  @override
  String get voltageFaultDetected => 'Voltage Fault Detected';

  @override
  String get systemNominal => 'System nominal';

  @override
  String get pasturePulse => 'Pasture Pulse';

  @override
  String get remoteConfig => 'Remote Config';

  @override
  String get remoteConfiguration => 'Remote Configuration';

  @override
  String get viewLogs => 'View Logs';

  @override
  String get editMapPlacement => 'Edit Map Placement';

  @override
  String get voltageOverTime => 'Voltage over time';

  @override
  String get latestEvents => 'Latest Events';

  @override
  String get dailyBehavior => 'Daily Behavior';

  @override
  String get activity => 'Activity';

  @override
  String get activityFeed => 'Activity Feed';

  @override
  String get resting => 'Resting';

  @override
  String get moving => 'Moving';

  @override
  String get grazing => 'Grazing';

  @override
  String get ruminating => 'Ruminating';

  @override
  String get geofenceEvents => 'Geofence Events';

  @override
  String get entered => 'Entered';

  @override
  String get exited => 'Exited';

  @override
  String get power => 'Power';

  @override
  String get gpsAccuracy => 'GPS Accuracy';

  @override
  String get gps => 'GPS';

  @override
  String get voltageMonitoring => 'Voltage Monitoring';

  @override
  String get fenceType => 'Fence Type';

  @override
  String get fenceVoltage => 'Fence Voltage';

  @override
  String get firmware => 'Firmware';

  @override
  String get powerManagement => 'Power Management';

  @override
  String get batteryThreshold => 'Battery Threshold';

  @override
  String get sleepTime => 'Sleep Time';

  @override
  String get gpsTimeout => 'GPS Timeout';

  @override
  String get reportInterval => 'Report Interval';

  @override
  String get normal => 'Normal';

  @override
  String get powerSave => 'Power Save';

  @override
  String get critical => 'Critical';

  @override
  String get applyChanges => 'Apply Changes';

  @override
  String get configApplyMessage =>
      'The new configuration will be applied on the next wake cycle';

  @override
  String get batteryLevelCascade => 'Battery Level Cascade';

  @override
  String get profilesActivateNote =>
      'Profiles activate in order as battery drains';

  @override
  String get maxHdopValue => 'Max HDOP Value';

  @override
  String get hdopDescription =>
      'Lower values require higher accuracy before accepting a fix. Recommended: 2.0 – 5.0';

  @override
  String get minSatellites => 'Min. Satellites Required';

  @override
  String get satDescription =>
      'Higher values improve accuracy but may increase fix time and power consumption.';

  @override
  String get fasterFix => '← Faster fix';

  @override
  String get moreAccurate => 'More accurate →';

  @override
  String get lowVoltageThreshold => 'Low Voltage Alert Threshold';

  @override
  String get lowVoltageDescription =>
      'Alert sent when voltage drops below this value.';

  @override
  String get outageDetection => 'Outage Detection';

  @override
  String get restorationConfirmation => 'Restoration Confirmation';

  @override
  String get alerts => 'Alerts';

  @override
  String get fenceOutage => 'Fence Outage';

  @override
  String get lowVoltage => 'Low Voltage';

  @override
  String get powerRestored => 'Power Restored';

  @override
  String get nodeOffline => 'Node Offline';

  @override
  String get checkForUpdates => 'Check for Updates';

  @override
  String get upToDate => 'Up to date';

  @override
  String get placedOnMap => 'Placed on Map';

  @override
  String get editPlacement => 'Edit Placement';

  @override
  String get located => 'Located';

  @override
  String get noGpsHardware => 'No GPS Hardware';

  @override
  String get noGpsDescription =>
      'GPS accuracy settings are not available for fence nodes.';

  @override
  String get logout => 'Logout';

  @override
  String get login => 'Login';

  @override
  String get username => 'Username';

  @override
  String get password => 'Password';

  @override
  String get totalNodes => 'Total Nodes';

  @override
  String get nodeId => 'Node ID';

  @override
  String get locate => 'Locate';

  @override
  String get overview => 'Overview';

  @override
  String get behavior => 'Behavior';

  @override
  String get location => 'Location';

  @override
  String get temperature => 'Temperature';

  @override
  String get voltage => 'Voltage';

  @override
  String get systemDetails => 'System Details';

  @override
  String get type => 'Type';

  @override
  String get breed => 'Breed';

  @override
  String get age => 'Age';

  @override
  String get comments => 'Comments';

  @override
  String get noComments => 'No additional comments provided.';

  @override
  String get surroundings => 'Surroundings';

  @override
  String get batteryLevel => 'Battery Level';

  @override
  String lastReported(String time) {
    return 'Last reported $time';
  }

  @override
  String get locationActions => 'Location Actions';

  @override
  String get positionHistoryBtn => 'Position History';

  @override
  String get heatmap => 'Heatmap';

  @override
  String get language => 'Language';

  @override
  String get english => 'English';

  @override
  String get spanish => 'Spanish';

  @override
  String get theme => 'Theme';

  @override
  String get system => 'System';

  @override
  String get light => 'Light';

  @override
  String get dark => 'Dark';

  @override
  String get refreshData => 'Refresh Data';

  @override
  String lastSynced(String time) {
    return 'Last synced: $time';
  }

  @override
  String version(String version) {
    return 'MooPoint v$version';
  }

  @override
  String get allSystemsOperational => 'All systems operational';

  @override
  String get online => 'Online';

  @override
  String get inPasture => 'In Pasture';

  @override
  String get recentGeofenceEvents => 'Recent Geofence Events';

  @override
  String get noRecentEvents => 'No recent events';

  @override
  String get batteryDistribution => 'Battery Distribution';

  @override
  String get backendUrl => 'Backend URL';

  @override
  String get refreshInterval => 'Refresh Interval';

  @override
  String get notifications => 'Notifications';

  @override
  String get geofenceExitAlerts => 'Geofence Exit Alerts';

  @override
  String get lowBatteryAlerts => 'Low Battery Alerts';
}
