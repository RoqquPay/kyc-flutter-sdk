## 0.1.0

* Initial release of `kyc_engine` — a headless, camera-based face liveness verification engine for Flutter.
* Face detection via Google ML Kit with gesture recognition (smile, mouth open, head tilt).
* Configurable liveness challenge sequences with shuffle support.
* Optional TFLite anti-spoofing inference (runs in background isolate).
* SDK-managed camera or bring-your-own camera stream support.
* Stream-based API emitting `KycLivenessState` snapshots.
* Selfie capture on successful face detection.
* Per-step and per-session timeout detection.
