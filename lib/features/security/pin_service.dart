import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class PinService {
  PinService([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();
  final FlutterSecureStorage _storage;
  bool configured = false;
  final _algorithm = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: 210000,
    bits: 256,
  );
  Future<void> initialize() async =>
      configured = await _storage.read(key: 'studylock_pin') != null;
  Future<int> get lockoutSeconds async {
    final data = await _storage.read(key: 'studylock_attempts');
    if (data == null) return 0;
    final until = (jsonDecode(data) as Map)['until'] as int? ?? 0;
    return max(
      0,
      ((until - DateTime.now().millisecondsSinceEpoch) / 1000).ceil(),
    );
  }

  Future<void> setPin(String pin) async {
    if (!RegExp(r'^\d{6}$').hasMatch(pin)) {
      throw const FormatException('请设置 6 位数字密码');
    }
    final salt = List.generate(24, (_) => Random.secure().nextInt(256));
    final key = await _algorithm.deriveKey(
      secretKey: SecretKey(utf8.encode(pin)),
      nonce: salt,
    );
    await _storage.write(
      key: 'studylock_pin',
      value: jsonEncode({
        'salt': base64Encode(salt),
        'hash': base64Encode(await key.extractBytes()),
        'iterations': 210000,
      }),
    );
    await _storage.delete(key: 'studylock_attempts');
    configured = true;
  }

  Future<bool> verify(String pin) async {
    if (await lockoutSeconds > 0) return false;
    final data = await _storage.read(key: 'studylock_pin');
    if (data == null) return false;
    final stored = jsonDecode(data) as Map;
    final key = await _algorithm.deriveKey(
      secretKey: SecretKey(utf8.encode(pin)),
      nonce: base64Decode(stored['salt']),
    );
    final actual = await key.extractBytes();
    final expected = base64Decode(stored['hash']);
    var mismatch = actual.length ^ expected.length;
    for (var i = 0; i < min(actual.length, expected.length); i++) {
      mismatch |= actual[i] ^ expected[i];
    }
    if (mismatch == 0) {
      await _storage.delete(key: 'studylock_attempts');
      return true;
    }
    final attemptsData = await _storage.read(key: 'studylock_attempts');
    final previous = attemptsData == null
        ? <String, dynamic>{}
        : jsonDecode(attemptsData) as Map;
    final previousUntil = previous['until'] as int? ?? 0;
    final attempts =
        (previousUntil > 0 ? 0 : previous['count'] as int? ?? 0) + 1;
    await _storage.write(
      key: 'studylock_attempts',
      value: jsonEncode({
        'count': attempts,
        'until': attempts >= 5
            ? DateTime.now()
                  .add(const Duration(minutes: 10))
                  .millisecondsSinceEpoch
            : 0,
      }),
    );
    return false;
  }
}
