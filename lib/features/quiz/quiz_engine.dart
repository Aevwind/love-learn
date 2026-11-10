import 'dart:math';

import '../../core/models.dart';

class ChoiceOrder {
  ChoiceOrder(Question question, Random random) {
    indices = List.generate(question.options.length, (i) => i);
    if (question.shuffle) {
      for (var i = indices.length - 1; i > 0; i--) {
        final j = random.nextInt(i + 1);
        final tmp = indices[i];
        indices[i] = indices[j];
        indices[j] = tmp;
      }
    }
  }
  late final List<int> indices;
  bool correct(Question q, Set<int> selections) {
    final original = selections.map((i) => indices[i]).toSet();
    final expected = q.answers.cast<int>().toSet();
    return original.length == expected.length && original.containsAll(expected);
  }
}

List<Question> sampleQuestions(
  List<Question> pool,
  Map<String, AnswerRecord> records,
  int count, {
  Random? random,
}) {
  if (pool.isEmpty) throw StateError('请至少启用一个有可用题目的题库');
  final rng = random ?? Random();
  final mistakes = pool
      .where((q) => records[q.id]?.inMistakes ?? false)
      .toList();
  final fresh = pool
      .where((q) => !(records[q.id]?.inMistakes ?? false))
      .toList();
  final selected = <Question>[];
  void draw(List<Question> source, int n, {bool weighted = false}) {
    for (var i = 0; i < n && source.isNotEmpty; i++) {
      final sum = source.fold<double>(
        0,
        (v, q) => v + (weighted ? records[q.id]?.weight ?? 100 : 1),
      );
      var cursor = rng.nextDouble() * sum;
      var chosen = source.length - 1;
      for (var j = 0; j < source.length; j++) {
        cursor -= weighted ? records[source[j].id]?.weight ?? 100 : 1;
        if (cursor < 0) {
          chosen = j;
          break;
        }
      }
      selected.add(source.removeAt(chosen));
    }
  }

  final actual = min(count, pool.length);
  draw(mistakes, (actual * .6).round(), weighted: true);
  draw(fresh, actual - selected.length);
  draw(mistakes, actual - selected.length, weighted: true);
  selected.shuffle(rng);
  return selected;
}

class QuizEngine {
  QuizEngine({
    required this.pool,
    required this.records,
    required this.settings,
    Random? random,
    int Function()? elapsedMilliseconds,
  }) : random = random ?? Random(),
       target = settings.requiredCorrect {
    _readTime = elapsedMilliseconds ?? () => _clock.elapsedMilliseconds;
    _refill();
    _next();
  }
  final List<Question> pool;
  final Map<String, AnswerRecord> records;
  final GuardSettings settings;
  final Random random;
  final _clock = Stopwatch()..start();
  late final int Function() _readTime;
  List<Question> _queue = [];
  late Question question;
  late ChoiceOrder order;
  int target, streak = 0, correctCount = 0, wrongCount = 0, attempted = 0;
  int _cooldownUntil = 0;
  bool? result;
  bool get passed => progress >= target;
  int get progress => settings.consecutive ? streak : correctCount;
  int get cooldown => max(0, ((_cooldownUntil - _readTime()) / 1000).ceil());
  void _refill() =>
      _queue = sampleQuestions(pool, records, max(5, target), random: random);
  void _next() {
    if (_queue.isEmpty) _refill();
    final previous = attempted > 0 ? question.id : null;
    if (_queue.length > 1 && _queue.first.id == previous) {
      _queue.add(_queue.removeAt(0));
    }
    question = _queue.removeAt(0);
    order = ChoiceOrder(question, random);
    result = null;
  }

  bool submit({Set<int> selections = const {}, String text = ''}) {
    if (result != null || cooldown > 0 || passed) throw StateError('当前不能重复提交');
    if (question.kind == QuestionKind.fillBlank
        ? text.trim().isEmpty
        : selections.isEmpty) {
      throw StateError('请先完成作答');
    }
    final correct = question.kind == QuestionKind.fillBlank
        ? question.acceptsText(text)
        : order.correct(question, selections);
    result = correct;
    attempted++;
    if (correct) {
      correctCount++;
      streak++;
    } else {
      wrongCount++;
      streak = 0;
      _cooldownUntil = _readTime() + 5000;
      if (settings.penalty) target++;
    }
    records[question.id] =
        (records[question.id] ?? AnswerRecord(questionId: question.id)).answer(
          correct,
        );
    return correct;
  }

  void next() {
    if (result == null || cooldown > 0 || passed) {
      throw StateError('请先完成当前题目与解析');
    }
    _next();
  }
}
