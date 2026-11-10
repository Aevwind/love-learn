import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/models.dart';
import '../core/study_controller.dart';
import '../features/dashboard/dashboard_page.dart';
import '../features/monitor/monitor_page.dart';
import '../features/banks/banks_page.dart';
import '../features/security/security_page.dart';
import '../features/quiz/quiz_screen.dart';
import 'dialogs.dart';
import 'brand.dart';
import 'glass.dart';
import 'theme.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});
  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell>
    with WidgetsBindingObserver {
  int _index = 0;
  final _scroll = ScrollController();
  Timer? _nativeTimer;
  bool _polling = false;
  static const _items = [
    (Icons.grid_view_rounded, '我的总览'),
    (Icons.hourglass_empty_rounded, '应用守护'),
    (Icons.auto_stories_outlined, '知识题库'),
    (Icons.bookmark_border_rounded, '我的错题'),
    (Icons.verified_user_outlined, '安全中心'),
  ];
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _poll();
    });
    _nativeTimer = Timer.periodic(const Duration(seconds: 3), (_) => _poll());
  }

  Future<void> _poll() async {
    if (_polling || !ref.read(bridgeProvider).supported) return;
    _polling = true;
    try {
      await ref.read(studyProvider.notifier).refreshNative();
    } catch (_) {
      /* Permission status is checked again on resume. */
    } finally {
      _polling = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      Future.microtask(() async {
        try {
          await ref.read(studyProvider.notifier).reloadFromDisk();
        } catch (_) {}
        if (mounted) _poll();
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _nativeTimer?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  void _navigate(int i) {
    if (_index == i) return;
    setState(() => _index = i);
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  Future<void> _practice([List<Question>? questions]) async {
    if ((questions ?? ref.read(studyProvider).enabledQuestions).isEmpty) {
      showMessage(context, '当前没有可用题目，先去题库启用一本或调整筛选条件吧。');
      return;
    }
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => QuizScreen(questions: questions)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(studyProvider);
    final width = MediaQuery.sizeOf(context).width;
    final mobile = width < 600;
    final expandedNav = width >= 1100;
    final body = switch (_index) {
      0 => DashboardPage(onPractice: () => _practice(), onNavigate: _navigate),
      1 => const MonitorPage(),
      2 => const BanksPage(),
      3 => MistakesPage(onPractice: (q) => _practice(q)),
      _ => const SecurityPage(),
    };
    return Scaffold(
      body: MacaronBackground(
        child: SafeArea(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!mobile)
                SizedBox(
                  width: expandedNav ? 222 : 86,
                  child: _sidebar(expandedNav),
                ),
              Expanded(
                child: Column(
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        mobile ? 22 : 30,
                        22,
                        mobile ? 22 : 30,
                        18,
                      ),
                      child: Row(
                        children: [
                          if (mobile) ...[
                            const Icon(
                              Icons.lock_outline_rounded,
                              size: 23,
                              color: Palette.mint,
                            ),
                            const SizedBox(width: 8),
                          ],
                          Text(
                            mobile ? AppBrand.name : '我的学习空间',
                            style: TextStyle(
                              fontSize: mobile ? 18 : 13,
                              fontWeight: mobile
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: mobile ? Palette.ink : Palette.muted,
                            ),
                          ),
                          if (!mobile) ...[
                            const SizedBox(width: 10),
                            const Icon(
                              Icons.chevron_right_rounded,
                              size: 14,
                              color: Palette.muted,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _items[_index].$2,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                          const Spacer(),
                          if (width >= 750) ...[
                            const Icon(
                              Icons.calendar_today_outlined,
                              size: 13,
                              color: Palette.muted,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _date(),
                              style: const TextStyle(
                                fontSize: 11,
                                color: Palette.muted,
                              ),
                            ),
                            const SizedBox(width: 18),
                          ],
                          IconButton(
                            onPressed: () => showDialog<void>(
                              context: context,
                              builder: (_) => GlassDialog(
                                width: 420,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SectionHeading(
                                      '很高兴，和你一起成长',
                                      subtitle:
                                          '${AppBrand.title} · ${AppBrand.version}',
                                      icon: Icons.spa_outlined,
                                    ),
                                    const SizedBox(height: 22),
                                    const Text(
                                      '先挑选想守护的应用，再设置合适的娱乐时长与解锁目标。\n\n达到时长后，用一小组题目给大脑充电。错题会自动收进错题本，连续答对 3 次便能毕业。\n\n你也可以随时从总览开始自由练习。',
                                      style: TextStyle(
                                        fontSize: 13,
                                        height: 2,
                                        color: Palette.muted,
                                      ),
                                    ),
                                    const SizedBox(height: 22),
                                    SoftButton(
                                      '知道啦',
                                      onPressed: () => Navigator.pop(context),
                                      filled: true,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            icon: const Icon(
                              Icons.help_outline_rounded,
                              size: 20,
                              color: Palette.muted,
                            ),
                            tooltip: '使用指南',
                          ),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: () => _navigate(4),
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              width: 37,
                              height: 37,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFFEEE1D3),
                                    Color(0xFFE4EBCF),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(13),
                                border: Border.all(color: Colors.white),
                              ),
                              child: const Text(
                                '学',
                                style: TextStyle(
                                  fontSize: 15,
                                  color: Color(0xFF8D9A79),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (state.error != null)
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 24),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Palette.peachLight,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                state.error!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Palette.rose,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () async {
                                try {
                                  await ref
                                      .read(studyProvider.notifier)
                                      .retrySave();
                                } catch (_) {
                                  if (context.mounted) {
                                    showMessage(context, '暂时仍无法保存');
                                  }
                                }
                              },
                              child: const Text('重试'),
                            ),
                          ],
                        ),
                      ),
                    Expanded(
                      child: Scrollbar(
                        controller: _scroll,
                        child: SingleChildScrollView(
                          controller: _scroll,
                          padding: EdgeInsets.fromLTRB(
                            mobile ? 18 : 30,
                            16,
                            mobile ? 18 : 30,
                            32,
                          ),
                          child: Align(
                            alignment: Alignment.topCenter,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 1400),
                              child: AnimatedSwitcher(
                                duration:
                                    MediaQuery.disableAnimationsOf(context)
                                    ? Duration.zero
                                    : const Duration(milliseconds: 200),
                                child: KeyedSubtree(
                                  key: ValueKey(_index),
                                  child: body,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (mobile) _bottomNav(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _date() {
    final now = DateTime.now();
    return '${now.month}月${now.day}日 · 星期${['一', '二', '三', '四', '五', '六', '日'][now.weekday - 1]}';
  }

  Widget _sidebar(bool full) => Padding(
    padding: EdgeInsets.fromLTRB(full ? 18 : 12, 26, full ? 16 : 12, 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.only(left: full ? 10 : 5),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFB5D0BB), Color(0xFF79A38E)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withValues(alpha: .8)),
                  boxShadow: [
                    BoxShadow(
                      color: Palette.mint.withValues(alpha: .15),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.lock_outline_rounded,
                  color: Colors.white,
                  size: 23,
                ),
              ),
              if (full) ...[
                const SizedBox(width: 11),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          AppBrand.name,
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -.8,
                          ),
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '${AppBrand.englishName} · 专注生长',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 9,
                          color: Palette.muted,
                          letterSpacing: .7,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 48),
        if (full)
          const Padding(
            padding: EdgeInsets.only(left: 16, bottom: 18),
            child: Text(
              '我的工作台',
              style: TextStyle(
                fontSize: 10,
                color: Palette.muted,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ...List.generate(
          _items.length,
          (i) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Tooltip(
              message: full ? '' : _items[i].$2,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _navigate(i),
                  borderRadius: BorderRadius.circular(14),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    height: 49,
                    decoration: BoxDecoration(
                      color: _index == i
                          ? Colors.white.withValues(alpha: .78)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _index == i ? Colors.white : Colors.transparent,
                      ),
                      boxShadow: _index == i
                          ? [
                              BoxShadow(
                                color: Palette.mint.withValues(alpha: .04),
                                blurRadius: 14,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : [],
                    ),
                    padding: EdgeInsets.symmetric(horizontal: full ? 16 : 0),
                    child: Row(
                      mainAxisAlignment: full
                          ? MainAxisAlignment.start
                          : MainAxisAlignment.center,
                      children: [
                        Icon(
                          _items[i].$1,
                          size: 20,
                          color: _index == i ? Palette.mint : Palette.muted,
                        ),
                        if (full) ...[
                          const SizedBox(width: 14),
                          Text(
                            _items[i].$2,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: _index == i
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              color: _index == i ? Palette.mint : Palette.muted,
                            ),
                          ),
                          const Spacer(),
                          if (i == 3 &&
                              ref.watch(studyProvider).mistakes.isNotEmpty)
                            Text(
                              '${ref.watch(studyProvider).mistakes.length}',
                              style: const TextStyle(
                                fontSize: 10,
                                color: Palette.peach,
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const Spacer(),
        if (full)
          GlassPanel(
            padding: const EdgeInsets.all(17),
            radius: 18,
            opacity: .46,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.eco_outlined, color: Palette.mint, size: 23),
                const SizedBox(height: 11),
                const Text(
                  '每天，长大一点点',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 7),
                const Text(
                  '你的专注，正在悄悄发芽。',
                  style: TextStyle(fontSize: 10, color: Palette.muted),
                ),
                const SizedBox(height: 14),
                InkWell(
                  onTap: () => _practice(),
                  child: const Row(
                    children: [
                      Text(
                        '开始今日练习',
                        style: TextStyle(fontSize: 10, color: Palette.mint),
                      ),
                      Spacer(),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 14,
                        color: Palette.mint,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 22),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.privacy_tip_outlined,
              size: 12,
              color: Palette.muted,
            ),
            if (full) ...[
              const SizedBox(width: 7),
              const Text(
                '本地存储 · 安心私密',
                style: TextStyle(fontSize: 9, color: Palette.muted),
              ),
            ],
          ],
        ),
      ],
    ),
  );
  Widget _bottomNav() => GlassPanel(
    radius: 0,
    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
    opacity: .85,
    child: Row(
      children: List.generate(
        _items.length,
        (i) => Expanded(
          child: InkWell(
            onTap: () => _navigate(i),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _items[i].$1,
                    size: 22,
                    color: _index == i ? Palette.mint : Palette.muted,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    ['总览', '应用', '题库', '错题', '安全'][i],
                    style: TextStyle(
                      fontSize: 10,
                      color: _index == i ? Palette.mint : Palette.muted,
                      fontWeight: _index == i
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
