# Dictation Replacement Plan

## Phase 1
- Disable macOS Dictation in System Settings.
- Remap the physical Dictation key to `F18` with `hidutil`.
- Build a minimal macOS menu bar app that listens for `F18`.
- Verify that pressing the physical Dictation key no longer opens Apple Dictation and instead toggles our app state.

## Phase 2
- Add a simple recording state machine to the menu bar app.
- First press starts recording.
- Second press stops recording.
- Show clear menu bar status for idle and recording states.

## Phase 3
- Upload the recorded audio to `gpt-4o-mini-transcribe`.
- Handle network errors, empty transcripts, and timeout cases.
- Print and persist the returned transcript locally for debugging.

## Phase 4
- Insert the transcript into the currently focused text input via Accessibility APIs.
- Fall back to clipboard plus simulated `Command+V` when direct insertion fails.
- Exclude sensitive fields such as password inputs.

## Immediate Execution Order
1. Finish the phase 1 app skeleton and hotkey listener.
2. Add the Dictation-key remap helper and persistence instructions.
3. Build and verify the phase 1 app locally.
4. Move on to recording only after the key-remap path is stable.
