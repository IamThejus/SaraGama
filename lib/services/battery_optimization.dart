// services/battery_optimization.dart
//
// Thin Dart side of the `com.saragama/battery` MethodChannel (handled in
// MainActivity.kt). Streamed playback stalls when the screen is off because
// Android Doze freezes the app process and restricts its network access; an
// exemption from battery optimization is what keeps background audio alive
// on non-Pixel devices. We ask for it once and never nag again.

import 'dart:io' show Platform;

import 'package:flutter/services.dart';
import 'package:hive/hive.dart';

class BatteryOptimization {
  static const _channel = MethodChannel('com.saragama/battery');
  static const _prefKey = 'batteryOptPrompted';

  /// Show the system battery-optimization exemption dialog once per install
  /// (Android only). No-op if already exempt, already asked, or off-Android.
  static Future<void> maybePrompt() async {
    if (!Platform.isAndroid) return;
    final prefs = Hive.box('AppPrefs');
    if (prefs.get(_prefKey) == true) return;
    try {
      final ignoring = await _channel
              .invokeMethod<bool>('isIgnoringBatteryOptimizations') ??
          false;
      if (ignoring) {
        // Already exempt — remember so we don't re-check every launch.
        await prefs.put(_prefKey, true);
        return;
      }
      await _channel.invokeMethod('requestIgnoreBatteryOptimizations');
      // Mark asked regardless of the user's choice; respecting a decline
      // matters more than the exemption.
      await prefs.put(_prefKey, true);
    } catch (_) {
      // Channel unavailable or platform exception — ignore silently.
    }
  }
}
