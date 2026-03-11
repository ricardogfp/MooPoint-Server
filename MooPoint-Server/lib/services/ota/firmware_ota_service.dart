import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:nordic_dfu/nordic_dfu.dart';
import 'package:moo_point/services/api/node_backend_config.dart';
import 'package:moo_point/services/api/node_backend_http_client.dart';

class FirmwareOtaService {
  final http.Client _client;

  FirmwareOtaService({http.Client? client})
      : _client = client ?? createNodeBackendHttpClient();

  String get _baseUrl => NodeBackendConfig.baseUrl.endsWith('/')
      ? NodeBackendConfig.baseUrl
          .substring(0, NodeBackendConfig.baseUrl.length - 1)
      : NodeBackendConfig.baseUrl;

  /// Download firmware DFU package from server
  Future<String> downloadFirmware(int firmwareId) async {
    if (kIsWeb) {
      throw UnsupportedError('Firmware download not supported on web');
    }

    final url = Uri.parse('$_baseUrl/admin/firmware/download/$firmwareId');
    final response =
        await _client.get(url).timeout(const Duration(seconds: 60));

    if (response.statusCode != 200) {
      throw Exception(
          'Failed to download firmware: HTTP ${response.statusCode}');
    }

    // Save to temporary directory
    final tempDir = await getTemporaryDirectory();
    final filePath = '${tempDir.path}/firmware_$firmwareId.zip';
    final file = File(filePath);
    await file.writeAsBytes(response.bodyBytes);

    return filePath;
  }

  /// Perform DFU update on device
  Future<void> performDfuUpdate(
    String deviceAddress,
    String zipPath, {
    Function(int)? onProgress,
    Function()? onComplete,
    Function(String)? onError,
  }) async {
    if (kIsWeb) {
      throw UnsupportedError('DFU not supported on web');
    }

    try {
      debugPrint('DFU: Starting DFU process for device $deviceAddress');
      debugPrint('DFU: Firmware file: $zipPath');

      await NordicDfu()
          .startDfu(
            deviceAddress,
            zipPath,
            fileInAsset: false,
            dfuEventHandler: DfuEventHandler(
              onProgressChanged: (
                String? deviceAddress,
                int? percent,
                double? speed,
                double? avgSpeed,
                int? currentPart,
                int? partsTotal,
              ) {
                debugPrint('DFU: Progress: $percent%');
                if (percent != null && onProgress != null) {
                  onProgress(percent);
                }
              },
              onDeviceConnecting: (String? deviceAddress) {
                debugPrint('DFU: Connecting to $deviceAddress');
              },
              onDeviceConnected: (String? deviceAddress) {
                debugPrint('DFU: Connected to $deviceAddress');
              },
              onDfuProcessStarting: (String? deviceAddress) {
                debugPrint('DFU: Process starting');
              },
              onDfuProcessStarted: (String? deviceAddress) {
                debugPrint('DFU: Process started');
              },
              onEnablingDfuMode: (String? deviceAddress) {
                debugPrint('DFU: Enabling DFU mode');
              },
              onFirmwareValidating: (String? deviceAddress) {
                debugPrint('DFU: Validating firmware');
              },
              onDeviceDisconnecting: (String? deviceAddress) {
                debugPrint('DFU: Disconnecting');
              },
              onDeviceDisconnected: (String? deviceAddress) {
                debugPrint('DFU: Disconnected');
              },
              onDfuCompleted: (String? deviceAddress) {
                debugPrint('DFU: Completed successfully');
                if (onComplete != null) {
                  onComplete();
                }
              },
              onDfuAborted: (String? deviceAddress) {
                debugPrint('DFU: Aborted');
                if (onError != null) {
                  onError('DFU aborted');
                }
              },
              onError: (
                String? deviceAddress,
                int? error,
                int? errorType,
                String? message,
              ) {
                debugPrint(
                    'DFU: Error $error - Type: $errorType - Message: $message');
                if (onError != null) {
                  onError('DFU Error $error: $message');
                }
              },
            ),
          )
          .timeout(const Duration(minutes: 10));
    } catch (e) {
      debugPrint('DFU: Exception occurred: $e');
      if (onError != null) {
        onError('DFU Exception: $e');
      }
      rethrow;
    }
  }

  /// Check if device is in DFU mode (bootloader)
  /// DFU devices typically have "DFU" in their name
  bool isDfuDevice(String deviceName) {
    return deviceName.toUpperCase().contains('DFU');
  }

  /// Scan for DFU devices specifically
  Future<List<String>> scanForDfuDevices() async {
    // This would require BLE scanning capabilities
    // For now, just return empty - the app should connect directly
    return [];
  }

  /// Clean up temporary firmware files
  Future<void> cleanupTempFiles() async {
    if (kIsWeb) return;

    try {
      final tempDir = await getTemporaryDirectory();
      final files = tempDir.listSync();
      for (final file in files) {
        if (file.path.contains('firmware_') && file.path.endsWith('.zip')) {
          try {
            file.deleteSync();
          } catch (e) {
            debugPrint('Failed to delete temp file: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('Failed to cleanup temp files: $e');
    }
  }
}
