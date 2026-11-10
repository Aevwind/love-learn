import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models.dart';
import '../../core/study_controller.dart';
import '../../ui/dialogs.dart';
import '../../ui/glass.dart';
import '../../ui/theme.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({
    super.key,
    required this.onPractice,
    required this.onNavigate,
  });
  final VoidCallback onPractice;
  final ValueChanged<int> onNavigate;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(studyProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageTitle(
          '专注，是给自己的温柔。',
          '把一点点分心，变成一点点进步。今天也和爱学习一起成长吧。',
          trailing: SoftButton(
            '来一组练习',
            icon: Icons.auto_awesome_outlined,
            onPressed: onPractice,
          ),
        ),
        LayoutBuilder(
          builder: (context, c) {
            final wide = MediaQuery.sizeOf(context).width >= 900;
            final main = Column(
              children: [
                _HeroCard(
                  state: state,
                  onPractice: onPractice,
                  onGuard: () => runAction(
                    context,
                    () => ref
                        .read(studyProvider.notifier)
                        .setGuard(!state.guarding),
                  ),
                ),
                const SizedBox(height: 20),
                _Statistics(state),
                const SizedBox(height: 24),
                ControlledAppsCard(onManage: () => onNavigate(1)),
                const SizedBox(height: 24),
                _BankOverview(
                  onNavigate: () => onNavigate(2),
                  onImport: () => openImport(context, ref),
                ),
                const SizedBox(height: 24),
                _WeekChart(state),
              ],
            );
            final aside = Column(
              children: [
                _TodayCard(state: state, onPractice: onPractice),
                const SizedBox(height: 20),
                _RuleCard(state: state, onNavigate: () => onNavigate(1)),
                const SizedBox(height: 20),
                _MistakeCard(state: state, onNavigate: () => onNavigate(3)),
                const SizedBox(height: 20),
                _QuoteCard(),
              ],
            );
            return wide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: main),
                      const SizedBox(width: 22),
                      SizedBox(
                        width: c.maxWidth < 900 ? 228 : 266,
                        child: aside,
                      ),
                    ],
                  )
                : Column(children: [main, const SizedBox(height: 24), aside]);
          },
        ),
        const SizedBox(height: 28),
        const Center(
          child: Text(
            '慢一点也没关系，每一次专注都算数。',
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 1,
              color: Palette.muted,
            ),
          ),
        ),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.state,
    required this.onPractice,
    required this.onGuard,
  });
  final StudyState state;
  final VoidCallback onPractice, onGuard;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final small = c.maxWidth < 470;
      return GlassPanel(
        tint: const Color(0xFFEEF6EE),
        opacity: .61,
        padding: EdgeInsets.all(small ? 24 : 30),
        child: SizedBox(
          height:
              (small ? 300 : 240) +
              (MediaQuery.textScalerOf(context).scale(14) / 14 - 1) * 140,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                right: small ? -25 : -12,
                top: small ? 85 : -12,
                child: Opacity(
                  opacity: small ? .76 : 1,
                  child: LockArtwork(
                    size: small
                        ? 190
                        : c.maxWidth < 600
                        ? 210
                        : 246,
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Pill(state.guarding ? '正在温柔守护' : '你的专注小伙伴', dot: true),
                      const SizedBox(width: 8),
                      if (!small)
                        const Text(
                          'STUDY A LITTLE, GROW A LOT',
                          style: TextStyle(
                            fontSize: 8,
                            letterSpacing: 1.4,
                            color: Palette.muted,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 21),
                  Text(
                    '把时间，留给\n更好的自己。',
                    style: TextStyle(
                      fontSize: small ? 29 : 32,
                      fontWeight: FontWeight.w700,
                      height: 1.5,
                      letterSpacing: 1,
                      color: const Color(0xFF3E6656),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    state.guarding ? '守护已开启，让分心在这里停一停。' : '少一点无意识滑动，多一点有所收获。',
                    style: TextStyle(
                      fontSize: small ? 11 : 12,
                      color: Palette.mint,
                      height: 1.6,
                    ),
                  ),
                  const Spacer(),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      SoftButton(
                        state.guarding ? '暂停守护' : '开始守护',
                        icon: state.guarding
                            ? Icons.pause_rounded
                            : Icons.shield_outlined,
                        onPressed: onGuard,
                        filled: true,
                        compact: true,
                      ),
                      SoftButton(
                        '体验答题',
                        icon: Icons.arrow_outward_rounded,
                        onPressed: onPractice,
                        compact: true,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _Statistics extends StatelessWidget {
  const _Statistics(this.state);
  final StudyState state;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final stats = [
        (
          Icons.shield_outlined,
          Palette.mint,
          '今日守护',
          '${state.today.guardSeconds ~/ 60}',
          '分钟',
        ),
        (
          Icons.edit_note_rounded,
          Palette.lavender,
          '完成练习',
          '${state.today.answers}',
          '道题',
        ),
        (
          Icons.check_circle_outline_rounded,
          Palette.peach,
          '答题正确率',
          state.today.answers == 0
              ? '—'
              : '${(state.today.correct * 100 / state.today.answers).round()}',
          '%',
        ),
      ];
      return Row(
        children: [
          for (var i = 0; i < stats.length; i++) ...[
            if (i > 0) const SizedBox(width: 12),
            Expanded(
              child: GlassPanel(
                radius: 20,
                padding: EdgeInsets.all(c.maxWidth < 500 ? 14 : 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(stats[i].$1, size: 17, color: stats[i].$2),
                        if (c.maxWidth >= 620) ...[
                          const SizedBox(width: 7),
                          Flexible(
                            child: Text(
                              stats[i].$3,
                              style: const TextStyle(
                                fontSize: 10,
                                color: Palette.muted,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (c.maxWidth < 620) ...[
                      const SizedBox(height: 10),
                      Text(
                        stats[i].$3,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Palette.muted,
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.end,
                      spacing: 4,
                      children: [
                        Text(
                          stats[i].$4,
                          style: TextStyle(
                            fontSize: c.maxWidth < 400 ? 25 : 29,
                            fontWeight: FontWeight.w600,
                            height: 1.2,
                            letterSpacing: -1,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Text(
                            stats[i].$5,
                            style: const TextStyle(
                              fontSize: 10,
                              color: Palette.muted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      );
    },
  );
}

class ControlledAppsCard extends ConsumerWidget {
  const ControlledAppsCard({
    super.key,
    required this.onManage,
    this.full = false,
  });
  final VoidCallback onManage;
  final bool full;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(studyProvider);
    final apps = full
        ? state.apps.where((a) => a.enabled).toList()
        : state.apps.take(4).toList();
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeading(
            '为分心按下暂停',
            subtitle: '${state.monitoredCount} 个应用已加入守护清单',
            trailing: TextButton(
              onPressed: onManage,
              child: const Text('管理', style: TextStyle(fontSize: 12)),
            ),
          ),
          const SizedBox(height: 18),
          if (apps.isEmpty)
            const EmptyState('还没有受控应用', '点击管理，选择想少花些时间的应用。')
          else
            ...apps.map(
              (app) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 11),
                child: Row(
                  children: [
                    AppGlyph(app, size: 39),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            app.name,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            '${app.category} · 今日 ${app.usedSeconds ~/ 60} 分钟',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Palette.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!state.settings.cumulative)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Text(
                          '${app.customLimit} 分钟',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Palette.muted,
                          ),
                        ),
                      ),
                    SizedBox(
                      height: 28,
                      width: 44,
                      child: FittedBox(
                        child: Switch(
                          value: app.enabled,
                          onChanged: (v) => runAction(
                            context,
                            () => ref
                                .read(studyProvider.notifier)
                                .updateApp(app.copyWith(enabled: v)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 14),
          const Divider(),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(
                Icons.info_outline_rounded,
                color: Palette.muted,
                size: 14,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  state.realAppList
                      ? '只在使用受控应用时计时，其他时间安心做自己。'
                      : '演示应用列表 · 实际监控需在 Android 设备上授权开启。',
                  style: const TextStyle(
                    fontSize: 10,
                    color: Palette.muted,
                    height: 1.6,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BankOverview extends ConsumerWidget {
  const _BankOverview({required this.onNavigate, required this.onImport});
  final VoidCallback onNavigate, onImport;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final banks = ref.watch(studyProvider).banks;
    return GlassPanel(
      child: Column(
        children: [
          SectionHeading(
            '装进口袋的知识',
            subtitle: '每一次解锁，都有一点新的收获',
            trailing: IconButton(
              onPressed: onImport,
              icon: const Icon(
                Icons.add_rounded,
                color: Palette.mint,
                size: 20,
              ),
              tooltip: '导入题库',
            ),
          ),
          const SizedBox(height: 18),
          ...banks
              .take(3)
              .map(
                (bank) => InkWell(
                  onTap: () => showBankPreview(context, bank),
                  borderRadius: BorderRadius.circular(14),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        BankGlyph(bank.category, size: 40),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                bank.name,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                '${bank.questions.length} 道题目 · ${bank.imported ? '自定义题库' : '精选内置'}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Palette.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Pill(
                          bank.enabled ? '已启用' : '已暂停',
                          color: bank.enabled ? Palette.mint : Palette.muted,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: SoftButton(
              '探索全部题库',
              icon: Icons.arrow_forward_rounded,
              onPressed: onNavigate,
              compact: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _TodayCard extends StatelessWidget {
  const _TodayCard({required this.state, required this.onPractice});
  final StudyState state;
  final VoidCallback onPractice;
  @override
  Widget build(BuildContext context) => GlassPanel(
    padding: const EdgeInsets.all(22),
    child: Column(
      children: [
        const SectionHeading('今日学习能量', icon: Icons.wb_sunny_outlined),
        const SizedBox(height: 24),
        SizedBox(
          width: 170,
          height: 170,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox.square(
                dimension: 154,
                child: CircularProgressIndicator(
                  value: math.min(state.today.answers / 10, 1),
                  strokeWidth: 10,
                  strokeCap: StrokeCap.round,
                  color: Palette.mint.withValues(alpha: .65),
                  backgroundColor: const Color(0xFFE6EEE5),
                ),
              ),
              SizedBox.square(
                dimension: 126,
                child: CircularProgressIndicator(
                  value: math.min(state.today.correct / 10, 1),
                  strokeWidth: 5,
                  strokeCap: StrokeCap.round,
                  color: Palette.lavender.withValues(alpha: .6),
                  backgroundColor: const Color(0xFFECE8F0),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${state.today.answers}',
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    '今日已练习 / 10 题',
                    style: TextStyle(fontSize: 10, color: Palette.muted),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text(
          state.today.answers == 0
              ? '小小的开始，也值得期待'
              : state.today.answers >= 10
              ? '今天的你，能量满满！'
              : '你的每一分努力，都在积蓄能量',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 11,
            color: Palette.muted,
            height: 1.7,
          ),
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: SoftButton(
            '给自己充点电',
            icon: Icons.bolt_rounded,
            compact: true,
            onPressed: onPractice,
          ),
        ),
      ],
    ),
  );
}

class _RuleCard extends StatelessWidget {
  const _RuleCard({required this.state, required this.onNavigate});
  final StudyState state;
  final VoidCallback onNavigate;
  @override
  Widget build(BuildContext context) => GlassPanel(
    padding: const EdgeInsets.all(22),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeading('我的守护节奏', icon: Icons.tune_rounded),
        const SizedBox(height: 24),
        _row(
          Icons.timelapse_rounded,
          '娱乐时长',
          '${state.settings.limitMinutes} 分钟',
        ),
        const SizedBox(height: 20),
        _row(
          Icons.link_rounded,
          '计时方式',
          state.settings.cumulative ? '累计共享' : '应用独立',
        ),
        const SizedBox(height: 20),
        _row(
          Icons.flag_outlined,
          '解锁条件',
          '${state.settings.consecutive ? '连对' : '答对'} ${state.settings.requiredCorrect} 题',
        ),
        const SizedBox(height: 20),
        _row(
          Icons.notifications_none_rounded,
          '提前提醒',
          state.settings.warning ? '60 秒' : '已关闭',
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: SoftButton('调整我的节奏', compact: true, onPressed: onNavigate),
        ),
      ],
    ),
  );
  Widget _row(IconData icon, String label, String value) => Row(
    children: [
      Icon(icon, size: 16, color: Palette.muted),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          label,
          style: const TextStyle(fontSize: 11, color: Palette.muted),
        ),
      ),
      Text(
        value,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      ),
    ],
  );
}

class _MistakeCard extends StatelessWidget {
  const _MistakeCard({required this.state, required this.onNavigate});
  final StudyState state;
  final VoidCallback onNavigate;
  @override
  Widget build(BuildContext context) => GlassPanel(
    tint: const Color(0xFFF7F0E8),
    opacity: .62,
    padding: const EdgeInsets.all(22),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.bookmark_border_rounded,
          color: Palette.peach,
          size: 24,
        ),
        const SizedBox(height: 14),
        const Text(
          '错过的，再遇见一次',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        Text(
          state.mistakes.isEmpty
              ? '答错也没关系，知识会在下一次相遇时更牢固。'
              : '有 ${state.mistakes.length} 道错题等待温习。每次进步，都比上次更好一点。',
          style: const TextStyle(
            fontSize: 11,
            color: Palette.muted,
            height: 1.9,
          ),
        ),
        const SizedBox(height: 16),
        InkWell(
          onTap: onNavigate,
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '翻开错题本',
                style: TextStyle(fontSize: 11, color: Color(0xFFB68E71)),
              ),
              SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_rounded,
                size: 14,
                color: Color(0xFFB68E71),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _QuoteCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.format_quote_rounded, size: 24, color: Color(0xFFB6C9B7)),
        SizedBox(height: 8),
        Text(
          '你不必一下子变得很厉害，\n只要每天比昨天好一点。',
          style: TextStyle(fontSize: 12, height: 2, color: Color(0xFF8B9A87)),
        ),
        SizedBox(height: 12),
        Text(
          'A NOTE TO YOURSELF',
          style: TextStyle(
            fontSize: 8,
            letterSpacing: 1.8,
            color: Color(0xFFA3AEA0),
          ),
        ),
      ],
    ),
  );
}

class _WeekChart extends StatelessWidget {
  const _WeekChart(this.state);
  final StudyState state;
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final days = List.generate(7, (i) => now.subtract(Duration(days: 6 - i)));
    final maximum = math.max(
      10,
      days
          .map((d) => state.reports[dateKey(d)]?.answers ?? 0)
          .fold<int>(0, math.max),
    );
    return GlassPanel(
      child: Column(
        children: [
          const SectionHeading(
            '一点一滴的成长',
            subtitle: '最近 7 天的练习足迹',
            trailing: Pill('近 7 天', color: Palette.muted),
          ),
          const SizedBox(height: 28),
          SizedBox(
            height: 112,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final day in days)
                  Expanded(
                    child: Tooltip(
                      message:
                          '${dateKey(day)} · ${state.reports[dateKey(day)]?.answers ?? 0} 题',
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if ((state.reports[dateKey(day)]?.answers ?? 0) > 0)
                            Text(
                              '${state.reports[dateKey(day)]!.answers}',
                              style: const TextStyle(
                                fontSize: 9,
                                color: Palette.mint,
                              ),
                            ),
                          const SizedBox(height: 5),
                          Container(
                            width: 19,
                            height: math.max(
                              3,
                              (state.reports[dateKey(day)]?.answers ?? 0) /
                                  maximum *
                                  78,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(6),
                              color: dateKey(day) == dateKey()
                                  ? const Color(0xFFAFCEB8)
                                  : const Color(0xFFD8E7DD),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            dateKey(day) == dateKey()
                                ? '今天'
                                : '${day.month}/${day.day}',
                            style: const TextStyle(
                              fontSize: 9,
                              color: Palette.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
