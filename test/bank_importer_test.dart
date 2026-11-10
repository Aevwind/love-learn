import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studylock/features/banks/bank_importer.dart';

Map<String, dynamic> bank() => {
  'bank_name': 'A test bank',
  'questions': [
    {
      'id': '1',
      'type': 'single_choice',
      'stem': '1+1?',
      'payload': {
        'options': ['2', '3'],
      },
      'answer': [0],
    },
  ],
};
Uint8List bytes(String s) => Uint8List.fromList(utf8.encode(s));
void main() {
  test('import namespaces ids and accepts UTF-8 BOM', () {
    final b = BankImporter.parse(
      'bank.json',
      bytes('\uFEFF${jsonEncode(bank())}'),
    );
    expect(b.questions.length, 1);
    expect(b.imported, isTrue);
    expect(b.questions.first.id, startsWith('${b.id}::'));
  });
  test('invalid choice indices and duplicate ids reject the whole bank', () {
    final data = bank();
    (data['questions'] as List).first['answer'] = [5];
    expect(
      () => BankImporter.fromText(jsonEncode(data)),
      throwsFormatException,
    );
    final duplicate = bank();
    (duplicate['questions'] as List).add(
      (duplicate['questions'] as List).first,
    );
    expect(
      () => BankImporter.fromText(jsonEncode(duplicate)),
      throwsFormatException,
    );
  });
  test('CSV handles quoted JSON arrays and answer columns', () {
    const data =
        'id,type,stem,options,answer,explanation\nq1,single_choice,1+1?,"[""2"",""3""]",[0],Addition';
    final b = BankImporter.parse('test.csv', bytes(data));
    expect(b.questions.first.options, ['2', '3']);
    expect(b.questions.first.answers, [0]);
  });
  test(
    'ZIP rejects traversal entries even when no files are written to disk',
    () {
      final archive = Archive()
        ..addFile(ArchiveFile.string('questions.json', jsonEncode(bank())))
        ..addFile(ArchiveFile.string('../outside.txt', 'invalid'));
      final zip = ZipEncoder().encode(archive);
      expect(
        () => BankImporter.parse('test.zip', Uint8List.fromList(zip)),
        throwsFormatException,
      );
    },
  );
  test('media manifests reject missing local audio', () {
    final data = bank();
    final q = (data['questions'] as List).first;
    q['type'] = 'listening';
    q['audio_source'] = 'file:media/word.mp3';
    expect(
      () => BankImporter.fromText(jsonEncode(data)),
      throwsFormatException,
    );
  });
}
