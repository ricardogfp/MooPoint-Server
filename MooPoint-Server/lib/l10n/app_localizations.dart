import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'MooPoint'**
  String get appTitle;

  /// No description provided for @dashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get dashboard;

  /// No description provided for @map.
  ///
  /// In en, this message translates to:
  /// **'Map'**
  String get map;

  /// No description provided for @mapView.
  ///
  /// In en, this message translates to:
  /// **'Map View'**
  String get mapView;

  /// No description provided for @herd.
  ///
  /// In en, this message translates to:
  /// **'Herd'**
  String get herd;

  /// No description provided for @events.
  ///
  /// In en, this message translates to:
  /// **'Events'**
  String get events;

  /// No description provided for @admin.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get admin;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @searchDevices.
  ///
  /// In en, this message translates to:
  /// **'Search devices...'**
  String get searchDevices;

  /// No description provided for @welcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome back, {name}. Here\'s what\'s happening on your ranch.'**
  String welcomeBack(String name);

  /// No description provided for @systemStatusStable.
  ///
  /// In en, this message translates to:
  /// **'System Status: Stable'**
  String get systemStatusStable;

  /// No description provided for @totalAnimals.
  ///
  /// In en, this message translates to:
  /// **'Total Animals'**
  String get totalAnimals;

  /// No description provided for @onlineNow.
  ///
  /// In en, this message translates to:
  /// **'Online Now'**
  String get onlineNow;

  /// No description provided for @activeAlerts.
  ///
  /// In en, this message translates to:
  /// **'Active Alerts'**
  String get activeAlerts;

  /// No description provided for @batteryCritical.
  ///
  /// In en, this message translates to:
  /// **'Battery Critical'**
  String get batteryCritical;

  /// No description provided for @fenceAlerts.
  ///
  /// In en, this message translates to:
  /// **'Fence Alerts'**
  String get fenceAlerts;

  /// No description provided for @recentActivity.
  ///
  /// In en, this message translates to:
  /// **'Recent Activity'**
  String get recentActivity;

  /// No description provided for @viewAll.
  ///
  /// In en, this message translates to:
  /// **'View all'**
  String get viewAll;

  /// No description provided for @cattleEvent.
  ///
  /// In en, this message translates to:
  /// **'Cattle Event'**
  String get cattleEvent;

  /// No description provided for @fenceEvent.
  ///
  /// In en, this message translates to:
  /// **'Fence Event'**
  String get fenceEvent;

  /// No description provided for @activeAlertsTitle.
  ///
  /// In en, this message translates to:
  /// **'Active Alerts'**
  String get activeAlertsTitle;

  /// No description provided for @active.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get active;

  /// No description provided for @offline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get offline;

  /// No description provided for @lowBattery.
  ///
  /// In en, this message translates to:
  /// **'Low Battery'**
  String get lowBattery;

  /// No description provided for @requiresAttention.
  ///
  /// In en, this message translates to:
  /// **'Requires attention'**
  String get requiresAttention;

  /// No description provided for @rechargeNeeded.
  ///
  /// In en, this message translates to:
  /// **'Recharge needed'**
  String get rechargeNeeded;

  /// No description provided for @breachDetected.
  ///
  /// In en, this message translates to:
  /// **'Breach detected'**
  String get breachDetected;

  /// No description provided for @acknowledge.
  ///
  /// In en, this message translates to:
  /// **'Acknowledge'**
  String get acknowledge;

  /// No description provided for @viewMap.
  ///
  /// In en, this message translates to:
  /// **'View Map'**
  String get viewMap;

  /// No description provided for @notifyTeam.
  ///
  /// In en, this message translates to:
  /// **'Notify Team'**
  String get notifyTeam;

  /// No description provided for @viewNodes.
  ///
  /// In en, this message translates to:
  /// **'View Nodes'**
  String get viewNodes;

  /// No description provided for @dismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get dismiss;

  /// No description provided for @connectivity.
  ///
  /// In en, this message translates to:
  /// **'{percent}% connectivity'**
  String connectivity(String percent);

  /// No description provided for @livePosition.
  ///
  /// In en, this message translates to:
  /// **'Live Position'**
  String get livePosition;

  /// No description provided for @positionHeatmap.
  ///
  /// In en, this message translates to:
  /// **'Position Heatmap'**
  String get positionHeatmap;

  /// No description provided for @coverageView.
  ///
  /// In en, this message translates to:
  /// **'Coverage View'**
  String get coverageView;

  /// No description provided for @positionHistory.
  ///
  /// In en, this message translates to:
  /// **'Position History'**
  String get positionHistory;

  /// No description provided for @liveView.
  ///
  /// In en, this message translates to:
  /// **'Live View'**
  String get liveView;

  /// No description provided for @battery.
  ///
  /// In en, this message translates to:
  /// **'Battery'**
  String get battery;

  /// No description provided for @signal.
  ///
  /// In en, this message translates to:
  /// **'Signal'**
  String get signal;

  /// No description provided for @strong.
  ///
  /// In en, this message translates to:
  /// **'Strong'**
  String get strong;

  /// No description provided for @good.
  ///
  /// In en, this message translates to:
  /// **'Good'**
  String get good;

  /// No description provided for @weak.
  ///
  /// In en, this message translates to:
  /// **'Weak'**
  String get weak;

  /// No description provided for @lastSeen.
  ///
  /// In en, this message translates to:
  /// **'Last seen {time}'**
  String lastSeen(String time);

  /// No description provided for @lastUpdate.
  ///
  /// In en, this message translates to:
  /// **'Last Update'**
  String get lastUpdate;

  /// No description provided for @justNow.
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get justNow;

  /// No description provided for @minutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{count}m ago'**
  String minutesAgo(int count);

  /// No description provided for @hoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{count}h ago'**
  String hoursAgo(int count);

  /// No description provided for @daysAgo.
  ///
  /// In en, this message translates to:
  /// **'{count}d ago'**
  String daysAgo(int count);

  /// No description provided for @fenceNode.
  ///
  /// In en, this message translates to:
  /// **'Fence Node'**
  String get fenceNode;

  /// No description provided for @cattleNode.
  ///
  /// In en, this message translates to:
  /// **'Cattle Node'**
  String get cattleNode;

  /// No description provided for @fenceStatus.
  ///
  /// In en, this message translates to:
  /// **'Fence Status'**
  String get fenceStatus;

  /// No description provided for @energized.
  ///
  /// In en, this message translates to:
  /// **'Energized'**
  String get energized;

  /// No description provided for @voltageFaultDetected.
  ///
  /// In en, this message translates to:
  /// **'Voltage Fault Detected'**
  String get voltageFaultDetected;

  /// No description provided for @systemNominal.
  ///
  /// In en, this message translates to:
  /// **'System nominal'**
  String get systemNominal;

  /// No description provided for @pasturePulse.
  ///
  /// In en, this message translates to:
  /// **'Pasture Pulse'**
  String get pasturePulse;

  /// No description provided for @remoteConfig.
  ///
  /// In en, this message translates to:
  /// **'Remote Config'**
  String get remoteConfig;

  /// No description provided for @remoteConfiguration.
  ///
  /// In en, this message translates to:
  /// **'Remote Configuration'**
  String get remoteConfiguration;

  /// No description provided for @viewLogs.
  ///
  /// In en, this message translates to:
  /// **'View Logs'**
  String get viewLogs;

  /// No description provided for @editMapPlacement.
  ///
  /// In en, this message translates to:
  /// **'Edit Map Placement'**
  String get editMapPlacement;

  /// No description provided for @voltageOverTime.
  ///
  /// In en, this message translates to:
  /// **'Voltage over time'**
  String get voltageOverTime;

  /// No description provided for @latestEvents.
  ///
  /// In en, this message translates to:
  /// **'Latest Events'**
  String get latestEvents;

  /// No description provided for @dailyBehavior.
  ///
  /// In en, this message translates to:
  /// **'Daily Behavior'**
  String get dailyBehavior;

  /// No description provided for @activity.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get activity;

  /// No description provided for @activityFeed.
  ///
  /// In en, this message translates to:
  /// **'Activity Feed'**
  String get activityFeed;

  /// No description provided for @resting.
  ///
  /// In en, this message translates to:
  /// **'Resting'**
  String get resting;

  /// No description provided for @moving.
  ///
  /// In en, this message translates to:
  /// **'Moving'**
  String get moving;

  /// No description provided for @grazing.
  ///
  /// In en, this message translates to:
  /// **'Grazing'**
  String get grazing;

  /// No description provided for @ruminating.
  ///
  /// In en, this message translates to:
  /// **'Ruminating'**
  String get ruminating;

  /// No description provided for @geofenceEvents.
  ///
  /// In en, this message translates to:
  /// **'Geofence Events'**
  String get geofenceEvents;

  /// No description provided for @entered.
  ///
  /// In en, this message translates to:
  /// **'Entered'**
  String get entered;

  /// No description provided for @exited.
  ///
  /// In en, this message translates to:
  /// **'Exited'**
  String get exited;

  /// No description provided for @power.
  ///
  /// In en, this message translates to:
  /// **'Power'**
  String get power;

  /// No description provided for @gpsAccuracy.
  ///
  /// In en, this message translates to:
  /// **'GPS Accuracy'**
  String get gpsAccuracy;

  /// No description provided for @gps.
  ///
  /// In en, this message translates to:
  /// **'GPS'**
  String get gps;

  /// No description provided for @voltageMonitoring.
  ///
  /// In en, this message translates to:
  /// **'Voltage Monitoring'**
  String get voltageMonitoring;

  /// No description provided for @fenceType.
  ///
  /// In en, this message translates to:
  /// **'Fence Type'**
  String get fenceType;

  /// No description provided for @fenceVoltage.
  ///
  /// In en, this message translates to:
  /// **'Fence Voltage'**
  String get fenceVoltage;

  /// No description provided for @firmware.
  ///
  /// In en, this message translates to:
  /// **'Firmware'**
  String get firmware;

  /// No description provided for @powerManagement.
  ///
  /// In en, this message translates to:
  /// **'Power Management'**
  String get powerManagement;

  /// No description provided for @batteryThreshold.
  ///
  /// In en, this message translates to:
  /// **'Battery Threshold'**
  String get batteryThreshold;

  /// No description provided for @sleepTime.
  ///
  /// In en, this message translates to:
  /// **'Sleep Time'**
  String get sleepTime;

  /// No description provided for @gpsTimeout.
  ///
  /// In en, this message translates to:
  /// **'GPS Timeout'**
  String get gpsTimeout;

  /// No description provided for @reportInterval.
  ///
  /// In en, this message translates to:
  /// **'Report Interval'**
  String get reportInterval;

  /// No description provided for @normal.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get normal;

  /// No description provided for @powerSave.
  ///
  /// In en, this message translates to:
  /// **'Power Save'**
  String get powerSave;

  /// No description provided for @critical.
  ///
  /// In en, this message translates to:
  /// **'Critical'**
  String get critical;

  /// No description provided for @applyChanges.
  ///
  /// In en, this message translates to:
  /// **'Apply Changes'**
  String get applyChanges;

  /// No description provided for @configApplyMessage.
  ///
  /// In en, this message translates to:
  /// **'The new configuration will be applied on the next wake cycle'**
  String get configApplyMessage;

  /// No description provided for @batteryLevelCascade.
  ///
  /// In en, this message translates to:
  /// **'Battery Level Cascade'**
  String get batteryLevelCascade;

  /// No description provided for @profilesActivateNote.
  ///
  /// In en, this message translates to:
  /// **'Profiles activate in order as battery drains'**
  String get profilesActivateNote;

  /// No description provided for @maxHdopValue.
  ///
  /// In en, this message translates to:
  /// **'Max HDOP Value'**
  String get maxHdopValue;

  /// No description provided for @hdopDescription.
  ///
  /// In en, this message translates to:
  /// **'Lower values require higher accuracy before accepting a fix. Recommended: 2.0 – 5.0'**
  String get hdopDescription;

  /// No description provided for @minSatellites.
  ///
  /// In en, this message translates to:
  /// **'Min. Satellites Required'**
  String get minSatellites;

  /// No description provided for @satDescription.
  ///
  /// In en, this message translates to:
  /// **'Higher values improve accuracy but may increase fix time and power consumption.'**
  String get satDescription;

  /// No description provided for @fasterFix.
  ///
  /// In en, this message translates to:
  /// **'← Faster fix'**
  String get fasterFix;

  /// No description provided for @moreAccurate.
  ///
  /// In en, this message translates to:
  /// **'More accurate →'**
  String get moreAccurate;

  /// No description provided for @lowVoltageThreshold.
  ///
  /// In en, this message translates to:
  /// **'Low Voltage Alert Threshold'**
  String get lowVoltageThreshold;

  /// No description provided for @lowVoltageDescription.
  ///
  /// In en, this message translates to:
  /// **'Alert sent when voltage drops below this value.'**
  String get lowVoltageDescription;

  /// No description provided for @outageDetection.
  ///
  /// In en, this message translates to:
  /// **'Outage Detection'**
  String get outageDetection;

  /// No description provided for @restorationConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Restoration Confirmation'**
  String get restorationConfirmation;

  /// No description provided for @alerts.
  ///
  /// In en, this message translates to:
  /// **'Alerts'**
  String get alerts;

  /// No description provided for @fenceOutage.
  ///
  /// In en, this message translates to:
  /// **'Fence Outage'**
  String get fenceOutage;

  /// No description provided for @lowVoltage.
  ///
  /// In en, this message translates to:
  /// **'Low Voltage'**
  String get lowVoltage;

  /// No description provided for @powerRestored.
  ///
  /// In en, this message translates to:
  /// **'Power Restored'**
  String get powerRestored;

  /// No description provided for @nodeOffline.
  ///
  /// In en, this message translates to:
  /// **'Node Offline'**
  String get nodeOffline;

  /// No description provided for @checkForUpdates.
  ///
  /// In en, this message translates to:
  /// **'Check for Updates'**
  String get checkForUpdates;

  /// No description provided for @upToDate.
  ///
  /// In en, this message translates to:
  /// **'Up to date'**
  String get upToDate;

  /// No description provided for @placedOnMap.
  ///
  /// In en, this message translates to:
  /// **'Placed on Map'**
  String get placedOnMap;

  /// No description provided for @editPlacement.
  ///
  /// In en, this message translates to:
  /// **'Edit Placement'**
  String get editPlacement;

  /// No description provided for @located.
  ///
  /// In en, this message translates to:
  /// **'Located'**
  String get located;

  /// No description provided for @noGpsHardware.
  ///
  /// In en, this message translates to:
  /// **'No GPS Hardware'**
  String get noGpsHardware;

  /// No description provided for @noGpsDescription.
  ///
  /// In en, this message translates to:
  /// **'GPS accuracy settings are not available for fence nodes.'**
  String get noGpsDescription;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// No description provided for @login.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get login;

  /// No description provided for @username.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get username;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @totalNodes.
  ///
  /// In en, this message translates to:
  /// **'Total Nodes'**
  String get totalNodes;

  /// No description provided for @nodeId.
  ///
  /// In en, this message translates to:
  /// **'Node ID'**
  String get nodeId;

  /// No description provided for @locate.
  ///
  /// In en, this message translates to:
  /// **'Locate'**
  String get locate;

  /// No description provided for @overview.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get overview;

  /// No description provided for @behavior.
  ///
  /// In en, this message translates to:
  /// **'Behavior'**
  String get behavior;

  /// No description provided for @location.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get location;

  /// No description provided for @temperature.
  ///
  /// In en, this message translates to:
  /// **'Temperature'**
  String get temperature;

  /// No description provided for @voltage.
  ///
  /// In en, this message translates to:
  /// **'Voltage'**
  String get voltage;

  /// No description provided for @systemDetails.
  ///
  /// In en, this message translates to:
  /// **'System Details'**
  String get systemDetails;

  /// No description provided for @type.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get type;

  /// No description provided for @breed.
  ///
  /// In en, this message translates to:
  /// **'Breed'**
  String get breed;

  /// No description provided for @age.
  ///
  /// In en, this message translates to:
  /// **'Age'**
  String get age;

  /// No description provided for @comments.
  ///
  /// In en, this message translates to:
  /// **'Comments'**
  String get comments;

  /// No description provided for @noComments.
  ///
  /// In en, this message translates to:
  /// **'No additional comments provided.'**
  String get noComments;

  /// No description provided for @surroundings.
  ///
  /// In en, this message translates to:
  /// **'Surroundings'**
  String get surroundings;

  /// No description provided for @batteryLevel.
  ///
  /// In en, this message translates to:
  /// **'Battery Level'**
  String get batteryLevel;

  /// No description provided for @lastReported.
  ///
  /// In en, this message translates to:
  /// **'Last reported {time}'**
  String lastReported(String time);

  /// No description provided for @locationActions.
  ///
  /// In en, this message translates to:
  /// **'Location Actions'**
  String get locationActions;

  /// No description provided for @positionHistoryBtn.
  ///
  /// In en, this message translates to:
  /// **'Position History'**
  String get positionHistoryBtn;

  /// No description provided for @heatmap.
  ///
  /// In en, this message translates to:
  /// **'Heatmap'**
  String get heatmap;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @spanish.
  ///
  /// In en, this message translates to:
  /// **'Spanish'**
  String get spanish;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @system.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get system;

  /// No description provided for @light.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get light;

  /// No description provided for @dark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get dark;

  /// No description provided for @refreshData.
  ///
  /// In en, this message translates to:
  /// **'Refresh Data'**
  String get refreshData;

  /// No description provided for @lastSynced.
  ///
  /// In en, this message translates to:
  /// **'Last synced: {time}'**
  String lastSynced(String time);

  /// No description provided for @version.
  ///
  /// In en, this message translates to:
  /// **'MooPoint v{version}'**
  String version(String version);

  /// No description provided for @allSystemsOperational.
  ///
  /// In en, this message translates to:
  /// **'All systems operational'**
  String get allSystemsOperational;

  /// No description provided for @online.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get online;

  /// No description provided for @inPasture.
  ///
  /// In en, this message translates to:
  /// **'In Pasture'**
  String get inPasture;

  /// No description provided for @recentGeofenceEvents.
  ///
  /// In en, this message translates to:
  /// **'Recent Geofence Events'**
  String get recentGeofenceEvents;

  /// No description provided for @noRecentEvents.
  ///
  /// In en, this message translates to:
  /// **'No recent events'**
  String get noRecentEvents;

  /// No description provided for @batteryDistribution.
  ///
  /// In en, this message translates to:
  /// **'Battery Distribution'**
  String get batteryDistribution;

  /// No description provided for @backendUrl.
  ///
  /// In en, this message translates to:
  /// **'Backend URL'**
  String get backendUrl;

  /// No description provided for @refreshInterval.
  ///
  /// In en, this message translates to:
  /// **'Refresh Interval'**
  String get refreshInterval;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @geofenceExitAlerts.
  ///
  /// In en, this message translates to:
  /// **'Geofence Exit Alerts'**
  String get geofenceExitAlerts;

  /// No description provided for @lowBatteryAlerts.
  ///
  /// In en, this message translates to:
  /// **'Low Battery Alerts'**
  String get lowBatteryAlerts;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
