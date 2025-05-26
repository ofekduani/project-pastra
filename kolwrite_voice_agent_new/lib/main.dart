import 'dart:async';
import 'dart:convert'; // For jsonDecode, jsonEncode
import 'dart:typed_data'; // For Uint8List
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:kolwrite_voice_agent_new/audio_handler.dart';
import 'package:kolwrite_voice_agent_new/gemini_api.dart';
import 'package:kolwrite_voice_agent_new/tools.dart' as tools; // aliased
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';

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

  // Add test mode flag
  bool _testMode = true; // Set to true to test audio without WebSocket

  MicStatus _micStatus = MicStatus.idle;
  String _statusText = "Initializing..."; // Changed initial status
  String _transcribedText = "";
  String _geminiResponseText = ""; // For text part of Gemini's response
  final String _currentTurnId = ""; // To store turn_id from Gemini
  final String _previousAudioId = ""; // To store previous_audio_id from Gemini

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

  final List<int> _pcmBuffer = []; // Buffer to collect PCM data
  List<FileSystemEntity> _savedRecordings = []; // List of saved recordings

  @override
  void initState() {
    super.initState();
    _audioHandler = AudioHandler();
    _geminiApi = GeminiApi(); // API key is hardcoded in GeminiApi class

    _initializeAgent();
    _loadSavedRecordings(); // Load saved recordings on init
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
        _statusText = _testMode ? "TEST MODE: Press mic to record" : "Press the mic to start."; // Initial ready state
      }
    });

    if (!_isMicrophonePermissionGranted) {
      // Optionally, prevent further initialization if permission is critical from the start
      // For this app, Gemini API connection can still proceed.
    }

    // Listen for errors before connecting
    bool connectionFailed = false;
    _geminiErrorSubscription = _geminiApi.onError.listen((errorMessage) {
      connectionFailed = true;
      setState(() {
        _statusText = "API Error: $errorMessage";
        _micStatus = MicStatus.idle;
      });
      print("Gemini API error: $errorMessage");
    });

    await _geminiApi.connect();

    if (!connectionFailed) {
      _geminiApi.sendDefaultSetup(
        modelName: "gemini-1.5-flash-latest",
        tools: _geminiTools,
      );
    } else {
      print("Not sending setup because connection failed.");
    }

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
      // Convert base64 string to Uint8List
      final decodedAudio = base64.decode(audioData);
      _audioHandler.playAudioChunk(decodedAudio);
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

    _geminiCloseSubscription = _geminiApi.onClose.listen((_) {
      setState(() {
        _statusText = "API Connection closed. Please restart.";
        _micStatus = MicStatus.idle;
      });
      print("Gemini API connection closed.");
    });
  }

  Future<void> _loadSavedRecordings() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final recordingsDir = Directory('${directory.path}/recordings');
      if (await recordingsDir.exists()) {
        final files = recordingsDir.listSync()
            .where((file) => file.path.endsWith('.wav'))
            .toList()
          ..sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified)); // Sort by newest first
        setState(() {
          _savedRecordings = files;
        });
      }
    } catch (e) {
      print('Error loading saved recordings: $e');
    }
  }

  Future<void> _playRecording(String filePath) async {
    try {
      setState(() {
        _micStatus = MicStatus.speaking;
        _statusText = "Playing saved recording...";
      });
      
      final file = File(filePath);
      final wavData = await file.readAsBytes();
      
      // Extract just the PCM data from WAV (skip 44-byte header)
      final pcmData = wavData.sublist(44);
      
      await _audioHandler.playAudioChunk(pcmData);
    } catch (e) {
      setState(() {
        _statusText = "Error playing recording: $e";
        _micStatus = MicStatus.idle;
      });
    }
  }

  void _showRecordingsList() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          height: 400,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Saved Recordings',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: () {
                      _loadSavedRecordings();
                      Navigator.pop(context);
                      _showRecordingsList();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _savedRecordings.isEmpty
                    ? const Center(child: Text('No recordings saved yet'))
                    : ListView.builder(
                        itemCount: _savedRecordings.length,
                        itemBuilder: (context, index) {
                          final file = _savedRecordings[index];
                          final fileName = file.path.split('/').last;
                          final timestamp = file.statSync().modified;
                          final size = file.statSync().size;
                          
                          return ListTile(
                            leading: const Icon(Icons.audio_file),
                            title: Text(fileName),
                            subtitle: Text(
                              '${timestamp.toString().split('.').first} • ${(size / 1024).toStringAsFixed(1)} KB',
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.play_arrow),
                                  onPressed: () {
                                    Navigator.pop(context);
                                    _playRecording(file.path);
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete),
                                  onPressed: () async {
                                    await file.delete();
                                    _loadSavedRecordings();
                                    Navigator.pop(context);
                                    _showRecordingsList();
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
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
      
      if (!_testMode) {
        _geminiApi.sendEndMessage(); // Signal end of user audio input
      }
      
      setState(() {
        _micStatus = _testMode ? MicStatus.idle : MicStatus.processing;
        _statusText = _testMode ? "TEST MODE: Playing back recording..." : "Processing audio...";
      });
      
      // --- Auto-save recording ---
      if (_pcmBuffer.isNotEmpty) {
        final wavData = _audioHandler.pcm16ToWav(Uint8List.fromList(_pcmBuffer));
        final filePath = await _audioHandler.saveRecording(wavData);
        print('Recording saved to: $filePath');
        
        // In test mode, play back the recording
        if (_testMode) {
          setState(() {
            _micStatus = MicStatus.speaking;
            // PCM16 at 16kHz mono = 2 bytes per sample, 16000 samples per second
            final durationSeconds = _pcmBuffer.length / (16000 * 2);
            _transcribedText = "Recorded ${durationSeconds.toStringAsFixed(1)} seconds of audio (${_pcmBuffer.length} bytes)";
            _geminiResponseText = "Saved to: $filePath";
          });
          print('Playing back ${_pcmBuffer.length} bytes of PCM audio');
          await _audioHandler.playAudioChunk(Uint8List.fromList(_pcmBuffer));
          await _loadSavedRecordings(); // Refresh the recordings list
        }
      }
      _pcmBuffer.clear();
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
          _statusText = _testMode ? "TEST MODE: Recording..." : "Listening...";
        });
        _pcmBuffer.clear();
        _recordingSubscription = _audioHandler.recordingStream.listen((audioChunk) {
          _pcmBuffer.addAll(audioChunk);
          if (!_testMode) {
            _geminiApi.sendAudioChunk(List<int>.from(audioChunk));
          }
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
             if (!_testMode) {
               _geminiApi.sendEndMessage();
             }
             setState(() {
               _micStatus = _testMode ? MicStatus.idle : MicStatus.processing;
               _statusText = _testMode ? "TEST MODE: Recording stopped" : "Finished listening, now processing...";
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
    if (!_testMode) {
      _geminiApi.dispose();
    }
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
        title: Text(_testMode ? "KolWrite Voice Agent (TEST MODE)" : "KolWrite Voice Agent"),
        actions: [
          // Add a button to show saved recordings
          IconButton(
            icon: const Icon(Icons.folder_open),
            onPressed: _showRecordingsList,
            tooltip: 'Saved Recordings',
          ),
          // Add a switch to toggle test mode
          Switch(
            value: _testMode,
            onChanged: (value) {
              setState(() {
                _testMode = value;
                _statusText = _testMode ? "TEST MODE: Press mic to record" : "Restart app to connect to API";
              });
            },
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(
              child: Text(_testMode ? "Test" : "Live"),
            ),
          ),
        ],
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
