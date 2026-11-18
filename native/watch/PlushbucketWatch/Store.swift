import SwiftUI
import WatchConnectivity

// Keeps the bikes the phone sent, the ride timer, and rides waiting to go back to the phone.
// The timer is just a saved start time, so it keeps counting when the watch screen sleeps or the app closes.
final class Store: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = Store()

    @Published var bikes: [Bike] = []
    @Published var updated: Date?
    @Published var rideStart: Date?
    @Published var rideBike: String?
    @Published var note: String?

    private let defaults = UserDefaults.standard
    private enum Key {
        static let bikes = "bikes", updated = "updated", rideStart = "rideStart", rideBike = "rideBike", outbox = "outbox"
    }

    override init() {
        super.init()
        if Demo.isOn {
            bikes = Demo.bikes
            updated = Date()
            if Demo.shot == "ride" || Demo.shot == "save" {
                rideStart = Date().addingTimeInterval(-(1 * 3600 + 23 * 60 + 17))
                rideBike = bikes.first?.id
            }
            return
        }
        if let s = defaults.string(forKey: Key.bikes) { decodeBikes(s) }
        let t = defaults.double(forKey: Key.updated)
        if t > 0 { updated = Date(timeIntervalSince1970: t) }
        let r = defaults.double(forKey: Key.rideStart)
        if r > 0 { rideStart = Date(timeIntervalSince1970: r) }
        rideBike = defaults.string(forKey: Key.rideBike)
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    var currentBike: Bike? { bikes.first { $0.id == rideBike } }

    // MARK: Bikes from the phone

    private func decodeBikes(_ s: String) {
        guard let data = s.data(using: .utf8), let list = try? JSONDecoder().decode([Bike].self, from: data) else { return }
        bikes = list
    }

    private func apply(_ ctx: [String: Any]) {
        guard let s = ctx["bikes"] as? String else { return }
        let at = (ctx["at"] as? Double) ?? Date().timeIntervalSince1970
        DispatchQueue.main.async {
            self.decodeBikes(s)
            self.updated = Date(timeIntervalSince1970: at)
            self.defaults.set(s, forKey: Key.bikes)
            self.defaults.set(at, forKey: Key.updated)
        }
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        guard activationState == .activated else { return }
        apply(session.receivedApplicationContext)
        DispatchQueue.main.async { self.flushOutbox() }
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        apply(applicationContext)
    }

    // MARK: Ride timer

    func start(_ bike: Bike) {
        let now = Date()
        rideStart = now
        rideBike = bike.id
        note = nil
        defaults.set(now.timeIntervalSince1970, forKey: Key.rideStart)
        defaults.set(bike.id, forKey: Key.rideBike)
    }

    func endRide() {
        rideStart = nil
        rideBike = nil
        defaults.removeObject(forKey: Key.rideStart)
        defaults.removeObject(forKey: Key.rideBike)
    }

    func save(hours: Double, wet: Bool) {
        guard let bike = currentBike else { endRide(); return }
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        let ride = Ride(id: "w" + String(UUID().uuidString.prefix(8)).lowercased(),
                        date: f.string(from: rideStart ?? Date()),
                        h: (hours * 100).rounded() / 100,
                        wet: wet,
                        bike: bike.id,
                        parts: bike.parts.map { $0.id })
        if let data = try? JSONEncoder().encode(ride), let s = String(data: data, encoding: .utf8) {
            var box = defaults.stringArray(forKey: Key.outbox) ?? []
            box.append(s)
            defaults.set(box, forKey: Key.outbox)
            flushOutbox()
        }
        note = String(format: "%.1f h added to %@. It shows in the service log on your iPhone.", ride.h, bike.name)
        endRide()
    }

    // Rides queue here until the watch connection is up; the system then delivers them to the phone,
    // even if the phone is out of range or the app isn't open.
    private func flushOutbox() {
        guard !Demo.isOn, WCSession.isSupported(), WCSession.default.activationState == .activated else { return }
        let box = defaults.stringArray(forKey: Key.outbox) ?? []
        guard !box.isEmpty else { return }
        for s in box { WCSession.default.transferUserInfo(["ride": s]) }
        defaults.removeObject(forKey: Key.outbox)
    }
}
