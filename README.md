# macos-transcribe

`macos-transcribe` is a lightweight replacement for Apple Dictation on macOS.
Press the Dictation key, speak, press again, and your transcript is inserted into the current input field.

Unlike a closed dictation service, this app lets you bring your own API key and optional base URL, so you can route transcription through the provider, gateway, or OpenAI-compatible endpoint that fits your cost, latency, and accuracy needs.

## Why This Product Exists

Apple Dictation is convenient, but it is also rigid.
If you want better recognition, custom routing, your own API account, or a workflow built around modern speech-to-text models, the default macOS experience does not give you much room.

`macos-transcribe` keeps the interaction model simple:

- Keep the familiar Dictation key workflow.
- Replace the transcription backend.
- Use your own endpoint and credentials.
- Stay in the app you are already typing in.

## What Makes It Different

- Lightweight by design: no benchmark dataset, no analytics dashboard, no heavyweight client.
- Native macOS workflow: menu bar app, not a browser wrapper.
- Bring your own API: configure your own API key and optional base URL in Settings.
- OpenAI-compatible routing: useful if you want to point the app at your own gateway or model provider.
- Better control: add reusable terminology hints for names, jargon, and preferred spellings.
- Practical fail-safes: retry the last recording if a transcription request fails.

## Core Experience

1. Launch the app from the menu bar.
2. Press the physical Dictation key once to start recording.
3. Press it again to stop.
4. The app sends the audio to your configured transcription endpoint.
5. The returned text is inserted into the currently focused input.

The app automatically remaps the Dictation key to `F18` on launch and restores the default mapping when the app exits.

## Product Capabilities

- Dictation-key replacement without building a full input method.
- Menu bar workflow with setup guidance and status feedback.
- API key and base URL configuration stored locally in the app.
- Personalization prompt for domain terms, names, and preferred spellings.
- Accessibility-first text insertion with paste fallback when needed.
- Clipboard restore after paste fallback, so the user’s clipboard is not left overwritten.
- Optional mute-while-recording mode to reduce speaker bleed into the microphone.
- Retry Last Recording action when the upstream transcription call fails.
- Signed and notarized macOS distribution flow for external sharing.

## Why Bring Your Own API Matters

This project is intentionally not tied to a single hosted backend.

That gives you flexibility to:

- choose the provider you trust,
- optimize for price or latency,
- route through your own proxy or API gateway,
- keep billing under your own account,
- experiment with different compatible backends without changing the Dictation UX.

Today, the macOS app is optimized around a `gpt-4o-mini-transcribe` style transcription request and can be pointed at compatible endpoints through the configured base URL.

## Install

Download the latest signed build from [Releases](https://github.com/Yng314/macos-transcribe/releases).

Then:

1. Open the DMG and move `Young Transcribe.app` into `/Applications`.
2. Launch the app.
3. Grant `Microphone` permission.
4. Grant `Accessibility` permission so the app can insert text into other apps.
5. Open `Settings...` from the menu bar icon.
6. Paste your API key.
7. Optionally set a custom base URL.

The current default base URL is:

```text
https://api.bltcy.ai/v1
```

## Personalization

The `Personalization` page lets you save a reusable prompt with:

- product names,
- technical terms,
- team names,
- preferred spellings,
- words the model often gets wrong.

This is useful when the model can hear the sound correctly but tends to choose the wrong written form.

## Privacy And Control

- Audio is recorded locally on your Mac.
- Audio is sent only after you stop recording.
- Requests go to the endpoint you configure.
- There is no bundled hosted transcription backend in this repo.

If you want stricter control, point the app at your own gateway or managed API layer.

## First-Run Experience

The built-in setup guide checks:

- API configuration
- Microphone permission
- Accessibility permission

This matters because the product is meant to be usable by non-developers, not only from `swift run`.

## Built For Real-World Dictation

This project focuses on the narrow workflow that matters:
replace the weak part of the default dictation stack without forcing users into a new editor, a browser tool, or a full speech platform.

If all you want is:

- a hotkey,
- a recording toggle,
- a stronger transcription model,
- and direct insertion into the current app,

that is exactly the shape of this product.

## For Developers

This repository also includes a lightweight Python runner for direct audio-to-text API experiments.

- `run.py` tests transcription providers against your own sample audio.
- `macos-app/` contains the native macOS menu bar application.
- `speech_sample/` contains sample audio assets for local testing.

### Local Development

Run the comparison script:

```bash
python3 run.py
```

Build the macOS app:

```bash
cd macos-app
swift build
```

Run the macOS app:

```bash
cd macos-app
swift run
```

Build a standalone app bundle:

```bash
./scripts/build_macos_app.sh
```

Build a signed and notarized release artifact:

```bash
SIGNING_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
NOTARY_KEYCHAIN_PROFILE="transcribe-notary" \
./scripts/release_macos_app.sh
```

## Technical Notes

- The Dictation key is remapped with `hidutil`.
- The app listens for `F18` after remapping.
- Recording is handled with native macOS audio APIs.
- Text insertion uses Accessibility APIs first, then a paste fallback when necessary.
- The packaged app includes the hardened-runtime microphone entitlement `com.apple.security.device.audio-input`.

## Status

Implemented today:

- native menu bar dictation replacement,
- packaged `.app` build,
- signed and notarized DMG release flow,
- API settings and personalization,
- retry-last-recording flow,
- onboarding for permissions and setup.

Planned next:

- launch at login,
- broader validation across more macOS target apps,
- more configurable provider and model routing where compatible.
