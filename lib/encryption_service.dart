import 'dart:math';
import 'dart:convert';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as enc;

class EncryptionService {
  // Генерация случайного 256-битного ключа для группы
  static String generateGroupKey() {
    final random = Random.secure();
    final keyBytes = Uint8List.fromList(
        List<int>.generate(32, (_) => random.nextInt(256)));
    return base64Encode(keyBytes);
  }

  // Шифрование координаты со случайным IV
  static Map<String, String> encryptCoordinate(
      double coordinate, String groupKeyBase64) {
    final keyBytes = Uint8List.fromList(base64Decode(groupKeyBase64));
    final key = enc.Key(keyBytes);

    final random = Random.secure();
    final ivBytes = Uint8List.fromList(
        List<int>.generate(16, (_) => random.nextInt(256)));
    final iv = enc.IV(ivBytes);

    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    final encrypted = encrypter.encrypt(coordinate.toString(), iv: iv);

    return {
      'data': encrypted.base64,
      'iv': base64Encode(ivBytes),
    };
  }

  // Расшифровка координаты
  static double decryptCoordinate(
      String encryptedData, String ivBase64, String groupKeyBase64) {
    try {
      final keyBytes = Uint8List.fromList(base64Decode(groupKeyBase64));
      final key = enc.Key(keyBytes);
      final ivBytes = Uint8List.fromList(base64Decode(ivBase64));
      final iv = enc.IV(ivBytes);

      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
      final decrypted = encrypter.decrypt64(encryptedData, iv: iv);
      return double.parse(decrypted);
    } catch (e) {
      return 0.0;
    }
  }

  // Шифрование ключа группы для пользователя через XOR
  static String encryptKeyForUser(String groupKey, String userId) {
    final keyBytes = Uint8List.fromList(utf8.encode(groupKey));
    final userBytes = utf8.encode(userId);
    final xored = Uint8List.fromList(List<int>.generate(
      keyBytes.length,
      (i) => keyBytes[i] ^ userBytes[i % userBytes.length],
    ));
    return base64Encode(xored);
  }

  // Расшифровка ключа группы для пользователя
  static String decryptKeyForUser(String encryptedKey, String userId) {
    final keyBytes = Uint8List.fromList(base64Decode(encryptedKey));
    final userBytes = utf8.encode(userId);
    final xored = Uint8List.fromList(List<int>.generate(
      keyBytes.length,
      (i) => keyBytes[i] ^ userBytes[i % userBytes.length],
    ));
    return utf8.decode(xored);
  }
}