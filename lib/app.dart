import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ui/app_shell.dart';
import 'ui/brand.dart';
import 'ui/theme.dart';
import 'features/quiz/quiz_screen.dart';
import 'features/security/app_access_gate.dart';

class StudyLockApp extends ConsumerStatefulWidget {
  const StudyLockApp({super.key, this.overlay = false});
  final bool overlay;
  @override
  ConsumerState<StudyLockApp> createState() => _StudyLockAppState();
}

class _StudyLockAppState extends ConsumerState<StudyLockApp> {
  bool _managementRequested = false;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: AppBrand.title,
    debugShowCheckedModeBanner: false,
    theme: studyTheme(),
    locale: const Locale('zh', 'CN'),
    supportedLocales: const [Locale('zh', 'CN'), Locale('en')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    home: widget.overlay && !_managementRequested
        ? QuizScreen(
            enforced: true,
            onOpenApp: () => setState(() => _managementRequested = true),
          )
        : const AppShell(),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: MediaQuery.textScalerOf(context)
            .clamp(minScaleFactor: 1, maxScaleFactor: 1.6),
      ),
      child: AppAccessGate(
        enabled: !widget.overlay || _managementRequested,
        child: child!,
      ),
    ),
  );
}
