import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:moo_point/services/ble/ble_tracker_service.dart';
import 'package:moo_point/services/api/node_backend_service.dart';

class CompassTrackerPage extends StatefulWidget {
  final int? initialNodeId;
  final bool autoRequestLocate;

  const CompassTrackerPage({
    super.key,
    this.initialNodeId,
    this.autoRequestLocate = false,
  });

  @override
  State<CompassTrackerPage> createState() => _CompassTrackerPageState();
}

class _CompassTrackerPageState extends State<CompassTrackerPage>
    with TickerProviderStateMixin {
  final BLETrackerService _bleService = BLETrackerService();
  final NodeBackendService _backend = NodeBackendService();
  static const MethodChannel _beepChannel = MethodChannel('moopoint/beep');
  double _distance = double.infinity;
  String _status = 'Initializing...';
  final bool _isConnected = false;
  bool _isProximityAlert = false;
  bool _requesting = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  Timer? _beepTimer;
  int _beepCooldownMs = 1200;
  DateTime _lastBeepAt = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();

    // Initialize pulse animation for proximity alerts
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Initialize BLE service
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      _status = 'BLE locate is available only on Android app builds';
      return;
    }
    _initializeBLE();
  }

  int _nodeId() {
    final v = widget.initialNodeId ?? 1;
    if (v <= 0) return 1;
    if (v > 255) return 255;
    return v;
  }

  Future<void> _initializeBLE() async {
    final success = await _bleService.initialize();
    if (!success) {
      setState(() => _status = 'BLE initialization failed');
      return;
    }

    // Set up callbacks
    _bleService.onStatusChanged = (String status) {
      setState(() => _status = status);
    };

    _bleService.onDistanceChanged = (double distance) {
      setState(() => _distance = distance);
      _updateBeepRateFromDistance(distance);
    };

    _bleService.onProximityAlert = (bool alert) {
      setState(() {
        _isProximityAlert = alert;
        if (alert) {
          _pulseController.repeat();
        } else {
          _pulseController.stop();
          _pulseController.reset();
        }
      });
    };

    if (widget.autoRequestLocate) {
      await _requestLocate();
    }

    // Start scanning (scan-only locate)
    _ensureBeepTimer();
    await _bleService.startScanning(targetNodeId: _nodeId());
  }

  void _ensureBeepTimer() {
    _beepTimer ??= Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted) return;
      if (!(_distance.isFinite)) return;

      final now = DateTime.now();
      if (now.difference(_lastBeepAt).inMilliseconds < _beepCooldownMs) return;

      _lastBeepAt = now;
      unawaited(() async {
        try {
          await _beepChannel.invokeMethod('beep', {
            'durationMs': 80,
            'volume': 90,
          });
        } catch (e) {
          if (!mounted) return;
          setState(() {
            _status = 'Beep failed: $e';
          });
        }
      }());
      HapticFeedback.selectionClick();
    });
  }

  void _updateBeepRateFromDistance(double distance) {
    if (!distance.isFinite) {
      _beepCooldownMs = 2000;
      return;
    }
    if (distance >= 10.0) {
      _beepCooldownMs = 2000;
      return;
    }
    if (distance >= 6.0) {
      _beepCooldownMs = 1500;
      return;
    }
    if (distance >= 4.0) {
      _beepCooldownMs = 1100;
      return;
    }
    if (distance <= 0.5) {
      _beepCooldownMs = 120;
      return;
    }
    if (distance <= 1.0) {
      _beepCooldownMs = 200;
      return;
    }
    if (distance <= 2.0) {
      _beepCooldownMs = 350;
      return;
    }
    if (distance <= 3.0) {
      _beepCooldownMs = 600;
      return;
    }
    _beepCooldownMs = 1200;
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _beepTimer?.cancel();
    _bleService.dispose();
    _backend.dispose();
    super.dispose();
  }

  Future<void> _requestLocate() async {
    final nodeId = _nodeId();

    setState(() {
      _requesting = true;
      _status = 'Requesting locate for node $nodeId...';
    });

    try {
      await _backend.requestBleLocate(nodeId, minutes: 5);
      if (!mounted) return;
      setState(() =>
          _status = 'Locate requested. Waiting for next tracker uplink...');
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = 'Locate request failed: $e');
    } finally {
      if (mounted) setState(() => _requesting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final nodeId = _nodeId();
    return Scaffold(
      appBar: AppBar(
        title: const Text('BLE Locate'),
        backgroundColor: Colors.red[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(_isConnected
                ? Icons.bluetooth_connected
                : Icons.bluetooth_searching),
            onPressed: () {
              if (_isConnected) {
                _bleService.disconnect();
              } else {
                _bleService.startScanning(targetNodeId: nodeId);
              }
            },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.grey[900]!,
              Colors.grey[800]!,
            ],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  16,
                  88,
                  16,
                  16 + MediaQuery.of(context).padding.bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ElevatedButton(
                            onPressed: _requesting ? null : _requestLocate,
                            child: const Text('Request Locate (5 min)'),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: () =>
                                _bleService.startScanning(targetNodeId: nodeId),
                            child: const Text('Start Scanning'),
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton(
                            onPressed: () async {
                              try {
                                await _beepChannel.invokeMethod('beep', {
                                  'durationMs': 200,
                                  'volume': 95,
                                });
                              } catch (e) {
                                if (!mounted) return;
                                setState(() {
                                  _status = 'Beep failed: $e';
                                });
                              }
                            },
                            child: const Text('Test Beep'),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Proximity indicator (pulsing circle when nearby)
                    AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale:
                              _isProximityAlert ? _pulseAnimation.value : 1.0,
                          child: Container(
                            width: 180,
                            height: 180,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withOpacity(0.05),
                              border: Border.all(
                                color: _isProximityAlert
                                    ? Colors.red
                                    : Colors.green,
                                width: 3,
                              ),
                            ),
                            child: Center(
                              child: Icon(
                                _isProximityAlert
                                    ? Icons.warning
                                    : Icons.bluetooth_searching,
                                size: 60,
                                color: _isProximityAlert
                                    ? Colors.red
                                    : Colors.green,
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 16),

                    // Distance indicator
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'Distance to Tracker',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _distance == double.infinity
                                ? 'Searching...'
                                : '${_distance.toStringAsFixed(1)} m',
                            style: TextStyle(
                              color:
                                  _isProximityAlert ? Colors.red : Colors.green,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Proximity alert indicator
                    if (_isProximityAlert)
                      Container(
                        margin: const EdgeInsets.only(top: 20),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.warning, color: Colors.white),
                            SizedBox(width: 8),
                            Text(
                              'TRACKER NEARBY!',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.75),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _status,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
