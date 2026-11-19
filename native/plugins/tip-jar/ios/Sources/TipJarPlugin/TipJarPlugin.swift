import Foundation
import Capacitor
import StoreKit
import UIKit

// Plushbucket tip jar. Optional tips through Apple's in-app purchases (StoreKit 2).
// The tips are consumables that unlock nothing: Apple handles the payment and the app says thanks.
@objc(TipJarPlugin)
public class TipJarPlugin: CAPPlugin, CAPBridgedPlugin {
    public let identifier = "TipJarPlugin"
    public let jsName = "TipJar"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "products", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "purchase", returnType: CAPPluginReturnPromise)
    ]

    private var updates: Task<Void, Never>?
    private var cache: [String: Product] = [:]

    public override func load() {
        // Finish any tip that completed outside the app (e.g. after Ask to Buy or an interrupted purchase)
        updates = Task.detached {
            for await result in Transaction.updates {
                if case .verified(let t) = result { await t.finish() }
            }
        }
    }

    @objc func products(_ call: CAPPluginCall) {
        let ids = call.getArray("ids", String.self) ?? []
        Task { @MainActor in
            do {
                let list = try await Product.products(for: ids)
                for p in list { self.cache[p.id] = p }
                let out: [[String: Any]] = list.sorted { $0.price < $1.price }.map {
                    ["id": $0.id, "name": $0.displayName, "description": $0.description, "price": $0.displayPrice]
                }
                call.resolve(["products": out])
            } catch {
                call.reject(error.localizedDescription)
            }
        }
    }

    @objc func purchase(_ call: CAPPluginCall) {
        guard let id = call.getString("id") else {
            call.reject("No tip chosen")
            return
        }
        Task { @MainActor in
            do {
                var product = self.cache[id]
                if product == nil { product = try await Product.products(for: [id]).first }
                guard let p = product else {
                    call.reject("That tip isn't available right now")
                    return
                }
                let result: Product.PurchaseResult
                if #available(iOS 17.0, *), let scene = self.bridge?.viewController?.view.window?.windowScene {
                    result = try await p.purchase(confirmIn: scene)
                } else {
                    result = try await p.purchase()
                }
                switch result {
                case .success(let verification):
                    switch verification {
                    case .verified(let t):
                        await t.finish()
                        call.resolve(["result": "purchased"])
                    case .unverified(let t, _):
                        await t.finish()
                        call.resolve(["result": "failed"])
                    }
                case .userCancelled:
                    call.resolve(["result": "cancelled"])
                case .pending:
                    call.resolve(["result": "pending"])
                @unknown default:
                    call.resolve(["result": "failed"])
                }
            } catch {
                call.reject(error.localizedDescription)
            }
        }
    }
}
