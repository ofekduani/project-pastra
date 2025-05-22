import 'dart:convert';
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'package:kolwrite_voice_agent/gemini_websocket_manager.dart';

class _MockWebSocketSink extends Mock implements WebSocketSink {}

class _MockWebSocketChannel extends Mock implements WebSocketChannel {}

void main() {
  group('GeminiWebSocketManager', () {
    late _MockWebSocketChannel mockChannel;
    late _MockWebSocketSink mockSink;
    late GeminiWebSocketManager manager;

    setUp(() {
      mockChannel = _MockWebSocketChannel();
      mockSink = _MockWebSocketSink();
      // Stub the sink getter to return our mockSink.
      when(() => mockChannel.sink).thenReturn(mockSink);

      manager = GeminiWebSocketManager(channel: mockChannel);
    });

    test('sends setup message on connect', () async {
      await manager.connect();

      final expectedMessage = jsonEncode({
        'setup': {
          'model': 'models/gemini-2.0-flash-exp',
        },
      });

      verify(() => mockSink.add(expectedMessage)).called(1);
    });

    test('emits SetupCompleteMessage when {"setupComplete": true} is received', () async {
      // Arrange: create a StreamController to simulate incoming messages.
      final controller = StreamController<dynamic>();
      when(() => mockChannel.stream).thenAnswer((_) => controller.stream);
      manager = GeminiWebSocketManager(channel: mockChannel);

      // Act & Assert: listen for the message, then add and close.
      final future = expectLater(
        manager.messages,
        emits(isA<SetupCompleteMessage>()),
      );
      controller.add('{"setupComplete": true}');
      await controller.close();
      await future;
    });
  });
} 