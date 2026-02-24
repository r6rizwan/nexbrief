# Meeting Summarizer Flutter

Flutter app for:
- Recording meeting audio
- Transcribing audio with OpenAI (`gpt-4o-transcribe`)
- Extracting action items (`title`, `owner`, `due`, `category`) using AI or rule-based fallback
- Exporting result to Markdown (`.md`) in app documents folder

## Setup
```bash
cd "/Users/rizwan/Documents/New project/meeting_summarizer_flutter"
flutter pub get
flutter run
```

## How to use
1. Enter OpenAI API key.
2. Tap `Start Recording`, then `Stop Recording`.
3. Tap `Transcribe (OpenAI)`.
4. Tap `Extract with AI` (or `Extract Rule-Based`).
5. Tap `Generate + Export Markdown`.

## Permissions
- Android microphone permission is already added in:
  - `android/app/src/main/AndroidManifest.xml`
- iOS microphone usage description is already added in:
  - `ios/Runner/Info.plist`

## Important note
API key is currently entered in-app for MVP speed. For production, move OpenAI calls to your backend and never expose raw API keys on client devices.
