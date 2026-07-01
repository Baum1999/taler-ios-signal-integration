/*
 * This file is part of GNU Taler
 * (C) 2026 Bohdan, Volodymyr Potuzhnyi
 *
 * GNU Taler is free software; you can redistribute it and/or modify it under the
 * terms of the GNU General Public License as published by the Free Software
 * Foundation; either version 3, or (at your option) any later version.
 *
 * GNU Taler is distributed in the hope that it will be useful, but WITHOUT ANY
 * WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
 * A PARTICULAR PURPOSE. See the GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along with
 * GNU Taler; see the file COPYING. If not, see <http://www.gnu.org/licenses/>
 */

import SwiftUI


@main
struct TalerPOSApp: App {
    @StateObject private var configManager: ConfigManager
    @StateObject private var orderManager: OrderManager
    @StateObject private var paymentManager: PaymentManager
    @StateObject private var historyManager: HistoryManager
    @StateObject private var refundManager: RefundManager
    @ObservedObject private var languageManager = LanguageManager.shared

    init() {
        let merchantApi = MerchantApi()
        let config = ConfigManager(api: merchantApi)
        let order = OrderManager()
        let payment = PaymentManager(api: merchantApi, configManager: config)
        let history = HistoryManager(api: merchantApi, configManager: config)
        let refund = RefundManager(api: merchantApi, configManager: config)

        config.addConfigurationReceiver(order)

        _configManager = StateObject(wrappedValue: config)
        _orderManager = StateObject(wrappedValue: order)
        _paymentManager = StateObject(wrappedValue: payment)
        _historyManager = StateObject(wrappedValue: history)
        _refundManager = StateObject(wrappedValue: refund)

        merchantApi.onUnauthorized = { [weak config] in
            Task { @MainActor in
                guard config?.merchantConfig != nil else { return }
                config?.forgetPassword()
                config?.sessionExpired = true
            }
        }
    }

    private func handleSetupUrl(_ url: URL) {
        guard url.scheme == "taler-pos", let host = url.host, !host.isEmpty else {
            configManager.configResult = .error("Invalid setup URL: missing scheme or host.")
            return
        }

        let pathSegments = url.pathComponents.filter { $0 != "/" }
        let pathStyleInstance: String? = {
            guard pathSegments.count >= 2,
                  pathSegments[0].caseInsensitiveCompare("instances") == .orderedSame,
                  !pathSegments[1].isEmpty else { return nil }
            return pathSegments[1]
        }()

        let fragment = url.fragment?.trimmingCharacters(in: CharacterSet(charactersIn: "/").union(.whitespaces)) ?? ""
        let params: [String: String]? = fragment.contains("=")
            ? Dictionary(uniqueKeysWithValues: fragment.split(separator: "&").compactMap { part in
                let kv = part.split(separator: "=", maxSplits: 1)
                guard kv.count == 2 else { return nil }
                return (String(kv[0]), String(kv[1]).removingPercentEncoding ?? String(kv[1]))
            })
            : nil

        let instance = pathStyleInstance ?? params?["username"]
        let token: String? = {
            if pathStyleInstance != nil {
                let decoded = fragment.removingPercentEncoding ?? fragment
                return decoded.isEmpty ? nil : decoded
            }
            return params?["password"]
        }()

        guard let instance, !instance.isEmpty, let token, !token.isEmpty else {
            configManager.configResult = .error("Invalid setup URL: missing instance or credentials.")
            return
        }

        var components = URLComponents()
        components.scheme = "https"
        components.host = host
        components.path = "/instances/\(instance)"
        guard let merchantUrl = components.url?.absoluteString else {
            configManager.configResult = .error("Invalid setup URL: could not build merchant URL.")
            return
        }

        configManager.savePassword = true
        configManager.fetchConfig(url: merchantUrl, token: token, save: true)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.locale, languageManager.locale)
                .id(languageManager.selectedLanguage)
                .environmentObject(configManager)
                .environmentObject(orderManager)
                .environmentObject(paymentManager)
                .environmentObject(historyManager)
                .environmentObject(refundManager)
                .onAppear {
                    if let scenario = ScreenshotController.activeScenario {
                        ScreenshotController.applyFixture(
                            configManager: configManager,
                            orderManager: orderManager,
                            paymentManager: paymentManager,
                            scenario: scenario
                        )
                    } else {
                        configManager.restoreCachedRuntimeConfig()
                        if configManager.isConfigured {
                            configManager.refreshConfigInBackground()
                        }
                    }
                }
                .onOpenURL { url in
                    handleSetupUrl(url)
                }
        }
    }
}
