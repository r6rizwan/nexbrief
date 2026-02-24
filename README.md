# NexBrief

Flutter meeting summarizer for side projects.

## Features
- Paste/edit meeting transcript
- Generate structured summary locally (`key points`, `decisions`, `risks`, `next steps`)
- Extract action items locally (`title`, `owner`, `due`, `category`)
- Edit action items before export
- Save meeting history on-device
- Export Markdown (`.md`) and delete exported files from the app

## Setup
```bash
cd "/Users/rizwan/Documents/GitHub/nexbrief"
flutter pub get
flutter run
```

## How To Use
1. Paste transcript in the `Transcript` section.
2. Tap `Generate Summary`.
3. Tap `Run Rule Extraction`.
4. Edit action items in `Action Items`.
5. Tap `Generate + Export Markdown`.
6. Use `Meeting History` to load/delete entries.

## Scope
- Standalone side-project app
- No backend
- No API key required
- Local storage only
