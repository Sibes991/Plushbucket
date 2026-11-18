import SwiftUI

// What the iPhone app sends: every value is already worked out and worded on the phone,
// so the watch shows exactly what the setup card on the phone shows.
struct Line: Codable, Hashable {
    var h: String
    var t: String
}

struct Part: Codable, Hashable, Identifiable {
    var id: String
    var kind: String        // "fork" or "shock"
    var svc: String?
    var title: String
    var l1: String          // "Starting pressure", "Bike park pressure", "Spring rate"...
    var psi: String
    var sag: String
    var l3: String          // "Volume spacers", "Tokens", "Max pressure"...
    var tok: String
    var lines: [Line]

    var kindName: String { kind == "fork" ? "Fork" : "Shock" }
}

struct Bike: Codable, Hashable, Identifiable {
    var id: String
    var name: String
    var rider: String
    var profile: String
    var parts: [Part]
}

// A ride timed on the watch. The phone adds it to the service log for the bike's fork and shock.
struct Ride: Codable {
    var id: String
    var date: String        // yyyy-MM-dd
    var h: Double           // hours
    var wet: Bool
    var bike: String
    var parts: [String]
}

enum Brand {
    static let orange = Color(red: 1.0, green: 0.478, blue: 0.180)   // #ff7a2e
    static let pine = Color(red: 0.102, green: 0.200, blue: 0.157)   // #1a3328
    static let cream = Color(red: 0.965, green: 0.937, blue: 0.894)  // #f6efe4

    static func big(_ size: CGFloat) -> Font {
        .system(size: size, weight: .heavy).width(.condensed).italic()
    }
}
