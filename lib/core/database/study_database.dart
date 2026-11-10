import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/services.dart';

import '../models.dart';

class StudyDatabase extends GeneratedDatabase {
  StudyDatabase([QueryExecutor? executor])
    : super(
        executor ??
            driftDatabase(
              name: 'studylock_v1',
              web: DriftWebOptions(
                sqlite3Wasm: Uri.parse('sqlite3.wasm'),
                driftWorker: Uri.parse('drift_worker.js'),
              ),
            ),
      );
  @override
  int get schemaVersion => 1;
  @override
  Iterable<TableInfo<Table, Object?>> get allTables => const [];
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => const [];
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (_) async {
      for (final sql in _schema) {
        await customStatement(sql);
      }
    },
    beforeOpen: (_) async => customStatement('PRAGMA foreign_keys = ON'),
  );
  static const _schema = [
    'CREATE TABLE question_banks (id TEXT PRIMARY KEY, name TEXT NOT NULL, category TEXT NOT NULL, is_enabled INTEGER NOT NULL, metadata_json TEXT NOT NULL)',
    'CREATE TABLE questions (id TEXT PRIMARY KEY, bank_id TEXT NOT NULL REFERENCES question_banks(id) ON DELETE CASCADE, type TEXT NOT NULL, payload_json TEXT NOT NULL)',
    'CREATE INDEX idx_questions_bank_type ON questions(bank_id, type)',
    'CREATE TABLE user_question_records (question_id TEXT PRIMARY KEY REFERENCES questions(id) ON DELETE CASCADE, is_in_mistake_book INTEGER NOT NULL, weight_score REAL NOT NULL, data_json TEXT NOT NULL)',
    'CREATE INDEX idx_records_mistake_weight ON user_question_records(is_in_mistake_book, weight_score DESC)',
    'CREATE TABLE monitored_apps (package_name TEXT PRIMARY KEY, app_name TEXT NOT NULL, data_json TEXT NOT NULL)',
    'CREATE TABLE app_security_config (id INTEGER PRIMARY KEY CHECK(id = 1), settings_json TEXT NOT NULL)',
    'CREATE TABLE daily_reports (date TEXT PRIMARY KEY, data_json TEXT NOT NULL)',
  ];

  Future<StudyState> load() async {
    final config = await customSelect(
      'SELECT settings_json FROM app_security_config WHERE id = 1',
    ).getSingleOrNull();
    if (config == null) {
      final banks = <QuestionBank>[];
      for (final asset in ['english', 'code', 'math']) {
        banks.add(
          QuestionBank.fromJson(
            jsonDecode(await rootBundle.loadString('assets/banks/$asset.json')),
          ),
        );
      }
      final initial = StudyState(
        banks: banks,
        apps: const [
          MonitoredApp(
            id: 'com.ss.android.ugc.aweme',
            name: '抖音',
            category: '短视频',
          ),
          MonitoredApp(
            id: 'com.tencent.tmgp.sgame',
            name: '王者荣耀',
            category: '游戏娱乐',
          ),
          MonitoredApp(id: 'tv.danmaku.bili', name: '哔哩哔哩', category: '短视频'),
          MonitoredApp(
            id: 'com.xingin.xhs',
            name: '小红书',
            category: '社交社区',
            enabled: false,
          ),
        ],
      );
      await save(initial);
      return initial;
    }
    final bankRows = await customSelect(
      'SELECT * FROM question_banks ORDER BY rowid',
    ).get();
    final questionRows = await customSelect(
      'SELECT * FROM questions ORDER BY rowid',
    ).get();
    final banks = bankRows.map((r) {
      final j =
          jsonDecode(r.read<String>('metadata_json')) as Map<String, dynamic>;
      j['questions'] = questionRows
          .where((q) => q.read<String>('bank_id') == r.read<String>('id'))
          .map((q) => jsonDecode(q.read<String>('payload_json')))
          .toList();
      return QuestionBank.fromJson(j);
    }).toList();
    final records = await customSelect(
      'SELECT data_json FROM user_question_records',
    ).get();
    final reports = await customSelect('SELECT data_json FROM daily_reports')
        .get();
    final apps = await customSelect(
      'SELECT data_json FROM monitored_apps ORDER BY rowid',
    ).get();
    final j = jsonDecode(
      config.read<String>('settings_json'),
    ) as Map<String, dynamic>;
    return StudyState(
      banks: banks,
      apps: apps
          .map(
            (r) =>
                MonitoredApp.fromJson(jsonDecode(r.read<String>('data_json'))),
          )
          .toList(),
      settings: GuardSettings.fromJson(j['settings']),
      realAppList: j['realAppList'] ?? false,
      records: {
        for (final r in records) ...{
          (jsonDecode(r.read<String>('data_json')) as Map)['questionId']
              as String: AnswerRecord.fromJson(
            jsonDecode(r.read<String>('data_json')),
          ),
        },
      },
      reports: {
        for (final r in reports) ...{
          (jsonDecode(r.read<String>('data_json')) as Map)['date'] as String:
              DayReport.fromJson(jsonDecode(r.read<String>('data_json'))),
        },
      },
    );
  }

  Future<void> save(StudyState state) => transaction(() async {
    // One atomic snapshot: an interrupted import never leaves half a question bank.
    for (final table in [
      'user_question_records',
      'questions',
      'question_banks',
      'monitored_apps',
      'daily_reports',
    ]) {
      await customStatement('DELETE FROM $table');
    }
    for (final bank in state.banks) {
      final meta = bank.toJson()..remove('questions');
      await customStatement(
        'INSERT INTO question_banks VALUES (?, ?, ?, ?, ?)',
        [
          bank.id,
          bank.name,
          bank.category,
          bank.enabled ? 1 : 0,
          jsonEncode(meta),
        ],
      );
      for (final q in bank.questions) {
        await customStatement('INSERT INTO questions VALUES (?, ?, ?, ?)', [
          q.id,
          bank.id,
          q.kind.name,
          jsonEncode(q.toJson()),
        ]);
      }
    }
    final ids = state.questions.map((q) => q.id).toSet();
    for (final record in state.records.values.where(
      (r) => ids.contains(r.questionId),
    )) {
      await customStatement(
        'INSERT INTO user_question_records VALUES (?, ?, ?, ?)',
        [
          record.questionId,
          record.inMistakes ? 1 : 0,
          record.weight,
          jsonEncode(record.toJson()),
        ],
      );
    }
    for (final app in state.apps) {
      await customStatement('INSERT INTO monitored_apps VALUES (?, ?, ?)', [
        app.id,
        app.name,
        jsonEncode(app.toJson()),
      ]);
    }
    for (final report in state.reports.values) {
      await customStatement('INSERT INTO daily_reports VALUES (?, ?)', [
        report.date,
        jsonEncode(report.toJson()),
      ]);
    }
    await customStatement(
      'INSERT OR REPLACE INTO app_security_config VALUES (1, ?)',
      [
        jsonEncode({
          'settings': state.settings.toJson(),
          'realAppList': state.realAppList,
        }),
      ],
    );
  });
}
