import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models.dart';
import '../../core/study_controller.dart';
import '../../ui/dialogs.dart';
import '../../ui/glass.dart';
import '../../ui/theme.dart';

class BanksPage extends ConsumerStatefulWidget {
  const BanksPage({super.key});
  @override
  ConsumerState<BanksPage> createState() => _BanksPageState();
}

class _BanksPageState extends ConsumerState<BanksPage> {
  String _search = '';
  String _category = '全部';
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(studyProvider);
    final banks = state.banks
        .where(
          (b) =>
              b.name.toLowerCase().contains(_search.toLowerCase()) &&
              (_category == '全部' ||
                  _category == '已启用' && b.enabled ||
                  _category == '我的导入' && b.imported),
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageTitle(
          '知识，随时可以靠近。',
          '多本题库一起练习，把感兴趣的世界装进口袋。',
          trailing: SoftButton(
            '导入题库',
            icon: Icons.add_rounded,
            filled: true,
            onPressed: () => openImport(context, ref),
          ),
        ),
        GlassPanel(
          padding: const EdgeInsets.all(20),
          child: Wrap(
            spacing: 20,
            runSpacing: 16,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 250,
                child: TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search_rounded, size: 20),
                    hintText: '寻找一本题库',
                    isDense: true,
                  ),
                  onChanged: (v) => setState(() => _search = v),
                ),
              ),
              Wrap(
                spacing: 10,
                children: ['全部', '已启用', '我的导入']
                    .map(
                      (c) => ChoiceChip(
                        label: Text(c, style: const TextStyle(fontSize: 12)),
                        selected: _category == c,
                        selectedColor: Palette.mintLight,
                        onSelected: (_) => setState(() => _category = c),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        LayoutBuilder(
          builder: (context, c) {
            final columns = c.maxWidth >= 1050
                ? 3
                : c.maxWidth >= 650
                ? 2
                : 1;
            return banks.isEmpty
                ? const GlassPanel(
                    child: EmptyState(
                      '暂时没有找到题库',
                      '换个关键词，或导入你喜欢的题库。',
                      icon: Icons.menu_book_outlined,
                    ),
                  )
                : Wrap(
                    spacing: 22,
                    runSpacing: 22,
                    children: banks
                        .map(
                          (bank) => SizedBox(
                            width: (c.maxWidth - (columns - 1) * 22) / columns,
                            child: _BankCard(bank),
                          ),
                        )
                        .toList(),
                  );
          },
        ),
        const SizedBox(height: 24),
        GlassPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeading(
                '给练习加一点偏好',
                subtitle: '筛选参与守护与日常练习的题目',
                icon: Icons.filter_list_rounded,
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 24,
                runSpacing: 18,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        '难度上限',
                        style: TextStyle(fontSize: 12, color: Palette.muted),
                      ),
                      const SizedBox(width: 14),
                      DropdownButton<int>(
                        value: state.settings.maxDifficulty,
                        underline: const SizedBox.shrink(),
                        items: List.generate(
                          5,
                          (i) => DropdownMenuItem(
                            value: i + 1,
                            child: Text(
                              '${i + 1} 星',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                        onChanged: (v) {
                          if (v != null) {
                            runAction(
                              context,
                              () => ref
                                  .read(studyProvider.notifier)
                                  .updateSettings(
                                    state.settings.copyWith(maxDifficulty: v),
                                  ),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        '知识标签',
                        style: TextStyle(fontSize: 12, color: Palette.muted),
                      ),
                      const SizedBox(width: 14),
                      DropdownButton<String>(
                        value: state.settings.tag,
                        underline: const SizedBox.shrink(),
                        items:
                            [
                                  '',
                                  ...state.questions
                                      .expand((q) => q.tags)
                                      .toSet(),
                                  if (state.settings.tag.isNotEmpty &&
                                      !state.questions.any(
                                        (q) =>
                                            q.tags.contains(state.settings.tag),
                                      ))
                                    state.settings.tag,
                                ]
                                .map(
                                  (t) => DropdownMenuItem(
                                    value: t,
                                    child: Text(
                                      t.isEmpty ? '全部标签' : t,
                                      style: const TextStyle(fontSize: 12),
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
                                  .updateSettings(
                                    state.settings.copyWith(tag: v),
                                  ),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                  Pill('${state.enabledQuestions.length} 道可用题目'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        GlassPanel(
          tint: const Color(0xFFEEF2F8),
          opacity: .5,
          child: Row(
            children: [
              const Icon(
                Icons.lightbulb_outline_rounded,
                color: Palette.sky,
                size: 26,
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Text(
                  '自己的知识，也值得被好好收藏。支持 JSON、CSV 和含音频的 ZIP 题库包。',
                  style: TextStyle(
                    fontSize: 12,
                    color: Palette.muted,
                    height: 1.8,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => showImportExample(context),
                child: const Text('格式示例', style: TextStyle(fontSize: 11)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BankCard extends ConsumerWidget {
  const _BankCard(this.bank);
  final QuestionBank bank;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = BankGlyph.colorFor(bank.category);
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              BankGlyph(bank.category, size: 50),
              const Spacer(),
              Pill(bank.imported ? '我的导入' : '精选内置', color: color),
            ],
          ),
          const SizedBox(height: 22),
          Text(
            bank.name,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Text(
            bank.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              color: Palette.muted,
              height: 1.8,
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Pill('${bank.questions.length} 道题目', color: color),
              ...bank.questions
                  .map((q) => q.typeLabel)
                  .toSet()
                  .take(3)
                  .map((t) => Pill(t, color: Palette.muted)),
            ],
          ),
          const SizedBox(height: 22),
          const Divider(),
          const SizedBox(height: 14),
          Row(
            children: [
              TextButton(
                onPressed: () => showBankPreview(context, bank),
                child: const Text('看看题目', style: TextStyle(fontSize: 11)),
              ),
              if (bank.imported)
                IconButton(
                  onPressed: () async {
                    if (!context.mounted) return;
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('移除这本题库？'),
                        content: const Text('这本题库的题目和相关错题记录将一起移除。'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('保留'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('移除'),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      try {
                        await ref.read(studyProvider.notifier).deleteBank(bank);
                      } catch (e) {
                        if (context.mounted) {
                          showMessage(context, readableError(e));
                        }
                      }
                    }
                  },
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    size: 18,
                    color: Palette.muted,
                  ),
                  tooltip: '移除题库',
                ),
              const Spacer(),
              Text(
                bank.enabled ? '参与练习' : '已暂停',
                style: const TextStyle(fontSize: 10, color: Palette.muted),
              ),
              const SizedBox(width: 4),
              Transform.scale(
                scale: .8,
                child: Switch(
                  value: bank.enabled,
                  onChanged: (v) => runAction(
                    context,
                    () => ref.read(studyProvider.notifier).toggleBank(bank, v),
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

class MistakesPage extends ConsumerStatefulWidget {
  const MistakesPage({super.key, required this.onPractice});
  final ValueChanged<List<Question>> onPractice;
  @override
  ConsumerState<MistakesPage> createState() => _MistakesPageState();
}

class _MistakesPageState extends ConsumerState<MistakesPage> {
  String _search = '';
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(studyProvider);
    final mistakes =
        state.mistakes
            .where((q) => q.stem.toLowerCase().contains(_search.toLowerCase()))
            .toList()
          ..sort(
            (a, b) => state.records[b.id]!.weight.compareTo(
              state.records[a.id]!.weight,
            ),
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageTitle(
          '再相遇，就更熟悉一点。',
          '每一道错题，都是下一次进步的起点。连续答对 3 次后会自动毕业。',
          trailing: SoftButton(
            '温习错题',
            icon: Icons.replay_rounded,
            onPressed: state.mistakes.isEmpty
                ? null
                : () => widget.onPractice(state.mistakes),
            filled: true,
          ),
        ),
        if (state.mistakes.isEmpty)
          GlassPanel(
            child: EmptyState(
              '这里暂时空空的，真好。',
              '答错的题目会自动收藏在这里。\n慢慢来，知识会在每一次练习中生根。',
              icon: Icons.auto_stories_outlined,
              action: SoftButton(
                '开始一组新练习',
                icon: Icons.auto_awesome_outlined,
                onPressed: () => widget.onPractice(state.enabledQuestions),
              ),
            ),
          )
        else ...[
          GlassPanel(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search_rounded),
                      hintText: '寻找一道错题',
                      isDense: true,
                    ),
                    onChanged: (v) => setState(() => _search = v),
                  ),
                ),
                const SizedBox(width: 16),
                Pill('${state.mistakes.length} 道待温习', color: Palette.peach),
              ],
            ),
          ),
          const SizedBox(height: 22),
          if (mistakes.isEmpty) const EmptyState('没有匹配的错题', '试试其他关键词'),
          ...mistakes.map((q) {
            final r = state.records[q.id]!;
            return Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: GlassPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Pill(q.typeLabel, color: Palette.lavender),
                        Pill('答错 ${r.wrong} 次', color: Palette.peach),
                        Pill('已连续答对 ${r.streak} / 3', color: Palette.mint),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      q.stem,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        height: 1.7,
                      ),
                    ),
                    const SizedBox(height: 14),
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      childrenPadding: const EdgeInsets.only(bottom: 12),
                      title: const Text(
                        '回顾答案与解析',
                        style: TextStyle(fontSize: 12, color: Palette.mint),
                      ),
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '正确答案：${q.answerText}\n\n${q.explanation}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Palette.muted,
                              height: 1.9,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ],
    );
  }
}
