import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models.dart';
import '../../core/study_controller.dart';
import '../../ui/dialogs.dart';
import '../../ui/glass.dart';
import '../../ui/theme.dart';
import '../dashboard/dashboard_page.dart';

class MonitorPage extends ConsumerWidget {
  const MonitorPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(studyProvider);
    final s = state.settings;
    void update(GuardSettings value) => runAction(
      context,
      () => ref.read(studyProvider.notifier).updateSettings(value),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageTitle(
          '给时间，一点边界。',
          '找到适合自己的节奏，让学习和放松都刚刚好。',
          trailing: SoftButton(
            '选择应用',
            icon: Icons.add_rounded,
            onPressed: () => showAppPicker(context, ref),
            filled: true,
          ),
        ),
        LayoutBuilder(
          builder: (context, c) {
            final policy = Column(
              children: [
                GlassPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionHeading(
                        '我的娱乐节奏',
                        subtitle: '达到时长后，完成一小组题目再继续',
                        icon: Icons.timelapse_rounded,
                      ),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: Palette.mint.withValues(alpha: .06),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Row(
                          children: [
                            for (final cumulative in [true, false])
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 2,
                                  ),
                                  child: SoftButton(
                                    cumulative ? '累计共享计时' : '应用独立计时',
                                    compact: true,
                                    color: s.cumulative == cumulative
                                        ? Palette.mint
                                        : Palette.muted,
                                    filled: s.cumulative == cumulative,
                                    onPressed: () => update(
                                      s.copyWith(cumulative: cumulative),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        s.cumulative
                            ? '所有受控应用共享一个周期，例如刷视频 15 分钟 + 玩游戏 15 分钟 = 累计 30 分钟。'
                            : '每个应用分别计时。你可以在下方为每个应用设置单独的时长。',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Palette.muted,
                          height: 1.9,
                        ),
                      ),
                      const SizedBox(height: 26),
                      const Text(
                        '每次可以放松多久？',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          for (final minutes in [5, 10, 15, 30, 45, 60])
                            ChoiceChip(
                              label: Text(
                                '$minutes 分钟',
                                style: const TextStyle(fontSize: 12),
                              ),
                              selected: s.limitMinutes == minutes,
                              selectedColor: Palette.mintLight,
                              showCheckmark: false,
                              onSelected: (_) =>
                                  update(s.copyWith(limitMinutes: minutes)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 26),
                      const Divider(),
                      const SizedBox(height: 16),
                      _SwitchRow(
                        '温柔地提前提醒',
                        '在拦截前 60 秒提醒，给你留好收尾时间',
                        s.warning,
                        (v) => update(s.copyWith(warning: v)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                GlassPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionHeading(
                        '每次解锁，进步一点',
                        subtitle: '选择一个力所能及的小目标',
                        icon: Icons.flag_outlined,
                      ),
                      const SizedBox(height: 22),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          for (final consecutive in [true, false])
                            ChoiceChip(
                              label: Text(
                                consecutive ? '连续答对' : '累计答对',
                                style: const TextStyle(fontSize: 12),
                              ),
                              selected: s.consecutive == consecutive,
                              selectedColor: Palette.lavenderLight,
                              onSelected: (_) =>
                                  update(s.copyWith(consecutive: consecutive)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          const Expanded(
                            child: Text('需要答对', style: TextStyle(fontSize: 13)),
                          ),
                          IconButton(
                            onPressed: s.requiredCorrect <= 1
                                ? null
                                : () => update(
                                    s.copyWith(
                                      requiredCorrect: s.requiredCorrect - 1,
                                    ),
                                  ),
                            tooltip: '减少题数',
                            icon: const Icon(
                              Icons.remove_circle_outline_rounded,
                              size: 22,
                              color: Palette.muted,
                            ),
                          ),
                          Text(
                            '${s.requiredCorrect} 题',
                            style: const TextStyle(
                              fontSize: 16,
                              color: Palette.lavender,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          IconButton(
                            onPressed: s.requiredCorrect >= 20
                                ? null
                                : () => update(
                                    s.copyWith(
                                      requiredCorrect: s.requiredCorrect + 1,
                                    ),
                                  ),
                            tooltip: '增加题数',
                            icon: const Icon(
                              Icons.add_circle_outline_rounded,
                              size: 22,
                              color: Palette.lavender,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      const Divider(),
                      const SizedBox(height: 16),
                      _SwitchRow(
                        '给错题多一次机会',
                        '答错时额外增加 1 题，认真对待每一次练习',
                        s.penalty,
                        (v) => update(s.copyWith(penalty: v)),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        '答错后会有 5 秒解析时间，帮助你真正记住知识。',
                        style: TextStyle(
                          fontSize: 10,
                          color: Palette.muted,
                          height: 1.8,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
            final apps = Column(
              children: [
                ControlledAppsCard(
                  full: true,
                  onManage: () => showAppPicker(context, ref),
                ),
                if (!s.cumulative) ...[
                  const SizedBox(height: 22),
                  GlassPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SectionHeading('每个应用，单独安排'),
                        const SizedBox(height: 16),
                        ...state.apps
                            .where((a) => a.enabled)
                            .map(
                              (a) => Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                                child: Row(
                                  children: [
                                    AppGlyph(a, size: 32),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        a.name,
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                    DropdownButton<int>(
                                      value: a.customLimit,
                                      underline: const SizedBox.shrink(),
                                      items: [15, 30, 45, 60]
                                          .map(
                                            (m) => DropdownMenuItem(
                                              value: m,
                                              child: Text(
                                                '$m 分钟',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                          )
                                          .toList(),
                                      onChanged: (v) {
                                        if (v != null) {
                                          runAction(
                                            context,
                                            () => ref
                                                .read(studyProvider.notifier)
                                                .updateApp(
                                                  a.copyWith(customLimit: v),
                                                ),
                                          );
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 22),
                const GlassPanel(
                  tint: Color(0xFFEFEAF6),
                  opacity: .5,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.spa_outlined,
                        color: Palette.lavender,
                        size: 22,
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '自律，也可以很温柔',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              '不必给自己太多压力。从 30 分钟和 3 道题开始，慢慢找到自己的节奏。',
                              style: TextStyle(
                                fontSize: 11,
                                color: Palette.muted,
                                height: 1.9,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
            return c.maxWidth >= 760
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 6, child: policy),
                      const SizedBox(width: 24),
                      Expanded(flex: 5, child: apps),
                    ],
                  )
                : Column(children: [policy, const SizedBox(height: 22), apps]);
          },
        ),
      ],
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow(this.title, this.subtitle, this.value, this.onChanged);
  final String title, subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 10,
                color: Palette.muted,
                height: 1.7,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(width: 12),
      Switch(value: value, onChanged: onChanged),
    ],
  );
}
