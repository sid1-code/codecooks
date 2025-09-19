import 'package:speech_to_text/speech_to_text.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class SpeechService {
  final SpeechToText _speechToText = SpeechToText();
  bool _isInitialized = false;
  bool _isListening = false;

  bool get isInitialized => _isInitialized;
  bool get isListening => _isListening;

  Future<bool> initialize() async {
    try {
      // On web, the browser will handle the mic permission prompt; permission_handler is not needed
      if (!kIsWeb) {
        final status = await Permission.microphone.request();
        if (status != PermissionStatus.granted) {
          // ignore: avoid_print
          print('Microphone permission denied');
          return false;
        }
      }

      // ignore: avoid_print
      print('Initializing speech recognition...');
      _isInitialized = await _speechToText.initialize(
        onStatus: (status) {
          // ignore: avoid_print
          print('Speech recognition status: $status');
          _isListening = status == 'listening';
        },
        onError: (error) {
          // ignore: avoid_print
          print('Speech recognition error: $error');
        },
      );

      // ignore: avoid_print
      print('Speech recognition initialized: $_isInitialized');
      return _isInitialized;
    } catch (e) {
      // ignore: avoid_print
      print('Error initializing speech service: $e');
      return false;
    }
  }

  /// Listen and stream interim/final results using the provided callback.
  /// The callback receives (text, isFinal). Returns true if started.
  Future<bool> startListeningWithCallback(
    void Function(String text, bool isFinal) onPartial,
  ) async {
    if (!_isInitialized) {
      final initialized = await initialize();
      if (!initialized) return false;
    }

    if (_speechToText.isListening) {
      await _speechToText.stop();
      await Future.delayed(const Duration(milliseconds: 300));
    }

    try {
      await _speechToText.listen(
        onResult: (result) {
          final text = result.recognizedWords.trim();
          onPartial(text, result.finalResult);
        },
        listenFor: const Duration(seconds: 12),
        pauseFor: const Duration(seconds: 2),
        partialResults: true,
        localeId: 'en_US',
      );
      return true;
    } catch (e) {
      // ignore: avoid_print
      print('Error starting listening with callback: $e');
      if (_speechToText.isListening) {
        await _speechToText.stop();
      }
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
      );

      int timeout = 0;
      while (_speechToText.isListening && !isCompleted && timeout < 100) {
        await Future.delayed(const Duration(milliseconds: 100));
        timeout++;
      }

      if (_speechToText.isListening) {
        await _speechToText.stop();
      }

      return recognizedText?.trim();
    } catch (e) {
      // ignore: avoid_print
      print('Error during speech recognition: $e');
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
}
