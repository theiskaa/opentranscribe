import Flutter
import Foundation
import FoundationModels

// Apple Foundation Models behind the Dart ReflectionEngine contract. It reads a
// period's entries (a day, a week, or a month) back as a short observation,
// using ONLY the on-device model (SystemLanguageModel.default) - never Private
// Cloud Compute, never a server. Silence is a valid, expected result: an empty
// response, or a guardrail refusal, both come back as empty text, which Dart
// reads as a quiet period (a quiet day, week, or month).

/// Channel error codes. Cross-boundary contract with foundation_models_engine.dart.
private enum ReflectErrorCode: String {
  /// The engine could not run this time (transient). Distinct from silence.
  case unavailable
  case badArgs = "bad_args"

  func error(_ message: String) -> FlutterError {
    FlutterError(code: rawValue, message: message, details: nil)
  }
}

public final class ReflectionEnginePlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    // Channel name + payload shapes: must match foundation_models_engine.dart.
    let methods = FlutterMethodChannel(
      name: "reflections/reflect", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(ReflectionEnginePlugin(), channel: methods)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
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
      // Absent period means an older caller; weekly is the historical default.
      let period = (args["period"] as? String) ?? "weekly"
      reflect(entries: entries, style: style, localeId: localeId, period: period, result: result)
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
    entries: [[String: Any]], style: [String: Any], localeId: String, period: String,
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

    let instructions = buildInstructions(style: style, localeId: localeId, period: period)
    let prompt = buildPrompt(entries: entries, localeId: localeId, period: period)

    Task {
      do {
        let session = LanguageModelSession(instructions: instructions)
        let response = try await session.respond(to: prompt)
        let text = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        await MainActor.run { result(["text": text]) }
      } catch let error as LanguageModelSession.GenerationError {
        let outcome = generationOutcome(for: error)
        await MainActor.run { result(outcome) }
      } catch {
        await MainActor.run {
          result(ReflectErrorCode.unavailable.error(String(describing: error)))
        }
      }
    }
  }

  /// Splits generation failures by what they mean for the PERIOD. Transient
  /// system conditions (throttled, model assets evicted, another request in
  /// flight) are could-not-run: the period stays unreflected and the next open
  /// retries, because persisting them would permanently mislabel a real period
  /// as quiet. Everything else means the model ran and produced nothing usable
  /// for this input (a refusal, an overflow, a decode failure): terminal for
  /// this period, so silence, never a retry that would head-of-line-block older
  /// periods.
  @available(iOS 26.0, *)
  private func generationOutcome(for error: LanguageModelSession.GenerationError) -> Any {
    switch error {
    case .rateLimited, .assetsUnavailable, .concurrentRequests:
      return ReflectErrorCode.unavailable.error(String(describing: error))
    default:
      return ["text": ""]
    }
  }

  /// The English noun for a period, for the observer instructions and prompt
  /// scaffolding. Weekly is the default for any unrecognized value.
  private func periodNoun(_ period: String) -> String {
    switch period {
    case "daily": return "day"
    case "monthly": return "month"
    default: return "week"
    }
  }

  /// The observer contract, plus the three user knobs. The non-negotiables are
  /// the base: observe, never address the person, never advise, and prefer
  /// silence over filler. First-draft copy; tuned on-device.
  private func buildInstructions(style: [String: Any], localeId: String, period: String) -> String {
    let noun = periodNoun(period)
    var lines: [String] = [
      "You read a person's \(noun) back to them from their own voice-journal entries.",
      "You are only an observer. You notice what recurred, what shifted, the shape of the \(noun).",
      "You never address the person, and never advise, comfort, encourage, reassure, or judge.",
      "You do not use the word \"you\", imperatives, greetings, or sign-offs.",
      "You never invent anything that is not in the entries.",
      "If the \(noun) holds nothing worth noticing, you reply with nothing at all. An empty reply is correct and expected; never pad it with filler.",
    ]

    switch style["voice"] as? String {
    case "sparse":
      lines.append(
        "Write as tersely as possible, close to a log: state what recurred, with minimal interpretation.")
    case "observational":
      lines.append("Write plainly, reporting the shape of the \(noun) with a little warmth.")
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
        "Name a specific person, project, or place only when it is clearly central to the \(noun); otherwise keep to themes.")
    default:  // name_freely
      lines.append("You may name the specific people, projects, and places you heard.")
    }

    // The reflection must come back in the app language: without the directive
    // the English instructions prime the model to answer in English no matter
    // what language the entries hold. Named in English (the instructions'
    // language) so the directive itself stays unambiguous to the model.
    let language = Locale(identifier: "en_US").localizedString(forLanguageCode: localeId) ?? localeId
    lines.append("Write in \(language).")

    return lines.joined(separator: " ")
  }

  private func buildPrompt(entries: [[String: Any]], localeId: String, period: String) -> String {
    let noun = periodNoun(period)
    let label = dayLabeller(period: period, localeId: localeId)
    var lines: [String] = ["This \(noun)'s entries, in order:", ""]
    for entry in entries {
      let dayLabel = label(entry["date"] as? String ?? "")
      let text = (entry["text"] as? String) ?? ""
      var head = dayLabel
      if let title = entry["title"] as? String, !title.isEmpty {
        head = head.isEmpty ? title : "\(dayLabel) - \(title)"
      }
      lines.append(head.isEmpty ? text : "\(head): \(text)")
    }
    lines.append("")
    lines.append("Read this \(noun) back.")
    return lines.joined(separator: "\n")
  }

  /// Builds the per-entry day label for a period, in the reflection's own
  /// language so the prompt never mixes English scaffolding into a non-English
  /// read. A day within a week is its weekday name; a day within a month is its
  /// month-day; a single day needs no label. The wire date is `yyyy-MM-dd`.
  private func dayLabeller(period: String, localeId: String) -> (String) -> String {
    if period == "daily" { return { _ in "" } }
    let iso = DateFormatter()
    iso.locale = Locale(identifier: "en_US_POSIX")
    iso.dateFormat = "yyyy-MM-dd"
    let out = DateFormatter()
    out.locale = Locale(identifier: localeId)
    // A month read is one month, so the day-of-month alone locates each entry;
    // a week read wants the weekday name.
    out.setLocalizedDateFormatFromTemplate(period == "monthly" ? "d" : "EEEE")
    return { dateString in
      guard let date = iso.date(from: dateString) else { return "" }
      return out.string(from: date)
    }
  }
}
