import 'dart:async';
import 'dart:convert'; // For jsonDecode, jsonEncode
import 'dart:typed_data'; // For Uint8List

import 'package:flutter/material.dart';
import 'package:kolwrite_voice_agent_new/audio_handler.dart';
import 'package:kolwrite_voice_agent_new/gemini_api.dart';
import 'package:kolwrite_voice_agent_new/tools.dart' as tools; // aliased
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KolWrite Voice Agent',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey),
        useMaterial3: true,
      ),
      home: const VoiceAgentPage(),
    );
  }
}

class VoiceAgentPage extends StatefulWidget {
  const VoiceAgentPage({super.key});

  @override
  State<VoiceAgentPage> createState() => _VoiceAgentPageState();
}

enum MicStatus {
  idle,
  recording,
  processing,
  speaking, // Gemini is sending audio
}

class _VoiceAgentPageState extends State<VoiceAgentPage> {
  final String _apiKey = 'AIzaSyAYpEO4Av_3R0QMnMX-5IAd0OBDGWBdCDU'; // Hardcoded API Key

  late AudioHandler _audioHandler;
  late GeminiApi _geminiApi;

  MicStatus _micStatus = MicStatus.idle;
  String _statusText = "Initializing..."; // Changed initial status
  String _transcribedText = "";
  String _geminiResponseText = ""; // For text part of Gemini's response
  String _currentTurnId = ""; // To store turn_id from Gemini
  String _previousAudioId = ""; // To store previous_audio_id from Gemini

  StreamSubscription? _recordingSubscription;
  StreamSubscription? _geminiSetupSubscription;
  StreamSubscription? _geminiAudioSubscription;
  StreamSubscription? _geminiToolCallSubscription;
  StreamSubscription? _geminiInterruptedSubscription;
  StreamSubscription? _geminiTurnCompleteSubscription;
  StreamSubscription? _geminiErrorSubscription;
  StreamSubscription? _geminiCloseSubscription;
  StreamSubscription? _playbackCompleteSubscription;

  final List<Map<String,dynamic>> _geminiTools = [{
    "functionDeclarations": [{
      "name": "get_weather",
      "description": "Get current weather information for a city",
      "parameters": {
        "type": "OBJECT",
        "properties": {
          "city": {
            "type": "STRING",
            "description": "The name of the city to get weather for"
          }
        },
        "required": ["city"]
      }
    }, {
      "name": "get_stock_price",
      "description": "Get current stock price and related information for a given stock symbol",
      "parameters": {
        "type": "OBJECT",
        "properties": {
          "symbol": {
            "type": "STRING",
            "description": "The stock symbol to get price information for (e.g., AAPL, GOOGL)"
          }
        },
        "required": ["symbol"]
      }
    }]
  }];
  final String _systemInstruction = "You are a helpful voice assistant. When providing information, be concise and clear.";
  bool _isMicrophonePermissionGranted = false;


  @override
  void initState() {
    super.initState();
    _audioHandler = AudioHandler();
    _geminiApi = GeminiApi(); // API key is hardcoded in GeminiApi class

    _initializeAgent();
  }

  Future<void> _initializeAgent() async {
    await _audioHandler.init(); // Prepare recorder
    
    // Request microphone permission via AudioHandler
    bool granted = await _audioHandler.requestPermission();
    setState(() {
      _isMicrophonePermissionGranted = granted;
      if (!granted) {
        _statusText = "Microphone permission denied. Please enable it in app settings.";
      } else {
        _statusText = "Press the mic to start."; // Initial ready state
      }
    });

    if (!_isMicrophonePermissionGranted) {
      // Optionally, prevent further initialization if permission is critical from the start
      // For this app, Gemini API connection can still proceed.
    }

    // Connect to Gemini API
    // Note: API key is handled within GeminiApi class constructor
    await _geminiApi.connect(); 

    // Setup Gemini API listeners
    _geminiSetupSubscription = _geminiApi.onSetupComplete.listen((_) {
      if (_isMicrophonePermissionGranted) { // Only update if permission was granted
        setState(() {
          _statusText = "API Ready. Press mic to start.";
        });
      }
      print("Gemini API setup complete.");
    });

    _geminiAudioSubscription = _geminiApi.onAudioData.listen((audioData) {
      setState(() {
        _micStatus = MicStatus.speaking;
        _statusText = "Speaking...";
      });
      _audioHandler.playAudioChunk(audioData);
    });
    
    _playbackCompleteSubscription = _audioHandler.playbackCompleteStream.listen((_) {
        // If playback finishes and we are in speaking state, transition appropriately.
        // This might need coordination with onTurnComplete from Gemini.
        if (_micStatus == MicStatus.speaking) {
             // If turn is also complete, go to idle. Otherwise, Gemini might send more.
            // For now, let's assume if speaking stops, we await next instruction or turn completion.
            // setState(() {
            //    _statusText = "Finished speaking. Waiting for next action or turn completion.";
            // });
        }
    });

    _geminiToolCallSubscription = _geminiApi.onToolCall.listen((toolCall) async {
      final functionName = toolCall['name'];
      final args = toolCall['args'] as Map<String, dynamic>;
      final toolCallId = toolCall['tool_call_id'] as String; // Assuming API sends this

      setState(() {
        _statusText = "Executing function: $functionName with args: $args";
        _geminiResponseText += "\nTool Call: $functionName(${args.entries.map((e) => "${e.key}: ${e.value}").join(', ')})";
      });
      print("Tool call received: $functionName, Args: $args, ID: $toolCallId");

      Map<String, dynamic> result;
      try {
        result = await tools.dispatchToolCall(functionName, args);
         print("Tool call result: $result");
      } catch (e) {
        result = {'error': 'Failed to execute tool $functionName: $e'};
         print("Tool call error: $e");
      }
      
      _geminiApi.sendToolResponse(toolCallId, result);
      setState(() {
        _statusText = "Function $functionName executed. Result: ${jsonEncode(result)}";
         _geminiResponseText += "\nTool Result for $functionName: ${jsonEncode(result)}";
      });
    });

    _geminiInterruptedSubscription = _geminiApi.onInterrupted.listen((_) {
      setState(() {
        _statusText = "Interaction interrupted by API.";
        // Potentially stop recording/playback if active
        if (_audioHandler.isRecording) {
          _audioHandler.stopRecording();
        }
        if (_audioHandler.isPlaying) {
            _audioHandler.stopPlayback();
        }
        _micStatus = MicStatus.idle; // Or some other appropriate status
      });
       print("Gemini API interrupted.");
    });

    _geminiTurnCompleteSubscription = _geminiApi.onTurnComplete.listen((_) {
      setState(() {
        _statusText = "Turn complete. Press mic for new turn.";
        // _transcribedText = ""; // Clear previous turn's transcription
        _geminiResponseText = ""; // Clear previous turn's response
        _micStatus = MicStatus.idle;
      });
      print("Gemini API turn complete.");
      // Potentially get turn_id and previous_audio_id here if provided in the message
      // For now, these are not explicitly handled from the turnComplete message itself
    });

    _geminiErrorSubscription = _geminiApi.onError.listen((errorMessage) {
      setState(() {
        _statusText = "API Error: $errorMessage";
        _micStatus = MicStatus.idle; // Reset status on error
      });
      print("Gemini API error: $errorMessage");
    });

    _geminiCloseSubscription = _geminiApi.onClose.listen((_) {
      setState(() {
        _statusText = "API Connection closed. Please restart.";
        _micStatus = MicStatus.idle;
      });
      print("Gemini API connection closed.");
    });

    // Send initial setup message to Gemini
    // This should include system_instruction and tools if required by API
    _geminiApi.sendDefaultSetup(
        modelName: "gemini-1.5-flash-latest", // Or "gemini-1.5-pro-latest"
        tools: _geminiTools,
        // languageCode: 'en-US' // Default is en-US in GeminiApi
        // turnId: _currentTurnId, // For first setup, these are empty or null
        // previousAudioId: _previousAudioId,
    );
    // Add system instruction if your GeminiApi's sendDefaultSetup or a specific setup message supports it.
    // For now, assuming sendDefaultSetup can be extended or a new method in GeminiApi handles this.
    // The current GeminiApi.sendDefaultSetup does not have a system_instruction parameter.
    // This might need a custom setup message or modification of GeminiApi.
    // Let's assume for now this setup is sufficient or GeminiApi handles system instructions internally.
    // If a more specific setup message is needed:
    // _geminiApi.sendSetupMessage({
    //   'model_name': 'gemini-1.5-flash-latest',
    //   'tools': _geminiTools,
    //   'system_instruction': {'parts': [{'text': _systemInstruction}]}, // Example structure
    //    // ... other configs from sendDefaultSetup ...
    // });
    // The above is a guess. The actual structure for system_instruction needs to be based on API docs.
    // Project Pastra's JS uses a 'context' object for system instructions.
    // Let's assume GeminiApi's `sendDefaultSetup` is configured for general use for now.
    // Update: GeminiApi.sendDefaultSetup was updated to include tools, modelName. System instruction is not directly part of it.
    // For system instructions, it's often part of the initial messages in a turn or session config.
    // For now, we rely on the tools definition and model behavior.
  }

  // _requestMicPermission() is removed as its core logic is now in AudioHandler and called in _initializeAgent

  Future<void> _toggleRecording() async {
    if (!_isMicrophonePermissionGranted) {
      // This should ideally not be reached if button is properly disabled.
      // But as a safeguard, or if user clicks before UI updates:
      bool granted = await _audioHandler.requestPermission(); // Re-request
      setState(() {
        _isMicrophonePermissionGranted = granted;
        if (!granted) {
          _statusText = "Microphone permission is required to record.";
        } else {
          _statusText = "Permission granted. Press mic again."; // Guide to press again
        }
      });
      if (!granted) return;
      // If granted now, user needs to press button again, so we don't proceed to record immediately.
      return; 
    }

    // Check current app lifecycle state if needed, for now assuming foreground.
    // AppLifecycleState appLifecycleState = WidgetsBinding.instance.lifecycleState;

    if (_micStatus == MicStatus.recording) {
      // Stop recording
      await _audioHandler.stopRecording();
      _recordingSubscription?.cancel();
      _geminiApi.sendEndMessage(); // Signal end of user audio input
      setState(() {
        _micStatus = MicStatus.processing;
        _statusText = "Processing audio...";
      });
    } else if (_micStatus == MicStatus.idle || _micStatus == MicStatus.speaking /* allow interrupting Gemini */) {
      // Start recording
      if (_audioHandler.isPlaying) { // Stop Gemini's playback if it's speaking
          await _audioHandler.stopPlayback();
      }
      _transcribedText = ""; // Clear previous transcription
      _geminiResponseText = ""; // Clear previous Gemini response

      bool started = await _audioHandler.startRecording();
      if (started) {
        setState(() {
          _micStatus = MicStatus.recording;
          _statusText = "Listening...";
        });
        _recordingSubscription = _audioHandler.recordingStream.listen((audioChunk) {
          // Convert Uint8List to List<int> if GeminiApi expects that.
          // Assuming GeminiApi.sendAudioChunk takes List<int>.
          // flutter_sound's toStream provides Uint8List.
          _geminiApi.sendAudioChunk(List<int>.from(audioChunk));
        }, onError: (error) {
          print("Error in recording stream: $error");
          setState(() {
            _statusText = "Recording error: $error";
            _micStatus = MicStatus.idle;
          });
        }, onDone: () {
          // This onDone might be called if the stream closes unexpectedly.
          // Normal stop is handled by _toggleRecording's stop path.
           if (_micStatus == MicStatus.recording) {
             _geminiApi.sendEndMessage();
             setState(() {
               _micStatus = MicStatus.processing;
               _statusText = "Finished listening, now processing...";
             });
           }
        });
      } else {
        setState(() {
          _statusText = "Failed to start recording.";
        });
      }
    }
  }

  @override
  void dispose() {
    _recordingSubscription?.cancel();
    _geminiSetupSubscription?.cancel();
    _geminiAudioSubscription?.cancel();
    _geminiToolCallSubscription?.cancel();
    _geminiInterruptedSubscription?.cancel();
    _geminiTurnCompleteSubscription?.cancel();
    _geminiErrorSubscription?.cancel();
    _geminiCloseSubscription?.cancel();
    _playbackCompleteSubscription?.cancel();

    _audioHandler.dispose();
    _geminiApi.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // bool canRecord = (_micStatus == MicStatus.idle || _micStatus == MicStatus.speaking) && _isMicrophonePermissionGranted;
    // Simplified: button is active if permission granted AND status is idle/speaking. Or if it's currently recording (to allow stop).
    bool isCurrentlyRecording = _micStatus == MicStatus.recording;
    bool canInteract = _isMicrophonePermissionGranted && 
                       (_micStatus == MicStatus.idle || _micStatus == MicStatus.speaking || _micStatus == MicStatus.recording);


    return Scaffold(
      appBar: AppBar(
        title: const Text("KolWrite Voice Agent"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: <Widget>[
            Text(
              _statusText,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_transcribedText.isNotEmpty) ...[
                      Text("You said:", style: Theme.of(context).textTheme.titleSmall),
                      Text(_transcribedText, style: Theme.of(context).textTheme.bodyMedium),
                      const SizedBox(height: 10),
                    ],
                    if (_geminiResponseText.isNotEmpty) ...[
                       Text("Gemini:", style: Theme.of(context).textTheme.titleSmall),
                       Text(_geminiResponseText, style: Theme.of(context).textTheme.bodyMedium),
                       const SizedBox(height: 10),
                    ]
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Placeholder for Gemini's text responses if not part of _statusText
            // Text(_geminiResponseText, style: Theme.of(context).textTheme.bodyLarge),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton(
        onPressed: canInteract ? _toggleRecording : () async {
          // If button is pressed when it *should* be disabled (e.g. permission not granted)
          // re-check and request permission. This is a fallback.
          if (!_isMicrophonePermissionGranted) {
            bool granted = await _audioHandler.requestPermission();
            setState(() {
              _isMicrophonePermissionGranted = granted;
              if (granted) {
                _statusText = "Permission granted. Press mic to start.";
              } else {
                _statusText = "Permission denied. Please enable in settings.";
              }
            });
          }
        },
        tooltip: isCurrentlyRecording ? 'Stop Listening' : 'Start Listening',
        backgroundColor: isCurrentlyRecording ? Colors.redAccent : 
                         (canInteract && _micStatus != MicStatus.processing) ? Colors.blueAccent : Colors.grey,
        child: Icon(isCurrentlyRecording ? Icons.stop : Icons.mic, size: 36),
      ),
    );
  }
}
