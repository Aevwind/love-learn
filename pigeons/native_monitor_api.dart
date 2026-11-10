import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/core/bridge/native_monitor.g.dart',
    kotlinOut: 'android/app/src/main/kotlin/com/studylock/studylock/NativeMonitor.g.kt',
    kotlinOptions: KotlinOptions(package: 'com.studylock.studylock'),
  ),
)
class InstalledAppInfo {
  InstalledAppInfo({
    required this.packageName,
    required this.name,
    required this.iconBase64,
    required this.category,
  });
  String packageName;
  String name;
  String? iconBase64;
  String category;
}

@HostApi()
abstract class NativeMonitorHostApi {
  List<InstalledAppInfo> getInstalledApps();
  Map<String, bool> getPermissionStatus();
  void requestPermission(String permission);
  void syncMonitorPolicy(String policyJson);
  void setGuardEnabled(bool enabled);
  void notifyQuizPassed();
  String getMonitorState();
  void openEmergencyDialer();
}
