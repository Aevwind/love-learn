import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studylock/core/bridge/native_bridge.dart';
import 'package:studylock/core/database/study_database.dart';
import 'package:studylock/core/models.dart';
import 'package:studylock/core/study_controller.dart';

class _UnavailableStorage extends StudyDatabase {
  _UnavailableStorage() : super(NativeDatabase.memory());
  bool fail = true;
  @override
  Future<void> save(StudyState state) async {
    if (fail) throw StateError('storage unavailable');
  }
}

class _StatusBridge extends NativeBridge {
  @override
  bool get supported => true;
  @override
  Future<Map<String, bool>> permissions() async => {};
  @override
  Future<Map<String, dynamic>> snapshot() async => {
    'date': dateKey(),
    'enabled': false,
    'usage': {},
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('a failed save remains visible across status polling until a successful retry', () async {
    final db = _UnavailableStorage();
    addTearDown(db.close);
    final scope = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        initialStateProvider.overrideWithValue(
          const StudyState(realAppList: true),
        ),
        bridgeProvider.overrideWithValue(_StatusBridge()),
      ],
    );
    addTearDown(scope.dispose);
    final controller = scope.read(studyProvider.notifier);
    await expectLater(
      controller.updateSettings(const GuardSettings(limitMinutes: 45)),
      throwsStateError,
    );
    expect(scope.read(studyProvider).error, isNotNull);
    await controller.refreshNative();
    expect(scope.read(studyProvider).error, isNotNull);
    db.fail = false;
    await controller.retrySave();
    expect(scope.read(studyProvider).error, isNull);
    expect(scope.read(studyProvider).settings.limitMinutes, 45);
  });
}
