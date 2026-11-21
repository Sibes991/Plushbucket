import Foundation
import Capacitor
import HealthKit

// Ride import, iPhone side.
// Reads cycling workouts that other apps (Garmin Connect, Strava, Trailforks, the Workout app...) saved to
// Apple Health, so the web app can count their hours toward fork and shock service. Read-only: it never
// writes to Health and nothing is sent off the phone. The watch app's own rides are returned too (with
// their bundle ID) so the web app can tell they're already in the service log.
//
// JS:  status() -> { available, platform, asked }
//      request() -> { asked }        (Apple doesn't tell apps whether read access was allowed)
//      rides({ from }) -> { rides: [{ id, start, end, duration, source, bundle, indoor }] }   (ms, seconds)

@objc(HealthRidesPlugin)
public class HealthRidesPlugin: CAPPlugin, CAPBridgedPlugin {
    public let identifier = "HealthRidesPlugin"
    public let jsName = "HealthRides"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "status", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "request", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "rides", returnType: CAPPluginReturnPromise)
    ]

    private lazy var store = HKHealthStore()
    private var readTypes: Set<HKObjectType> { [HKObjectType.workoutType()] }

    @objc func status(_ call: CAPPluginCall) {
        guard HKHealthStore.isHealthDataAvailable() else {
            call.resolve(["available": false, "platform": "ios", "asked": false])
            return
        }
        // "unnecessary" means the rider has already answered the permission sheet (allowed or not)
        store.getRequestStatusForAuthorization(toShare: [], read: readTypes) { st, _ in
            call.resolve(["available": true, "platform": "ios", "asked": st == .unnecessary])
        }
    }

    @objc func request(_ call: CAPPluginCall) {
        guard HKHealthStore.isHealthDataAvailable() else {
            call.resolve(["asked": false])
            return
        }
        DispatchQueue.main.async {
            self.store.requestAuthorization(toShare: [], read: self.readTypes) { ok, _ in
                call.resolve(["asked": ok])
            }
        }
    }

    @objc func rides(_ call: CAPPluginCall) {
        guard HKHealthStore.isHealthDataAvailable() else {
            call.resolve(["rides": []])
            return
        }
        let fromMs = call.getDouble("from") ?? (Date().timeIntervalSince1970 - 30 * 86400) * 1000
        let from = Date(timeIntervalSince1970: fromMs / 1000)
        let pred = HKQuery.predicateForSamples(withStart: from, end: nil, options: .strictStartDate)
        let sort = [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
        let q = HKSampleQuery(sampleType: HKObjectType.workoutType(), predicate: pred, limit: 1000, sortDescriptors: sort) { _, samples, error in
            if let error = error as? HKError, error.code != .errorNoData {
                call.resolve(["rides": [], "error": error.localizedDescription])
                return
            }
            let out: [[String: Any]] = (samples as? [HKWorkout] ?? [])
                .filter { $0.workoutActivityType == .cycling }
                .map { w in
                    let src = w.sourceRevision.source
                    return [
                        "id": w.uuid.uuidString,
                        "start": w.startDate.timeIntervalSince1970 * 1000,
                        "end": w.endDate.timeIntervalSince1970 * 1000,
                        "duration": w.duration,
                        "source": src.name,
                        "bundle": src.bundleIdentifier,
                        "indoor": (w.metadata?[HKMetadataKeyIndoorWorkout] as? NSNumber)?.boolValue ?? false
                    ]
                }
            call.resolve(["rides": out])
        }
        store.execute(q)
    }
}
