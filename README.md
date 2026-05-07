# Transcribe

This repo is building a lightweight macOS dictation replacement.
The goal is to press the existing Dictation hardware key, record speech, send it to `gpt-4o-mini-transcribe`, and paste the text into the focused input.

## Project Overview

- `run.py` is the existing lightweight multi-provider transcription runner for local audio comparison.
- `macos-app/` is the new native macOS menu bar app that will replace Apple Dictation for this workflow.
- `speech_sample/` contains sample audio used for API testing.

## Technical Architecture

- Python is used for quick API comparison and provider experiments.
- Swift and AppKit are used for the menu bar app and system integration.
- `hidutil` remaps the physical Dictation key to a normal function key that the app can listen for.
- `AVAudioRecorder` is used for the first recording implementation and writes temporary `.m4a` files locally.
- The macOS app can now store `OPENAI_API_KEY` and optional `OPENAI_BASE_URL` inside its own settings window and persists them under Application Support.
- The settings window now separates `Personalization` from `API` and can store a reusable transcription hint prompt for domain terms and preferred spellings.
- Accessibility APIs are used to insert text into the focused app, with a clipboard plus `Command+V` fallback when direct insertion fails.
- When paste fallback is used, the app now restores the user's previous clipboard contents after the paste completes if the clipboard has not changed again.
- The app plays built-in macOS recording start and stop sounds for immediate user feedback.
- Runtime status is surfaced inside the menu bar app menu with a fixed-width layout, and the latest transcript can be copied directly from that menu.
- A first-run setup guide now checks API config, Microphone permission, and Accessibility permission and provides direct actions for each.
- A packaging script now builds a standalone `Young Transcribe.app` bundle with the supplied app icon, `Info.plist`, and microphone `audio-input` entitlement for hardened-runtime distribution.
- The packaged app now loads its menu bar icon from the main app bundle resources instead of relying on a SwiftPM development-path fallback.

## Local Run

Python transcription runner:

```bash
python3 run.py
```

macOS app build:

```bash
cd macos-app
swift build
```

macOS app run:

```bash
cd macos-app
swift run
```

Build standalone `.app`:

```bash
./scripts/build_macos_app.sh
```

Build signed `.app` with a specific identity:

```bash
SIGNING_IDENTITY="Developer ID Application: Your Name (TEAMID)" ./scripts/build_macos_app.sh
```

The signed standalone app now includes the `com.apple.security.device.audio-input` entitlement so microphone permission can work correctly under hardened runtime.

Package zip for sharing:

```bash
./scripts/package_macos_zip.sh
```

Build DMG for sharing:

```bash
./scripts/create_macos_dmg.sh
```

One-step release build:

```bash
SIGNING_IDENTITY="Developer ID Application: ..." NOTARY_KEYCHAIN_PROFILE="transcribe-notary" ./scripts/release_macos_app.sh
```

Notarize after signing:

```bash
NOTARY_KEYCHAIN_PROFILE="transcribe-notary" ./scripts/notarize_macos_app.sh
```

When the app starts recording for the first time, macOS should prompt for microphone access.
When the app inserts text for the first time, macOS may prompt for Accessibility permission.
When the app launches, it automatically remaps the physical Dictation key to `F18`.
When the app exits, it automatically restores the default key mapping.
If API settings are missing, use the menu bar icon and open `Settings…`.

## Deployment And Commands

- Standalone macOS app bundle output:

```bash
./scripts/build_macos_app.sh
open macos-app/dist/Transcribe.app
```

- Manual key remap helper, mainly as a fallback:

```bash
./scripts/map_dictation_key_to_f18.sh
```

## Testing

- Build the macOS app with `cd macos-app && swift build`.
- Run the macOS app with `cd macos-app && swift run`.
- Build the packaged app with `./scripts/build_macos_app.sh`.
- Build the signed packaged app with `SIGNING_IDENTITY="Developer ID Application: ..."` when preparing external distribution.
- Notarize with `NOTARY_KEYCHAIN_PROFILE="..." ./scripts/notarize_macos_app.sh`.
- Build a shareable DMG with `./scripts/create_macos_dmg.sh`.
- Use `./scripts/release_macos_app.sh` for the full signed + notarized release flow.
- Verify the Python transcription runner with `python3 run.py`.
- Verify the first-run setup guide flow from a clean launch.

## Search Record

- Apple Dictation cannot be replaced through a dedicated third-party API hook.
- `hidutil` supports hardware-level key remapping through `UserKeyMapping`.
- Spokenly documents a working Dictation-key remap flow using `hidutil`.
- The practical path is `Dictation key -> hidutil remap -> app hotkey listener`.

## Completed And Todo

Completed:
- Lightweight Python transcription comparison script for OpenAI and Qwen.
- Verified `gpt-4o-transcribe`, `gpt-4o-mini-transcribe`, and `qwen3-asr-flash` on the provided sample audio.
- Added a phase 1 native macOS app skeleton for Dictation-key replacement.
- Added a phase 2 recording state machine that toggles recording with `F18` and saves temporary audio files.
- Added a phase 3 direct OpenAI transcription path from the macOS app using `gpt-4o-mini-transcribe`.
- Added a phase 4 insertion path that tries Accessibility first and falls back to pasteboard plus `Command+V`.
- Added clipboard preservation and delayed restore for the paste fallback path.
- Added built-in macOS start and stop recording sounds.
- Replaced terminal-oriented logging with in-app menu state and recent-event history.
- Moved Dictation-key remap lifecycle into the app so launch applies the remap and termination restores defaults.
- Replaced the temporary menu bar text button with a branded icon and fixed-width menu layout.
- Added an in-app settings window for API key and base URL persistence.
- Added a `Personalization` settings page that stores a reusable transcription prompt and sends it to `gpt-4o-mini-transcribe` as `prompt`.
- Added a standalone `Transcribe.app` packaging script and app icon source.
- Added a first-run setup guide for configuration, Microphone permission, and Accessibility permission.
- Added scripts for signed packaging, notarization, and shareable zip output.
- Added the microphone `audio-input` entitlement to the signed app bundle so hardened-runtime builds can request microphone access correctly.

Todo:
- Verify the Dictation-key remap and `F18` listener on the local machine.
- Verify focused-input insertion behavior across common macOS apps.
- Add launch-at-login support.
- Re-verify microphone permission flow on the signed `.app` and notarized DMG after adding the audio-input entitlement.
