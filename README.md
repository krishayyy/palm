# Palm

A macOS menu-bar background app that lets you type into any app system-wide using
hand-tracking (webcam) instead of a physical keyboard, plus on-device voice dictation.

## What it does

- Tracks up to two hands via the webcam using Apple's Vision framework
  (`VNDetectHumanHandPoseRequest`, ANE-accelerated, 21 landmarks per hand).
- A floating, click-through overlay shows a QWERTY keyboard and one pointer per
  hand, mapped to your index-finger tip position (mirrored, like looking in a mirror).
- Pinching your thumb and index finger together over a key "clicks" it — pinch
  detection uses hysteresis (a lower on-threshold, higher off-threshold) so
  landmark jitter near the boundary doesn't cause rapid flicker between states.
- Keystrokes are injected system-wide via `CGEvent` posted to `.cghidEventTap`,
  so they land in whatever app is currently frontmost, not just Palm's own window.
- Voice dictation transcribes speech on-device and types the result the same way.
- Everything is toggled from the menu-bar icon; no Dock icon, no main window.

## Voice backend: WhisperKit (not the SFSpeechRecognizer fallback)

WhisperKit (https://github.com/argmaxinc/WhisperKit, Apache 2.0) resolved and
built successfully in this environment, so it's what's actually wired in
(`Sources/Palm/VoiceDictation.swift`), using the `base.en` Core ML Whisper model
via `WhisperKit`'s `AudioStreamTranscriber` for real-time streaming transcription.
It's on-device and meaningfully more accurate than `SFSpeechRecognizer`,
especially on accents and technical vocabulary. The `SFSpeechRecognizer` fallback
was not needed.

Note: the first time voice dictation is turned on, WhisperKit downloads the
`base.en` model from Hugging Face and caches it locally — this needs network
access once, then works fully offline.

## Build

```
./Scripts/build_app.sh
open Palm.app
```

This runs `swift build -c release`, assembles `Palm.app` (Info.plist with
camera/microphone usage strings, `LSUIElement=true`, bundle id
`com.krishay.palm`), and ad-hoc codesigns it so it launches locally.

Palm.app is **not notarized** (that requires a paid Apple Developer account,
which isn't set up). On first launch, right-click `Palm.app` and choose
**Open** — a normal double-click will be blocked by Gatekeeper as "damaged"
or "from an unidentified developer" the first time.

## Permissions you'll need to grant

- **Camera** — for hand tracking (prompted automatically when you enable
  "Hand Keyboard" from the menu).
- **Microphone** — for voice dictation (prompted automatically when you enable
  "Voice Dictation").
- **Accessibility** — required for system-wide keystroke injection via
  `CGEvent`. Palm calls `AXIsProcessTrustedWithOptions` on launch, which
  prompts you to add Palm in **System Settings > Privacy & Security >
  Accessibility**. You must enable it there and may need to relaunch Palm
  once after granting it.

## Project layout

- `Sources/Palm/HandTracker.swift` — webcam capture + Vision hand-pose tracking, pinch detection.
- `Sources/Palm/InputInjector.swift` — CGEvent-based system-wide typing + Accessibility trust helpers.
- `Sources/Palm/OverlayWindow.swift` — the transparent, click-through, always-on-top overlay window.
- `Sources/Palm/KeyboardOverlayView.swift` — the on-screen QWERTY layout and key highlighting.
- `Sources/Palm/PointerView.swift` — per-hand pointer rendering (color/shape from Preferences).
- `Sources/Palm/VoiceDictation.swift` — WhisperKit streaming transcription.
- `Sources/Palm/AppDelegate.swift` — menu-bar item/menu, feature toggles, hand-to-key hit testing.
- `Sources/Palm/Preferences.swift` — UserDefaults-backed pointer/feature settings.
- `Scripts/build_app.sh` — release build + app bundle assembly + ad-hoc codesigning.
