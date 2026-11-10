import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/study_controller.dart';
import '../../ui/dialogs.dart';
import '../../ui/glass.dart';
import '../../ui/theme.dart';

class SecurityPage extends ConsumerStatefulWidget {
  const SecurityPage({super.key});
  @override
  ConsumerState<SecurityPage> createState() => _SecurityPageState();
}

class _SecurityPageState extends ConsumerState<SecurityPage> {
  bool _refreshing = false;
  Future<void> _refresh() async {
    setState(() => _refreshing = true);
    try {
      await ref.read(studyProvider.notifier).refreshNative();
    } catch (e) {
      if (mounted) showMessage(context, readableError(e));
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(studyProvider);
    final native = ref.read(bridgeProvider);
    final pin = ref.read(pinProvider);
    final entries = [
      ('usage', Icons.query_stats_rounded, '应用使用情况', '用于统计受控应用的前台使用时间'),
      (
        'accessibility',
        Icons.accessibility_new_rounded,
        '应用切换识别',
        '通过无障碍服务识别受控应用与触发拦截',
      ),
      ('overlay', Icons.layers_outlined, '悬浮提醒', '允许显示提前 60 秒提醒与答题拦截窗口'),
      (
        'admin',
        Icons.admin_panel_settings_outlined,
        '设备管理保护',
        '由监督者主动启用，移除前需解除设备管理',
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageTitle(
          '安心守护，每一个决定。',
          '让认真许下的约定，被好好保护。',
          trailing: SoftButton(
            _refreshing ? '正在检查…' : '检查权限',
            icon: Icons.refresh_rounded,
            onPressed: _refreshing ? null : _refresh,
          ),
        ),
        GlassPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeading(
                '应用密码',
                subtitle: '打开应用或从后台返回时验证',
                icon: Icons.lock_outline_rounded,
                trailing: Pill(
                  pin.configured ? '已设置' : '未设置',
                  color: pin.configured ? Palette.mint : Palette.peach,
                ),
              ),
              const SizedBox(height: 26),
              const Text(
                '给约定加一道温柔的锁',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              const Text(
                '设置 6 位数字的应用密码。打开应用或从后台返回时需要验证，进入后修改设置、管理应用和题库无需重复输入。\n连续输错 5 次会锁定 10 分钟。',
                style: TextStyle(fontSize: 12, color: Palette.muted, height: 2),
              ),
              const SizedBox(height: 24),
              SoftButton(
                pin.configured ? '修改应用密码' : '设置应用密码',
                icon: Icons.password_rounded,
                filled: true,
                onPressed: () async {
                  if (!context.mounted) return;
                  final saved = await showDialog<bool>(
                    context: context,
                    barrierDismissible: false,
                    builder: (_) => const PinDialog(setup: true),
                  );
                  if (saved == true && mounted && context.mounted) {
                    setState(() {});
                    showMessage(context, '应用密码已安全保存');
                  }
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        GlassPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeading(
                '系统守护权限',
                subtitle: native.supported
                    ? '点击对应项目，前往系统完成授权'
                    : '系统应用守护需要在 Android 设备上完成授权',
                icon: Icons.verified_user_outlined,
                trailing: Pill(
                  native.supported
                      ? '${entries.where((e) => state.permissions[e.$1] == true).length} / 4 已开启'
                      : '当前平台未接入',
                  color: native.supported ? Palette.mint : Palette.muted,
                ),
              ),
              const SizedBox(height: 22),
              ...entries.map((entry) {
                final granted = state.permissions[entry.$1] == true;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: granted
                              ? Palette.mintLight
                              : const Color(0xFFEDF0EB),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Icon(
                          entry.$2,
                          size: 22,
                          color: granted ? Palette.mint : Palette.muted,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.$3,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              entry.$4,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Palette.muted,
                                height: 1.7,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      native.supported
                          ? SoftButton(
                              granted ? '已开启' : '去开启',
                              compact: true,
                              onPressed: granted
                                  ? null
                                  : () => runAction(
                                      context,
                                      () => native.request(entry.$1),
                                    ),
                            )
                          : const Pill('不可用', color: Palette.muted),
                    ],
                  ),
                );
              }),
              if (native.supported && state.permissions['admin'] == true)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => runAction(
                      context,
                      () => native.request('disableAdmin'),
                    ),
                    child: const Text(
                      '解除设备管理',
                      style: TextStyle(fontSize: 11, color: Palette.muted),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        GlassPanel(
          child: Row(
            children: [
              const Icon(
                Icons.settings_outlined,
                color: Palette.lavender,
                size: 28,
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '为系统设置增加答题保护',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '守护开启时，进入设置或安装程序会触发答题。紧急电话始终豁免。',
                      style: TextStyle(
                        fontSize: 11,
                        color: Palette.muted,
                        height: 1.8,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Switch(
                value: state.settings.protectSettings,
                onChanged: native.supported
                    ? (v) => runAction(
                        context,
                        () => ref
                            .read(studyProvider.notifier)
                            .updateSettings(
                              state.settings.copyWith(protectSettings: v),
                            ),
                      )
                    : null,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const GlassPanel(
          tint: Color(0xFFF1EEF7),
          opacity: .6,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.favorite_border_rounded,
                color: Palette.lavender,
                size: 24,
              ),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '你的学习，留在你的设备',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      '题库、练习和错题记录保存在本地。应用密码采用随机盐值与 PBKDF2 加密派生，存入设备安全存储。\n系统管理权限由设备所有者授权；不同系统的后台与卸载限制以系统实际能力为准。',
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
  }
}
