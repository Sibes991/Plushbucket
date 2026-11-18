import Foundation
import Capacitor
import WatchConnectivity

// Plushbucket on Apple Watch, phone side.
// The web app sends each garage bike's settings as one JSON string; the latest copy goes to the watch
// as its application context (the watch always gets the newest one, even if it was asleep).
// Rides timed on the watch arrive as user info, are kept here until the web app takes them, and then
// count toward service like a ride logged on the phone. Everything stays between the phone and the watch.

@objc(WatchSyncPlugin)
public class WatchSyncPlugin: CAPPlugin, CAPBridgedPlugin, WCSessionDelegate {
    public let identifier = "WatchSyncPlugin"
    public let jsName = "WatchSync"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "status", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "sendBikes", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "takeRides", returnType: CAPPluginReturnPromise)
    ]

    private let ridesKey = "plushbucket.watch.rides"
    private var pendingContext: [String: Any]?

    public override func load() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    @objc func status(_ call: CAPPluginCall) {
        guard WCSession.isSupported() else {
            call.resolve(["supported": false, "paired": false, "installed": false])
            return
        }
        let s = WCSession.default
        let on = s.activationState == .activated
        call.resolve(["supported": true, "paired": on && s.isPaired, "installed": on && s.isWatchAppInstalled])
    }

    @objc func sendBikes(_ call: CAPPluginCall) {
        guard WCSession.isSupported() else {
            call.resolve(["sent": false])
            return
        }
        let ctx: [String: Any] = ["bikes": call.getString("json") ?? "[]", "at": Date().timeIntervalSince1970]
        let s = WCSession.default
        guard s.activationState == .activated else {
            pendingContext = ctx
            call.resolve(["sent": false, "queued": true])
            return
        }
        do {
            try s.updateApplicationContext(ctx)
            call.resolve(["sent": true])
        } catch {
            call.resolve(["sent": false, "error": error.localizedDescription])
        }
    }

    @objc func takeRides(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            let d = UserDefaults.standard
            let rides = d.stringArray(forKey: self.ridesKey) ?? []
            d.removeObject(forKey: self.ridesKey)
            call.resolve(["rides": rides])
        }
    }

    // MARK: WCSessionDelegate

    public func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        guard activationState == .activated, let ctx = pendingContext else { return }
        pendingContext = nil
        try? session.updateApplicationContext(ctx)
    }

    public func sessionDidBecomeInactive(_ session: WCSession) {}

    public func sessionDidDeactivate(_ session: WCSession) {
        // the rider switched to another watch: start talking to the new one
        session.activate()
    }

    public func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        guard let ride = userInfo["ride"] as? String else { return }
        DispatchQueue.main.async {
            let d = UserDefaults.standard
            var rides = d.stringArray(forKey: self.ridesKey) ?? []
            rides.append(ride)
            d.set(rides, forKey: self.ridesKey)
            self.notifyListeners("ride", data: [:])
        }
    }
}
