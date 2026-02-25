# NexBrief

Flutter meeting summarizer for side projects.

## Features
- 4-screen app structure: `Home`, `Workspace`, `History`, `Settings`
- Paste/edit meeting transcript
- Generate structured summary locally (`key points`, `decisions`, `risks`, `next steps`)
- Extract action items locally (`title`, `owner`, `due`, `category`)
- Edit action items before export
- Save meeting history on-device
- Export Markdown (`.md`) and delete exported files from the app
- Confirmation dialogs for destructive actions (history delete, clear workspace)
- Read-only markdown preview (export is generated from current workspace data)

## Setup
```bash
flutter pub get
flutter run
```

## How To Use
1. Open `Workspace` and paste transcript in the `Transcript` section.
2. Tap `Generate Summary`.
3. Tap `Run Rule Extraction`.
4. Edit action items in `Action Items`.
5. Tap `Generate + Export Markdown`.
6. Open `History` to load/delete entries.
7. Use `Settings` for workspace reset.

## Scope
- Standalone side-project app
- No backend
- No API key required
- Local storage only
