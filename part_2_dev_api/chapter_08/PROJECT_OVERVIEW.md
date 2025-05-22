# Project Pastra Overview

Project Pastra is a mobile-first, multimodal AI assistant web application inspired by Google DeepMind's Project Astra. It allows users to interact with an AI assistant using real-time audio, video, and text. Key capabilities include leveraging the Gemini API for advanced AI interactions, function calling for real-world tasks (like checking weather or stock prices), and a responsive user interface optimized for both mobile and desktop browsers. The application is containerized using Docker and deployed on Google Cloud Run, ensuring scalability and accessibility.

## Key Component Roles and Interactions

This section details the roles and interactions of the core HTML and JavaScript components that make up the Project Pastra frontend.

*   **`index.html`**:
    *   **Role**: Serves as the main entry point and user interface (UI) for the application. It defines the layout with buttons for microphone, webcam, screen sharing, mute, and camera switching, a video preview area, and a display area for function call statuses.
    *   **Interactions**:
        *   Initializes and orchestrates other JavaScript modules.
        *   Handles user UI interactions (e.g., button clicks) to trigger functionalities like starting/stopping recording, toggling media sources.
        *   Loads system instructions from `system-instructions.txt` to configure the Gemini API.
        *   Receives media streams and frame data from `MediaHandler` to display video and send frames to `GeminiLiveAPI`.
        *   Receives audio data from `AudioRecorder` (via events) and sends it to `GeminiLiveAPI`.
        *   Receives audio responses from `GeminiLiveAPI` and passes them to `AudioStreamer` for playback.
        *   Manages the overall state of the application (e.g., `isRecording`, `isMuted`).
        *   Uses `StatusHandler` to display updates about function calls.

*   **`shared/gemini-live-api.js` (`GeminiLiveAPI` class)**:
    *   **Role**: Manages all WebSocket communication with the backend Gemini API.
    *   **Interactions**:
        *   Establishes and maintains the WebSocket connection.
        *   Sends initial setup messages (including model configuration, system instructions, and tool declarations) to the Gemini API.
        *   Transmits real-time media data:
            *   Audio chunks (base64 encoded PCM16) received from `AudioRecorder` (via `index.html`).
            *   Video frames (base64 encoded JPEG) received from `MediaHandler` (via `index.html`).
        *   Sends client content messages, including `turn_complete: true` when the user stops speaking or `turn_complete: false` for continuous streaming.
        *   Sends responses to tool calls initiated by the Gemini API.
        *   Receives messages from the Gemini API:
            *   `setupComplete`: Indicates the API is ready.
            *   `toolCall`: Contains function call requests (e.g., `get_weather`, `get_stock_price`).
            *   `serverContent`: Contains audio data from the model's response, interruption signals, and turn completion status.
        *   Uses an event-based system (e.g., `onSetupComplete`, `onAudioData`, `onToolCall`, `onInterrupted`, `onTurnComplete`, `onError`, `onClose`) to communicate API events back to `index.html`.

*   **`shared/audio-recorder.js` (`AudioRecorder` class)**:
    *   **Role**: Handles capturing, processing, and encoding audio from the user's microphone.
    *   **Interactions**:
        *   Uses `navigator.mediaDevices.getUserMedia` to request microphone access and obtain an audio stream.
        *   Initializes an `AudioContext` and an `AudioWorklet` (`audio-recording-worklet.js`, not detailed here but crucial for its operation) for audio processing. The worklet converts raw audio to PCM16 format.
        *   Emits `data` events containing base64-encoded PCM16 audio chunks. These events are listened to by `index.html`, which then forwards the data to `GeminiLiveAPI`.
        *   Provides `start()`, `stop()`, `mute()`, and `unmute()` methods to control the recording process, called from `index.html`.

*   **`shared/audio-streamer.js` (`AudioStreamer` class)**:
    *   **Role**: Manages the playback of audio data received from the Gemini API.
    *   **Interactions**:
        *   Receives base64-encoded PCM16 audio data from `index.html` (which gets it from `GeminiLiveAPI`).
        *   Converts the base64 data to `Float32Array` and then into `AudioBuffer` objects compatible with the Web Audio API.
        *   Queues and plays these `AudioBuffer`s sequentially using an `AudioContext` and `BufferSourceNode` to ensure smooth and continuous audio output.
        *   Handles audio context state (e.g., resuming if suspended) and manages playback status (`isPlaying`).
        *   Provides `addPCM16()`, `stop()`, `resume()`, and `complete()` methods for `index.html` to manage the audio playback lifecycle.
        *   Fires an `onComplete` callback (set by `index.html`) when the audio queue is empty and playback has finished.

*   **`shared/media-handler.js` (`MediaHandler` class)**:
    *   **Role**: Manages video input from the user's webcam or screen sharing.
    *   **Interactions**:
        *   Uses `navigator.mediaDevices.getUserMedia` (for webcam) or `navigator.mediaDevices.getDisplayMedia` (for screen sharing) to obtain video streams.
        *   Displays the active video stream in the `videoPreview` HTML element provided during initialization by `index.html`.
        *   Provides `startWebcam()`, `startScreenShare()`, `switchCamera()`, and `stopAll()` methods for `index.html` to control video input.
        *   Implements `startFrameCapture(onFrame)` which, when called by `index.html`, periodically captures frames from the current video stream, converts them to base64 encoded JPEG images, and passes them to the `onFrame` callback. This callback in `index.html` then sends the image data to `GeminiLiveAPI`.
        *   Manages the state of active media sources (`isWebcamActive`, `isScreenActive`) and camera facing mode (`usingFrontCamera`).

*   **`status-handler.js` (`StatusHandler` class, exported as `statusHandler` instance)**:
    *   **Role**: Displays status messages and results of function calls in a designated UI element (`functionInfo` div).
    *   **Interactions**:
        *   Initialized by `index.html`.
        *   Provides an `update(functionName, params)` method that `index.html` calls when a tool call is initiated or when results are received from `GeminiLiveAPI`.
        *   Formats and displays information about the function being called (e.g., `get_weather` with city) and the data returned (e.g., temperature, stock price).
        *   Updates the `textContent` of the `functionInfo` DOM element.

## Gemini API Communication Flow

This section outlines the sequence of messages exchanged between the Project Pastra frontend (client) and the Gemini API (server) via WebSocket for various interaction scenarios.

### 1. Connection & Setup

1.  **Client (index.html & gemini-live-api.js)**: A WebSocket connection is established to the Gemini API endpoint (`wss://generativelanguage.googleapis.com/ws/...`).
2.  **Client (gemini-live-api.js)**:
    *   Once the WebSocket connection is open (`onopen` event), `gemini-live-api.js` sends a setup message.
    *   This message is constructed in `index.html` (function `sendCustomSetup`) and includes:
        *   The model to use (e.g., "models/gemini-2.0-flash-exp").
        *   `system_instruction`: Loaded from `system-instructions.txt`, providing context to the AI.
        *   `tools`: Declarations for available functions (`get_weather`, `get_stock_price`), code execution, and Google Search.
        *   `generation_config`: Specifies response modalities (e.g., "audio") and speech configuration (e.g., voice name "Puck").
    *   The message structure is like: `{"setup": {...}}`.
3.  **Server (Gemini API)**:
    *   Processes the setup message.
    *   If successful, sends a `{"setupComplete": true}` message back to the client.
4.  **Client (gemini-live-api.js & index.html)**:
    *   The `onSetupComplete` handler in `gemini-live-api.js` is triggered.
    *   This, in turn, enables UI elements in `index.html` (like the microphone button).

### 2. Sending Audio/Video (User Input)

*   **Audio Input (Microphone)**:
    1.  **Client (index.html)**: When the user starts recording (clicks mic button):
        *   `AudioRecorder` is started.
    2.  **Client (audio-recorder.js)**:
        *   Captures audio, processes it into PCM16 format (via `AudioWorklet`).
        *   Emits `data` events with base64-encoded audio chunks.
    3.  **Client (index.html)**:
        *   Receives audio data from `AudioRecorder`.
        *   Calls `geminiAPI.sendAudioChunk(base64Data)`.
    4.  **Client (gemini-live-api.js)**:
        *   Wraps the audio data in a message: `{"realtime_input": {"media_chunks": [{"mime_type": "audio/pcm", "data": base64Audio}]}}`.
        *   Sends this message via WebSocket.
*   **Video Input (Webcam/Screen Share)**:
    1.  **Client (index.html)**: When the user starts webcam/screen share:
        *   `MediaHandler` is started.
        *   `mediaHandler.startFrameCapture()` is called with a callback.
    2.  **Client (media-handler.js)**:
        *   Captures video frames periodically (e.g., 2fps).
        *   Encodes each frame as a base64 JPEG image.
        *   Invokes the callback provided by `index.html` with the image data.
    3.  **Client (index.html)**:
        *   The callback receives the base64 image.
        *   Constructs a message: `{"realtimeInput": {"mediaChunks": [{"mime_type": "image/jpeg", "data": base64Image}]}}`.
        *   Sends this message via `geminiAPI.ws.send()`.

### 3. Receiving Responses (AI Output)

1.  **Server (Gemini API)**: Sends messages containing AI responses. These can be:
    *   Audio data (if requested in `generation_config`).
    *   Text data (though the current focus is audio).
    *   Signals like interruption or turn completion.
2.  **Client (gemini-live-api.js)**:
    *   The `onmessage` handler processes incoming WebSocket messages.
    *   If the message contains `serverContent.modelTurn.parts[0].inlineData.data` (audio):
        *   It extracts the base64 audio data.
        *   Calls `this.onAudioData(audioData)`.
        *   If `serverContent.turnComplete` is `false`, it sends a "continue" signal: `{"client_content": {"turns": [{"role": "user", "parts": []}], "turn_complete": false}}` to indicate readiness for more audio.
    *   If `serverContent.interrupted` is true:
        *   Calls `this.onInterrupted()`.
    *   If `serverContent.turnComplete` is true:
        *   Calls `this.onTurnComplete()`.
3.  **Client (index.html)**:
    *   `geminiAPI.onAudioData`: Receives audio data, passes it to `AudioStreamer` to be played.
    *   `geminiAPI.onInterrupted`: Stops `AudioStreamer` playback.
    *   `geminiAPI.onTurnComplete`: Allows `AudioStreamer` to finish playing its current queue.

### 4. Handling Tool Calls

1.  **Server (Gemini API)**: If the AI decides to use a declared tool (e.g., `get_weather`), it sends a `{"toolCall": {...}}` message. This message includes:
    *   `functionCalls`: An array of functions to call, each with an `id`, `name` (e.g., "get_weather"), and `args` (e.g., `{"city": "London"}`).
2.  **Client (gemini-live-api.js)**:
    *   The `onmessage` handler detects `wsResponse.toolCall`.
    *   Calls `this.onToolCall(wsResponse.toolCall)`.
3.  **Client (index.html)**:
    *   `geminiAPI.onToolCall`:
        *   Iterates through `functionCalls`.
        *   For each call:
            *   Updates UI via `statusHandler` (e.g., "Requesting weather for London...").
            *   Executes the corresponding local JavaScript function (e.g., `getWeather(call.args.city)` from `weather-api.js`).
            *   Awaits the result from the local function.
            *   Updates UI via `statusHandler` with the result.
            *   Constructs a response object for this function call, including its `id`, `name`, and the `result` (as `object_value`).
        *   Collects all function responses.
        *   Calls `geminiAPI.sendToolResponse(functionResponses)`.
4.  **Client (gemini-live-api.js)**:
    *   `sendToolResponse(functionResponses)`:
        *   Wraps the responses in a message: `{"tool_response": {"function_responses": [...]}}`.
        *   Sends this message via WebSocket.
5.  **Server (Gemini API)**: Receives the tool response and continues processing, potentially generating further audio/text output based on the tool's result.

### 5. Ending Interaction

*   **User-Initiated Stop**:
    1.  **Client (index.html)**: User clicks the stop button (previously mic button).
        *   `stopRecording()` is called.
        *   `audioRecorder.stop()` is called.
        *   `mediaHandler.stopAll()` is called (stops webcam/screen share).
        *   `geminiAPI.sendEndMessage()` is called.
    2.  **Client (gemini-live-api.js)**:
        *   `sendEndMessage()`: Sends `{"client_content": {"turns": [{"role": "user", "parts": []}], "turn_complete": true}}`. This signals to the API that the user has finished their turn.
*   **API-Initiated Turn Completion**:
    1.  **Server (Gemini API)**: Can send a message with `serverContent.turnComplete: true` if it determines the conversation turn is over from its side.
    2.  **Client (gemini-live-api.js)**: `onTurnComplete` callback is triggered.
    3.  **Client (index.html)**: `geminiAPI.onTurnComplete` handler allows `AudioStreamer` to finish playing any queued audio. The recording might still be active if not explicitly stopped by the user.

*   **WebSocket Closure**:
    *   The connection can be closed by either client or server.
    *   **Client (gemini-live-api.js)**: `ws.onclose` handler is triggered, which calls `this.onClose(event)`.
    *   **Client (index.html)**: `geminiAPI.onClose` handler logs the closure event. If recording was active, `index.html` might attempt to re-initialize the Gemini API and send the setup message again upon the next recording attempt.

## UI Elements and User Interaction Flow

This section describes the main user interface (UI) components of Project Pastra and the typical flow of user interactions with the application.

### Main UI Components

The user interface is primarily composed of:

*   **Title:** "Project Pastra 🍝" displayed at the top.
*   **Control Buttons:** A row of icon-based buttons allows users to manage media input:
    *   **Microphone Button (`micButton`):** A toggle button (Play/Stop icons) to start and stop audio recording. It's disabled until the connection to the Gemini API is established.
    *   **Mute Button (`muteButton`):** A toggle button (Mic/Mic Off icons) to mute and unmute the microphone while recording. Disabled when not recording.
    *   **Webcam Button (`webcamButton`):** A toggle button (Videocam/Videocam Off icons) to start and stop sharing video from the user's webcam.
    *   **Switch Camera Button (`switchCameraButton`):** (Primarily for mobile devices) An icon button (Flip Camera) to switch between front and rear-facing cameras. Only visible when the webcam is active on compatible devices.
    *   **Screen Share Button (`screenButton`):** (Primarily for desktop devices) An icon button (Present to All/Cancel Presentation icons) to start and stop screen sharing.
*   **Video Preview (`videoPreview`):** An HTML `<video>` element that displays the live feed from the webcam or the content of the shared screen. It is hidden when no video input is active.
*   **Function Information Display (`functionInfo`):** A text area used to display real-time status messages and results from tool calls (e.g., weather updates, stock prices). Initially, it shows "Waiting for function calls...".

### User Interaction Flow

A typical interaction with Project Pastra follows these steps:

1.  **Application Load:**
    *   The user opens the web application.
    *   The UI loads, with the Microphone button initially disabled.
    *   The system attempts to connect to the Gemini API. Once the setup is complete, the Microphone button is enabled.

2.  **Starting an Audio Conversation:**
    *   The user clicks the **Microphone Button** (Play icon) to begin.
    *   The button's icon changes to Stop, and the Mute button becomes active.
    *   The application starts recording audio from the user's microphone.
    *   The user speaks their query or command. This audio is streamed in real-time to the Gemini API.

3.  **Receiving AI Responses:**
    *   The Gemini API processes the input and streams an audio response back.
    *   The application plays this audio response directly to the user.
    *   If the AI invokes a tool (e.g., to get weather information), the **Function Information Display** updates to show the status of the tool call (e.g., "Requesting weather for London...") and then displays the results (e.g., "Weather in London: Sunny, 25°C").

4.  **Managing Media During Interaction:**
    *   **Muting/Unmuting:** While recording, the user can click the **Mute Button** to temporarily stop sending audio (icon changes to Mic Off). Clicking it again unmutes the microphone (icon changes back to Mic).
    *   **Enabling Webcam:** The user can click the **Webcam Button** (Videocam icon). The button's icon changes (Videocam Off), the `videoPreview` area shows the webcam feed, and video frames are sent to the API. On mobile, the **Switch Camera Button** may appear, allowing the user to toggle between front and rear cameras.
    *   **Enabling Screen Sharing:** The user can click the **Screen Share Button** (Present to All icon). After selecting a screen/window/tab in the browser prompt, the button's icon changes (Cancel Presentation), the `videoPreview` shows the shared content, and frames are sent to the API.
    *   **Disabling Video:** Clicking the active **Webcam Button** or **Screen Share Button** again will stop the respective video feed, hide the `videoPreview` (if no other video source is active), and stop sending video frames.

5.  **Ending the Interaction:**
    *   The user clicks the **Microphone Button** (Stop icon).
    *   Audio recording stops. Any active video sharing (webcam or screen) is also stopped.
    *   The button's icon reverts to Play, and the Mute button is disabled.
    *   A final message is sent to the Gemini API indicating the user has finished their turn.

The application is designed to be intuitive, with visual feedback provided through icon changes on buttons and status updates in the information display area.

## Configuration and Deployment

This section covers key aspects of Project Pastra's configuration, including system instructions, API key management, and the deployment process using Docker and Google Cloud Run.

### 1. System Instructions (`system-instructions.txt`)

*   **Role:** The `system-instructions.txt` file provides initial contextual information or directives to the Gemini AI model at the beginning of a session. This helps in guiding the AI's behavior, personality, or operational parameters.
*   **Usage:**
    *   The content of `system-instructions.txt` is fetched by `index.html` when the application loads.
    *   This text is then included in the initial setup message sent to the Gemini API via the WebSocket connection (specifically within the `setup.system_instruction.parts.text` field).

### 2. API Keys and Model Selection

*   **API Keys:**
    *   **Gemini API Key:** A `GEMINI_API_KEY` is required to authenticate with the Gemini API. In the provided `index.html`, this key is directly embedded in the WebSocket endpoint URL. For a production deployment, this key is typically managed as an environment variable (see Cloud Run deployment below).
    *   **Tool-Specific API Keys:**
        *   `OPENWEATHER_API_KEY`: For the `get_weather` function tool.
        *   `FINNHUB_API_KEY`: For the `get_stock_price` function tool.
        These keys are not directly used by the client-side code but are implicitly required by the backend services that these function calls would interact with, or if the Gemini model itself is configured to use these keys when executing the tool functions. The declaration in `index.html`'s `setupMessage` makes the AI aware of these tools.
*   **Model Selection:**
    *   The AI model is specified in `index.html` within the `sendCustomSetup` function. The current configuration uses `"models/gemini-2.0-flash-exp"`.

### 3. Docker Containerization (`Dockerfile`)

The application is containerized using Docker for consistent deployment. The provided `Dockerfile` sets up an Nginx server to serve the static frontend files:

*   **Base Image:** It uses `nginx:alpine`, a lightweight Nginx image.
*   **File Copying:** All application files (HTML, CSS, JavaScript, assets like `system-instructions.txt`) are copied from the build context into Nginx's web root directory (`/usr/share/nginx/html/`).
*   **Port Exposure:** The container exposes port `8080`, which is the standard port Cloud Run expects.
*   **Nginx Configuration:** A simple Nginx server block is configured to listen on port `8080` and serve `index.html` as the default file for the root location.

*(Note: The project's README.md also references a Docker configuration using a Node.js server (`server.js`). While the current `Dockerfile` uses Nginx for serving static files directly, a Node.js server like `server.js` would typically be used in a production environment for tasks such as securely handling API keys, server-side rendering, or proxying requests, rather than embedding API keys client-side or relying solely on client-side tool execution.)*

### 4. Google Cloud Run Deployment

Project Pastra is designed to be deployed on Google Cloud Run, a serverless platform. The deployment process generally involves these steps:

1.  **Build the Docker Image:**
    *   The Docker image is built using the `Dockerfile`. This can be done locally or using Google Cloud Build (`gcloud builds submit ...`).
    *   Example command (from README): `docker build --platform linux/amd64 -t gcr.io/PROJECT_ID/project-pastra-dev-api .` (The `--platform` flag is noted for Apple Silicon compatibility).
2.  **Push to Google Container Registry (GCR):**
    *   The built image is tagged and pushed to GCR.
    *   Example command: `docker push gcr.io/PROJECT_ID/project-pastra-dev-api`
3.  **Deploy to Cloud Run:**
    *   The application is deployed to Cloud Run using the `gcloud run deploy` command.
    *   Key parameters in the deployment command include:
        *   `--image`: Specifies the GCR path to the container image.
        *   `--platform managed`: Uses the fully managed Cloud Run environment.
        *   `--region`: Specifies the deployment region (e.g., `us-central1`).
        *   `--allow-unauthenticated`: Makes the service publicly accessible.
        *   `--set-env-vars`: **Crucially, this is where API keys (like `GEMINI_API_KEY`, `OPENWEATHER_API_KEY`, `FINNHUB_API_KEY`) should be securely passed to the application environment if a backend like `server.js` were handling them.** In the current Nginx setup, these client-side visible keys wouldn't be set this way, but this is standard practice for backend services.
    *   The application will then be available at a URL provided by Cloud Run.
    *   Redeployment is necessary for any code changes, API key updates, or configuration modifications.
