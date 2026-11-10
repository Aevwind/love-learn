import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'native_monitor.g.dart';
import '../models.dart';

class NativeBridge {
  final _host = NativeMonitorHostApi();
  bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  Future<Map<String, bool>> permissions() async =>
      supported ? (await _host.getPermissionStatus()).cast<String, bool>() : {};
  Future<List<MonitoredApp>> installedApps() async {
    if (!supported) return [];
    final apps = await _host.getInstalledApps();
    return apps
        .map(
          (a) => MonitoredApp(
            id: a.packageName,
            name: a.name,
            category: a.category,
            enabled: false,
            icon: a.iconBase64,
          ),
        )
        .toList();
  }

  Future<void> request(String permission) =>
      _host.requestPermission(permission);
  Future<void> sync(StudyState state) => _host.syncMonitorPolicy(
    jsonEncode({
      ...state.settings.toJson(),
      'packages': {
        for (final a in state.apps.where((a) => a.enabled))
          a.id: {'name': a.name, 'limitSeconds': a.customLimit * 60},
      },
    }),
  );
  Future<void> setEnabled(bool enabled) => _host.setGuardEnabled(enabled);
  Future<Map<String, dynamic>> snapshot() async => supported
      ? (jsonDecode(await _host.getMonitorState()) as Map)
            .cast<String, dynamic>()
      : {};
  Future<void> passed() async {
    if (supported) await _host.notifyQuizPassed();
  }

  Future<void> emergencyDialer() async {
    if (supported) await _host.openEmergencyDialer();
  }
}
