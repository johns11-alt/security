import 'dart:convert';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:crypto/crypto.dart' as crypto;
import 'dart:math' as math;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class Security {

  static String encryptJson(Map<String, dynamic> jsonData) {
    final String tokenSecret = dotenv.env["ENCRYPT_KEY"]!;
    final key = encrypt.Key(Uint8List.fromList(
      crypto.sha256.convert(utf8.encode(tokenSecret)).bytes
    ));
    final iv = Uint8List.fromList(
        List<int>.generate(16, (_) => math.Random.secure().nextInt(256)));
    final jsonString = json.encode(jsonData);
    final encrypter =
        encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.cbc));
    final encrypted = encrypter.encrypt(jsonString, iv: encrypt.IV(iv));
    final concatenatedData = Uint8List.fromList(iv + encrypted.bytes);
    final encryptedData = base64.encode(concatenatedData);
    return encryptedData;
  }

static Map<String, dynamic> decryptJson(String encryptedJSON) {
    final String tokenSecret = dotenv.env["ENCRYPT_KEY"]!;
    final key = encrypt.Key(Uint8List.fromList(
        crypto.sha256.convert(utf8.encode(tokenSecret)).bytes));
    Uint8List encryptedBytes = Uint8List.fromList(base64.decode(encryptedJSON));
    final iv = encrypt.IV(encryptedBytes.sublist(0, 16));
    final encryptedDataBytes = encryptedBytes.sublist(16);
    final encrypter =
        encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.cbc));
    final decrypted = encrypter.decryptBytes(
      encrypt.Encrypted(encryptedDataBytes),
      iv: iv,
    );
    String decryptedString = utf8.decode(decrypted);
    Map<String, dynamic> decryptedData = json.decode(decryptedString);
    return decryptedData;
  }
}
