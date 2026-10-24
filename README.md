# kyc_engine

A headless, camera-based face liveness verification engine for Flutter. Detects faces via Google ML Kit, runs configurable gesture challenges (smile, tilt head, open mouth), and optionally validates liveness with a TFLite anti-spoofing model — all through a single stream-based API.

## How it works

The engine runs a pipeline on each camera frame:

1. **Face detection** — ML Kit finds and analyzes the largest face (position, landmarks, classification)
2. **Anti-spoofing** *(optional)* — A TFLite model in a background isolate scores whether the face is live or a photo/screen replay
3. **Liveness session** — A state machine checks whether the detected gesture matches the current challenge step
4. **State emission** — A `KycLivenessState` snapshot is emitted on the stream with the current step, progress, feedback, and results

The flow: `initial` → `detectFace` → gesture challenges (e.g. `tiltLeft`, `smile`) → `done`.

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  kyc_engine:
    git:
      url: <your-repo-url>
```

### Android setup

Add camera permission to `android/app/src/main/AndroidManifest.xml`:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.CAMERA" />
    ...
</manifest>
```

### iOS setup

Add camera usage description to `ios/Runner/Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>Camera access is required for face liveness verification.</string>
```

If using `permission_handler` for runtime permission requests, add the preprocessor macro to your `ios/Podfile`:

```ruby
post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)

    target.build_configurations.each do |config|
      config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= [
        '$(inherited)',
        'PERMISSION_CAMERA=1',
      ]
    end
  end
end
```

## Important: Camera permissions are NOT handled by this SDK

`kyc_engine` does **not** request camera permissions. Your app must request and handle camera permissions before calling `engine.start()`. If permissions are not granted, `start()` will throw a `CameraException` with a descriptive message.

Use a package like [`permission_handler`](https://pub.dev/packages/permission_handler) in your app:

```dart
import 'package:permission_handler/permission_handler.dart';

final status = await Permission.camera.request();
if (!status.isGranted) {
  // Show error or redirect to settings
  return;
}

// Safe to start the engine now
await engine.start();
```

## Quick start

### Full liveness flow (SDK-managed camera)

```dart
import 'package:kyc_engine/kyc_engine.dart';

final engine = KycEngine(
  config: KycConfig(),
  onError: (error, stack) {
    // Optional: handle non-fatal frame processing errors
    print('KYC error: $error');
  },
);

// Request camera permissions first (see above), then:
await engine.start();

engine.stateStream.listen((state) {
  // Update your UI
  print('Step: ${state.currentStep}, Progress: ${state.progress}');

  if (state.isTimedOut) {
    // Current step exceeded its timeout
  }

  if (state.isComplete) {
    final selfie = state.capturedImage; // File? — captured during detectFace
  }
});

// Reset challenges without restarting camera:
await engine.reset();

// Clean up:
await engine.dispose();
```

### Bring-your-own camera

If you manage your own camera, pass the stream directly:

```dart
final engine = KycEngine(config: KycConfig());

await engine.startWithStream(
  myCameraImageStream,
  myCameraController,
  myCameraList,
);
```

### Standalone face detection (no liveness flow)

Use `KycFaceDetectionService` directly for face analysis without the challenge pipeline:

```dart
final detector = KycFaceDetectionService();
final config = KycConfig();

final result = await detector.processImage(inputImage, config);
print(result.isSmiling);      // true if smiling
print(result.turnedLeft);     // true if head turned left
print(result.isMouthOpen);    // true if mouth is open
print(result.feedback);       // KycFeedback.moveCloser, .faceNotCentered, etc.

await detector.dispose();
```

## Architecture

The SDK is organized in three layers. Each can be used independently:

| Layer | Class | Purpose |
|-------|-------|---------|
| **1 — Primitives** | `KycFaceDetectionService` | Face detection + gesture analysis |
| | `KycAntiSpoofingIsolateService` | TFLite anti-spoofing inference |
| **2 — Session** | `LivenessSession` | Challenge state machine |
| **3 — Engine** | `KycEngine` | Full orchestrator (camera + detection + session) |

Most apps should use `KycEngine` (Layer 3). Use the lower layers only if you need custom control over the pipeline.

## Configuration

All behavior is controlled through `KycConfig`. Every parameter has a sensible default — you only need to override what you want to change.

```dart
KycConfig(
  // Which gesture challenges to present (default: all four)
  challenges: [
    KycFaceRecognitionStage.tiltLeft,
    KycFaceRecognitionStage.tiltRight,
    KycFaceRecognitionStage.smile,
    KycFaceRecognitionStage.mouthOpen,
  ],

  // Randomize challenge order each session (default: true)
  // Makes it harder for pre-recorded videos to pass
  shuffleChallenges: true,

  // Run TFLite anti-spoofing model during detectFace step (default: false)
  // Requires the bundled anti_spoof.tflite model
  enableAntispoofing: false,

  // How often to process a camera frame (default: 500ms)
  // Shorter = faster feedback, more CPU usage
  scanInterval: Duration(milliseconds: 500),

  // Max time for each gesture step before timeout (default: 20s)
  stepTimeout: Duration(seconds: 20),

  // Max time for initial face detection step (default: 60s)
  // Longer than gesture steps since user may need to adjust position
  detectFaceTimeout: Duration(seconds: 60),

  // Consecutive frames a gesture must be detected before advancing (default: 2)
  // Higher = fewer false positives, user must hold gesture longer
  gestureConfirmations: 2,

  // Which step to capture the selfie image on (default: null = detectFace)
  // Set to e.g. KycFaceRecognitionStage.smile for a smiling selfie
  captureStep: KycFaceRecognitionStage.smile,

  // --- Anti-spoofing tuning (only relevant if enableAntispoofing is true) ---

  // Minimum image clarity score for spoof analysis (default: 750)
  // Frames below this are considered too blurry
  clearnessThreshold: 750,

  // Lower bound — frames below this don't count at all (default: 450)
  clearnessLowerThreshold: 450,

  // Liveness score threshold (default: 0.2)
  // Frames scoring above this are classified as "not spoofed"
  livenessThreshold: 0.2,

  // Non-spoof frames needed to pass anti-spoofing (default: 3)
  maxFrameCount: 3,

  // Required ratio of non-spoof frames (default: 0.6 / 60%)
  framePassPercentage: 0.6,

  // Path to a custom TFLite model (default: null = bundled model)
  // Must accept 256x256x3 float32 input
  customModelPath: null,
)
```

## State stream

`KycEngine.stateStream` emits `KycLivenessState` on every processed frame:

| Field | Type | Description |
|-------|------|-------------|
| `currentStep` | `KycFaceRecognitionStage` | The active challenge step |
| `detectedFace` | `KycDetectedFace?` | Face analysis result for this frame |
| `spoofResult` | `KycSpoofResult?` | Anti-spoofing result (if enabled) |
| `feedback` | `KycFeedback` | User guidance hint (`moveCloser`, `faceNotCentered`, etc.) |
| `progress` | `double` | 0.0 to 1.0 overall completion |
| `isComplete` | `bool` | All challenges passed |
| `capturedImage` | `File?` | Selfie image (available after detectFace passes) |
| `isCameraReady` | `bool` | Camera initialized and streaming |
| `isTimedOut` | `bool` | Current step exceeded its timeout |

## Feedback values

The `KycFeedback` enum tells you what guidance to show the user:

| Value | Meaning |
|-------|---------|
| `noFaceDetected` | No face found in frame |
| `faceTooFar` / `moveCloser` | User is too far from camera |
| `faceNotCentered` | Face not centered in frame |
| `faceRotated` | Head turned too far from forward |
| `keepStill` | User should hold still |
| `multipleFaces` | More than one face visible |
| `none` | No corrective action needed |

## Error handling

The SDK uses a throw-or-callback approach:

- **Fatal errors** (camera init failure, permissions not granted) — `start()` throws a `CameraException`. Catch it in your app code.
- **Non-fatal frame errors** (a single frame fails to process) — Routed to the optional `onError` callback. If not set, the frame is silently skipped and the next one is processed. This is intentional — a dropped frame is a non-event.

```dart
final engine = KycEngine(
  config: KycConfig(),
  onError: (error, stack) {
    // Log to your crash reporting service, or ignore
    print('Frame error: $error');
  },
);

try {
  await engine.start();
} on CameraException catch (e) {
  // Camera permission denied, no cameras available, etc.
  print('${e.code}: ${e.description}');
}
```

The SDK does **not** log anything to the console. Your app controls all logging through `onError`.

## What this SDK does NOT handle

- **Camera permissions** — Your app must request and handle camera permissions before calling `start()`. See the [permissions section](#important-camera-permissions-are-not-handled-by-this-sdk) above.
- **UI** — This is a headless engine. It provides data (state stream, camera controller) but no widgets. You build your own UI.
- **Networking** — No API calls, no uploads, no sessions. The captured selfie is a local `File` — what you do with it is up to you.
- **Storage** — Captured selfie images are written to the device's temp directory. Your app is responsible for moving or uploading them.
- **Localization** — Feedback values are enums, not user-facing strings. Map them to localized text in your app.

## Example app

The `example/` directory contains a working app with two demos:

- **Full Liveness Flow** — Uses `KycEngine` with an oval camera preview, challenge instructions, progress bar, and completion view
- **Standalone Face Detection** — Uses `KycFaceDetectionService` directly with a custom camera setup

Run it:

```bash
cd example
flutter run
```

## Project structure

```
lib/
  kyc_engine.dart              # Barrel file (public API exports)
  src/
    core/
      config.dart              # KycConfig
    engine/
      kyc_engine.dart          # Main orchestrator
      liveness_state.dart      # KycLivenessState
      camera_service.dart      # Internal camera lifecycle (not exported)
    services/
      face_detection_service.dart   # ML Kit face detection
      anti_spoofing_service.dart    # TFLite anti-spoofing
      liveness_session.dart         # Challenge state machine
      face_kit.dart                 # Camera image conversion utilities
    models/
      detected_face.dart       # KycDetectedFace
      spoof_result.dart        # KycSpoofResult
      kyc_feedback.dart        # KycFeedback enum
      enums.dart               # KycFaceRecognitionStage enum
```

## Made with ❤️ from lukas-roqqu. Buy me coffee ☕️.

