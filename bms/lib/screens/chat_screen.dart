import 'package:flutter/material.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import '../models/message_model.dart';
import '../services/storage_service.dart';
import '../services/speech_service.dart';
import '../services/tts_service.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final StorageService _storageService = StorageService();
  final SpeechService _speechService = SpeechService();
  final TTSService _ttsService = TTSService();
  
  List<MessageModel> _messages = [];
  bool _isLoading = false;
  bool _isListening = false;
  bool _isTyping = false;
  
  late AnimationController _micAnimationController;
  late AnimationController _typingAnimationController;
  late Animation<double> _micAnimation;
  late Animation<double> _typingAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeServices();
  }

  void _initializeAnimations() {
    _micAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _micAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _micAnimationController, curve: Curves.easeInOut),
    );

    _typingAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _typingAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _typingAnimationController, curve: Curves.easeInOut),
    );
  }

  Future<void> _initializeServices() async {
    setState(() => _isLoading = true);
    
    try {
      await _storageService.init();
      await _speechService.initialize();
      await _ttsService.initialize();
      
      // Load previous messages
      _messages = _storageService.getAllMessages();
      
      setState(() => _isLoading = false);
    } catch (e) {
      print('Error initializing services: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    final now = DateTime.now();
    final userMessage = MessageModel(
      id: '${now.millisecondsSinceEpoch}_user',
      text: text.trim(),
      isUser: true,
      timestamp: now,
    );

    setState(() {
      _messages.add(userMessage);
      // Sort messages after adding to maintain chronological order
      _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    });

    await _storageService.saveMessage(userMessage);

    // Generate bot response
    await _generateBotResponse(text.trim());
  }

  Future<void> _generateBotResponse(String userMessage) async {
    // Show typing indicator
    setState(() => _isTyping = true);
    _typingAnimationController.repeat(reverse: true);
    
    // Add a small delay to simulate thinking
    await Future.delayed(const Duration(milliseconds: 1200));
    
    // Hide typing indicator
    setState(() => _isTyping = false);
    _typingAnimationController.stop();
    
    final botResponse = _getDummyResponse(userMessage);
    
    // Ensure bot message has a timestamp after the user message
    final botNow = DateTime.now();
    final botMessage = MessageModel(
      id: '${botNow.millisecondsSinceEpoch}_bot',
      text: botResponse,
      isUser: false,
      timestamp: botNow, // This will be after user message due to the delay
    );

    setState(() {
      _messages.add(botMessage);
      // Sort messages after adding to maintain chronological order
      _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    });

    await _storageService.saveMessage(botMessage);

    // Speak the bot response
    await _ttsService.speak(botResponse);
  }

  String _getDummyResponse(String userMessage) {
    final message = userMessage.toLowerCase().trim();
    
    // First-time greeting responses
    if (message.contains('hello') || message.contains('hi') || message.contains('hey')) {
      if (_messages.length <= 2) { // First interaction
        return "Hello! I'm your AI assistant. How can I help you today?";
      } else {
        return "Hello again! How can I help you today?";
      }
    }
    
    // How are you responses
    if (message.contains('how are you') || message.contains('how do you do')) {
      return "I'm doing great, thank you for asking! I'm here and ready to help you with anything you need. What can I assist you with?";
    }
    
    // Thank you responses
    if (message.contains('thank') || message.contains('thanks')) {
      return "You're very welcome! I'm happy to help. Is there anything else I can assist you with?";
    }
    
    // Goodbye responses
    if (message.contains('bye') || message.contains('goodbye') || message.contains('see you')) {
      return "Goodbye! It was nice chatting with you. Feel free to come back anytime if you need help!";
    }
    
    // Question responses
    if (message.contains('?')) {
      return "That's a great question! While I'm a simple assistant right now, I'm here to help. Could you tell me more about what you're looking for?";
    }
    
    // Name/identity questions
    if (message.contains('who are you') || message.contains('what are you') || message.contains('your name')) {
      return "I'm your AI assistant! I'm here to help you with questions, have conversations, and assist you with various tasks. What would you like to know?";
    }
    
    // Help requests
    if (message.contains('help') || message.contains('assist')) {
      return "I'd be happy to help! I can chat with you, answer questions, and assist with various topics. What specifically do you need help with?";
    }
    
    // Weather questions
    if (message.contains('weather')) {
      return "I don't have access to real-time weather data, but I'd be happy to chat about other topics! What else interests you?";
    }
    
    // Time questions
    if (message.contains('time') || message.contains('date')) {
      final now = DateTime.now();
      return "The current time is ${now.hour}:${now.minute.toString().padLeft(2, '0')} on ${now.day}/${now.month}/${now.year}. Is there anything else I can help you with?";
    }
    
    // Default contextual responses based on conversation length
    if (_messages.length < 4) {
      return "That's interesting! Tell me more about it.";
    } else if (_messages.length < 8) {
      return "I understand what you're saying. What would you like to know more about?";
    } else {
      final responses = [
        "Great point! What's your next question?",
        "I'm listening. Please continue.",
        "That's fascinating! Tell me more.",
        "I see what you mean. What else can I help you with?",
        "Interesting perspective! What would you like to explore next?",
      ];
      return responses[DateTime.now().millisecondsSinceEpoch % responses.length];
    }
  }

  Future<void> _startVoiceInput() async {
    if (_isListening) return;

    setState(() => _isListening = true);
    _micAnimationController.repeat(reverse: true);

    try {
      print('Starting voice input...');
      final recognizedText = await _speechService.startListening();
      print('Voice input result: $recognizedText');
      
      if (recognizedText != null && recognizedText.isNotEmpty) {
        print('Sending recognized text: $recognizedText');
        await _sendMessage(recognizedText);
      } else {
        print('No text recognized or empty result');
        // Show a brief message to user that no speech was detected
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No speech detected. Please try again.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Error during voice input: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Voice input error: $e'),
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      setState(() => _isListening = false);
      _micAnimationController.stop();
    }
  }

  List<types.Message> _convertToFlutterChatMessages() {
    // Sort messages by timestamp to ensure correct order
    final sortedMessages = List<MessageModel>.from(_messages)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    
    return sortedMessages.map((message) {
      return types.TextMessage(
        id: message.id,
        text: message.text,
        author: types.User(
          id: message.isUser ? 'user' : 'bot',
          firstName: message.isUser ? 'You' : 'Bot',
        ),
        createdAt: message.timestamp.millisecondsSinceEpoch,
        metadata: {
          'isUser': message.isUser,
          'timestamp': message.timestamp.toIso8601String(),
        },
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFF1A1A2E),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
              ),
              const SizedBox(height: 20),
              Text(
                'Initializing AI Assistant...',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.smart_toy,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'AI Assistant',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF16213E),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.clear_all),
            onPressed: () async {
              await _storageService.clearAllMessages();
              setState(() {
                _messages.clear();
              });
            },
            tooltip: 'Clear Chat',
            color: Colors.white,
          ),
          AnimatedBuilder(
            animation: _micAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _isListening ? _micAnimation.value : 1.0,
                child: Container(
                  margin: const EdgeInsets.only(right: 16),
                  decoration: BoxDecoration(
                    gradient: _isListening 
                        ? const LinearGradient(colors: [Colors.red, Colors.pink])
                        : const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)]),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: IconButton(
                    icon: Icon(_isListening ? Icons.mic : Icons.mic_none),
                    onPressed: _isListening ? null : _startVoiceInput,
                    tooltip: 'Voice Input',
                    color: Colors.white,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
                ),
              ),
              child: Stack(
                children: [
                  Chat(
                    messages: _convertToFlutterChatMessages(),
                    onSendPressed: (partialText) {
                      if (partialText != null && partialText.text.isNotEmpty) {
                        _sendMessage(partialText.text);
                      }
                    },
                    user: const types.User(
                      id: 'user',
                      firstName: 'You',
                    ),
                    theme: const DefaultChatTheme(
                      primaryColor: Color(0xFF6366F1),
                      secondaryColor: Color(0xFF8B5CF6),
                      backgroundColor: Colors.transparent,
                      inputBackgroundColor: Color(0xFF2D3748),
                      inputTextColor: Colors.white,
                      inputBorderRadius: BorderRadius.all(Radius.circular(25)),
                      userAvatarTextStyle: TextStyle(color: Colors.white),
                      receivedMessageDocumentIconColor: Color(0xFF6366F1),
                      sentMessageDocumentIconColor: Colors.white,
                    ),
                    showUserAvatars: true,
                    showUserNames: true,
                    inputOptions: const InputOptions(
                      sendButtonVisibilityMode: SendButtonVisibilityMode.always,
                    ),
                  ),
                  if (_isTyping)
                    Positioned(
                      bottom: 80,
                      left: 20,
                      child: AnimatedBuilder(
                        animation: _typingAnimation,
                        builder: (context, child) {
                          return Opacity(
                            opacity: _typingAnimation.value,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2D3748),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                    'AI is typing',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white.withOpacity(0.6),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _micAnimationController.dispose();
    _typingAnimationController.dispose();
    _storageService.close();
    super.dispose();
  }
}
