import Flutter
import Foundation
import FoundationModels

// Apple Foundation Models behind the Dart ReflectionEngine contract. It reads a
// week's entries back as a short observation, using ONLY the on-device model
// (SystemLanguageModel.default) - never Private Cloud Compute, never a server.
// Silence is a valid, expected result: an empty response, or a guardrail
// refusal, both come back as empty text, which Dart reads as "a quiet week".

/// Channel error codes. Cross-boundary contract with foundation_models_engine.dart.
private enum ReflectErrorCode: String {
  /// The engine could not run this time (transient). Distinct from silence.
  case unavailable
  case badArgs = "bad_args"

  func error(_ message: String) -> FlutterError {
    FlutterError(code: rawValue, message: message, details: nil)
  }
}

final class ReflectionEnginePlugin: NSObject, FlutterPlugin {
  static func register(with registrar: FlutterPluginRegistrar) {
    // Channel name + payload shapes: must match foundation_models_engine.dart.
    let methods = FlutterMethodChannel(
      name: "opentranscribe/reflect", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(ReflectionEnginePlugin(), channel: methods)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "availability":
      result(["status": availabilityStatus()])
    case "reflect":
      guard let args = call.arguments as? [String: Any],
        let entries = args["entries"] as? [[String: Any]],
        let style = args["style"] as? [String: Any],
        let localeId = args["localeId"] as? String
      else {
        result(ReflectErrorCode.badArgs.error("reflect: missing or malformed arguments"))
        return
      }
      reflect(entries: entries, style: style, localeId: localeId, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  /// Maps the system model's availability to the wire strings Dart expects.
  /// Only `available` runs; the rest keep the feature invisible or surfaced as
  /// help, decided on the Dart side.
  private func availabilityStatus() -> String {
    guard #available(iOS 26.0, *) else { return "unsupported" }
    switch SystemLanguageModel.default.availability {
    case .available:
      return "available"
    case .unavailable(.appleIntelligenceNotEnabled):
      return "not_enabled"
    case .unavailable(.modelNotReady):
      return "model_not_ready"
    case .unavailable(.deviceNotEligible):
      return "device_not_eligible"
    case .unavailable:
      return "unsupported"
    @unknown default:
      return "unsupported"
    }
  }

  private func reflect(
    entries: [[String: Any]], style: [String: Any], localeId: String,
    result: @escaping FlutterResult
  ) {
    guard #available(iOS 26.0, *) else {
      result(ReflectErrorCode.unavailable.error("Foundation Models requires iOS 26"))
      return
    }
    // Never call the model when it is not the on-device path; Dart gates on this
    // too, but the engine refuses on its own as a second guard.
    guard case .available = SystemLanguageModel.default.availability else {
      result(ReflectErrorCode.unavailable.error("on-device model unavailable"))
      return
    }

    let instructions = buildInstructions(style: style)
    let prompt = buildPrompt(entries: entries)

    Task {
      do {
        let session = LanguageModelSession(instructions: instructions)
        let response = try await session.respond(to: prompt)
        let text = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        await MainActor.run { result(["text": text]) }
      } catch let error as LanguageModelSession.GenerationError {
        // The model RAN but produced nothing usable for this input: a guardrail
        // refusal, a week too long for the context window, a decode failure. All
        // are terminal for this week, so all are SILENCE, never a retry. Only a
        // non-generation (system) failure below is transient/could-not-run, so a
        // deterministic per-week failure can never head-of-line-block older weeks.
        _ = error
        await MainActor.run { result(["text": ""]) }
      } catch {
        await MainActor.run {
          result(ReflectErrorCode.unavailable.error(String(describing: error)))
        }
      }
    }
  }

  /// The observer contract, plus the three user knobs. The non-negotiables are
  /// the base: observe, never address the person, never advise, and prefer
  /// silence over filler. First-draft copy; tuned on-device.
  private func buildInstructions(style: [String: Any]) -> String {
    var lines: [String] = [
      "You read a person's week back to them from their own voice-journal entries.",
      "You are only an observer. You notice what recurred, what shifted, the shape of the week.",
      "You never address the person, and never advise, comfort, encourage, reassure, or judge.",
      "You do not use the word \"you\", imperatives, greetings, or sign-offs.",
      "You never invent anything that is not in the entries.",
      "If the week holds nothing worth noticing, you reply with nothing at all. An empty reply is correct and expected; never pad it with filler.",
    ]

    switch style["voice"] as? String {
    case "sparse":
      lines.append(
        "Write as tersely as possible, close to a log: state what recurred, with minimal interpretation.")
    case "observational":
      lines.append("Write plainly, reporting the shape of the week with a little warmth.")
    default:  // literary
      lines.append(
        "Write a few plain, quietly evocative sentences, like a short reflective note.")
    }

    switch style["length"] as? String {
    case "one_line":
      lines.append("Use at most one sentence.")
    case "paragraph":
      lines.append("Use at most one short paragraph (up to five sentences).")
    default:  // sentences
      lines.append("Use at most three sentences.")
    }

    switch style["specificity"] as? String {
    case "abstract":
      lines.append(
        "Refer to themes only (work, family, a trip). Do not name specific people, projects, or places.")
    case "let_week_decide":
      lines.append(
        "Name a specific person, project, or place only when it is clearly central to the week; otherwise keep to themes.")
    default:  // name_freely
      lines.append("You may name the specific people, projects, and places you heard.")
    }

    return lines.joined(separator: " ")
  }

  private func buildPrompt(entries: [[String: Any]]) -> String {
    let weekdays = [
      "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday",
    ]
    var lines: [String] = ["This week's entries, in order:", ""]
    for entry in entries {
      let weekday = entry["weekday"] as? Int ?? 0
      let dayName = (weekday >= 1 && weekday <= 7) ? weekdays[weekday - 1] : ""
      let text = (entry["text"] as? String) ?? ""
      var head = dayName
      if let title = entry["title"] as? String, !title.isEmpty {
        head = head.isEmpty ? title : "\(dayName) - \(title)"
      }
      lines.append(head.isEmpty ? text : "\(head): \(text)")
    }
    lines.append("")
    lines.append("Read this week back.")
    return lines.joined(separator: "\n")
  }
}
