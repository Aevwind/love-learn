import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studylock/features/security/pin_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'PINs are salted, verified, and locked after five consecutive failures',
    () async {
      FlutterSecureStorage.setMockInitialValues({});
      final pin = PinService();
      await pin.initialize();
      expect(pin.configured, isFalse);
      await pin.setPin('582619');
      expect(await pin.verify('582619'), isTrue);
      const storage = FlutterSecureStorage();
      final saved = await storage.read(key: 'studylock_pin');
      expect(saved, isNot(contains('582619')));
      for (var i = 0; i < 5; i++) {
        expect(await pin.verify('000000'), isFalse);
      }
      expect(await pin.lockoutSeconds, greaterThanOrEqualTo(599));
      expect(await pin.verify('582619'), isFalse);
    },
  );
}
