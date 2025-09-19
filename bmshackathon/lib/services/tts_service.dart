import 'package:flutter_tts/flutter_tts.dart';

class TTSService {
  final FlutterTts _flutterTts = FlutterTts();
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  Future<bool> initialize() async {
    try {
      await _flutterTts.setLanguage('en-US');
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);

      _flutterTts.setStartHandler(() {
        // ignore: avoid_print
        print('TTS started');
      });

      _flutterTts.setCompletionHandler(() {
        // ignore: avoid_print
        print('TTS completed');
      });

      _flutterTts.setErrorHandler((message) {
        // ignore: avoid_print
        print('TTS error: $message');
      });

      _flutterTts.setPauseHandler(() {
        // ignore: avoid_print
        print('TTS paused');
      });

      _flutterTts.setContinueHandler(() {
        // ignore: avoid_print
        print('TTS continued');
      });

      _isInitialized = true;
      return true;
    } catch (e) {
      // ignore: avoid_print
      print('Error initializing TTS service: $e');
      return false;
    }
  }

  Future<void> speak(String text) async {
    if (!_isInitialized) {
      final initialized = await initialize();
      if (!initialized) {
        return;
      }
    }
    try {
      if (text.isNotEmpty) {
        await _flutterTts.speak(text);
      }
    } catch (e) {
      // ignore: avoid_print
      print('Error during TTS: $e');
    }
  }

  Future<void> stop() async {
    try {
      await _flutterTts.stop();
    } catch (e) {
      // ignore: avoid_print
      print('Error stopping TTS: $e');
    }
  }

  Future<void> pause() async {
    try {
      await _flutterTts.pause();
    } catch (e) {
      // ignore: avoid_print
      print('Error pausing TTS: $e');
    }
  }

  Future<void> setLanguage(String language) async {
    try {
      await _flutterTts.setLanguage(language);
    } catch (e) {
      // ignore: avoid_print
      print('Error setting TTS language: $e');
    }
  }

  Future<void> setSpeechRate(double rate) async {
    try {
      await _flutterTts.setSpeechRate(rate);
    } catch (e) {
      // ignore: avoid_print
      print('Error setting TTS speech rate: $e');
    }
  }

  Future<void> setVolume(double volume) async {
    try {
      await _flutterTts.setVolume(volume);
    } catch (e) {
      // ignore: avoid_print
      print('Error setting TTS volume: $e');
    }
  }

  Future<void> setPitch(double pitch) async {
    try {
      await _flutterTts.setPitch(pitch);
    } catch (e) {
      // ignore: avoid_print
      print('Error setting TTS pitch: $e');
    }
  }
}
