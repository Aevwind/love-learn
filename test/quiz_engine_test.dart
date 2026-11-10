import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:studylock/core/models.dart';
import 'package:studylock/features/quiz/quiz_engine.dart';

Question question(String id, {QuestionKind kind = QuestionKind.singleChoice}) =>
    Question(
      id: id,
      bankId: 'test',
      kind: kind,
      stem: 'Test',
      options: const ['First', 'Second', 'Third'],
      answers: kind == QuestionKind.multiChoice ? [0, 2] : [0],
    );

void main() {
  test('Fisher–Yates shuffling preserves original correct answers for every permutation', () {
    final q = question('multi', kind: QuestionKind.multiChoice);
    final permutations = <String>{};
    for (var seed = 0; seed < 50; seed++) {
      final order = ChoiceOrder(q, Random(seed));
      permutations.add(order.indices.join());
      final correct = {
        for (var i = 0; i < order.indices.length; i++)
          if (q.answers.contains(order.indices[i])) i,
      };
      expect(order.correct(q, correct), isTrue);
      expect(order.correct(q, {correct.first}), isFalse);
      expect(order.correct(q, {0, 1, 2}), isFalse);
    }
    expect(permutations.length, greaterThan(1));
    expect(q.options, ['First', 'Second', 'Third']);
  });
  test('fill blank trims whitespace and supports case-insensitive alternative answers', () {
    const q = Question(
      id: 'fill',
      bankId: 'test',
      kind: QuestionKind.fillBlank,
      stem: 'attribute ...',
      options: [],
      answers: ['to|归因于'],
    );
    expect(q.acceptsText('  TO  '), isTrue);
    expect(q.acceptsText('归因于'), isTrue);
    expect(q.acceptsText('into'), isFalse);
    expect(q.acceptsText(''), isFalse);
  });
  test(
    'sampling returns 60% mistakes, no duplicates, and handles shortages',
    () {
      final pool = List.generate(20, (i) => question('$i'));
      final records = {
        for (var i = 0; i < 10; i++)
          '$i': AnswerRecord(questionId: '$i', inMistakes: true),
      };
      final selected = sampleQuestions(pool, records, 10, random: Random(4));
      expect(
        selected.where((q) => records[q.id]?.inMistakes ?? false).length,
        6,
      );
      expect(selected.map((q) => q.id).toSet().length, 10);
      expect(sampleQuestions(pool.take(2).toList(), records, 10).length, 2);
      expect(() => sampleQuestions([], records, 3), throwsStateError);
    },
  );
  test('a mistake needs three consecutive correct answers to graduate', () {
    var record = const AnswerRecord(questionId: 'x').answer(false);
    expect(record.inMistakes, isTrue);
    expect(record.weight, 150);
    record = record.answer(true).answer(true);
    expect(record.inMistakes, isTrue);
    record = record.answer(false).answer(true).answer(true);
    expect(record.inMistakes, isTrue);
    record = record.answer(true);
    expect(record.inMistakes, isFalse);
    expect(record.attempts, 7);
    expect(record.wrong, 2);
  });
  test('wrong answers enforce all five seconds, reset streak and apply optional penalty', () {
    var now = 0;
    final quiz = QuizEngine(
      pool: [question('x')],
      records: {},
      settings: const GuardSettings(penalty: true),
      elapsedMilliseconds: () => now,
    );
    final wrongIndex = quiz.order.indices.indexOf(1);
    expect(quiz.submit(selections: {wrongIndex}), isFalse);
    expect(quiz.target, 4);
    expect(quiz.progress, 0);
    expect(quiz.cooldown, 5);
    expect(quiz.next, throwsStateError);
    expect(() => quiz.submit(selections: {0}), throwsStateError);
    now = 4999;
    expect(quiz.cooldown, 1);
    expect(quiz.next, throwsStateError);
    now = 5000;
    expect(quiz.cooldown, 0);
    quiz.next();
    for (var i = 0; i < 4; i++) {
      expect(quiz.submit(selections: {quiz.order.indices.indexOf(0)}), isTrue);
      if (i < 3) quiz.next();
    }
    expect(quiz.passed, isTrue);
  });
  test('cumulative mode keeps progress across a wrong answer', () {
    var now = 0;
    final quiz = QuizEngine(
      pool: [question('x')],
      records: {},
      settings: const GuardSettings(consecutive: false, requiredCorrect: 2),
      elapsedMilliseconds: () => now,
    );
    quiz.submit(selections: {quiz.order.indices.indexOf(0)});
    quiz.next();
    quiz.submit(selections: {quiz.order.indices.indexOf(1)});
    expect(quiz.progress, 1);
    expect(quiz.target, 2);
    now = 5000;
    quiz.next();
    quiz.submit(selections: {quiz.order.indices.indexOf(0)});
    expect(quiz.passed, isTrue);
  });
}
