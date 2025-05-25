# Jarvis Flutter Voice Assistant

## Description

This is a Flutter-based voice assistant application inspired by Jarvis. It uses the Google Gemini API for advanced AI interactions, including real-time audio streaming and function calling. The application is primarily designed for Android.

## Features Implemented

*   **Voice Interaction**: Real-time voice streaming to Google Gemini API using Opus audio codec.
*   **Hardcoded User Session**: Operates with a hardcoded user ID: `test_user_001`.
*   **Conversation History**:
    *   Displays the conversation log (user queries and assistant responses) in the UI.
    *   Stores conversation history in Google Firestore associated with the hardcoded user ID.
*   **Function Calling**:
    *   `get_calendar_events`: Displays a hardcoded list of calendar events for today.
    *   `send_message`: Simulates sending a text message to a specified recipient.
    *   `make_call`: Simulates initiating a phone call to a contact.
*   **Basic UI for Android**: Including a microphone button to start/stop recording and a conversation log view.
*   **Test Gemini Connection**: A dedicated button to test the WebSocket connection, setup message, and disconnection with the Gemini API.

## Setup Instructions

### Prerequisites

*   **Flutter SDK**: Ensure Flutter is installed and configured. (See [Flutter installation guide](https://docs.flutter.dev/get-started/install))
*   **IDE**: Android Studio (with Flutter plugin) or Visual Studio Code (with Flutter extension).
*   **Android Emulator or Device**: An Android emulator set up or a physical Android device connected for debugging.

### 1. Clone/Download Code

You should already have the project code. If not, clone or download it to your local machine.

### 2. Firebase Setup

1.  **Create a Firebase Project**:
    *   Go to the [Firebase Console](https://console.firebase.google.com/).
    *   Click on "Add project" and follow the steps to create a new project.

2.  **Add an Android App to Firebase**:
    *   In your Firebase project dashboard, click on the Android icon (or "Add app" then select Android).
    *   Follow the setup wizard:
        *   **Android package name**: `com.example.jarvis_flutter_app` (You can find this in `jarvis_flutter_app/android/app/build.gradle.kts` under `applicationId`).
        *   You can skip the "App nickname" and "Debug signing certificate SHA-1" for initial setup if you prefer.
    *   Download the `google-services.json` file.

3.  **Place `google-services.json`**:
    *   Move the downloaded `google-services.json` file into the `jarvis_flutter_app/android/app/` directory of your project.

4.  **Setup Firestore**:
    *   In the Firebase Console, navigate to "Firestore Database" (under Build).
    *   Click "Create database".
    *   Choose a mode (e.g., "Start in test mode" for initial development, or "Start in production mode" and then update security rules).
    *   Select a Firestore location.
    *   Click "Enable".

5.  **Deploy Firestore Security Rules**:
    *   Go to the "Rules" tab in the Firestore Database section.
    *   Replace the existing rules with the following:
      ```
      rules_version = '2';
      service cloud.firestore {
        match /databases/{database}/documents {
          match /users/{userId}/conversations/{conversationId} {
            // Allow read/write access only if the userId in the path
            // matches the hardcoded user ID "test_user_001".
            allow read, write: if userId == "test_user_001";
          }
        }
      }
      ```
    *   Click "Publish".

### 3. Gemini API Key

1.  **Obtain an API Key**:
    *   Go to [Google AI Studio](https://aistudio.google.com/app/apikey) (or your Google Cloud Console project where the Gemini API is enabled).
    *   Create an API key if you don't have one.
2.  **Update in Code**:
    *   Open the file: `jarvis_flutter_app/lib/services/gemini_service.dart`.
    *   Find the line:
      `String _apiKey = "AIzaSyAYpEO4Av_3R0QMnMX-5IAd0OBDGWBdCDU";`
    *   Replace `"AIzaSyAYpEO4Av_3R0QMnMX-5IAd0OBDGWBdCDU"` with your actual Gemini API key if you are using your own. The current key is a specific one provided for this context.
    *   **Important Security Note**: This method of embedding API keys directly in client-side code is **not secure for production applications**. For a real application, use environment variables, a secure backend proxy, or other secrets management solutions.

### 4. Get Dependencies

Open your terminal, navigate to the root directory of the `jarvis_flutter_app` project, and run:
```bash
flutter pub get
```

## Running the App

1.  **Ensure Device/Emulator**: Make sure you have an Android emulator running or a physical Android device connected and recognized by Flutter (`flutter devices`).
2.  **Run the App**: From the root `jarvis_flutter_app` directory, execute:
    ```bash
    flutter run
    ```
3.  **View Logs**: To see console output from the app, including print statements from services and UI interactions, you can use:
    ```bash
    flutter logs
    ```

## Using the App

*   **Main Interaction**: Tap the microphone button at the bottom center of the screen to start recording your voice query. Tap it again (it will show a stop icon) to stop recording. The app will then process your audio.
*   **Conversation Display**: Your spoken queries (transcribed text, if available from Gemini) and the assistant's text responses will appear in the main area of the screen.
*   **Test Gemini Connection**: Use the "Test Gemini Connection" button to perform a quick check of the WebSocket connection to the Gemini API. This will connect, send a setup message, wait for 5 seconds, and then disconnect. Console logs will provide details of this test.
*   **User ID**: All interactions, including Firestore logging, are currently associated with the hardcoded user ID: `test_user_001`.

This README provides a basic guide to setting up and running the Jarvis Flutter Voice Assistant.
