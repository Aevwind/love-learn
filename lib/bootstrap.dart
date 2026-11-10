import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/database/study_database.dart';
import 'core/study_controller.dart';
import 'features/security/pin_service.dart';
import 'ui/glass.dart';
import 'ui/theme.dart';

Future<void> runStudyLock({bool overlay = false}) async {
  WidgetsFlutterBinding.ensureInitialized();
  final database = StudyDatabase();
  try {
    final state = await database.load();
    final pin = PinService();
    await pin.initialize();
    runApp(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          initialStateProvider.overrideWithValue(state),
          pinProvider.overrideWithValue(pin),
        ],
        child: StudyLockApp(
          overlay:
              overlay ||
              PlatformDispatcher.instance.defaultRouteName == '/intercept',
        ),
      ),
    );
  } catch (_) {
    await database.close();
    runApp(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: studyTheme(),
        home: Scaffold(
          body: MacaronBackground(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: GlassPanel(
                  child: EmptyState(
                    '暂时无法打开学习空间',
                    '请检查本地存储是否可用，然后再试一次。\n网页端请使用常规模式并允许网站存储。',
                    icon: Icons.cloud_off_outlined,
                    action: SoftButton(
                      '重新打开',
                      onPressed: () => runStudyLock(overlay: overlay),
                      filled: true,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
