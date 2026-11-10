import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studylock/app.dart';
import 'package:studylock/core/bridge/native_bridge.dart';
import 'package:studylock/core/database/study_database.dart';
import 'package:studylock/core/study_controller.dart';
import 'package:studylock/features/security/pin_service.dart';
import 'package:studylock/features/quiz/quiz_screen.dart';
import 'package:studylock/ui/theme.dart';
import 'package:drift/native.dart';

class _PreviewBridge extends NativeBridge {
  @override
  bool get supported => false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final width in [360.0, 390.0, 768.0, 1024.0, 1440.0]) {
    testWidgets('all main pages fit at ${width.toInt()}px', (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final db = StudyDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final state = (await tester.runAsync(db.load))!;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            initialStateProvider.overrideWithValue(state),
            pinProvider.overrideWithValue(PinService()),
            bridgeProvider.overrideWithValue(_PreviewBridge()),
          ],
          child: const StudyLockApp(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 250));
      expect(tester.takeException(), isNull);
      final mobile = width < 600;
      final full = width >= 1100;
      for (final label
          in mobile
              ? ['应用', '题库', '错题', '安全']
              : ['应用守护', '知识题库', '我的错题', '安全中心']) {
        if (full || mobile) {
          await tester.tap(find.text(label).first);
        } else {
          final index = ['应用守护', '知识题库', '我的错题', '安全中心'].indexOf(label);
          await tester.tap(
            find
                .byIcon(
                  [
                    Icons.hourglass_empty_rounded,
                    Icons.auto_stories_outlined,
                    Icons.bookmark_border_rounded,
                    Icons.verified_user_outlined,
                  ][index],
                )
                .first,
          );
        }
        await tester.pumpAndSettle(
          const Duration(milliseconds: 100),
          EnginePhase.sendSemanticsUpdate,
          const Duration(seconds: 5),
        );
        expect(tester.takeException(), isNull, reason: '$label at $width');
      }
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  for (final width in [360.0, 768.0, 1440.0]) {
    testWidgets('quiz handles a 20-question goal at ${width.toInt()}px', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final db = StudyDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final original = (await tester.runAsync(db.load))!;
      final state = original.copyWith(
        settings: original.settings.copyWith(requiredCorrect: 20),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            initialStateProvider.overrideWithValue(state),
            pinProvider.overrideWithValue(PinService()),
            bridgeProvider.overrideWithValue(_PreviewBridge()),
          ],
          child: MaterialApp(theme: studyTheme(), home: const QuizScreen()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 250));
      expect(tester.takeException(), isNull);
      expect(find.text('0 / 20'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
