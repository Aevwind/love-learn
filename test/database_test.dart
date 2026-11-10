import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studylock/core/database/study_database.dart';
import 'package:studylock/core/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('banks, answers, settings and daily quota survive an atomic database round trip', () async {
    final db = StudyDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final initial = await db.load();
    expect(initial.questions.length, 28);
    final question = initial.questions.first;
    final today = DayReport(date: dateKey(), answers: 1, skipUsed: true);
    await db.save(
      initial.copyWith(
        settings: initial.settings.copyWith(limitMinutes: 45),
        records: {
          question.id: AnswerRecord(questionId: question.id).answer(false),
        },
        reports: {today.date: today},
      ),
    );
    final restored = await db.load();
    expect(restored.settings.limitMinutes, 45);
    expect(restored.mistakes.single.id, question.id);
    expect(restored.today.skipUsed, isTrue);
    expect(restored.today.answers, 1);
    expect(restored.questions.length, 28);
    expect(
      (await db.customSelect('PRAGMA foreign_keys').getSingle())
          .data
          .values
          .first,
      1,
    );
  });
}
