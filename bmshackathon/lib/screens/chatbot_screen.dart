import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import '../i18n/app_localizations.dart';
import '../models/message_model.dart' as local;
import '../services/storage_service.dart';
import '../services/speech_service.dart';
import '../services/tts_service.dart';
import '../services/api_service.dart';

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  // Chat controller from flutter_chat_core
  final ChatController _chatController = InMemoryChatController();
  StreamSubscription<ChatOperation>? _opsSub;

  // Replace with your logged-in user id
  final String _currentUserId = "user-123";
  final String _botUserId = "bot";

  // Offline storage and voice services
  final StorageService _storage = StorageService();
  final SpeechService _speech = SpeechService();
  final TTSService _tts = TTSService();
  final ApiService _api = ApiService();
  bool _initializing = true;
  bool _listening = false;
  final TextEditingController _textCtrl = TextEditingController();
  final FocusNode _textFocus = FocusNode();

  // Called when a message is sent
  void _handleSendPressed(String text) {
    if (text.trim().isEmpty) return;
    // Debug log
    // ignore: avoid_print
    print('[Chatbot] onMessageSend: "$text"');
    final message = Message.text(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      authorId: _currentUserId,
      createdAt: DateTime.now(),
      text: text,
    );
    try {
      _chatController.insertMessage(message);
      _saveLocal(message);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send: $e')),
        );
      }
      return;
    }
    _sendBotReply(text);
  }

  // Resolve user info by id (required by flutter_chat_ui 2.9.0)
  Future<User?> _resolveUser(String userId) async {
    return User(id: userId);
  }

  @override
  void initState() {
    super.initState();
    // Log controller operations to debug UI updates
    _opsSub = _chatController.operationsStream.listen((op) {
      // ignore: avoid_print
      print('[Chatbot] controller op: $op');
    });
    // Initialize storage and voice; then load previous messages or seed welcome
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _initializeServicesAndLoad();
      await _checkApi();
    });
  }

  void _sendBotReply(String userText) async {
    try {
      // Determine current UI language
      final currentLang = LanguageScope.of(context).languageCode;
      // Translate user message to English if needed for backend
      String userTextEn = userText;
      if (currentLang != 'en' && userText.trim().isNotEmpty) {
        try {
          userTextEn = await _api.translate(text: userText, targetLanguage: 'en');
        } catch (_) {
          userTextEn = userText; // fallback
        }
      }
      // Build chat history with roles expected by backend
      final history = _chatController.messages.map<Map<String, String>>((m) {
        final role = (m.authorId == _currentUserId) ? 'user' : 'assistant';
        final content = (m is TextMessage) ? m.text : '';
        return {'role': role, 'content': content};
      }).toList()
        ..add({'role': 'user', 'content': userTextEn});

      final aiTextEn = await _api.aiChat(history: history, language: 'en');
      // Translate AI reply back to current language if needed
      String aiText = aiTextEn;
      if (currentLang != 'en' && aiTextEn.isNotEmpty) {
        try {
          aiText = await _api.translate(text: aiTextEn, targetLanguage: currentLang);
        } catch (_) {
          aiText = aiTextEn; // fallback
        }
      }
      final reply = Message.text(
        id: 'bot-${DateTime.now().millisecondsSinceEpoch}',
        authorId: _botUserId,
        createdAt: DateTime.now(),
        text: aiText.isNotEmpty
            ? aiText
            : "${AppLocalizations.of(context).t('you_said')}: '$userText'. ${AppLocalizations.of(context).t('start_triage')}",
      );
      _chatController.insertMessage(reply);
      _saveLocal(reply);
      final replyText = (reply is TextMessage) ? reply.text : '';
      if (replyText.isNotEmpty) {
        await _tts.speak(replyText);
      }
    } catch (e) {
      if (!mounted) return;
      final fallback = Message.text(
        id: 'bot-${DateTime.now().millisecondsSinceEpoch}',
        authorId: _botUserId,
        createdAt: DateTime.now(),
        text: 'Sorry, I could not reach the server. Please try again later.',
      );
      _chatController.insertMessage(fallback);
      _saveLocal(fallback);
      // Surface the actual error to the user for easier debugging (CORS, URL, etc.)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('AI chat error: $e')),
      );
    }
  }

  @override
  void dispose() {
    _opsSub?.cancel();
    _textCtrl.dispose();
    _textFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    // Ensure the initial bot welcome matches current locale if already inserted
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final msgs = _chatController.messages;
      if (msgs.isNotEmpty) {
        final first = msgs.first;
        // If first message is bot welcome but text doesn't match current locale, update it
        if (first is TextMessage && first.authorId == _botUserId) {
          final desired = loc.t('bot_welcome');
          if (first.text != desired) {
            final updated = first.copyWith(text: desired);
            _chatController.updateMessage(first, updated);
            // also update local storage for first message
            _saveLocal(updated);
          }
        }
      }
    });
    return Scaffold(
      appBar: AppBar(
        title: Text(loc.t('chatbot')),
        actions: [
          IconButton(
            tooltip: 'Clear chat',
            icon: const Icon(Icons.clear_all),
            onPressed: _clearChat,
          ),
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFE3F2FD), Color(0xFFE8F5E9)],
          ),
        ),
        child: Chat(
          currentUserId: _currentUserId,
          resolveUser: _resolveUser,
          chatController: _chatController,
          // Disable built-in composer; we render our own bottom bar
          onMessageSend: null,
          // Hide the built-in composer by overriding it with an empty widget
          builders: Builders(
            composerBuilder: (context) => const SizedBox.shrink(),
          ),
          theme: ChatTheme.light(),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Container
          (
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2)),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Speak',
                  icon: Icon(_listening ? Icons.mic : Icons.mic_none, color: Color(0xFF43A047)),
                  onPressed: _listening ? null : _startVoiceIntoComposer,
                ),
                Expanded(
                  child: TextField(
                    controller: _textCtrl,
                    focusNode: _textFocus,
                    minLines: 1,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: loc.t('composer_hint'),
                      border: InputBorder.none,
                    ),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _handleComposerSend(),
                  ),
                ),
                const SizedBox(width: 6),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E88E5),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    elevation: 3,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _handleComposerSend,
                  icon: const Icon(Icons.send),
                  label: Text(loc.t('send')),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'mic',
            onPressed: _listening ? null : _startVoiceInput,
            backgroundColor: const Color(0xFF43A047),
            icon: Icon(_listening ? Icons.mic : Icons.mic_none, color: Colors.white),
            label: Text(_listening ? 'Listening...' : 'Speak', style: const TextStyle(color: Colors.white)),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'triage',
            onPressed: () => Navigator.pushNamed(context, '/triage'),
            backgroundColor: const Color(0xFF1E88E5),
            icon: const Icon(Icons.stacked_line_chart_rounded, color: Colors.white),
            label: Text(loc.t('start_triage'), style: const TextStyle(color: Colors.white)),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'map',
            onPressed: () => Navigator.pushNamed(context, '/map'),
            backgroundColor: const Color(0xFF1E88E5),
            icon: const Icon(Icons.map_outlined, color: Colors.white),
            label: const Text('View Nearby Facilities', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _initializeServicesAndLoad() async {
    setState(() => _initializing = true);
    try {
      await _storage.init();
      await _speech.initialize();
      await _tts.initialize();
      final stored = _storage.getAllMessages();
      if (stored.isEmpty) {
        // seed welcome message localized
        final welcome = Message.text(
          id: 'welcome-${DateTime.now().millisecondsSinceEpoch}',
          authorId: _botUserId,
          createdAt: DateTime.now(),
          text: AppLocalizations.of(context).t('bot_welcome'),
        );
        _chatController.setMessages([welcome]);
        await _saveLocal(welcome);
      } else {
        // map stored to controller messages
        final msgs = stored.map(_fromLocal).toList();
        _chatController.setMessages(msgs);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Init error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _initializing = false);
    }
  }

  // Map from package Message to local Hive model and save
  Future<void> _saveLocal(Message msg) async {
    try {
      final model = local.MessageModel(
        id: msg.id,
        text: msg is TextMessage ? msg.text : '',
        isUser: msg.authorId == _currentUserId,
        timestamp: (msg.createdAt is DateTime)
            ? (msg.createdAt as DateTime)
            : DateTime.fromMillisecondsSinceEpoch(
                (msg.createdAt as int?) ?? DateTime.now().millisecondsSinceEpoch,
              ),
      );
      await _storage.saveMessage(model);
    } catch (e) {
      // ignore: avoid_print
      print('Persist error: $e');
    }
  }

  // Map from local Hive model to package Message
  Message _fromLocal(local.MessageModel m) {
    return Message.text(
      id: m.id,
      authorId: m.isUser ? _currentUserId : _botUserId,
      createdAt: m.timestamp,
      text: m.text,
    );
  }

  Future<void> _clearChat() async {
    try {
      await _storage.clearAllMessages();
      _chatController.setMessages([]);
      // Seed welcome again
      final welcome = Message.text(
        id: 'welcome-${DateTime.now().millisecondsSinceEpoch}',
        authorId: _botUserId,
        createdAt: DateTime.now(),
        text: AppLocalizations.of(context).t('bot_welcome'),
      );
      _chatController.setMessages([welcome]);
      await _saveLocal(welcome);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to clear: $e')),
      );
    }
  }

  // Check backend connectivity and show a banner if unreachable
  Future<void> _checkApi() async {
    final ok = await _api.ping();
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
    } else {
      // Intentionally do not show a banner. We silently ignore unreachable state here
      // to avoid displaying a persistent red warning at the top of the chat screen.
      // You can re-enable a banner or a more subtle indicator if needed.
    }
  }

  Future<void> _startVoiceInput() async {
    if (_listening) return;
    setState(() => _listening = true);
    try {
      String buffer = '';
      final started = await _speech.startListeningWithCallback((text, isFinal) {
        buffer = text;
        if (isFinal && buffer.isNotEmpty) {
          _handleSendPressed(buffer);
        }
      });
      if (!started) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to access microphone. Check browser/site permissions.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Voice input error: $e')),
      );
    } finally {
      if (mounted) setState(() => _listening = false);
    }
  }

  // Custom composer: send current typed text
  void _handleComposerSend() {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    _handleSendPressed(text);
    _textCtrl.clear();
    _textFocus.requestFocus();
  }

  // Custom composer: dictate into the text field (does not auto-send)
  Future<void> _startVoiceIntoComposer() async {
    if (_listening) return;
    setState(() => _listening = true);
    try {
      final started = await _speech.startListeningWithCallback((text, isFinal) {
        _textCtrl.text = text;
        _textCtrl.selection = TextSelection.fromPosition(
          TextPosition(offset: _textCtrl.text.length),
        );
        if (isFinal) {
          _textFocus.requestFocus();
        }
      });
      if (!started) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to access microphone. Check browser/site permissions.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Voice input error: $e')),
      );
    } finally {
      if (mounted) setState(() => _listening = false);
    }
  }
}
