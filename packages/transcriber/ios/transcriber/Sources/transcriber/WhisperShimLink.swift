import WhisperShim

/// Referenced from registration so the linker pulls the shim's object file
/// into the app; Dart resolves its symbols from the process image.
enum WhisperShimLink {
  static func retain() {
    _ = otr_whisper_version()
  }
}
