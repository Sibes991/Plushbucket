import Foundation
import Capacitor
#if canImport(FoundationModels)
import FoundationModels
#endif

// Trail notes: turns "harsh on roots, kicked me off the jump" into one symptom from the app's own fix list.
// Uses Apple's on-device model only (no network). The model can only answer with one of the ids below,
// and it never writes advice or numbers: the app shows its own fix text for the chosen symptom.
// On phones without Apple Intelligence (or below iOS 26) isAvailable() returns false and the app
// just shows the tap-to-pick list.

#if canImport(FoundationModels)
@available(iOS 26.0, *)
@Generable
enum TrailSymptom: String {
    case harsh, kick, dive, bottomOut, sitsLow, stiffTop, pumpReading, sagCreep, pressureDrop, coilSag, none
}

@available(iOS 26.0, *)
@Generable
struct TrailMatch {
    @Guide(description: "The one problem from the list that best matches what the rider said, or none if nothing fits")
    var symptom: TrailSymptom
}
#endif

@objc(TrailNotesPlugin)
public class TrailNotesPlugin: CAPPlugin, CAPBridgedPlugin {
    public let identifier = "TrailNotesPlugin"
    public let jsName = "TrailNotes"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "isAvailable", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "classify", returnType: CAPPluginReturnPromise)
    ]

    @objc func isAvailable(_ call: CAPPluginCall) {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            if case .available = SystemLanguageModel.default.availability {
                call.resolve(["available": true])
                return
            }
        }
        #endif
        call.resolve(["available": false])
    }

    @objc func classify(_ call: CAPPluginCall) {
        let text = (call.getString("text") ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let part = call.getString("part") ?? "fork"
        let ids = (call.getArray("ids") as? [String]) ?? []
        let labels = (call.getArray("labels") as? [String]) ?? []
        guard !text.isEmpty, !ids.isEmpty, ids.count == labels.count else {
            call.reject("Nothing to match")
            return
        }
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            guard case .available = SystemLanguageModel.default.availability else {
                call.reject("On-device model not available")
                return
            }
            let list = zip(ids, labels).map { "- \($0.0): \($0.1)" }.joined(separator: "\n")
            let prompt = """
            Part: mountain bike \(part)
            What the rider said: "\(String(text.prefix(400)))"

            Problems (answer with one id, or none):
            \(list)
            """
            Task {
                do {
                    let session = LanguageModelSession(instructions: """
                    You match a mountain biker's description of how their suspension felt to one problem from a fixed list. \
                    Choose the single closest problem. If nothing on the list fits, choose none. Do not give advice.
                    """)
                    let response = try await session.respond(to: prompt, generating: TrailMatch.self)
                    let id = response.content.symptom.rawValue
                    call.resolve(["id": ids.contains(id) ? id : "none"])
                } catch {
                    call.reject("Couldn't match that note")
                }
            }
            return
        }
        #endif
        call.reject("On-device model not available")
    }
}
