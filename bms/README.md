# AI Chatbot App with Offline Support

A Flutter application that provides a chatbot interface with voice input/output capabilities and offline message storage.

## Features

- **Chat Interface**: Clean UI with user messages on the right and bot messages on the left
- **Voice Input**: Speech-to-text functionality for hands-free messaging
- **Voice Output**: Text-to-speech for bot responses
- **Offline Support**: All messages are stored locally using Hive database
- **Persistent Storage**: Chat history is preserved across app restarts

## Dependencies

- `flutter_chat_ui`: For the chat interface
- `speech_to_text`: For voice input functionality
- `flutter_tts`: For text-to-speech output
- `hive`: For local data storage
- `permission_handler`: For microphone permissions

## Project Structure

```
lib/
├── main.dart                 # App entry point
├── models/
│   ├── message_model.dart    # Message data model
│   └── message_model.g.dart  # Generated Hive adapter
├── screens/
│   └── chat_screen.dart      # Main chat interface
└── services/
    ├── storage_service.dart  # Hive database operations
    ├── speech_service.dart   # Speech-to-text functionality
    └── tts_service.dart      # Text-to-speech functionality
```

## Setup Instructions

1. **Install Flutter**: Make sure you have Flutter SDK installed
2. **Get Dependencies**: Run `flutter pub get`
3. **Generate Hive Adapters**: Run `flutter packages pub run build_runner build`
4. **Run the App**: Use `flutter run`

## Permissions

### Android
- `RECORD_AUDIO`: For voice input
- `INTERNET`: For speech recognition services
- `WRITE_EXTERNAL_STORAGE`: For local storage

### iOS
- `NSMicrophoneUsageDescription`: For microphone access
- `NSSpeechRecognitionUsageDescription`: For speech recognition

## Usage

1. **Text Input**: Type messages in the text field and press send
2. **Voice Input**: Tap the microphone button to start voice input
3. **Voice Output**: Bot responses are automatically read aloud
4. **Offline Storage**: All messages are automatically saved and restored

## Bot Responses

The app currently uses dummy responses. You can customize the bot logic in the `_getDummyResponse()` method in `chat_screen.dart`.

## Customization

- Modify the chat theme in `chat_screen.dart`
- Adjust TTS settings in `tts_service.dart`
- Change speech recognition parameters in `speech_service.dart`
- Update the message model in `message_model.dart` for additional fields

