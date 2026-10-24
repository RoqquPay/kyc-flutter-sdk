/// Actionable feedback hints emitted during face detection.
///
/// Use these values to display user-facing guidance (e.g., "Move closer"
/// or "Center your face"). The [none] value indicates no corrective
/// action is needed.
enum KycFeedback {
  /// No face was found in the current frame.
  noFaceDetected,

  /// A face was detected but is too small — the user is too far away.
  faceTooFar,

  /// The face is not centered within the camera frame.
  faceNotCentered,

  /// The face is rotated too far from a forward-facing position.
  faceRotated,

  /// The user needs to move closer to the camera.
  moveCloser,

  /// The user should hold still for the current step.
  keepStill,

  /// Multiple faces detected — only one face should be visible.
  multipleFaces,

  /// No feedback needed; the face position is acceptable.
  none,
}
