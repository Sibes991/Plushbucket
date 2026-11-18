import SwiftUI

@main
struct PlushbucketWatchApp: App {
    @StateObject private var store = Store.shared

    var body: some Scene {
        WindowGroup {
            RootView().environmentObject(store)
        }
    }
}

struct RootView: View {
    @EnvironmentObject var store: Store
    @State private var path: [Bike] = Demo.path

    var body: some View {
        NavigationStack(path: $path) {
            BikeList()
                .navigationDestination(for: Bike.self) { BikeView(bike: $0) }
        }
        .fullScreenCover(isPresented: Binding(get: { store.rideStart != nil }, set: { _ in })) {
            RideView().environmentObject(store)
        }
        .onChange(of: store.rideStart) { _, start in
            if start == nil { path = [] }
        }
    }
}

// MARK: Bikes

struct BikeList: View {
    @EnvironmentObject var store: Store

    var body: some View {
        List {
            if let note = store.note {
                Text(note).font(.footnote).foregroundStyle(Brand.orange)
            }
            if store.bikes.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("No bikes yet").font(.headline)
                    Text("Add a bike to your garage in Plushbucket on your iPhone. Its settings show up here.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            ForEach(store.bikes) { bike in
                NavigationLink(value: bike) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(bike.name).font(Brand.big(22))
                        Text(bike.parts.map(\.kindName).joined(separator: " + "))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            if let updated = store.updated, !store.bikes.isEmpty {
                Text("From your iPhone, \(updated.formatted(.relative(presentation: .named)))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Plushbucket")
        .containerBackground(Brand.pine.gradient, for: .navigation)
    }
}

struct BikeView: View {
    @EnvironmentObject var store: Store
    let bike: Bike

    var body: some View {
        ScrollViewReader { proxy in
            List {
                Button {
                    store.start(bike)
                } label: {
                    Label("Start ride", systemImage: "timer").font(.headline)
                }
                .foregroundStyle(.black)
                .listRowBackground(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Brand.orange))

                ForEach(bike.parts) { part in
                    PartSection(part: part)
                }

                Text("\(bike.rider) · \(bike.profile) profile. \"Out\" means clicks counterclockwise from fully closed. Starting points only: check sag, and never exceed the maximum pressure printed on your fork or shock.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .onAppear {
                if let focus = Demo.focus { proxy.scrollTo(focus, anchor: .center) }
            }
        }
        .navigationTitle(bike.name)
        .containerBackground(Brand.pine.gradient, for: .navigation)
    }
}

struct PartSection: View {
    let part: Part

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 2) {
                Text(part.l1).font(.caption2).foregroundStyle(.secondary)
                Text(part.psi).font(Brand.big(36)).foregroundStyle(Brand.orange)
                Text(part.title).font(.caption2).foregroundStyle(.secondary)
            }
            .id(part.kind)
            Stat(label: "Sag target", value: part.sag)
            Stat(label: part.l3, value: part.tok)
            ForEach(Array(part.lines.enumerated()), id: \.offset) { _, line in
                Stat(label: line.h, value: line.t)
            }
        } header: {
            Text(part.kindName)
        }
    }
}

struct Stat: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption2).foregroundStyle(.secondary)
            Text(value)
        }
    }
}

// MARK: Ride timer

struct RideView: View {
    @EnvironmentObject var store: Store
    @State private var stoppedAt: Date? = Demo.shot == "save" ? Date() : nil
    @State private var wet = false

    var body: some View {
        let start = store.rideStart ?? Date()
        ScrollView {
            VStack(spacing: 10) {
                Text(store.currentBike?.name ?? "Ride")
                    .font(.headline)
                    .foregroundStyle(Brand.orange)
                if let end = stoppedAt {
                    let hours = max(0.1, (end.timeIntervalSince(start) / 360).rounded() / 10)
                    Text(String(format: "%.1f h", hours)).font(Brand.big(44))
                    Toggle("Wet or muddy", isOn: $wet)
                    Button {
                        store.save(hours: hours, wet: wet)
                    } label: {
                        Text("Save ride").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Brand.orange)
                    .foregroundStyle(.black)
                    Button("Keep riding") { stoppedAt = nil }
                    Button("Discard", role: .destructive) { store.endRide() }
                } else {
                    Text(start, style: .timer)
                        .font(Brand.big(44))
                        .monospacedDigit()
                    Text("Stop when you're done and the hours go into the service log on your iPhone.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button {
                        stoppedAt = Date()
                    } label: {
                        Label("Stop", systemImage: "stop.fill").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Brand.orange)
                    .foregroundStyle(.black)
                }
            }
            .padding(.horizontal, 4)
        }
        .background(Brand.pine.gradient, ignoresSafeAreaEdges: .all)
    }
}
