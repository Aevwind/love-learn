import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/study_controller.dart';
import '../../ui/brand.dart';
import '../../ui/dialogs.dart';
import '../../ui/glass.dart';
import '../../ui/theme.dart';

/// Covers the entire navigator, including open pages and dialogs, until entry
/// is verified. Brief focus losses (keyboard, notification shade) do not end a
/// session; hiding or pausing the app does.
class AppAccessGate extends ConsumerStatefulWidget {
  const AppAccessGate({super.key, required this.enabled, required this.child});

  final bool enabled;
  final Widget child;

  @override
  ConsumerState<AppAccessGate> createState() => _AppAccessGateState();
}

class _AppAccessGateState extends ConsumerState<AppAccessGate>
    with WidgetsBindingObserver {
  late bool _locked;
  bool _backgrounded = false;
  int _entry = 0;

  @override
  void initState() {
    super.initState();
    _locked = widget.enabled && ref.read(pinProvider).configured;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didUpdateWidget(covariant AppAccessGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled != oldWidget.enabled) {
      _locked = widget.enabled && ref.read(pinProvider).configured;
      _entry++;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      if (_backgrounded) return;
      FocusManager.instance.primaryFocus?.unfocus();
      setState(() {
        _backgrounded = true;
        _locked = widget.enabled && ref.read(pinProvider).configured;
        // Discard partial input and invalidate verification started before the
        // app left the foreground.
        _entry++;
      });
    } else if (state == AppLifecycleState.resumed && _backgrounded) {
      setState(() => _backgrounded = false);
    }
  }

  void _unlock(int entry) {
    if (!mounted || _backgrounded || entry != _entry) return;
    setState(() => _locked = false);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entry = _entry;
    return Overlay.wrap(
      child: Stack(
        fit: StackFit.expand,
        children: [
          Offstage(
            offstage: _locked,
            child: ExcludeFocus(
              excluding: _locked,
              child: TickerMode(enabled: !_locked, child: widget.child),
            ),
          ),
          if (_locked)
            Scaffold(
              key: const ValueKey('app-password-screen'),
              body: MacaronBackground(
                child: SafeArea(
                  child: Column(
                    children: [
                      const Padding(
                        padding: EdgeInsets.fromLTRB(24, 24, 24, 0),
                        child: Row(
                          children: [
                            Icon(
                              Icons.lock_outline_rounded,
                              color: Palette.mint,
                            ),
                            SizedBox(width: 10),
                            Text(
                              AppBrand.name,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(width: 10),
                            Text(
                              AppBrand.englishName,
                              style: TextStyle(
                                color: Palette.muted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: _backgrounded
                            ? const SizedBox.shrink()
                            : MediaQuery.removeViewInsets(
                                context: context,
                                removeBottom: true,
                                child: PinDialog(
                                  key: ValueKey(entry),
                                  startup: true,
                                  onVerified: () => _unlock(entry),
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
