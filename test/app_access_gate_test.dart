import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studylock/app.dart';
import 'package:studylock/core/bridge/native_bridge.dart';
import 'package:studylock/core/database/study_database.dart';
import 'package:studylock/core/study_controller.dart';
import 'package:studylock/features/security/app_access_gate.dart';
import 'package:studylock/features/security/pin_service.dart';
import 'package:studylock/ui/theme.dart';

class _TestPin extends PinService {
  _TestPin({bool configured = true}) {
    this.configured = configured;
  }

  int verifications = 0;
  Completer<bool>? pending;

  @override
  Future<int> get lockoutSeconds async => 0;

  @override
  Future<bool> verify(String pin) async {
    verifications++;
    return pending == null ? pin == '246810' : await pending!.future;
  }
}

class _PreviewBridge extends NativeBridge {
  @override
  bool get supported => false;
}

Future<void> _studyApp(
  WidgetTester tester,
  _TestPin pin, {
  bool emptyInterception = false,
}) async {
  tester.view.physicalSize = const Size(390, 844);
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
        initialStateProvider.overrideWithValue(
          emptyInterception ? state.copyWith(banks: []) : state,
        ),
        pinProvider.overrideWithValue(pin),
        bridgeProvider.overrideWithValue(_PreviewBridge()),
      ],
      child: StudyLockApp(overlay: emptyInterception),
    ),
  );
  await tester.pumpAndSettle();
}

Widget _app(_TestPin pin) => ProviderScope(
  overrides: [pinProvider.overrideWithValue(pin)],
  child: MaterialApp(
    theme: studyTheme(),
    builder: (context, child) => AppAccessGate(enabled: true, child: child!),
    home: Builder(
      builder: (context) => Scaffold(
        body: Column(
          children: [
            const Text('应用内容'),
            TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => const AlertDialog(title: Text('已打开设置')),
              ),
              child: const Text('打开设置'),
            ),
          ],
        ),
      ),
    ),
  ),
);

Future<void> _enter(WidgetTester tester, [String pin = '246810']) async {
  await tester.enterText(find.byType(TextField), pin);
  await tester.ensureVisible(find.text('验证并继续'));
  await tester.tap(find.text('验证并继续'));
  await tester.pumpAndSettle();
}

Future<void> _backgroundAndReturn(WidgetTester tester) async {
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
  await tester.pump();
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized()
        .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  });

  testWidgets('entry stays covered until a correct application password', (
    tester,
  ) async {
    final pin = _TestPin();
    await tester.pumpWidget(_app(pin));
    await tester.pumpAndSettle();
    expect(find.text('输入应用密码'), findsOneWidget);
    expect(find.text('应用内容'), findsNothing);

    await _enter(tester, '000000');
    expect(find.text('密码不正确，请再试一次'), findsOneWidget);
    expect(find.text('应用内容'), findsNothing);

    await _enter(tester);
    expect(find.text('应用内容'), findsOneWidget);
    await tester.tap(find.text('打开设置'));
    await tester.pumpAndSettle();
    expect(find.text('已打开设置'), findsOneWidget);
    expect(find.text('输入应用密码'), findsNothing);
    expect(pin.verifications, 2);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('brief focus loss keeps the current verified session', (
    tester,
  ) async {
    final pin = _TestPin();
    await tester.pumpWidget(_app(pin));
    await tester.pumpAndSettle();
    await _enter(tester);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('输入应用密码'), findsNothing);
    expect(find.text('应用内容'), findsOneWidget);
    expect(pin.verifications, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'returning from background covers open dialogs and restores them',
    (tester) async {
      final pin = _TestPin();
      await tester.pumpWidget(_app(pin));
      await tester.pumpAndSettle();
      await _enter(tester);
      await tester.tap(find.text('打开设置'));
      await tester.pumpAndSettle();

      await _backgroundAndReturn(tester);
      expect(find.text('输入应用密码'), findsOneWidget);
      expect(find.text('已打开设置'), findsNothing);
      await _enter(tester);
      expect(find.text('输入应用密码'), findsNothing);
      expect(find.text('已打开设置'), findsOneWidget);
      expect(pin.verifications, 2);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'backgrounding clears partial input and invalidates in-flight verification',
    (tester) async {
      final pin = _TestPin()..pending = Completer<bool>();
      await tester.pumpWidget(_app(pin));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '246810');
      await tester.tap(find.text('验证并继续'));
      await tester.pump();

      await _backgroundAndReturn(tester);
      pin.pending!.complete(true);
      await tester.pumpAndSettle();
      expect(find.text('输入应用密码'), findsOneWidget);
      expect(find.text('应用内容'), findsNothing);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );

      pin.pending = null;
      await _enter(tester);
      expect(find.text('应用内容'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'a password first configured this session takes effect on return',
    (tester) async {
      final pin = _TestPin(configured: false);
      await tester.pumpWidget(_app(pin));
      await tester.pumpAndSettle();
      expect(find.text('应用内容'), findsOneWidget);
      pin.configured = true;
      await _backgroundAndReturn(tester);
      expect(find.text('输入应用密码'), findsOneWidget);
      expect(find.text('应用内容'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('password entry fits a narrow screen with the keyboard open', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpWidget(_app(_TestPin()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await _enter(tester);
    expect(find.text('应用内容'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'app selection and password editing reuse the current entry session',
    (tester) async {
      final pin = _TestPin();
      await _studyApp(tester, pin);
      await _enter(tester);
      await tester.tap(find.text('应用').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('选择应用').first);
      await tester.pumpAndSettle();
      expect(find.text('选择需要守护的应用'), findsOneWidget);
      expect(find.text('输入应用密码'), findsNothing);
      await tester.tap(find.byTooltip('关闭'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('安全').first);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('修改应用密码'));
      await tester.tap(find.text('修改应用密码'));
      await tester.pumpAndSettle();
      expect(find.text('设置应用密码'), findsOneWidget);
      expect(find.text('输入应用密码'), findsNothing);
      expect(pin.verifications, 1);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'empty interception opens management through the entry password gate',
    (tester) async {
      final pin = _TestPin();
      await _studyApp(tester, pin, emptyInterception: true);
      expect(find.text('还没有可用题目'), findsOneWidget);
      expect(find.text('输入应用密码'), findsNothing);
      await tester.tap(find.text('打开爱学习'));
      await tester.pumpAndSettle();
      expect(find.text('输入应用密码'), findsOneWidget);
      expect(find.text('我的总览'), findsNothing);
      await _enter(tester);
      expect(find.text('输入应用密码'), findsNothing);
      expect(find.text('专注，是给自己的温柔。'), findsOneWidget);
      expect(pin.verifications, 1);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
