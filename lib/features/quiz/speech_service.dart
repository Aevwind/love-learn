import 'dart:convert';

import 'package:flutter_tts/flutter_tts.dart';
import 'package:just_audio/just_audio.dart';

class SpeechService {
  FlutterTts? _tts;
  AudioPlayer? _audio;
  Future<void> play(
    String source,
    double speed,
    Map<String, String> media,
  ) async {
    await stop();
    if (source.startsWith('tts:')) {
      final tts = _tts ??= FlutterTts();
      await tts.setLanguage('en-US');
      await tts.setSpeechRate(.45 * speed);
      await tts.awaitSpeakCompletion(true);
      await tts.speak(source.substring(4));
    } else {
      final path = source.substring(5);
      final bytes = media[path];
      if (bytes == null) throw StateError('题库音频文件不存在');
      final mime = path.endsWith('.wav')
          ? 'audio/wav'
          : path.endsWith('.ogg')
          ? 'audio/ogg'
          : path.endsWith('.m4a')
          ? 'audio/mp4'
          : 'audio/mpeg';
      final audio = _audio ??= AudioPlayer();
      await audio.setUrl(
        Uri.dataFromBytes(base64Decode(bytes), mimeType: mime).toString(),
      );
      await audio.setSpeed(speed);
      await audio.play();
    }
  }

  Future<void> stop() async {
    await _tts?.stop();
    await _audio?.stop();
  }

  Future<void> dispose() async {
    await stop();
    await _audio?.dispose();
  }
}
