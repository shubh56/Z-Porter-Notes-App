import 'dart:convert';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class EncryptionService {
  static const _keyStorageKey = 'notes_encryption_key_v1';
  final FlutterSecureStorage _secure = const FlutterSecureStorage();

  Future<Uint8List> _getOrCreateKey() async {
    final existing = await _secure.read(key: _keyStorageKey);
    if (existing != null && existing.isNotEmpty) {
      return base64Url.decode(existing);
    }
    // generate 32 bytes key
    final key = List<int>.generate(
      32,
      (i) => DateTime.now().microsecondsSinceEpoch.remainder(256),
    );
    final keyBytes = Uint8List.fromList(key);
    await _secure.write(key: _keyStorageKey, value: base64Url.encode(keyBytes));
    return keyBytes;
  }

  Future<String> encryptString(String plain) async {
    final keyBytes = await _getOrCreateKey();
    final key = encrypt.Key(keyBytes);
    final iv = encrypt.IV.fromSecureRandom(16);
    final encrypter = encrypt.Encrypter(
      encrypt.AES(key, mode: encrypt.AESMode.cbc),
    );
    final encrypted = encrypter.encrypt(plain, iv: iv);
    // store iv + cipher as base64
    final combined = iv.bytes + encrypted.bytes;
    return base64Url.encode(combined);
  }

  Future<String> decryptString(String cipherText) async {
    try {
      final keyBytes = await _getOrCreateKey();
      final combined = base64Url.decode(cipherText);
      final ivBytes = combined.sublist(0, 16);
      final ctBytes = combined.sublist(16);
      final key = encrypt.Key(keyBytes);
      final iv = encrypt.IV(ivBytes);
      final encrypter = encrypt.Encrypter(
        encrypt.AES(key, mode: encrypt.AESMode.cbc),
      );
      final decrypted = encrypter.decrypt(
        encrypt.Encrypted(Uint8List.fromList(ctBytes)),
        iv: iv,
      );
      return decrypted;
    } catch (e) {
      return ''; // return empty on error
    }
  }
}
