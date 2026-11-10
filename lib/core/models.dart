import 'dart:convert';
import 'dart:math';

enum QuestionKind { singleChoice, multiChoice, fillBlank, listening }

class Question {
  const Question({
    required this.id,
    required this.bankId,
    required this.kind,
    required this.stem,
    required this.options,
    required this.answers,
    this.explanation = '',
    this.audioSource,
    this.tags = const [],
    this.difficulty = 1,
    this.caseSensitive = false,
    this.shuffle = true,
    this.placeholder = '在这里输入你的答案',
  });
  final String id, bankId, stem, explanation, placeholder;
  final String? audioSource;
  final QuestionKind kind;
  final List<String> options, tags;
  final List<Object?> answers;
  final int difficulty;
  final bool caseSensitive, shuffle;

  String get typeLabel => switch (kind) {
    QuestionKind.singleChoice => '单选题',
    QuestionKind.multiChoice => '多选题',
    QuestionKind.fillBlank => '填空题',
    QuestionKind.listening => '听力题',
  };
  factory Question.fromJson(Map<String, dynamic> json, String bankId) {
    final kind = switch (json['type']) {
      'single_choice' => QuestionKind.singleChoice,
      'multi_choice' => QuestionKind.multiChoice,
      'fill_blank' => QuestionKind.fillBlank,
      'listening' => QuestionKind.listening,
      _ => throw const FormatException('不支持的题型'),
    };
    final payload = (json['payload'] as Map?)?.cast<String, dynamic>() ?? {};
    final options = (payload['options'] as List? ?? [])
        .map((v) => v.toString())
        .toList();
    final answers = List<Object?>.from(json['answer'] as List? ?? []);
    final rawId = json['id']?.toString().trim() ?? '';
    final stem = json['stem']?.toString().trim() ?? '';
    final difficulty = json['difficulty'] as int? ?? 1;
    if (rawId.isEmpty ||
        stem.isEmpty ||
        answers.isEmpty ||
        difficulty < 1 ||
        difficulty > 5) {
      throw const FormatException('题目需要有效的 id、stem、answer 和 1–5 的难度');
    }
    if (kind != QuestionKind.fillBlank &&
        (options.length < 2 ||
            answers.any((v) => v is! int || v < 0 || v >= options.length) ||
            (kind != QuestionKind.multiChoice && answers.length != 1))) {
      throw const FormatException('选择题的答案必须是有效选项下标（从 0 开始）');
    }
    if (kind == QuestionKind.fillBlank &&
        answers.any((a) => a is! String || a.trim().isEmpty)) {
      throw const FormatException('填空题答案必须为非空字符串');
    }
    final audio = json['audio_source'] as String?;
    if (kind == QuestionKind.listening &&
        (audio == null ||
            !(audio.startsWith('tts:') || audio.startsWith('file:')) ||
            audio.length <= 4)) {
      throw const FormatException('听力题需提供 tts: 或 file: 音频来源');
    }
    return Question(
      id: rawId.startsWith('$bankId::') ? rawId : '$bankId::$rawId',
      bankId: bankId,
      kind: kind,
      stem: stem,
      options: options,
      answers: answers,
      explanation: json['explanation'] as String? ?? '',
      audioSource: audio,
      difficulty: difficulty,
      caseSensitive: payload['case_sensitive'] == true,
      shuffle: payload['shuffle'] != false,
      placeholder: payload['placeholder'] as String? ?? '输入答案，按 Enter 提交',
      tags: json['tags'] is List
          ? List<String>.from(json['tags'])
          : (json['tags']?.toString() ?? '')
                .split(',')
                .where((s) => s.trim().isNotEmpty)
                .map((s) => s.trim())
                .toList(),
    );
  }
  Map<String, dynamic> toJson() => {
    'id': id,
    'type': [
      'single_choice',
      'multi_choice',
      'fill_blank',
      'listening',
    ][kind.index],
    'stem': stem,
    'difficulty': difficulty,
    'audio_source': audioSource,
    'payload': {
      'options': options,
      'shuffle': shuffle,
      'case_sensitive': caseSensitive,
      'placeholder': placeholder,
    },
    'answer': answers,
    'explanation': explanation,
    'tags': tags,
  };
  bool acceptsText(String value) {
    String normalize(String v) =>
        caseSensitive ? v.trim() : v.trim().toLowerCase();
    return answers
        .whereType<String>()
        .expand((v) => v.split('|'))
        .any((a) => normalize(a) == normalize(value));
  }

  String get answerText => kind == QuestionKind.fillBlank
      ? answers.join(' / ').replaceAll('|', ' / ')
      : answers.cast<int>().map((i) => options[i]).join('、');
}

class QuestionBank {
  const QuestionBank({
    required this.id,
    required this.name,
    required this.category,
    required this.questions,
    this.description = '',
    this.version = '1.0.0',
    this.enabled = true,
    this.imported = false,
    this.media = const {},
  });
  final String id, name, category, description, version;
  final bool enabled, imported;
  final List<Question> questions;
  // ZIP media remains in the same SQLite transaction as its question bank.
  final Map<String, String> media;
  factory QuestionBank.fromJson(
    Map<String, dynamic> json, {
    String? id,
    bool imported = false,
  }) {
    final bankId =
        id ??
        json['bank_id'] as String? ??
        'bank_${DateTime.now().microsecondsSinceEpoch}';
    final name = json['bank_name']?.toString().trim() ?? '';
    if (name.isEmpty ||
        json['questions'] is! List ||
        (json['questions'] as List).isEmpty) {
      throw const FormatException('题库需要 bank_name 和非空 questions 数组');
    }
    final questions = (json['questions'] as List)
        .map(
          (q) => Question.fromJson((q as Map).cast<String, dynamic>(), bankId),
        )
        .toList();
    if (questions.map((q) => q.id).toSet().length != questions.length) {
      throw const FormatException('同一题库中不能包含重复的题目 id');
    }
    return QuestionBank(
      id: bankId,
      name: name,
      category: json['category'] as String? ?? 'general',
      description: json['description'] as String? ?? '让每一次小小的练习，都成为成长的养分。',
      version: json['version'] as String? ?? '1.0.0',
      questions: questions,
      enabled: json['enabled'] != false,
      imported: imported || json['imported'] == true,
      media: (json['media'] as Map?)?.cast<String, String>() ?? {},
    );
  }
  QuestionBank copyWith({bool? enabled, Map<String, String>? media}) =>
      QuestionBank(
        id: id,
        name: name,
        category: category,
        questions: questions,
        description: description,
        version: version,
        enabled: enabled ?? this.enabled,
        imported: imported,
        media: media ?? this.media,
      );
  Map<String, dynamic> toJson() => {
    'bank_id': id,
    'bank_name': name,
    'category': category,
    'description': description,
    'version': version,
    'enabled': enabled,
    'imported': imported,
    'media': media,
    'questions': questions.map((q) => q.toJson()).toList(),
  };
}

class MonitoredApp {
  const MonitoredApp({
    required this.id,
    required this.name,
    required this.category,
    this.enabled = true,
    this.usedSeconds = 0,
    this.cycleSeconds = 0,
    this.customLimit = 30,
    this.icon,
  });
  final String id, name, category;
  final String? icon;
  final bool enabled;
  final int usedSeconds, cycleSeconds, customLimit;
  MonitoredApp copyWith({
    bool? enabled,
    int? usedSeconds,
    int? cycleSeconds,
    int? customLimit,
  }) => MonitoredApp(
    id: id,
    name: name,
    category: category,
    icon: icon,
    enabled: enabled ?? this.enabled,
    usedSeconds: usedSeconds ?? this.usedSeconds,
    cycleSeconds: cycleSeconds ?? this.cycleSeconds,
    customLimit: customLimit ?? this.customLimit,
  );
  factory MonitoredApp.fromJson(Map<String, dynamic> j) => MonitoredApp(
    id: j['id'],
    name: j['name'],
    category: j['category'] ?? '其他',
    enabled: j['enabled'] ?? true,
    usedSeconds: j['usedSeconds'] ?? 0,
    cycleSeconds: j['cycleSeconds'] ?? 0,
    customLimit: j['customLimit'] ?? 30,
    icon: j['icon'],
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'category': category,
    'enabled': enabled,
    'usedSeconds': usedSeconds,
    'cycleSeconds': cycleSeconds,
    'customLimit': customLimit,
    'icon': icon,
  };
}

class GuardSettings {
  const GuardSettings({
    this.cumulative = true,
    this.limitMinutes = 30,
    this.requiredCorrect = 3,
    this.consecutive = true,
    this.penalty = false,
    this.warning = true,
    this.protectSettings = false,
    this.tag = '',
    this.maxDifficulty = 5,
  });
  final bool cumulative, consecutive, penalty, warning, protectSettings;
  final int limitMinutes, requiredCorrect, maxDifficulty;
  final String tag;
  GuardSettings copyWith({
    bool? cumulative,
    int? limitMinutes,
    int? requiredCorrect,
    bool? consecutive,
    bool? penalty,
    bool? warning,
    bool? protectSettings,
    String? tag,
    int? maxDifficulty,
  }) => GuardSettings(
    cumulative: cumulative ?? this.cumulative,
    limitMinutes: limitMinutes ?? this.limitMinutes,
    requiredCorrect: requiredCorrect ?? this.requiredCorrect,
    consecutive: consecutive ?? this.consecutive,
    penalty: penalty ?? this.penalty,
    warning: warning ?? this.warning,
    protectSettings: protectSettings ?? this.protectSettings,
    tag: tag ?? this.tag,
    maxDifficulty: maxDifficulty ?? this.maxDifficulty,
  );
  factory GuardSettings.fromJson(Map<String, dynamic> j) => GuardSettings(
    cumulative: j['cumulative'] ?? true,
    limitMinutes: j['limitMinutes'] ?? 30,
    requiredCorrect: j['requiredCorrect'] ?? 3,
    consecutive: j['consecutive'] ?? true,
    penalty: j['penalty'] ?? false,
    warning: j['warning'] ?? true,
    protectSettings: j['protectSettings'] ?? false,
    tag: j['tag'] ?? '',
    maxDifficulty: j['maxDifficulty'] ?? 5,
  );
  Map<String, dynamic> toJson() => {
    'cumulative': cumulative,
    'limitMinutes': limitMinutes,
    'requiredCorrect': requiredCorrect,
    'consecutive': consecutive,
    'penalty': penalty,
    'warning': warning,
    'protectSettings': protectSettings,
    'tag': tag,
    'maxDifficulty': maxDifficulty,
  };
}

class AnswerRecord {
  const AnswerRecord({
    required this.questionId,
    this.attempts = 0,
    this.wrong = 0,
    this.streak = 0,
    this.weight = 100,
    this.inMistakes = false,
    this.lastAnswered,
  });
  final String questionId;
  final int attempts, wrong, streak;
  final double weight;
  final bool inMistakes;
  final DateTime? lastAnswered;
  AnswerRecord answer(bool correct) {
    final nextStreak = correct ? streak + 1 : 0;
    return AnswerRecord(
      questionId: questionId,
      attempts: attempts + 1,
      wrong: wrong + (correct ? 0 : 1),
      streak: nextStreak,
      weight: max(1, weight + (correct ? -20 : 50)),
      inMistakes: correct ? inMistakes && nextStreak < 3 : true,
      lastAnswered: DateTime.now(),
    );
  }

  factory AnswerRecord.fromJson(Map<String, dynamic> j) => AnswerRecord(
    questionId: j['questionId'],
    attempts: j['attempts'],
    wrong: j['wrong'],
    streak: j['streak'],
    weight: (j['weight'] as num).toDouble(),
    inMistakes: j['inMistakes'],
    lastAnswered: DateTime.tryParse(j['lastAnswered'] ?? ''),
  );
  Map<String, dynamic> toJson() => {
    'questionId': questionId,
    'attempts': attempts,
    'wrong': wrong,
    'streak': streak,
    'weight': weight,
    'inMistakes': inMistakes,
    'lastAnswered': lastAnswered?.toIso8601String(),
  };
}

class DayReport {
  const DayReport({
    required this.date,
    this.interceptions = 0,
    this.answers = 0,
    this.correct = 0,
    this.guardSeconds = 0,
    this.skipUsed = false,
  });
  final String date;
  final int interceptions, answers, correct, guardSeconds;
  final bool skipUsed;
  DayReport copyWith({
    int? interceptions,
    int? answers,
    int? correct,
    int? guardSeconds,
    bool? skipUsed,
  }) => DayReport(
    date: date,
    interceptions: interceptions ?? this.interceptions,
    answers: answers ?? this.answers,
    correct: correct ?? this.correct,
    guardSeconds: guardSeconds ?? this.guardSeconds,
    skipUsed: skipUsed ?? this.skipUsed,
  );
  factory DayReport.fromJson(Map<String, dynamic> j) => DayReport(
    date: j['date'],
    interceptions: j['interceptions'] ?? 0,
    answers: j['answers'] ?? 0,
    correct: j['correct'] ?? 0,
    guardSeconds: j['guardSeconds'] ?? 0,
    skipUsed: j['skipUsed'] ?? false,
  );
  Map<String, dynamic> toJson() => {
    'date': date,
    'interceptions': interceptions,
    'answers': answers,
    'correct': correct,
    'guardSeconds': guardSeconds,
    'skipUsed': skipUsed,
  };
}

String dateKey([DateTime? time]) =>
    (time ?? DateTime.now()).toIso8601String().substring(0, 10);

class StudyState {
  static const _preserveError = Object();
  const StudyState({
    this.banks = const [],
    this.apps = const [],
    this.records = const {},
    this.reports = const {},
    this.settings = const GuardSettings(),
    this.guarding = false,
    this.realAppList = false,
    this.permissions = const {},
    this.error,
  });
  final List<QuestionBank> banks;
  final List<MonitoredApp> apps;
  final Map<String, AnswerRecord> records;
  final Map<String, DayReport> reports;
  final GuardSettings settings;
  final bool guarding, realAppList;
  final Map<String, bool> permissions;
  final String? error;
  List<Question> get questions => banks.expand((b) => b.questions).toList();
  List<Question> get enabledQuestions => banks
      .where((b) => b.enabled)
      .expand((b) => b.questions)
      .where(
        (q) =>
            q.difficulty <= settings.maxDifficulty &&
            (settings.tag.isEmpty || q.tags.contains(settings.tag)),
      )
      .toList();
  List<Question> get mistakes =>
      questions.where((q) => records[q.id]?.inMistakes ?? false).toList();
  DayReport get today => reports[dateKey()] ?? DayReport(date: dateKey());
  int get monitoredCount => apps.where((a) => a.enabled).length;
  StudyState copyWith({
    List<QuestionBank>? banks,
    List<MonitoredApp>? apps,
    Map<String, AnswerRecord>? records,
    Map<String, DayReport>? reports,
    GuardSettings? settings,
    bool? guarding,
    bool? realAppList,
    Map<String, bool>? permissions,
    Object? error = _preserveError,
  }) => StudyState(
    banks: banks ?? this.banks,
    apps: apps ?? this.apps,
    records: records ?? this.records,
    reports: reports ?? this.reports,
    settings: settings ?? this.settings,
    guarding: guarding ?? this.guarding,
    realAppList: realAppList ?? this.realAppList,
    permissions: permissions ?? this.permissions,
    error: identical(error, _preserveError) ? this.error : error as String?,
  );
  Map<String, dynamic> toJson() => {
    'banks': banks.map((b) => b.toJson()).toList(),
    'apps': apps.map((a) => a.toJson()).toList(),
    'records': records.map((k, v) => MapEntry(k, v.toJson())),
    'reports': reports.map((k, v) => MapEntry(k, v.toJson())),
    'settings': settings.toJson(),
    'realAppList': realAppList,
  };
  factory StudyState.fromJson(Map<String, dynamic> j) => StudyState(
    banks: (j['banks'] as List? ?? [])
        .map((v) => QuestionBank.fromJson((v as Map).cast<String, dynamic>()))
        .toList(),
    apps: (j['apps'] as List? ?? [])
        .map((v) => MonitoredApp.fromJson((v as Map).cast<String, dynamic>()))
        .toList(),
    records: (j['records'] as Map? ?? {}).map(
      (k, v) => MapEntry(
        k as String,
        AnswerRecord.fromJson((v as Map).cast<String, dynamic>()),
      ),
    ),
    reports: (j['reports'] as Map? ?? {}).map(
      (k, v) => MapEntry(
        k as String,
        DayReport.fromJson((v as Map).cast<String, dynamic>()),
      ),
    ),
    settings: GuardSettings.fromJson(
      (j['settings'] as Map? ?? {}).cast<String, dynamic>(),
    ),
    realAppList: j['realAppList'] ?? false,
  );
  String encode() => jsonEncode(toJson());
}
