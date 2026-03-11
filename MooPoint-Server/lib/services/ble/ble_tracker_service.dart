import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class BLETrackerService {
  static final BLETrackerService _instance = BLETrackerService._internal();
  factory BLETrackerService() => _instance;
  BLETrackerService._internal();

  BluetoothDevice? _connectedDevice;
  StreamSubscription<List<ScanResult>>? _discoverySubscription;

  // Callbacks for UI updates
  Function(BluetoothDevice)? onDeviceFound;
  Function(double)? onDistanceChanged;
  Function(bool)? onProximityAlert;
  Function(String)? onStatusChanged;

  bool _isScanning = false;
  double _currentDistance = double.infinity;
  Timer? _updateTimer;

  double? _smoothedRssi;

  int? _targetNodeId;
  DateTime? _lastSeen;
  String? _lockedDeviceId;

  final Map<String, int> _lastRssiByDeviceId = {};
  DateTime _lastStatusAt = DateTime.fromMillisecondsSinceEpoch(0);

  String _normalizeName(String s) {
    return s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  String _resultName(ScanResult result) {
    final a = result.advertisementData.advName;
    final b = result.device.advName;
    final c = result.device.platformName;

    if (a.isNotEmpty) return a;
    if (b.isNotEmpty) return b;
    return c;
  }

  void _updateDistanceFromRssi(int rssi) {
    final alpha = 0.3;
    _smoothedRssi = (_smoothedRssi == null)
        ? rssi.toDouble()
        : (_smoothedRssi! * (1 - alpha) + rssi * alpha);

    // Adjusted for typical indoor/line-of-sight: -59 dBm at 1m may be too optimistic
    final measuredPowerAt1m = -65; // more conservative
    final pathLossExponent = 2.5; // indoor/obstructed environments
    final distance =
        pow(10, (measuredPowerAt1m - _smoothedRssi!) / (10 * pathLossExponent))
            .toDouble();

    _currentDistance = distance;
    onDistanceChanged?.call(distance);

    if (distance < 3.0) {
      onProximityAlert?.call(true);
    } else {
      onProximityAlert?.call(false);
    }
  }

  // Initialize BLE service
  Future<bool> initialize() async {
    try {
      if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
        onStatusChanged
            ?.call('BLE locate is available only on Android app builds');
        return false;
      }

      // Request necessary permissions
      await _requestPermissions();

      // Check if Bluetooth is available
      if (!await FlutterBluePlus.isSupported) {
        onStatusChanged?.call('Bluetooth not supported');
        return false;
      }

      // Check if Bluetooth is enabled
      if (await FlutterBluePlus.adapterState.first ==
          BluetoothAdapterState.off) {
        onStatusChanged?.call('Bluetooth disabled');
        return false;
      }

      onStatusChanged?.call('Ready');
      return true;
    } catch (e) {
      onStatusChanged?.call('Initialization failed: $e');
      return false;
    }
  }

  // Request necessary permissions
  Future<void> _requestPermissions() async {
    await Permission.bluetooth.request();
    await Permission.bluetoothScan.request();
    await Permission.locationWhenInUse.request();
  }

  // Start scanning for tracker devices
  Future<void> startScanning({int? targetNodeId}) async {
    if (_isScanning) return;

    _targetNodeId = targetNodeId;

    _isScanning = true;
    if (_targetNodeId != null) {
      onStatusChanged?.call('Scanning for LoRa-Tracker-${_targetNodeId!}...');
    } else {
      onStatusChanged?.call('Scanning...');
    }

    try {
      // Turn on Bluetooth if it's off
      if (await FlutterBluePlus.adapterState.first ==
          BluetoothAdapterState.off) {
        await FlutterBluePlus.turnOn();
      }

      // Reset previous scan state
      _lastRssiByDeviceId.clear();
      _lastSeen = null;
      _lockedDeviceId = null;

      _discoverySubscription = FlutterBluePlus.scanResults.listen((results) {
        ScanResult? best;

        // If we've already identified the tracker device, keep tracking it even if
        // later scan results stop including the advertised name.
        if (_lockedDeviceId != null) {
          for (final r in results) {
            if (r.device.remoteId.str == _lockedDeviceId) {
              best = r;
              break;
            }
          }
        }

        // Otherwise, pick the strongest matching result.
        best ??= (() {
          ScanResult? b;
          for (final r in results) {
            if (!_isTrackerResult(r)) continue;
            if (b == null || r.rssi > b.rssi) {
              b = r;
            }
          }
          return b;
        })();

        if (best == null) return;

        _lockedDeviceId ??= best.device.remoteId.str;

        final id = best.device.remoteId.str;
        _lastRssiByDeviceId[id] = best.rssi;

        _lastSeen = DateTime.now();
        _updateDistanceFromRssi(best.rssi);

        // Throttle status updates to avoid UI churn.
        final now = DateTime.now();
        if (now.difference(_lastStatusAt).inMilliseconds >= 500) {
          _lastStatusAt = now;
          if (_targetNodeId != null) {
            onStatusChanged?.call(
                'Tracking LoRa-Tracker-${_targetNodeId!} (RSSI ${best.rssi})  ~${_currentDistance.toStringAsFixed(1)}m');
          } else {
            onStatusChanged?.call(
                'Tracking tracker (RSSI ${best.rssi})  ~${_currentDistance.toStringAsFixed(1)}m');
          }
        }

        onDeviceFound?.call(best.device);
      });

      // Continuous scan for real-time distance updates.
      // The scan is stopped explicitly via stopScanning() or dispose().
      await FlutterBluePlus.stopScan();
      await FlutterBluePlus.startScan(
        continuousUpdates: true,
        continuousDivisor: 1,
        androidScanMode: AndroidScanMode.lowLatency,
      );
    } catch (e) {
      _isScanning = false;
      await _discoverySubscription?.cancel();
      await FlutterBluePlus.stopScan();
      onStatusChanged?.call('Scan failed: $e');
    }
  }

  // Stop scanning
  Future<void> stopScanning() async {
    _lockedDeviceId = null;
    await _discoverySubscription?.cancel();
    await FlutterBluePlus.stopScan();
    _isScanning = false;
    onStatusChanged?.call('Scan stopped');
  }

  bool _isTrackerResult(ScanResult result) {
    final name = _resultName(result);
    final normalized = _normalizeName(name);

    if (_targetNodeId != null) {
      final target = _normalizeName('LoRa-Tracker-${_targetNodeId!}');
      final mptTarget = _normalizeName('MPT_${_targetNodeId!}');
      return normalized == target ||
          normalized == mptTarget ||
          (normalized.contains('loratracker') &&
              normalized.endsWith('${_targetNodeId!}')) ||
          (normalized.contains('mpt') &&
              normalized.endsWith('${_targetNodeId!}'));
    }

    return normalized.contains('loratracker') ||
        normalized.contains('tracker') ||
        normalized.contains('cow') ||
        normalized.contains('mpt');
  }

  // Connect to specific device
  Future<bool> connectToDevice(BluetoothDevice device) async {
    try {
      onStatusChanged?.call('Connecting to ${device.platformName}');

      await device.connect(license: License.free);
      _connectedDevice = device;

      if (device.isConnected) {
        onStatusChanged?.call('Connected to ${device.platformName}');
        _startDistanceTracking();
        return true;
      }

      return false;
    } catch (e) {
      onStatusChanged?.call('Connection failed: $e');
      return false;
    }
  }

  // Start tracking distance based on signal strength
  void _startDistanceTracking() {
    _updateTimer?.cancel();
    _updateTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_connectedDevice?.isConnected == true) {
        _updateRssiAndDistance();
      }
    });
  }

  Future<void> _updateRssiAndDistance() async {
    final device = _connectedDevice;
    if (device == null || device.isConnected != true) return;

    int rssi;
    try {
      rssi = await device.readRssi();
    } catch (e) {
      onStatusChanged?.call('RSSI read failed: $e');
      return;
    }

    final alpha = 0.3;
    _smoothedRssi = (_smoothedRssi == null)
        ? rssi.toDouble()
        : (_smoothedRssi! * (1 - alpha) + rssi * alpha);

    final measuredPowerAt1m = -59;
    final pathLossExponent = 2.0;
    final distance =
        pow(10, (measuredPowerAt1m - _smoothedRssi!) / (10 * pathLossExponent))
            .toDouble();

    _currentDistance = distance;
    onDistanceChanged?.call(distance);

    if (distance < 5.0) {
      onProximityAlert?.call(true);
    } else {
      onProximityAlert?.call(false);
    }
  }

  // Get current tracking status
  Map<String, dynamic> getTrackingStatus() {
    return {
      'isConnected': _connectedDevice?.isConnected ?? false,
      'deviceName': _connectedDevice?.platformName,
      'deviceAddress': _connectedDevice?.remoteId.str,
      'distance': _currentDistance,
      'isScanning': _isScanning,
      'targetNodeId': _targetNodeId,
      'lastSeen': _lastSeen?.toIso8601String(),
    };
  }

  // Disconnect from current device
  Future<void> disconnect() async {
    _updateTimer?.cancel();
    _smoothedRssi = null;
    if (_connectedDevice?.isConnected == true) {
      await _connectedDevice?.disconnect();
    }
    _connectedDevice = null;
    onStatusChanged?.call('Disconnected');
  }

  // Dispose all resources
  void dispose() {
    _updateTimer?.cancel();
    _discoverySubscription?.cancel();
    FlutterBluePlus.stopScan();
  }
}
