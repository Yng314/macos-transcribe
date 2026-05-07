# Architecture

## Module Responsibilities

- `run.py` runs local audio through configured transcription providers and prints results in the terminal.
- `providers/openai_provider.py` calls OpenAI transcription models.
- `providers/qwen_provider.py` calls Qwen ASR and normalizes local audio input for that API.
- `macos-app/Package.swift` defines the native macOS app package.
- `macos-app/Info.plist` defines the packaged app metadata, menu bar app mode, version, bundle id, and microphone usage string.
- `macos-app/Transcribe.entitlements` defines the hardened-runtime entitlements required by the distributed app, including microphone audio input.
- `macos-app/AppAssets/app-icon-source.png` stores the source image used for the packaged app icon.
- `macos-app/Sources/macos-app/AppMain.swift` starts the AppKit menu bar app.
- `macos-app/Sources/macos-app/AppDelegate.swift` owns app lifecycle, hotkey flow, and settings reload.
- `macos-app/Sources/macos-app/AppConfig.swift` loads and persists `OPENAI_API_KEY` and optional `OPENAI_BASE_URL`.
- `macos-app/Sources/macos-app/AppConfig.swift` loads and persists API settings plus the reusable transcription prompt used for personalization.
- `macos-app/Sources/macos-app/KeyMappingManager.swift` applies the `hidutil` Dictation-key remap on launch and clears it on app termination.
- `macos-app/Sources/macos-app/HotKeyManager.swift` registers and handles the global hotkey.
- `macos-app/Sources/macos-app/RecordingController.swift` manages microphone permission and temporary audio recording.
- `macos-app/Sources/macos-app/SoundEffectPlayer.swift` plays the built-in macOS start and stop recording sounds.
- `macos-app/Sources/macos-app/StatusBarController.swift` updates the menu bar item, fixed-width status menu, transcript copy action, and settings entry.
- `macos-app/Sources/macos-app/SettingsWindowController.swift` shows the native settings window with separate `Personalization` and `API` pages.
- `macos-app/Sources/macos-app/OnboardingWindowController.swift` shows the first-run setup guide for API config and required permissions.
- `macos-app/Sources/macos-app/TextInsertionService.swift` inserts the transcript into the focused UI element or falls back to pasteboard paste.
- `macos-app/Sources/macos-app/TranscriptionService.swift` uploads a completed audio file to `gpt-4o-mini-transcribe`, including the optional personalization prompt, and returns plain text.
- `scripts/map_dictation_key_to_f18.sh` remaps the physical Dictation key to `F18`.
- `scripts/clear_user_key_mappings.sh` clears the temporary key remap.
- `scripts/build_macos_app.sh` builds and packages the standalone `Transcribe.app` bundle.

## Module Relationships

- The physical Dictation key is remapped by `hidutil` to `F18` when the app launches.
- The macOS app listens for `F18` and toggles recording state.
- `SoundEffectPlayer` gives immediate audible feedback when recording starts and stops.
- `StatusBarController` stores the current state summary, transcript preview, and exposes a settings entry through the menu.
- `SettingsWindowController` writes API configuration into Application Support and notifies `AppDelegate` to rebuild the transcription client immediately.
- `OnboardingWindowController` checks readiness for API config, Microphone, and Accessibility and routes the user to the right action when one is missing.
- `RecordingController` writes a temporary local audio file on each completed recording.
- `TranscriptionService` sends the completed recording file to OpenAI and prints the returned transcript.
- `TextInsertionService` tries to replace the current selection in the focused input and falls back to a simulated paste with clipboard restoration.
- The Python runner remains separate and is used only for API experimentation and cost or quality checks.
- `scripts/build_macos_app.sh` wraps the release binary, resource bundle, `Info.plist`, generated `.icns`, and entitlement file into `macos-app/dist/Young Transcribe.app`.

## Key Design Decisions

- Use `hidutil` instead of trying to replace Apple Dictation through a nonexistent dedicated API.
- Apply and clear the remap from inside the app lifecycle so users do not need a separate startup script during normal use.
- Use a menu bar app instead of an input method because the workflow is simple toggle dictation, not full IME behavior.
- Use `F18` as the remap target because it is less likely to conflict with foreground apps than `F5`.
- Keep the macOS app native in Swift and AppKit to reduce system integration friction.
- Use a temporary-file recording flow first because it is simpler to debug than a streaming capture path.
- Move long-term app configuration into Application Support with a settings window, while still tolerating `.env` during local development.
- Keep transcription personalization as a reusable saved prompt instead of per-recording UI so domain-specific terms can improve accuracy without adding friction to the dictation flow.
- Prefer Accessibility insertion first so existing clipboard contents are not overwritten unless fallback is necessary.
- When fallback paste is necessary, restore the prior clipboard contents unless the user has already changed the clipboard again.
- Package as a pure menu bar app with `LSUIElement` so the Dock stays clean and the behavior matches the product intent.
- Treat first-run onboarding as part of the app, not README-only setup, because external users will not have terminal context.
- Sign the distributed app with hardened runtime plus `com.apple.security.device.audio-input` so microphone permission continues to work after Developer ID signing and notarization.
