import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final nativeBridgeServiceProvider = Provider<NativeBridgeService>((ref) {
  return NativeBridgeService();
});

class NativeBridgeService {
  static const _channel = MethodChannel('com.mindfullock/control');
  static const _eventChannel = EventChannel('com.mindfullock/app_events');

  Future<Uint8List?> getAppIcon(String packageName) async {
    try {
      final dynamic result = await _channel.invokeMethod('getAppIcon', {
        'packageName': packageName,
      });
      if (result is Uint8List) {
        return result;
      } else if (result is List<dynamic>) {
        return Uint8List.fromList(result.cast<int>());
      }
      return null;
    } catch (e) {
      debugPrint("Failed to get app icon for $packageName: '$e'.");
      return null;
    }
  }

  Future<void> startMonitoring(List<Map<String, dynamic>> blockedRules) async {
    try {
      await _channel.invokeMethod('startMonitoring', {
        'blocked_packages': blockedRules,
      });
    } on PlatformException catch (e) {
      debugPrint("Failed to start monitoring: '${e.message}'.");
    }
  }

  Future<void> stopMonitoring() async {
    try {
      await _channel.invokeMethod('stopMonitoring');
    } on PlatformException catch (e) {
      debugPrint("Failed to stop monitoring: '${e.message}'.");
    }
  }

  Future<void> updateBlockedList(List<Map<String, dynamic>> rules) async {
    try {
      await _channel.invokeMethod('updateBlockedList', {
        'blocked_packages': rules,
      });
    } on PlatformException catch (e) {
      debugPrint("Failed to update blocked list: '${e.message}'.");
    }
  }

  Future<Map<String, bool>> checkAllPermissions() async {
    try {
      final usage = await _channel.invokeMethod<bool>('checkUsagePermission') ?? false;
      final overlay = await _channel.invokeMethod<bool>('checkOverlayPermission') ?? false;
      final battery = await _channel.invokeMethod<bool>('checkBatteryOptimization') ?? false;
      final deviceAdmin = await _channel.invokeMethod<bool>('checkDeviceAdminPermission') ?? false;
      final accessibility = await _channel.invokeMethod<bool>('checkAccessibilityPermission') ?? false;
      final vpn = await _channel.invokeMethod<bool>('checkVpnStatus') ?? false;
      return {
        'usage': usage,
        'overlay': overlay,
        'battery': battery,
        'deviceAdmin': deviceAdmin,
        'accessibility': accessibility,
        'vpn': vpn,
      };
    } on PlatformException catch (e) {
      debugPrint("Failed to check permissions: '${e.message}'.");
      return {'usage': false, 'overlay': false, 'battery': false, 'deviceAdmin': false, 'accessibility': false, 'vpn': false};
    }
  }

  Future<void> openSettingsFor(String type) async {
    try {
      switch (type) {
        case 'usage':
          await _channel.invokeMethod('openUsageSettings');
          break;
        case 'overlay':
          await _channel.invokeMethod('openOverlaySettings');
          break;
        case 'battery':
          await _channel.invokeMethod('openBatterySettings');
          break;
        case 'deviceAdmin':
          await _channel.invokeMethod('requestDeviceAdminPermission');
          break;
        case 'accessibility':
          await _channel.invokeMethod('requestAccessibilityPermission');
          break;
      }
    } on PlatformException catch (e) {
      debugPrint("Failed to open settings for $type: '${e.message}'.");
    }
  }

  Future<void> removeDeviceAdmin() async {
    try {
      await _channel.invokeMethod('removeDeviceAdmin');
    } on PlatformException catch (e) {
      debugPrint("Failed to remove device admin: '${e.message}'.");
    }
  }

  Future<List<Map<String, dynamic>>> getInstalledApps() async {
    try {
      final List<dynamic>? appsList = await _channel.invokeMethod<List<dynamic>>('getInstalledApps');
      if (appsList != null) {
        return appsList.map((dynamic item) => Map<String, dynamic>.from(item as Map)).toList();
      }
      return [];
    } catch (e) {
      debugPrint("Failed to get installed apps: '$e'.");
      return [];
    }
  }

  Future<void> startVpnService() async {
    try {
      await _channel.invokeMethod('startVpnService');
    } on PlatformException catch (e) {
      debugPrint("Failed to start VPN service: '${e.message}'.");
    }
  }

  Future<void> stopVpnService() async {
    try {
      await _channel.invokeMethod('stopVpnService');
    } on PlatformException catch (e) {
      debugPrint("Failed to stop VPN service: '${e.message}'.");
    }
  }

  Future<Map<String, int>> getNativeQuotaUsage() async {
    try {
      final res = await _channel.invokeMethod<Map>('getNativeQuotaUsage');
      if (res != null) {
        return res.map((k, v) => MapEntry(k.toString(), (v as num).toInt()));
      }
      return {};
    } catch (e) {
      debugPrint("Failed to get native quota usage: $e");
      return {};
    }
  }

  Stream<String> get appBlockedEvents {
    return _eventChannel.receiveBroadcastStream().map((dynamic event) => event.toString());
  }
}
