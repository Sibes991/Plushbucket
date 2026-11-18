import Foundation

// Sample bikes for the App Store screenshots only (launch with -PBDemo, and -PBShot list|fork|shock|ride|save).
// The numbers are what the iPhone app shows for these bikes; normal use never sees this.
enum Demo {
    static let isOn = ProcessInfo.processInfo.arguments.contains("-PBDemo")

    static var shot: String {
        let args = ProcessInfo.processInfo.arguments
        guard isOn, let i = args.firstIndex(of: "-PBShot"), i + 1 < args.count else { return "list" }
        return args[i + 1]
    }

    static var path: [Bike] { isOn && (shot == "fork" || shot == "shock") ? Array(bikes.prefix(1)) : [] }
    static var focus: String? { isOn && shot == "shock" ? "shock" : nil }

    static let bikes: [Bike] = (try? JSONDecoder().decode([Bike].self, from: Data(json.utf8))) ?? []

    private static let json = #"""
[
 {
  "id": "demo-enduro",
  "name": "Enduro",
  "rider": "175 lb rider",
  "profile": "Trail",
  "parts": [
   {
    "id": "demo-enduro-fork",
    "kind": "fork",
    "svc": "Fox 36 2027 FLOAT · 160 mm",
    "title": "Fox 36 2027 · FLOAT · 160 mm · GRIP X2",
    "l1": "Starting pressure",
    "psi": "86 psi",
    "sag": "32 mm · 20% of travel",
    "l3": "Volume spacers",
    "tok": "1 stock · 6 max",
    "lines": [
     {
      "h": "Rebound",
      "t": "Low-speed 7 and high-speed 5 out (of 16 and 8)."
     },
     {
      "h": "Compression",
      "t": "High-speed 5 and low-speed 10 out (of 8 and 16)."
     }
    ]
   },
   {
    "id": "demo-enduro-shock",
    "kind": "shock",
    "svc": "Fox FLOAT X2 (2026–2027)",
    "title": "Fox FLOAT X2 (2026–2027) · 60 mm stroke",
    "l1": "Starting pressure",
    "psi": "175 psi",
    "sag": "18 mm · 30% of travel",
    "l3": "Max pressure",
    "tok": "350 psi",
    "lines": [
     {
      "h": "Rebound",
      "t": "Low-speed 9 and high-speed 5 out (of 16 and 8)."
     },
     {
      "h": "Compression",
      "t": "Low-speed 9–10 and high-speed 4–5 out (of 16 and 8)."
     },
     {
      "h": "Lever",
      "t": "2-position climb lever on some models: start in Open (counterclockwise)."
     },
     {
      "h": "Volume",
      "t": "1 cc (green) and 2 cc (blue) XV spacers, mixed for 1 cc steps."
     }
    ]
   }
  ]
 },
 {
  "id": "demo-hardtail",
  "name": "Hardtail",
  "rider": "175 lb rider",
  "profile": "Trail",
  "parts": [
   {
    "id": "demo-hardtail-fork",
    "kind": "fork",
    "svc": "RockShox Lyrik 2023–2026 · 150 mm",
    "title": "RockShox Lyrik 2023–2026 · 150 mm · Charger 3 RC2",
    "l1": "Starting pressure",
    "psi": "78 psi",
    "sag": "30 mm · 20% of travel",
    "l3": "Tokens",
    "tok": "0 stock · 5 max",
    "lines": [
     {
      "h": "Rebound",
      "t": "10 out (of 18)."
     },
     {
      "h": "Compression",
      "t": "Low-speed 8 and high-speed 3 out (of 15 and 5)."
     }
    ]
   }
  ]
 }
]
"""#
}
