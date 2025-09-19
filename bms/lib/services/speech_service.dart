import 'package:speech_to_text/speech_to_text.dart';
import 'package:permission_handler/permission_handler.dart';

class SpeechService {
  final SpeechToText _speechToText = SpeechToText();
  bool _isInitialized = false;
  bool _isListening = false;

  bool get isInitialized => _isInitialized;
  bool get isListening => _isListening;

  Future<bool> initialize() async {
    try {
      // Request microphone permission
      final status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) {
        print('Microphone permission denied');
        return false;
      }

      print('Initializing speech recognition...');
      _isInitialized = await _speechToText.initialize(
        onStatus: (status) {
          print('Speech recognition status: $status');
          _isListening = status == 'listening';
        },
        onError: (error) {
          print('Speech recognition error: $error');
        },
      );

      print('Speech recognition initialized: $_isInitialized');
      return _isInitialized;
    } catch (e) {
      print('Error initializing speech service: $e');
      return false;
    }
  }

  Future<String?> startListening() async {
    if (!_isInitialized) {
      final initialized = await initialize();
      if (!initialized) {
        return null;
      }
    }

    // Stop any existing listening session
    if (_speechToText.isListening) {
      await _speechToText.stop();
      await Future.delayed(const Duration(milliseconds: 500));
    }

    try {
      String? recognizedText;
      bool isCompleted = false;
      
      await _speechToText.listen(
        onResult: (result) {
          recognizedText = result.recognizedWords;
          if (result.finalResult) {
            isCompleted = true;
          }
        },
        listenFor: const Duration(seconds: 10),
        pauseFor: const Duration(seconds: 2),
        partialResults: true,
        localeId: 'en_US',
        onSoundLevelChange: (level) {
          // Handle sound level changes if needed
        },
      );

      // Wait for listening to complete or timeout
      int timeout = 0;
      while (_speechToText.isListening && !isCompleted && timeout < 100) {
        await Future.delayed(const Duration(milliseconds: 100));
        timeout++;
      }

      // Stop listening if still active
      if (_speechToText.isListening) {
        await _speechToText.stop();
      }

      return recognizedText?.trim();
    } catch (e) {
      print('Error during speech recognition: $e');
      // Ensure we stop listening on error
      if (_speechToText.isListening) {
        await _speechToText.stop();
      }
      return null;
    }
  }

  Future<void> stopListening() async {
    if (_speechToText.isListening) {
      await _speechToText.stop();
    }
  }

  Future<void> cancelListening() async {
    if (_speechToText.isListening) {
      await _speechToText.cancel();
    }
  }

  Future<List<LocaleName>> get availableLocales async => await _speechToText.locales();
}
