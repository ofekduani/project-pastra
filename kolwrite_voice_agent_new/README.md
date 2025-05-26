# kolwrite_voice_agent_new

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Gemini API Integration Notes

### Additional Packages Needed
- `web_socket_channel`: For WebSocket communication with Gemini API
- `permission_handler`: For microphone permissions (already present)
- `just_audio`, `flutter_sound`: For audio playback/recording (already present)

### Error Handling & Reconnection
- All WebSocket errors and closures are logged to the console and streamed to listeners.
- The `GeminiApi` class automatically attempts to reconnect with a backoff delay if the connection is lost, unless disposed.
- Errors in message parsing or sending are logged and streamed via the `onError` stream.
- The API is designed to be robust to transient network issues and will re-establish the connection as needed.
