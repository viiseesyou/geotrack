import 'package:encrypt/encrypt.dart' as enc;

class EncryptionService {
  // Ключ шифрования — в реальном приложении хранится безопасно
  static final _key = enc.Key.fromUtf8('geotrack_secret_key_32bytes!!!!!');
  static final _iv = enc.IV.fromUtf8('geotrack_iv_16b!');
  static final _encrypter = enc.Encrypter(enc.AES(_key));

  // Зашифровать число (координату)
  static String encryptCoordinate(double coordinate) {
    final encrypted = _encrypter.encrypt(coordinate.toString(), iv: _iv);
    return encrypted.base64;
  }

  // Расшифровать координату
  static double decryptCoordinate(String encryptedValue) {
    try {
      final decrypted = _encrypter.decrypt64(encryptedValue, iv: _iv);
      return double.parse(decrypted);
    } catch (e) {
      return 0.0;
    }
  }
}