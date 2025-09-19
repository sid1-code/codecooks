import 'package:hive_flutter/hive_flutter.dart';
import '../models/message_model.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import 'dart:math';
import 'consent_service.dart';

class StorageService {
  static const String _messagesBoxName = 'messages';
  late Box<MessageModel> _messagesBox;
  final _secure = const FlutterSecureStorage();

  Future<List<int>> _loadOrCreateKey() async {
    const keyName = 'hive_messages_key';
    String? b64 = await _secure.read(key: keyName);
    if (b64 == null) {
      final rnd = Random.secure();
      final key = List<int>.generate(32, (_) => rnd.nextInt(256));
      b64 = base64UrlEncode(key);
      await _secure.write(key: keyName, value: b64);
      return key;
    }
    return base64Url.decode(b64);
  }

  Future<void> init() async {
    final key = await _loadOrCreateKey();
    _messagesBox = await Hive.openBox<MessageModel>(
      _messagesBoxName,
      encryptionCipher: HiveAesCipher(key),
    );
  }

  Future<void> saveMessage(MessageModel message) async {
    // Respect consent: if user opted out of storage, ignore
    final consent = ConsentService();
    if (!await consent.isStoreAllowed()) return;
    await _messagesBox.put(message.id, message);
  }

  Future<void> saveMessages(List<MessageModel> messages) async {
    final consent = ConsentService();
    if (!await consent.isStoreAllowed()) return;
    final Map<String, MessageModel> messageMap = {
      for (var message in messages) message.id: message
    };
    await _messagesBox.putAll(messageMap);
  }

  List<MessageModel> getAllMessages() {
    return _messagesBox.values.toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  Future<void> deleteMessage(String messageId) async {
    await _messagesBox.delete(messageId);
  }

  Future<void> clearAllMessages() async {
    await _messagesBox.clear();
  }

  Future<void> close() async {
    await _messagesBox.close();
  }

  Future<void> clearAllData() async {
    try {
      await _messagesBox.clear();
    } catch (_) {}
    // Remove encryption key from secure storage
    try {
      await _secure.delete(key: 'hive_messages_key');
    } catch (_) {}
  }
}
