import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models.dart';
import '../../core/study_controller.dart';
import '../../ui/dialogs.dart';
import '../../ui/brand.dart';
import '../../ui/glass.dart';
import '../../ui/theme.dart';
import 'quiz_engine.dart';
import 'speech_service.dart';

class QuizScreen extends ConsumerStatefulWidget {
  const QuizScreen({
    super.key,
    this.questions,
    this.enforced = false,
    this.onOpenApp,
  });
  final List<Question>? questions;
  final bool enforced;
  final VoidCallback? onOpenApp;
  @override
  ConsumerState<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends ConsumerState<QuizScreen>
    with SingleTickerProviderStateMixin {
  late QuizEngine _engine;
  final _text = TextEditingController();
  final _speech = SpeechService();
  final Set<int> _selected = {};
  Timer? _ticker;
  late AnimationController _shake;
  bool _busy = false, _playing = false, _finishing = false, _empty = false;
  double _speed = 1;
  int _lastCooldown = 0;
  @override
  void initState() {
    super.initState();
    final state = ref.read(studyProvider);
    final pool = widget.questions ?? state.enabledQuestions;
    _empty = pool.isEmpty;
    if (!_empty) {
      _engine = QuizEngine(
        pool: pool,
        records: Map.of(state.records),
        settings: state.settings,
      );
    }
    _shake = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 440),
    );
    _ticker = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (mounted && !_empty && _lastCooldown != _engine.cooldown) {
        setState(() => _lastCooldown = _engine.cooldown);
      }
    });
    if (widget.enforced) {
      Future.microtask(() async {
        try {
          await ref.read(studyProvider.notifier).recordInterception();
        } catch (_) {}
      });
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _shake.dispose();
    _text.dispose();
    _speech.dispose();
    super.dispose();
  }

  Future<void> _primary() async {
    if (_busy || _engine.cooldown > 0) return;
    if (_engine.passed) {
      await _finish();
      return;
    }
    if (_engine.result != null) {
      await _speech.stop();
      if (!mounted) return;
      setState(() {
        _engine.next();
        _selected.clear();
        _text.clear();
        _playing = false;
      });
      return;
    }
    if (_engine.question.kind == QuestionKind.fillBlank
        ? _text.text.trim().isEmpty
        : _selected.isEmpty) {
      return;
    }
    setState(() => _busy = true);
    try {
      final correct = _engine.submit(selections: _selected, text: _text.text);
      if (!correct) {
        HapticFeedback.heavyImpact();
        if (!MediaQuery.disableAnimationsOf(context)) _shake.forward(from: 0);
      } else {
        HapticFeedback.lightImpact();
      }
      await ref.read(studyProvider.notifier).answer(_engine.question, correct);
    } catch (e) {
      if (mounted) showMessage(context, readableError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _select(int index) {
    if (_engine.result != null || index >= _engine.order.indices.length) return;
    setState(() {
      if (_engine.question.kind == QuestionKind.multiChoice) {
        if (!_selected.add(index)) _selected.remove(index);
      } else {
        _selected.clear();
        _selected.add(index);
      }
    });
  }

  Future<void> _finish() async {
    if (_finishing) return;
    setState(() => _finishing = true);
    try {
      await ref.read(studyProvider.notifier).retrySave();
      if (widget.enforced) {
        await ref.read(bridgeProvider).passed();
      }
      if (mounted && !widget.enforced) Navigator.pop(context);
    } catch (e) {
      if (mounted) showMessage(context, readableError(e));
    } finally {
      if (mounted) setState(() => _finishing = false);
    }
  }

  Future<void> _play() async {
    if (_playing) {
      await _speech.stop();
      if (mounted) setState(() => _playing = false);
      return;
    }
    setState(() => _playing = true);
    try {
      final q = _engine.question;
      final bank = ref
          .read(studyProvider)
          .banks
          .firstWhere((b) => b.id == q.bankId);
      await _speech.play(q.audioSource!, _speed, bank.media);
    } catch (_) {
      if (mounted) showMessage(context, '暂时无法播放，请检查设备语音引擎或音频文件。');
    } finally {
      if (mounted) setState(() => _playing = false);
    }
  }

  Future<void> _emergency() async {
    if (ref.read(studyProvider).today.skipUsed) {
      showMessage(context, '今天的紧急跳过已使用，继续完成练习吧。');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _BreathingDialog(),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref.read(studyProvider.notifier).useSkip();
      await ref.read(bridgeProvider).passed();
    } catch (e) {
      if (mounted) showMessage(context, readableError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_empty) {
      return Scaffold(
        body: MacaronBackground(
          child: SafeArea(
            child: Center(
              child: GlassPanel(
                child: EmptyState(
                  '还没有可用题目',
                  '请打开应用检查题库与筛选条件。',
                  action: SoftButton(
                    widget.enforced ? '打开爱学习' : '返回应用',
                    onPressed: widget.enforced
                        ? widget.onOpenApp
                        : () => Navigator.pop(context),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }
    final engine = _engine;
    final ready = engine.question.kind == QuestionKind.fillBlank
        ? _text.text.trim().isNotEmpty
        : _selected.isNotEmpty;
    final actionText = engine.cooldown > 0
        ? '读一读解析，再等 ${engine.cooldown} 秒'
        : engine.result != null
        ? '记住啦，下一题'
        : '确认答案';
    return PopScope(
      canPop: !widget.enforced,
      onPopInvokedWithResult: (popped, _) {
        if (!popped) showMessage(context, '完成这组练习，就可以继续啦。');
      },
      child: Shortcuts(
        shortcuts: <ShortcutActivator, Intent>{
          const SingleActivator(LogicalKeyboardKey.enter):
              const _SubmitIntent(),
          for (var i = 0; i < 4; i++)
            SingleActivator(
              [
                LogicalKeyboardKey.digit1,
                LogicalKeyboardKey.digit2,
                LogicalKeyboardKey.digit3,
                LogicalKeyboardKey.digit4,
              ][i],
            ): _SelectIntent(
              i,
            ),
          if (widget.enforced)
            const SingleActivator(LogicalKeyboardKey.escape):
                const _BlockedIntent(),
        },
        child: Actions(
          actions: <Type, Action<Intent>>{
            _SubmitIntent: CallbackAction<_SubmitIntent>(
              onInvoke: (_) {
                if (engine.passed || engine.result != null || ready) _primary();
                return null;
              },
            ),
            _SelectIntent: CallbackAction<_SelectIntent>(
              onInvoke: (i) {
                if (engine.question.kind != QuestionKind.fillBlank &&
                    !engine.passed) {
                  _select(i.index);
                }
                return null;
              },
            ),
            _BlockedIntent: CallbackAction<_BlockedIntent>(
              onInvoke: (_) => null,
            ),
          },
          child: Focus(
            autofocus: true,
            child: Scaffold(
              body: MacaronBackground(
                child: SafeArea(
                  child: LayoutBuilder(
                    builder: (context, c) {
                      final wide = c.maxWidth >= 900;
                      return Column(
                        children: [
                          Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: wide ? 44 : 20,
                              vertical: 20,
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.lock_outline_rounded,
                                  color: Palette.mint,
                                  size: 23,
                                ),
                                const SizedBox(width: 10),
                                const Flexible(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      AppBrand.name,
                                      style: TextStyle(
                                        fontSize: 19,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: -.5,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Pill(
                                  widget.enforced ? '正在守护' : '自在练习',
                                  dot: true,
                                ),
                                const Spacer(),
                                if (!widget.enforced)
                                  IconButton(
                                    onPressed: () => Navigator.pop(context),
                                    tooltip: '退出练习',
                                    icon: const Icon(
                                      Icons.close_rounded,
                                      color: Palette.muted,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 1100,
                                ),
                                child: SingleChildScrollView(
                                  padding: EdgeInsets.fromLTRB(
                                    wide ? 32 : 20,
                                    16,
                                    wide ? 32 : 20,
                                    24,
                                  ),
                                  child: engine.passed
                                      ? _success()
                                      : AnimatedBuilder(
                                          animation: _shake,
                                          builder: (context, child) =>
                                              Transform.translate(
                                                offset: Offset(
                                                  math.sin(
                                                        _shake.value *
                                                            math.pi *
                                                            8,
                                                      ) *
                                                      7 *
                                                      (1 - _shake.value),
                                                  0,
                                                ),
                                                child: child,
                                              ),
                                          child: wide
                                              ? Row(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.center,
                                                  children: [
                                                    Expanded(
                                                      flex: 5,
                                                      child: _questionHeader(
                                                        true,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 64),
                                                    Expanded(
                                                      flex: 6,
                                                      child: _answerCard(
                                                        actionText,
                                                        ready,
                                                      ),
                                                    ),
                                                  ],
                                                )
                                              : ConstrainedBox(
                                                  constraints:
                                                      const BoxConstraints(
                                                        maxWidth: 520,
                                                      ),
                                                  child: Column(
                                                    children: [
                                                      _questionHeader(false),
                                                      const SizedBox(
                                                        height: 28,
                                                      ),
                                                      _answerCard(
                                                        actionText,
                                                        ready,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                        ),
                                ),
                              ),
                            ),
                          ),
                          if (widget.enforced)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                20,
                                10,
                                20,
                                20,
                              ),
                              child: Wrap(
                                spacing: 20,
                                runSpacing: 8,
                                alignment: WrapAlignment.center,
                                children: [
                                  TextButton.icon(
                                    onPressed: () async {
                                      try {
                                        await ref
                                            .read(bridgeProvider)
                                            .emergencyDialer();
                                      } catch (_) {
                                        if (context.mounted) {
                                          showMessage(
                                            context,
                                            '无法打开系统拨号，请使用设备紧急呼叫入口。',
                                          );
                                        }
                                      }
                                    },
                                    icon: const Icon(
                                      Icons.phone_outlined,
                                      size: 15,
                                    ),
                                    label: const Text(
                                      '紧急电话',
                                      style: TextStyle(fontSize: 11),
                                    ),
                                  ),
                                  TextButton.icon(
                                    onPressed:
                                        ref.watch(studyProvider).today.skipUsed
                                        ? null
                                        : _emergency,
                                    icon: const Icon(
                                      Icons.air_rounded,
                                      size: 17,
                                    ),
                                    label: Text(
                                      '紧急跳过 · 今日剩 ${ref.watch(studyProvider).today.skipUsed ? 0 : 1} 次',
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            const Padding(
                              padding: EdgeInsets.only(bottom: 22),
                              child: Text(
                                '放轻松，每一次尝试都有收获。',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Palette.muted,
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _questionHeader(bool wide) {
    final e = _engine;
    final q = e.question;
    final bank = ref
        .read(studyProvider)
        .banks
        .firstWhere((b) => b.id == q.bankId);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.enforced ? '让眼睛休息一下，给大脑充点电。' : '留一点时间，和知识相遇。',
          style: const TextStyle(fontSize: 12, color: Palette.mint),
        ),
        const SizedBox(height: 14),
        Text(
          '小小练习，\n大大进步。',
          style: TextStyle(
            fontSize: wide ? 42 : 30,
            fontWeight: FontWeight.w700,
            height: 1.5,
            letterSpacing: 1,
            color: const Color(0xFF3F6555),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Flexible(
              child: SizedBox(
                width: 320,
                child: e.target > 12
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: e.progress / e.target,
                          minHeight: 6,
                          color: Palette.mint,
                          backgroundColor: const Color(0xFFDDE7DB),
                        ),
                      )
                    : Row(
                        children: [
                          for (var i = 0; i < e.target; i++) ...[
                            if (i > 0) const SizedBox(width: 7),
                            Flexible(
                              child: Container(
                                width: 22,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: i < e.progress
                                      ? Palette.mint
                                      : const Color(0xFFDDE7DB),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '${e.progress} / ${e.target}',
              style: const TextStyle(
                fontSize: 12,
                color: Palette.mint,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          '${e.settings.consecutive ? '连续' : '累计'}答对 ${e.target} 题${widget.enforced ? '，解锁下一个放松周期' : '，完成本次练习'}',
          style: const TextStyle(
            fontSize: 11,
            color: Palette.muted,
            height: 1.7,
          ),
        ),
        const SizedBox(height: 32),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            Pill(bank.name, color: BankGlyph.colorFor(bank.category)),
            Pill(q.typeLabel, color: Palette.muted),
            if (e.records[q.id]?.inMistakes ?? false)
              const Pill('错题再相遇', color: Palette.peach),
          ],
        ),
        const SizedBox(height: 22),
        Text(
          q.stem,
          style: TextStyle(
            fontSize: wide ? 22 : 20,
            fontWeight: FontWeight.w600,
            height: 1.9,
          ),
        ),
        if (q.kind == QuestionKind.listening) ...[
          const SizedBox(height: 24),
          GlassPanel(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                IconButton.filled(
                  onPressed: _play,
                  icon: Icon(
                    _playing ? Icons.stop_rounded : Icons.play_arrow_rounded,
                  ),
                  style: IconButton.styleFrom(backgroundColor: Palette.mint),
                  tooltip: _playing ? '停止播放' : '播放发音',
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '听见新的知识',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: List.generate(
                          16,
                          (i) => Container(
                            width: 3,
                            height: 6 + math.sin(i * 1.7).abs() * 16,
                            margin: const EdgeInsets.only(right: 3),
                            decoration: BoxDecoration(
                              color: Palette.mint.withValues(
                                alpha: _playing ? .8 : .3,
                              ),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    await _speech.stop();
                    if (mounted) {
                      setState(() {
                        _speed = _speed == 1 ? .75 : 1;
                        _playing = false;
                      });
                    }
                  },
                  child: Text(
                    '${_speed == 1 ? '1.0' : '0.75'}×',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _answerCard(String actionText, bool ready) {
    final e = _engine;
    final q = e.question;
    return GlassPanel(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                q.kind == QuestionKind.fillBlank
                    ? '写下你的答案'
                    : q.kind == QuestionKind.multiChoice
                    ? '选择所有正确选项'
                    : '选一个你认为正确的答案',
                style: const TextStyle(fontSize: 12, color: Palette.muted),
              ),
              const Spacer(),
              if (MediaQuery.sizeOf(context).width >= 900)
                const Icon(
                  Icons.keyboard_outlined,
                  size: 17,
                  color: Palette.muted,
                ),
            ],
          ),
          const SizedBox(height: 22),
          if (q.kind == QuestionKind.fillBlank)
            TextField(
              controller: _text,
              autofocus: true,
              enabled: e.result == null,
              decoration: InputDecoration(hintText: q.placeholder),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _primary(),
            )
          else
            ...List.generate(e.order.indices.length, (i) {
              final original = e.order.indices[i];
              final correct = e.result != null && q.answers.contains(original);
              final incorrect =
                  e.result == false && _selected.contains(i) && !correct;
              final color = correct
                  ? Palette.mint
                  : incorrect
                  ? Palette.rose
                  : _selected.contains(i)
                  ? Palette.lavender
                  : Palette.muted;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Semantics(
                  selected: _selected.contains(i),
                  button: true,
                  child: InkWell(
                    onTap: e.result == null ? () => _select(i) : null,
                    borderRadius: BorderRadius.circular(15),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 17,
                        vertical: 17,
                      ),
                      decoration: BoxDecoration(
                        color: correct || incorrect || _selected.contains(i)
                            ? color.withValues(alpha: .08)
                            : Colors.white.withValues(alpha: .5),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: correct || incorrect || _selected.contains(i)
                              ? color.withValues(alpha: .6)
                              : Palette.line,
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: .08),
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: Text(
                              String.fromCharCode(65 + i),
                              style: TextStyle(
                                fontSize: 12,
                                color: color,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 13),
                          Expanded(
                            child: Text(
                              q.options[original],
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.6,
                                color:
                                    correct ||
                                        incorrect ||
                                        _selected.contains(i)
                                    ? color
                                    : Palette.ink,
                              ),
                            ),
                          ),
                          if (correct)
                            const Icon(
                              Icons.check_circle_outline_rounded,
                              color: Palette.mint,
                              size: 20,
                            )
                          else if (incorrect)
                            const Icon(
                              Icons.cancel_outlined,
                              color: Palette.rose,
                              size: 20,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          if (e.result != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: e.result!
                    ? Palette.mintLight.withValues(alpha: .6)
                    : Palette.peachLight.withValues(alpha: .6),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    e.result! ? '答对啦，给认真思考的你一朵小花。' : '差一点点，再认识它一次吧。',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: e.result! ? Palette.mint : Palette.rose,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (!e.result!) ...[
                    Text(
                      '正确答案：${q.answerText}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Palette.ink,
                        height: 1.7,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Text(
                    q.explanation,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Palette.muted,
                      height: 1.9,
                    ),
                  ),
                  if (!e.result!) ...[
                    const SizedBox(height: 10),
                    Text(
                      e.settings.penalty
                          ? '已收进错题本 · 本次目标 +1 题'
                          : '已收进错题本，下次一起复习',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Palette.peach,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: SoftButton(
              _busy ? '正在记录…' : actionText,
              filled: true,
              icon: e.cooldown > 0
                  ? Icons.hourglass_top_rounded
                  : Icons.arrow_forward_rounded,
              onPressed: _busy || e.cooldown > 0 || e.result == null && !ready
                  ? null
                  : _primary,
            ),
          ),
          if (MediaQuery.sizeOf(context).width >= 900)
            const Padding(
              padding: EdgeInsets.only(top: 14),
              child: Center(
                child: Text(
                  '1–4 选择答案 · Enter 确认',
                  style: TextStyle(fontSize: 9, color: Palette.muted),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _success() => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 500),
      child: GlassPanel(
        padding: const EdgeInsets.all(36),
        child: Column(
          children: [
            const LockArtwork(size: 180),
            const Text(
              '又向更好的自己，近了一步。',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.w700,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.enforced ? '认真学习的你，值得好好放松一下。' : '知识在慢慢积累，你也在悄悄成长。',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                color: Palette.muted,
                height: 1.8,
              ),
            ),
            const SizedBox(height: 28),
            Wrap(
              spacing: 12,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                Pill('答对 ${_engine.correctCount} 题'),
                Pill('温习 ${_engine.wrongCount} 道错题', color: Palette.peach),
                if (widget.enforced)
                  Pill(
                    '+ ${_engine.settings.limitMinutes} 分钟',
                    color: Palette.lavender,
                  ),
              ],
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: SoftButton(
                _finishing
                    ? '正在解锁…'
                    : widget.enforced
                    ? '解锁，继续放松'
                    : '收下进步，回到工作台',
                icon: Icons.check_rounded,
                filled: true,
                onPressed: _finishing ? null : _finish,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _SubmitIntent extends Intent {
  const _SubmitIntent();
}

class _SelectIntent extends Intent {
  const _SelectIntent(this.index);
  final int index;
}

class _BlockedIntent extends Intent {
  const _BlockedIntent();
}

class _BreathingDialog extends StatefulWidget {
  const _BreathingDialog();
  @override
  State<_BreathingDialog> createState() => _BreathingDialogState();
}

class _BreathingDialogState extends State<_BreathingDialog> {
  final _clock = Stopwatch()..start();
  Timer? _timer;
  int get remaining => math.max(0, 10 - _clock.elapsed.inSeconds);
  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _clock.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GlassDialog(
    width: 380,
    child: Column(
      children: [
        const Icon(Icons.air_rounded, size: 46, color: Palette.sky),
        const SizedBox(height: 22),
        const Text(
          '先深呼吸，再出发。',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 16),
        const Text(
          '如果现在有更重要的事，就给自己一次从容处理的机会。每日可使用一次。',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: Palette.muted, height: 1.9),
        ),
        const SizedBox(height: 26),
        Text(
          '$remaining',
          style: const TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.w300,
            color: Palette.sky,
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: SoftButton(
            remaining > 0 ? '慢慢吸气，轻轻呼气…' : '使用今天的紧急跳过',
            color: Palette.sky,
            filled: true,
            onPressed: remaining > 0
                ? null
                : () => Navigator.pop(context, true),
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text(
            '继续完成练习',
            style: TextStyle(fontSize: 12, color: Palette.muted),
          ),
        ),
      ],
    ),
  );
}
