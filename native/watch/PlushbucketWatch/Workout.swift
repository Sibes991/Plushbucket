import HealthKit
import WatchKit

// Records each timed ride as an Outdoor Cycle workout in Apple Health, so it shows in the Fitness app
// and counts toward the Activity rings. It also keeps Plushbucket on screen during the ride, with heart rate
// and calories. If the rider says no to Health access, the ride timer still works, just without the workout.
final class Workout: NSObject, ObservableObject, HKWorkoutSessionDelegate, HKLiveWorkoutBuilderDelegate {
    static let shared = Workout()

    @Published var recording = false
    @Published var heartRate: Double?
    @Published var calories: Double?

    private let health = HKHealthStore()
    private var session: HKWorkoutSession?
    private var saveWhenEnded = true

    private var readTypes: Set<HKObjectType> {
        [HKQuantityType(.heartRate), HKQuantityType(.activeEnergyBurned), HKQuantityType(.distanceCycling), HKObjectType.activitySummaryType()]
    }
    private var shareTypes: Set<HKSampleType> {
        [HKObjectType.workoutType(), HKQuantityType(.activeEnergyBurned), HKQuantityType(.distanceCycling)]
    }

    func start(at date: Date) {
        guard !Demo.isOn, HKHealthStore.isHealthDataAvailable(), session == nil else { return }
        health.requestAuthorization(toShare: shareTypes, read: readTypes) { _, _ in
            DispatchQueue.main.async { self.begin(at: date) }
        }
    }

    private func begin(at date: Date) {
        guard session == nil, health.authorizationStatus(for: HKObjectType.workoutType()) == .sharingAuthorized else { return }
        let config = HKWorkoutConfiguration()
        config.activityType = .cycling
        config.locationType = .outdoor
        do {
            let s = try HKWorkoutSession(healthStore: health, configuration: config)
            let b = s.associatedWorkoutBuilder()
            b.dataSource = HKLiveWorkoutDataSource(healthStore: health, workoutConfiguration: config)
            s.delegate = self
            b.delegate = self
            session = s
            saveWhenEnded = true
            s.startActivity(with: date)
            b.beginCollection(withStart: date) { _, _ in }
            recording = true
        } catch {
            session = nil
        }
    }

    func pause() { session?.pause() }
    func resume() { session?.resume() }

    // save: true keeps it in Health and Fitness; false throws the workout away
    func finish(save: Bool) {
        guard let s = session else { return }
        saveWhenEnded = save
        s.end()
    }

    // After a crash or restart mid-ride, watchOS hands the running workout back
    func recover() {
        health.recoverActiveWorkoutSession { s, _ in
            guard let s else { return }
            DispatchQueue.main.async {
                s.delegate = self
                s.associatedWorkoutBuilder().delegate = self
                self.session = s
                self.recording = true
            }
        }
    }

    // MARK: HKWorkoutSessionDelegate

    func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
        guard toState == .ended else { return }
        let b = workoutSession.associatedWorkoutBuilder()
        let save = saveWhenEnded
        b.endCollection(withEnd: date) { _, _ in
            if save {
                b.finishWorkout { _, _ in }
            } else {
                b.discardWorkout()
            }
            DispatchQueue.main.async { self.reset() }
        }
    }

    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        DispatchQueue.main.async { self.reset() }
    }

    private func reset() {
        session = nil
        recording = false
        heartRate = nil
        calories = nil
    }

    // MARK: HKLiveWorkoutBuilderDelegate

    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}

    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        let hr = workoutBuilder.statistics(for: HKQuantityType(.heartRate))?.mostRecentQuantity()?
            .doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
        let kcal = workoutBuilder.statistics(for: HKQuantityType(.activeEnergyBurned))?.sumQuantity()?
            .doubleValue(for: .kilocalorie())
        DispatchQueue.main.async {
            if let hr { self.heartRate = hr }
            if let kcal { self.calories = kcal }
        }
    }
}

final class AppDelegate: NSObject, WKApplicationDelegate {
    func handleActiveWorkoutRecovery() {
        Workout.shared.recover()
    }
}
