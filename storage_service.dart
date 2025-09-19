import 'package:hive_flutter/hive_flutter.dart';
import '../models/message_model.dart';

class StorageService {
  static const String _messagesBoxName = 'messages';
  late Box<MessageModel> _messagesBox;

  Future<void> init() async {
    // Open boxes (Hive is already initialized in main.dart)
    _messagesBox = await Hive.openBox<MessageModel>(_messagesBoxName);
  }

  Future<void> saveMessage(MessageModel message) async {
    await _messagesBox.put(message.id, message);
  }

  Future<void> saveMessages(List<MessageModel> messages) async {
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
}

