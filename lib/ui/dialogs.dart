import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/models.dart';
import '../core/study_controller.dart';
import '../features/banks/bank_importer.dart';
import 'glass.dart';
import 'theme.dart';

Future<void> runAction(
  BuildContext context,
  Future<void> Function() action,
) async {
  if (!context.mounted) return;
  try {
    await action();
  } catch (e) {
    if (context.mounted) showMessage(context, readableError(e));
  }
}

class GlassDialog extends StatelessWidget {
  const GlassDialog({
    super.key,
    required this.child,
    this.width = 480,
    this.padding = const EdgeInsets.all(28),
  });
  final Widget child;
  final double width;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Colors.transparent,
    elevation: 0,
    insetPadding: const EdgeInsets.all(20),
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: width,
        maxHeight: MediaQuery.sizeOf(context).height * .88,
      ),
      child: GlassPanel(
        opacity: .94,
        padding: padding,
        child: SingleChildScrollView(child: child),
      ),
    ),
  );
}

class PinDialog extends ConsumerStatefulWidget {
  const PinDialog({
    super.key,
    this.setup = false,
    this.startup = false,
    this.onVerified,
  });
  final bool setup, startup;
  final VoidCallback? onVerified;
  @override
  ConsumerState<PinDialog> createState() => _PinDialogState();
}

class _PinDialogState extends ConsumerState<PinDialog> {
  final _text = TextEditingController();
  final _focus = FocusNode();
  String? _first;
  String _error = '';
  bool _busy = false;
  int _lockout = 0;
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    _refreshLockout();
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _refreshLockout(),
    );
  }

  Future<void> _refreshLockout() async {
    final seconds = await ref.read(pinProvider).lockoutSeconds;
    if (mounted && _lockout != seconds) setState(() => _lockout = seconds);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || _lockout > 0) return;
    if (_text.text.length != 6) {
      setState(() => _error = '请输入完整的 6 位数字密码');
      return;
    }
    if (widget.setup && _first == null) {
      setState(() {
        _first = _text.text;
        _text.clear();
        _error = '';
      });
      _focus.requestFocus();
      return;
    }
    setState(() => _busy = true);
    try {
      if (widget.setup) {
        if (_first != _text.text) {
          setState(() {
            _error = '两次输入不一致，请重新设置';
            _first = null;
            _text.clear();
          });
          return;
        }
        await ref.read(pinProvider).setPin(_text.text);
        if (mounted) Navigator.pop(context, true);
      } else {
        final valid = await ref.read(pinProvider).verify(_text.text);
        if (!mounted) return;
        if (valid) {
          _focus.unfocus();
          if (widget.onVerified != null) {
            widget.onVerified!();
          } else {
            Navigator.pop(context, true);
          }
        } else {
          HapticFeedback.heavyImpact();
          setState(() {
            _error = '密码不正确，请再试一次';
            _text.clear();
          });
          await _refreshLockout();
        }
      }
    } catch (_) {
      if (mounted) setState(() => _error = '安全存储暂不可用，请重试');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !widget.startup,
    child: GlassDialog(
      width: 400,
      padding: EdgeInsets.all(widget.startup ? 20 : 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (!widget.startup)
                IconButton(
                  onPressed: () => Navigator.pop(context, false),
                  icon: const Icon(Icons.close_rounded),
                  tooltip: '取消',
                ),
            ],
          ),
          if (!widget.startup) ...[
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Palette.lavenderLight,
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Icon(
                Icons.lock_outline_rounded,
                color: Palette.lavender,
                size: 30,
              ),
            ),
            const SizedBox(height: 24),
          ],
          Text(
            widget.setup ? (_first == null ? '设置应用密码' : '再次确认密码') : '输入应用密码',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Text(
            widget.setup ? '设置一个 6 位数字的应用密码' : '打开应用或从后台返回时验证一次',
            textAlign: TextAlign.start,
            style: const TextStyle(
              fontSize: 12,
              color: Palette.muted,
              height: 1.8,
            ),
          ),
          SizedBox(height: widget.startup ? 20 : 24),
          TextField(
            controller: _text,
            focusNode: _focus,
            autofocus: true,
            enabled: !_busy && _lockout == 0,
            obscureText: true,
            obscuringCharacter: '•',
            textAlign: TextAlign.center,
            textAlignVertical: TextAlignVertical.center,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            autocorrect: false,
            enableSuggestions: false,
            enableIMEPersonalizedLearning: false,
            cursorColor: Palette.mint,
            cursorWidth: 2,
            cursorHeight: 24,
            cursorRadius: const Radius.circular(1),
            style: const TextStyle(fontSize: 22, height: 1.2),
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            decoration: const InputDecoration(
              hintText: '请输入 6 位数字',
              hintStyle: TextStyle(fontSize: 14, color: Palette.muted),
            ),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 14),
          if (_lockout > 0)
            Text(
              '请在 ${_lockout ~/ 60}:${(_lockout % 60).toString().padLeft(2, '0')} 后重试',
              style: const TextStyle(color: Palette.rose, fontSize: 12),
            )
          else
            Text(
              _error,
              style: const TextStyle(color: Palette.rose, fontSize: 12),
            ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: SoftButton(
              _busy
                  ? '正在验证…'
                  : widget.setup && _first == null
                  ? '下一步'
                  : widget.setup
                  ? '保存密码'
                  : '验证并继续',
              filled: true,
              onPressed: _busy || _lockout > 0 ? null : _submit,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            '连续输错 5 次，将锁定 10 分钟',
            style: TextStyle(fontSize: 10, color: Palette.muted),
          ),
        ],
      ),
    ),
  );
}

class ImportDialog extends ConsumerStatefulWidget {
  const ImportDialog({super.key});
  @override
  ConsumerState<ImportDialog> createState() => _ImportDialogState();
}

class _ImportDialogState extends ConsumerState<ImportDialog> {
  final _text = TextEditingController();
  QuestionBank? _preview;
  String? _error;
  String? _filename;
  bool _busy = false;
  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['json', 'csv', 'zip'],
      );
      if (file == null) return;
      final selected = file;
      if ((await selected.length() ?? 0) > BankImporter.maxBytes) {
        throw const FormatException('题库文件不能超过 20 MB');
      }
      final bank = BankImporter.parse(
        selected.name,
        await selected.readAsBytes(),
      );
      if (!mounted) return;
      setState(() {
        _preview = bank;
        _filename = selected.name;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = readableError(e));
    }
  }

  void _validate() {
    try {
      setState(() {
        _preview = BankImporter.fromText(_text.text);
        _filename = null;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _preview = null;
        _error = readableError(e);
      });
    }
  }

  Future<void> _import() async {
    if (_preview == null || _busy) return;
    setState(() => _busy = true);
    await ref.read(studyProvider.notifier).importBank(_preview!);
    if (mounted) {
      Navigator.pop(context);
      showMessage(context, '题库已导入，一起开始新的学习旅程吧');
    }
  }

  @override
  Widget build(BuildContext context) => GlassDialog(
    width: 600,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                '给学习加一点新鲜感',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              ),
            ),
            IconButton(
              onPressed: _busy ? null : () => Navigator.pop(context),
              icon: const Icon(Icons.close_rounded),
              tooltip: '关闭',
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          '导入自己的题库，让每次解锁都有新收获。',
          style: TextStyle(fontSize: 12, color: Palette.muted),
        ),
        const SizedBox(height: 22),
        InkWell(
          onTap: _pick,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(26),
            decoration: BoxDecoration(
              color: Palette.mint.withValues(alpha: .05),
              border: Border.all(color: Palette.mint.withValues(alpha: .3)),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.cloud_upload_outlined,
                  size: 36,
                  color: Palette.mint,
                ),
                const SizedBox(height: 10),
                Text(
                  _filename ?? '点击选择题库文件',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Palette.mint,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'JSON / CSV / ZIP · 单个文件不超过 20 MB',
                  style: TextStyle(fontSize: 10, color: Palette.muted),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 22),
        const Text(
          '或粘贴 JSON 内容',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _text,
          minLines: 5,
          maxLines: 8,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 11,
            height: 1.7,
          ),
          decoration: const InputDecoration(
            hintText: '{\n  "bank_name": "我的题库",\n  "questions": [...]\n}',
          ),
          onChanged: (_) => setState(() {
            _preview = null;
            _filename = null;
          }),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: SoftButton(
            '检查内容',
            icon: Icons.fact_check_outlined,
            compact: true,
            onPressed: _validate,
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              _error!,
              style: const TextStyle(color: Palette.rose, fontSize: 12),
            ),
          ),
        if (_preview != null)
          Container(
            margin: const EdgeInsets.only(top: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Palette.mintLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.check_circle_outline_rounded,
                  color: Palette.mint,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${_preview!.name} · ${_preview!.questions.length} 道题目\n校验通过，可以导入',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Palette.mint,
                      height: 1.7,
                    ),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 22),
        SizedBox(
          width: double.infinity,
          child: SoftButton(
            _busy ? '正在保存…' : '确认导入',
            filled: true,
            icon: Icons.add_rounded,
            onPressed: _preview == null || _busy ? null : _import,
          ),
        ),
      ],
    ),
  );
}

Future<void> openImport(BuildContext context, WidgetRef ref) async {
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (_) => const ImportDialog(),
  );
}

Future<void> showBankPreview(BuildContext context, QuestionBank bank) =>
    showDialog<void>(
      context: context,
      builder: (_) => GlassDialog(
        width: 640,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                BankGlyph(bank.category),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    bank.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                  tooltip: '关闭',
                ),
              ],
            ),
            const SizedBox(height: 20),
            ...bank.questions.map(
              (q) => Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Pill(
                      '${q.typeLabel} · ${q.difficulty} 星',
                      color: BankGlyph.colorFor(bank.category),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      q.stem,
                      style: const TextStyle(fontSize: 14, height: 1.6),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '答案：${q.answerText}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Palette.mint,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );

Future<void> showAppPicker(BuildContext context, WidgetRef ref) async {
  if (!context.mounted) return;
  await showDialog<void>(context: context, builder: (_) => const _AppPicker());
}

class _AppPicker extends ConsumerStatefulWidget {
  const _AppPicker();
  @override
  ConsumerState<_AppPicker> createState() => _AppPickerState();
}

class _AppPickerState extends ConsumerState<_AppPicker> {
  late List<MonitoredApp> _apps;
  String _search = '';
  String _category = '全部';
  @override
  void initState() {
    super.initState();
    _apps = List.of(ref.read(studyProvider).apps);
  }

  @override
  Widget build(BuildContext context) {
    final visible = _apps
        .where(
          (a) =>
              a.name.toLowerCase().contains(_search.toLowerCase()) &&
              (_category == '全部' || a.category == _category),
        )
        .toList();
    return GlassDialog(
      width: 540,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '选择需要守护的应用',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
                tooltip: '关闭',
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            ref.read(studyProvider).realAppList
                ? '已读取设备可启动的应用'
                : '当前为演示应用列表，Android 上会读取已安装应用',
            style: const TextStyle(fontSize: 11, color: Palette.muted),
          ),
          const SizedBox(height: 20),
          TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search_rounded),
              hintText: '搜索应用',
            ),
            onChanged: (v) => setState(() => _search = v),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ['全部', ..._apps.map((a) => a.category).toSet()]
                .map(
                  (c) => ChoiceChip(
                    label: Text(c, style: const TextStyle(fontSize: 11)),
                    selected: c == _category,
                    onSelected: (_) => setState(() => _category = c),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '已选择 ${_apps.where((a) => a.enabled).length} 个应用',
                style: const TextStyle(fontSize: 12, color: Palette.muted),
              ),
              TextButton(
                onPressed: () => setState(
                  () => _apps = _apps
                      .map(
                        (a) => visible.any((v) => v.id == a.id)
                            ? a.copyWith(
                                enabled: !visible.every((v) => v.enabled),
                              )
                            : a,
                      )
                      .toList(),
                ),
                child: const Text('全选当前分组'),
              ),
            ],
          ),
          SizedBox(
            height: 300,
            child: visible.isEmpty
                ? const EmptyState(
                    '没有找到应用',
                    '试试其他关键词',
                    icon: Icons.search_rounded,
                  )
                : ListView.builder(
                    itemCount: visible.length,
                    itemBuilder: (_, i) {
                      final app = visible[i];
                      return CheckboxListTile(
                        value: app.enabled,
                        activeColor: Palette.mint,
                        secondary: AppGlyph(app, size: 36),
                        title: Text(
                          app.name,
                          style: const TextStyle(fontSize: 13),
                        ),
                        subtitle: Text(
                          app.category,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Palette.muted,
                          ),
                        ),
                        onChanged: (v) => setState(
                          () => _apps = _apps
                              .map(
                                (a) =>
                                    a.id == app.id ? a.copyWith(enabled: v) : a,
                              )
                              .toList(),
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: SoftButton(
              '保存应用列表',
              filled: true,
              onPressed: () async {
                try {
                  await ref.read(studyProvider.notifier).chooseApps(_apps);
                  if (context.mounted) Navigator.pop(context);
                } catch (e) {
                  if (context.mounted) showMessage(context, readableError(e));
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> showImportExample(BuildContext context) => showDialog<void>(
  context: context,
  builder: (_) => GlassDialog(
    width: 620,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                '题库格式示例',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
            ),
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close_rounded),
              tooltip: '关闭',
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Text(
          'JSON 的 answer 为选项下标（从 0 开始）；填空题可用 | 分隔同义答案。ZIP 包需在根目录包含 questions.json，音频放在 media/。',
          style: TextStyle(fontSize: 12, color: Palette.muted, height: 1.9),
        ),
        const SizedBox(height: 16),
        SelectableText(
          const JsonEncoder.withIndent('  ').convert({
            'bank_name': '我的小题库',
            'category': 'general',
            'questions': [
              {
                'id': 'q1',
                'type': 'single_choice',
                'stem': '1 + 1 = ?',
                'payload': {
                  'options': ['2', '3', '4'],
                },
                'answer': [0],
                'explanation': '1 + 1 = 2',
              },
            ],
          }),
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 12,
            height: 1.7,
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'CSV 表头：id,type,stem,options,answer,explanation,difficulty,tags,audio_source\noptions、选择题 answer 使用 JSON 数组；填空题 answer 使用文本。',
          style: TextStyle(fontSize: 11, height: 1.8, color: Palette.muted),
        ),
      ],
    ),
  ),
);
