import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:csv/csv.dart';

import '../../core/models.dart';

class BankImporter {
  static const maxBytes = 20 * 1024 * 1024;
  static QuestionBank parse(String name, Uint8List bytes) {
    if (bytes.length > maxBytes) throw const FormatException('题库文件不能超过 20 MB');
    final extension = name.split('.').last.toLowerCase();
    if (extension == 'zip') {
      final archive = ZipDecoder().decodeBytes(bytes, verify: true);
      if (archive.length > 512 ||
          archive.fold<int>(0, (v, f) => v + f.size) > 50 * 1024 * 1024) {
        throw const FormatException('题库包解压后不能超过 50 MB 或 512 个文件');
      }
      final media = <String, String>{};
      Uint8List? manifest;
      for (final file in archive) {
        final path = file.name.replaceAll('\\', '/');
        if (path.startsWith('/') ||
            path.contains(':') ||
            path.split('/').contains('..') ||
            file.isSymbolicLink) {
          throw const FormatException('ZIP 包含无效的文件路径');
        }
        if (!file.isFile) continue;
        if (path == 'questions.json') {
          manifest = Uint8List.fromList(file.content);
        }
        if (path.startsWith('media/') &&
            RegExp(
              r'\.(mp3|wav|m4a|ogg)$',
              caseSensitive: false,
            ).hasMatch(path)) {
          media[path] = base64Encode(file.content);
        }
      }
      if (manifest == null) {
        throw const FormatException('ZIP 根目录需要 questions.json');
      }
      final bank = _json(utf8.decode(manifest)).copyWith(media: media);
      _validateAudio(bank);
      return bank;
    }
    final text = utf8.decode(bytes).replaceFirst('\uFEFF', '');
    final bank = extension == 'csv'
        ? _csv(name, text)
        : extension == 'json'
        ? _json(text)
        : throw const FormatException('请选择 JSON、CSV 或 ZIP 文件');
    _validateAudio(bank);
    return bank;
  }

  static QuestionBank fromText(String text) {
    final bytes = utf8.encode(text);
    return parse('import.json', Uint8List.fromList(bytes));
  }

  static QuestionBank _json(String text) {
    final decoded = jsonDecode(text);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('JSON 顶层必须是题库对象');
    }
    final bank = QuestionBank.fromJson(
      decoded,
      id: 'import_${DateTime.now().microsecondsSinceEpoch}',
      imported: true,
    );
    if (bank.questions.length > 5000) {
      throw const FormatException('每个题库最多支持 5000 题');
    }
    return bank;
  }

  static void _validateAudio(QuestionBank bank) {
    for (final q in bank.questions) {
      final audio = q.audioSource;
      if (audio != null &&
          audio.startsWith('file:') &&
          !bank.media.containsKey(audio.substring(5))) {
        throw FormatException(
          '缺少音频 ${audio.substring(5)}，请使用 ZIP 包并放在 media/ 目录',
        );
      }
    }
  }

  static QuestionBank _csv(String name, String text) {
    final rows = const CsvDecoder().convert(text);
    if (rows.length < 2) throw const FormatException('CSV 需要表头和至少一道题目');
    final headers = rows.first.map((v) => v.toString().trim()).toList();
    for (final key in ['id', 'type', 'stem', 'answer']) {
      if (!headers.contains(key)) throw FormatException('CSV 缺少 $key 列');
    }
    final questions = <Map<String, dynamic>>[];
    for (final row in rows.skip(1)) {
      String get(String key) {
        final i = headers.indexOf(key);
        return i < 0 || i >= row.length ? '' : row[i].toString();
      }

      final fill = get('type') == 'fill_blank';
      final options = get('options').isEmpty
          ? <dynamic>[]
          : jsonDecode(get('options')) as List;
      questions.add({
        'id': get('id'),
        'type': get('type'),
        'stem': get('stem'),
        'answer': fill ? [get('answer')] : jsonDecode(get('answer')),
        'payload': {'options': options},
        'explanation': get('explanation'),
        'audio_source': get('audio_source').isEmpty
            ? null
            : get('audio_source'),
        'difficulty': int.tryParse(get('difficulty')) ?? 1,
        'tags': get('tags'),
      });
    }
    return _json(
      jsonEncode({
        'bank_name': name.replaceFirst(
          RegExp(r'\.csv$', caseSensitive: false),
          '',
        ),
        'category': 'general',
        'questions': questions,
      }),
    );
  }
}
