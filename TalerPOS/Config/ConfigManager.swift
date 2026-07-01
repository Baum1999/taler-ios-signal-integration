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

import Foundation
import Combine

private let kBackendApiVersion = "20:0:8"
private let kMerchantUrl = "merchantUrl"
private let kAccessToken = "accessToken"
private let kSavePassword = "savePassword"
private let kInitialOrderScreen = "initialOrderScreen"
private let kCachedRuntimeConfig = "cachedRuntimeConfig"

struct LibtoolVersion {
    let current: Int
    let revision: Int
    let age: Int

    static func parse(_ v: String) -> LibtoolVersion? {
        let parts = v.split(separator: ":")
        guard parts.count == 3,
              let c = Int(parts[0]), let r = Int(parts[1]), let a = Int(parts[2]) else { return nil }
        return LibtoolVersion(current: c, revision: r, age: a)
    }

    func isCompatible(with other: LibtoolVersion) -> Bool {
        current - age <= other.current && current >= other.current - other.age
    }
}

enum ConfigUpdateResult: Equatable {
    case success(currency: String)
    case error(String)
}

enum InitialOrderScreen: String, CaseIterable {
    case amountEntry = "amountEntry"
    case inventory = "inventory"

    var destination: PosDestination {
        switch self {
        case .amountEntry: return .amountEntry
        case .inventory: return .order
        }
    }
}

@MainActor
protocol ConfigurationReceiver: AnyObject {
    func onConfigurationReceived(posConfig: PosConfig, currency: String, currencySpec: CurrencySpecification?) -> String?
    func onInventoryUpdated(posConfig: PosConfig, currency: String, currencySpec: CurrencySpecification?) -> String?
}

extension ConfigurationReceiver {
    func onInventoryUpdated(posConfig: PosConfig, currency: String, currencySpec: CurrencySpecification?) -> String? {
        return onConfigurationReceived(posConfig: posConfig, currency: currency, currencySpec: currencySpec)
    }
}

private struct CachedRuntimeConfig: Codable {
    let posConfig: PosConfig
    let merchantConfig: MerchantConfig
    let currency: String
    let currencySpec: CurrencySpecification?
}

@MainActor
class ConfigManager: ObservableObject {
    @Published var merchantUrl: String
    @Published var accessToken: String
    @Published var savePassword: Bool

    @Published var merchantConfig: MerchantConfig?
    @Published var currency: String?
    @Published var currencySpec: CurrencySpecification?
    @Published var backendVersion: String?
    @Published var configResult: ConfigUpdateResult?
    @Published var isLoading = false
    @Published var sessionExpired = false
    @Published var initialOrderScreen: InitialOrderScreen

    let api: MerchantApi
    private let defaults = UserDefaults.standard
    private var configurationReceivers: [ConfigurationReceiver] = []
    private var inventoryRefreshTask: Task<Void, Never>?
    private var cachedRuntimeConfig: CachedRuntimeConfig?

    var isConfigured: Bool {
        merchantConfig != nil && currency != nil
    }

    var isValid: Bool {
        !merchantUrl.isEmpty && !accessToken.isEmpty
    }

    var hasPassword: Bool {
        !accessToken.isEmpty
    }

    init(api: MerchantApi) {
        self.api = api
        self.merchantUrl = defaults.string(forKey: kMerchantUrl) ?? ""
        self.accessToken = defaults.string(forKey: kAccessToken) ?? ""
        self.savePassword = defaults.object(forKey: kSavePassword) != nil ? defaults.bool(forKey: kSavePassword) : true
        self.initialOrderScreen = InitialOrderScreen(rawValue: defaults.string(forKey: kInitialOrderScreen) ?? "") ?? .amountEntry
        restoreCachedRuntimeConfig()
    }

    func addConfigurationReceiver(_ receiver: ConfigurationReceiver) {
        configurationReceivers.append(receiver)
        if let cached = cachedRuntimeConfig {
            _ = receiver.onConfigurationReceived(posConfig: cached.posConfig, currency: cached.currency, currencySpec: cached.currencySpec)
        }
    }

    func setInitialOrderScreen(_ screen: InitialOrderScreen) {
        initialOrderScreen = screen
        defaults.set(screen.rawValue, forKey: kInitialOrderScreen)
    }

    func fetchConfig(config: (url: String, token: String), save: Bool) {
        fetchConfigInternal(url: config.url, token: config.token, save: save, inventoryOnly: false, silent: false)
    }

    func fetchConfig(url: String, token: String, save: Bool) {
        fetchConfigInternal(url: url, token: token, save: save, inventoryOnly: false, silent: false)
    }

    func reloadConfig() {
        fetchConfigInternal(url: merchantUrl, token: accessToken, save: true, inventoryOnly: true, silent: false)
    }

    func refreshConfigInBackground() {
        guard isValid, hasPassword else { return }
        fetchConfigInternal(url: merchantUrl, token: accessToken, save: false, inventoryOnly: false, silent: true)
    }

    func refreshInventory() {
        inventoryRefreshTask?.cancel()
        inventoryRefreshTask = Task {
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self.fetchConfigInternal(url: self.merchantUrl, token: self.accessToken, save: false, inventoryOnly: true, silent: true)
            }
        }
    }

    private func fetchConfigInternal(url: String, token: String, save: Bool, inventoryOnly: Bool, silent: Bool) {
        guard !url.isEmpty, !token.isEmpty else { return }
        if !silent {
            isLoading = true
            configResult = nil
        }

        Task {
            do {
                let fullToken = token.hasPrefix("secret-token:") ? token : "secret-token:\(token)"
                let posConfig = try await api.fetchPosConfig(merchantUrl: url, accessToken: fullToken)
                let mc = MerchantConfig(baseUrl: url, apiKey: fullToken)
                let backendConfig = try await api.fetchBackendConfig(merchantConfig: mc)

                if let expected = LibtoolVersion.parse(kBackendApiVersion),
                   let actual = LibtoolVersion.parse(backendConfig.version),
                   !expected.isCompatible(with: actual) {
                    if !silent {
                        self.configResult = .error("Backend API version \(backendConfig.version) is incompatible (expected \(kBackendApiVersion)).")
                        self.isLoading = false
                    }
                    return
                }

                let spec = backendConfig.currencies?[backendConfig.currency]

                let posConfigWithCachedStock = applyCachedStockData(posConfig)

                for receiver in configurationReceivers {
                    let error: String?
                    if inventoryOnly {
                        error = receiver.onInventoryUpdated(posConfig: posConfigWithCachedStock, currency: backendConfig.currency, currencySpec: spec)
                    } else {
                        error = receiver.onConfigurationReceived(posConfig: posConfigWithCachedStock, currency: backendConfig.currency, currencySpec: spec)
                    }
                    if let error {
                        if !silent {
                            self.configResult = .error(error)
                            self.isLoading = false
                        }
                        return
                    }
                }

                if save {
                    self.merchantUrl = url
                    self.accessToken = token
                    self.saveConfig()
                }
                self.merchantConfig = mc
                self.currency = backendConfig.currency
                self.currencySpec = spec
                self.backendVersion = backendConfig.version
                self.saveCachedRuntimeConfig(CachedRuntimeConfig(
                    posConfig: posConfigWithCachedStock,
                    merchantConfig: mc,
                    currency: backendConfig.currency,
                    currencySpec: spec
                ))
                if !silent {
                    self.configResult = .success(currency: backendConfig.currency)
                    self.isLoading = false
                }

                await enrichStockDetails(posConfig: posConfig, merchantConfig: mc, currency: backendConfig.currency, currencySpec: spec)
            } catch let apiError as ApiError where apiError.isUnauthorized {
                self.forgetPassword()
                self.sessionExpired = true
                if !silent {
                    self.configResult = .error("Authentication error: check your access token.")
                    self.isLoading = false
                }
            } catch {
                if !silent {
                    self.configResult = .error(error.localizedDescription)
                    self.isLoading = false
                }
            }
        }
    }

    // MARK: - MFA Token Exchange

    /// Attempts to fetch a limited access token.
    /// Throws ChallengeRequiredError if MFA is needed.
    func fetchLimitedAccessToken(
        baseUrl: String,
        username: String,
        initialSecret: String,
        challengeIds: [String] = []
    ) async throws -> String {
        return try await api.fetchLimitedAccessToken(
            baseUrl: baseUrl,
            username: username,
            initialSecret: initialSecret,
            duration: .forever,
            challengeIds: challengeIds
        )
    }

    func requestChallenge(baseUrl: String, username: String, challengeId: String) async throws {
        try await api.requestChallenge(baseUrl: baseUrl, username: username, challengeId: challengeId)
    }

    func confirmChallenge(baseUrl: String, username: String, challengeId: String, tan: String) async throws {
        try await api.confirmChallenge(baseUrl: baseUrl, username: username, challengeId: challengeId, tan: tan)
    }

    func logout() {
        inventoryRefreshTask?.cancel()
        merchantUrl = ""
        accessToken = ""
        merchantConfig = nil
        currency = nil
        currencySpec = nil
        configResult = nil
        defaults.removeObject(forKey: kMerchantUrl)
        defaults.removeObject(forKey: kAccessToken)
        clearCachedRuntimeConfig()
    }

    func forgetPassword() {
        accessToken = ""
        merchantConfig = nil
        currency = nil
        currencySpec = nil
        defaults.removeObject(forKey: kAccessToken)
        clearCachedRuntimeConfig()
    }

    private func saveConfig() {
        defaults.set(merchantUrl, forKey: kMerchantUrl)
        if savePassword {
            defaults.set(accessToken, forKey: kAccessToken)
        } else {
            defaults.removeObject(forKey: kAccessToken)
        }
        defaults.set(savePassword, forKey: kSavePassword)
    }

    private func applyCachedStockData(_ posConfig: PosConfig) -> PosConfig {
        guard let cached = cachedRuntimeConfig else { return posConfig }
        let cachedByProductId = Dictionary(
            cached.posConfig.products.compactMap { p -> (String, ConfigProduct)? in
                guard let pid = p.productId else { return nil }
                return (pid, p)
            },
            uniquingKeysWith: { _, last in last }
        )
        var changed = false
        var products = posConfig.products
        for i in products.indices {
            guard let pid = products[i].productId,
                  let cachedProduct = cachedByProductId[pid] else { continue }
            if cachedProduct.totalSold == nil && cachedProduct.totalLost == nil &&
               cachedProduct.unitTotalSold == nil && cachedProduct.unitTotalLost == nil { continue }
            changed = true
            products[i] = ConfigProduct(
                id: products[i].id,
                productId: products[i].productId,
                productName: products[i].productName,
                description: products[i].description,
                descriptionI18n: products[i].descriptionI18n,
                price: products[i].price,
                pricesAreNet: products[i].pricesAreNet,
                location: products[i].location,
                image: products[i].image,
                taxes: products[i].taxes,
                categories: products[i].categories,
                quantity: products[i].quantity,
                totalStock: products[i].totalStock,
                unitTotalStock: products[i].unitTotalStock,
                totalSold: cachedProduct.totalSold,
                unitTotalSold: cachedProduct.unitTotalSold,
                totalLost: cachedProduct.totalLost,
                unitTotalLost: cachedProduct.unitTotalLost,
                availableToSell: products[i].availableToSell,
                remainingStock: products[i].remainingStock,
                currencyMismatch: products[i].currencyMismatch
            )
        }
        return changed ? PosConfig(categories: posConfig.categories, products: products) : posConfig
    }

    private func enrichStockDetails(posConfig: PosConfig, merchantConfig: MerchantConfig, currency: String, currencySpec: CurrencySpecification?) async {
        var enrichedProducts = posConfig.products
        var changed = false
        for (i, product) in enrichedProducts.enumerated() {
            guard let pid = product.productId, product.stockLimit != nil else { continue }
            do {
                let detail = try await api.fetchProductDetail(merchantConfig: merchantConfig, productId: pid)
                enrichedProducts[i] = ConfigProduct(
                    id: product.id,
                    productId: product.productId,
                    productName: product.productName,
                    description: product.description,
                    descriptionI18n: product.descriptionI18n,
                    price: product.price,
                    pricesAreNet: product.pricesAreNet,
                    location: product.location,
                    image: product.image,
                    taxes: product.taxes,
                    categories: product.categories,
                    quantity: product.quantity,
                    totalStock: product.totalStock,
                    unitTotalStock: product.unitTotalStock,
                    totalSold: detail.totalSold ?? product.totalSold,
                    unitTotalSold: detail.unitTotalSold ?? product.unitTotalSold,
                    totalLost: detail.totalLost ?? product.totalLost,
                    unitTotalLost: detail.unitTotalLost ?? product.unitTotalLost,
                    availableToSell: product.availableToSell,
                    remainingStock: product.remainingStock,
                    currencyMismatch: product.currencyMismatch
                )
                changed = true
            } catch {
                continue
            }
        }
        if changed {
            let enriched = PosConfig(categories: posConfig.categories, products: enrichedProducts)
            for receiver in configurationReceivers {
                _ = receiver.onInventoryUpdated(posConfig: enriched, currency: currency, currencySpec: currencySpec)
            }
            self.saveCachedRuntimeConfig(CachedRuntimeConfig(
                posConfig: enriched,
                merchantConfig: merchantConfig,
                currency: currency,
                currencySpec: currencySpec
            ))
        }
    }

    func restoreCachedRuntimeConfig() {
        guard isValid, hasPassword else {
            clearCachedRuntimeConfig()
            return
        }
        guard let data = defaults.data(forKey: kCachedRuntimeConfig) else { return }
        guard let restored = try? JSONDecoder().decode(CachedRuntimeConfig.self, from: data) else {
            clearCachedRuntimeConfig()
            return
        }
        cachedRuntimeConfig = restored
        merchantConfig = restored.merchantConfig
        currency = restored.currency
        currencySpec = restored.currencySpec
    }

    private func saveCachedRuntimeConfig(_ snapshot: CachedRuntimeConfig) {
        cachedRuntimeConfig = snapshot
        if let data = try? JSONEncoder().encode(snapshot) {
            defaults.set(data, forKey: kCachedRuntimeConfig)
        }
    }

    private func clearCachedRuntimeConfig() {
        cachedRuntimeConfig = nil
        defaults.removeObject(forKey: kCachedRuntimeConfig)
    }
}
