import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'database/study_database.dart';
import 'bridge/native_bridge.dart';
import 'models.dart';
import '../features/security/pin_service.dart';

final databaseProvider = Provider<StudyDatabase>(
  (ref) => throw UnimplementedError(),
);
final initialStateProvider = Provider<StudyState>((ref) => const StudyState());
final pinProvider = Provider<PinService>((ref) => throw UnimplementedError());
final bridgeProvider = Provider<NativeBridge>((ref) => NativeBridge());
final studyProvider = NotifierProvider<StudyController, StudyState>(
  StudyController.new,
);

class StudyController extends Notifier<StudyState> {
  Future<void> _writes = Future.value();
  @override
  StudyState build() => ref.read(initialStateProvider);
  Future<void> _save() async {
    final snapshot = state;
    _writes = _writes
        .catchError((Object _) {})
        .then((_) => ref.read(databaseProvider).save(snapshot));
    try {
      await _writes;
      if (state.error != null) state = state.copyWith(error: null);
    } catch (_) {
      state = state.copyWith(error: '数据暂未保存，请检查设备存储空间后重试。');
      rethrow;
    }
  }

  Future<void> retrySave() => _save();
  Future<void> reloadFromDisk() async {
    await _writes.catchError((Object _) {});
    final loaded = await ref.read(databaseProvider).load();
    state = loaded.copyWith(
      guarding: state.guarding,
      permissions: state.permissions,
    );
  }

  Future<void> updateSettings(GuardSettings value) async {
    if (state.guarding) {
      final candidate = state.copyWith(settings: value);
      if (candidate.enabledQuestions.isEmpty) {
        throw StateError('当前筛选没有可用题目，无法用于守护');
      }
      await ref.read(bridgeProvider).sync(candidate);
    }
    state = state.copyWith(settings: value);
    await _save();
  }

  Future<void> updateApp(MonitoredApp app) async {
    final next = state.copyWith(
      apps: [
        for (final a in state.apps)
          if (a.id == app.id) app else a,
      ],
    );
    if (state.guarding) await ref.read(bridgeProvider).sync(next);
    state = next;
    await _save();
  }

  Future<void> chooseApps(List<MonitoredApp> apps) async {
    final next = state.copyWith(apps: apps);
    if (state.guarding) await ref.read(bridgeProvider).sync(next);
    state = next;
    await _save();
  }

  Future<void> toggleBank(QuestionBank bank, bool enabled) async {
    final next = state.copyWith(
      banks: [
        for (final b in state.banks)
          b.id == bank.id ? b.copyWith(enabled: enabled) : b,
      ],
    );
    if (state.guarding && next.enabledQuestions.isEmpty) {
      throw StateError('守护期间至少需要一个有可用题目的题库');
    }
    state = next;
    await _save();
  }

  Future<void> importBank(QuestionBank bank) async {
    state = state.copyWith(banks: [...state.banks, bank]);
    await _save();
  }

  Future<void> deleteBank(QuestionBank bank) async {
    final next = state.copyWith(
      banks: state.banks.where((b) => b.id != bank.id).toList(),
    );
    if (state.guarding && next.enabledQuestions.isEmpty) {
      throw StateError('守护期间不能删除最后一个可用题库');
    }
    state = next.copyWith(
      records: Map.of(next.records)
        ..removeWhere((k, _) => bank.questions.any((q) => q.id == k)),
    );
    await _save();
  }

  Future<void> answer(Question question, bool correct) async {
    final record =
        (state.records[question.id] ?? AnswerRecord(questionId: question.id))
            .answer(correct);
    final today = state.today;
    state = state.copyWith(
      records: {...state.records, question.id: record},
      reports: {
        ...state.reports,
        today.date: today.copyWith(
          answers: today.answers + 1,
          correct: today.correct + (correct ? 1 : 0),
        ),
      },
    );
    await _save();
  }

  Future<void> recordInterception() async {
    final today = state.today;
    state = state.copyWith(
      reports: {
        ...state.reports,
        today.date: today.copyWith(interceptions: today.interceptions + 1),
      },
    );
    await _save();
  }

  Future<void> useSkip() async {
    if (state.today.skipUsed) throw StateError('今天的紧急跳过次数已用完');
    final today = state.today;
    state = state.copyWith(
      reports: {...state.reports, today.date: today.copyWith(skipUsed: true)},
    );
    await _save();
  }

  Future<void> refreshNative() async {
    final bridge = ref.read(bridgeProvider);
    if (!bridge.supported) return;
    final permissions = await bridge.permissions();
    final snap = await bridge.snapshot();
    var apps = state.apps;
    final needsSave = !state.realAppList;
    if (needsSave) {
      final installed = await bridge.installedApps();
      apps = installed
          .map(
            (a) => a.copyWith(
              enabled: state.apps.any((b) => b.id == a.id && b.enabled),
            ),
          )
          .toList();
    }
    final today = state.today;
    final dayMatches = snap['date'] == today.date;
    final used = dayMatches ? (snap['usage'] as Map? ?? {}) : {};
    apps = apps
        .map((a) => a.copyWith(usedSeconds: (used[a.id] as num?)?.toInt() ?? 0))
        .toList();
    final reports = {
      ...state.reports,
      today.date: today.copyWith(
        guardSeconds: dayMatches
            ? (snap['guardSeconds'] as num?)?.toInt() ?? today.guardSeconds
            : today.guardSeconds,
      ),
    };
    state = state.copyWith(
      apps: apps,
      permissions: permissions,
      reports: reports,
      realAppList: true,
      guarding: snap['enabled'] == true,
    );
    if (needsSave) await _save();
  }

  Future<void> setGuard(bool enabled) async {
    final bridge = ref.read(bridgeProvider);
    if (!bridge.supported) {
      throw StateError('浏览器与当前桌面版本支持学习体验；系统应用守护请在 Android 设备上开启。');
    }
    if (enabled) {
      if (!ref.read(pinProvider).configured) {
        throw StateError('请先在安全中心设置 6 位应用密码');
      }
      if (state.enabledQuestions.isEmpty || state.monitoredCount == 0) {
        throw StateError('请先选择受控应用，并启用至少一个有可用题目的题库');
      }
      final permissions = await bridge.permissions();
      if (permissions['accessibility'] != true ||
          permissions['usage'] != true ||
          permissions['overlay'] != true) {
        throw StateError('请先在安全中心开启应用使用情况、无障碍与悬浮窗权限');
      }
      await bridge.sync(state);
    }
    await bridge.setEnabled(enabled);
    state = state.copyWith(guarding: enabled);
    await _save();
  }
}
