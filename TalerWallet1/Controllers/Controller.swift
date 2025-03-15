/*
 * This file is part of GNU Taler, ©2022-25 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * Controller
 *
 * @author Marc Stibane
 */
import Foundation
import AVFoundation
import SwiftUI
import SymLog
import os.log
import CoreHaptics
import Network

enum BackendState {
    case none
    case instantiated
    case initing
    case ready
    case error
}

enum UrlCommand {
    case unknown
    case withdraw
    case withdrawExchange
    case addExchange
    case pay
    case payPull
    case payPush
    case payTemplate
    case refund

    var isOutgoing: Bool {
        switch self {
            case .pay, .payPull, .payTemplate:
                true
            default:
                false
        }
    }
}

// MARK: -
class Controller: ObservableObject {
    public static let shared = Controller()
    private let symLog = SymLogC()

    @Published var balances: [Balance] = []

    @Published var backendState: BackendState = .none       // only used for launch animation
    @Published var currencyTicker: Int = 0                  // updates whenever a new currency is added
    @Published var isConnected: Bool = true
    @Published var oimModeActive: Bool = false
    @Published var diagnosticModeActive: Bool = false
    @AppStorage("useHaptics") var useHaptics: Bool = true   // extension mustn't define this, so it must be here
    @AppStorage("playSoundsI") var playSoundsI: Int = 1     // extension mustn't define this, so it must be here
    @AppStorage("playSoundsB") var playSoundsB: Bool = false
    @AppStorage("talerFontIndex") var talerFontIndex: Int = 0         // extension mustn't define this, so it must be here
    let hapticCapability = CHHapticEngine.capabilitiesForHardware()
    let logger = Logger(subsystem: "net.taler.gnu", category: "Controller")
    let player = AVQueuePlayer()
    let semaphore = AsyncSemaphore(value: 1)
    private var currencyInfos: [ScopeInfo : CurrencyInfo]
    var exchanges: [Exchange]
    var messageForSheet: String? = nil

    private let monitor = NWPathMonitor()

    private var oimModeObservation: NSKeyValueObservation?
    private var diagnosticModeObservation: NSKeyValueObservation?

    func startObserving() {
        let defaults = UserDefaults.standard
        self.oimModeObservation = defaults.observe(\.oimModeEnabled, options: [.new, .old, .prior, .initial]) { [weak self](_, _) in
            self?.oimModeActive = UserDefaults.standard.oimModeEnabled
        }
        self.diagnosticModeObservation = defaults.observe(\.diagnosticModeEnabled, options: [.new, .old,.prior,.initial]) {  [weak self](_, _) in
            self?.diagnosticModeActive = UserDefaults.standard.diagnosticModeEnabled
        }
    }

    func checkInternetConnection() {
        monitor.pathUpdateHandler = { path in
            let status = switch path.status {
                case .satisfied: "active"
                case .unsatisfied: "inactive"
                default: "unknown"
            }
            self.logger.log("Internet connection is \(status)")
#if false
            DispatchQueue.main.async {
                if path.status == .unsatisfied {
                    self.isConnected = false
                    Task.detached {
                        await WalletModel.shared.hintNetworkAvailabilityT(false)
                    }
                } else {
                    self.stopCheckingConnection()
                    self.isConnected = true
                    Task.detached {
                        await WalletModel.shared.hintNetworkAvailabilityT(true)
                    }
                }
            }
#endif
        }
        self.logger.log("Start monitoring internet connection")
        let queue = DispatchQueue(label: "InternetMonitor")
        monitor.start(queue: queue)
    }
    func stopCheckingConnection() {
        self.logger.log("Stop monitoring internet connection")
        monitor.cancel()
    }

    init() {
//        for family in UIFont.familyNames {
//            print(family)
//            for names in UIFont.fontNames(forFamilyName: family) {
//                print("== \(names)")
//            }
//        }
        backendState = .instantiated
        currencyTicker = 0
        currencyInfos = [:]
        exchanges = []
        balances = []
//        checkInternetConnection()
        startObserving()
    }
// MARK: -
    @MainActor
    @discardableResult
    func loadBalances(_ stack: CallStack,_ model: WalletModel) async -> Int? {
        if let reloaded = try? await model.getBalances(stack.push()) {
            if reloaded != balances {
                for balance in reloaded {
                    let scope = balance.scopeInfo
                    checkInfo(for: scope, model: model)
                }
                self.logger.log("••Got new balances, will redraw")
                balances = reloaded         // redraw
            } else {
                self.logger.log("••Same balances, no redraw")
            }
            return reloaded.count
        }
        return nil
    }

// MARK: -
    func exchange(for baseUrl: String) -> Exchange? {
        for exchange in exchanges {
            if exchange.exchangeBaseUrl == baseUrl {
                return exchange
            }
        }
        return nil
    }

    func info(for scope: ScopeInfo) -> CurrencyInfo? {
//        return CurrencyInfo.euro()              // Fake EUR instead of the real Currency
//        return CurrencyInfo.francs()            // Fake CHF instead of the real Currency
        return currencyInfos[scope]
    }
    func info(for scope: ScopeInfo, _ ticker: Int) -> CurrencyInfo {
        if ticker != currencyTicker {
            print("  ❗️Yikes - race condition while getting info for \(scope.currency)")
        }
        return info(for: scope) ?? CurrencyInfo.zero(scope.currency)
    }

    func info2(for currency: String) -> CurrencyInfo? {
//        return CurrencyInfo.euro()              // Fake EUR instead of the real Currency
//        return CurrencyInfo.francs()            // Fake CHF instead of the real Currency
        for (scope, info) in currencyInfos {
            if scope.currency == currency {
                return info
            }
        }
//        logger.log("  ❗️ no info for \(currency)")
        return nil
    }
    func info2(for currency: String, _ ticker: Int) -> CurrencyInfo {
        if ticker != currencyTicker {
            print("  ❗️Yikes - race condition while getting info for \(currency)")
        }
        return info2(for: currency) ?? CurrencyInfo.zero(currency)
    }

    func hasInfo(for currency: String) -> Bool {
        for (scope, info) in currencyInfos {
            if scope.currency == currency {
                return true
            }
        }
//        logger.log("  ❗️ no info for \(currency)")
        return false
    }

    @MainActor
    func exchange(for baseUrl: String?, model: WalletModel) async -> Exchange? {
        if let baseUrl {
            if let exchange1 = exchange(for: baseUrl) {
                return exchange1
            }
            if let exchange2 = try? await model.getExchangeByUrl(url: baseUrl) {
//                logger.log("  ❗️ will add \(baseUrl)")
                exchanges.append(exchange2)
                return exchange2
            }
        }
        return nil
    }

    @MainActor
    func updateInfo(_ scope: ScopeInfo, model: WalletModel) async {
        if let info = try? await model.getCurrencyInfo(scope: scope) {
            await setInfo(info, for: scope)
//            logger.log("  ❗️info set for \(scope.currency)")
        }
    }

    func checkCurrencyInfo(for baseUrl: String, model: WalletModel) async -> Exchange? {
        if let exchange = await exchange(for: baseUrl, model: model) {
            let scope = exchange.scopeInfo
            if currencyInfos[scope] == nil {
                logger.log("  ❗️got no info for \(baseUrl.trimURL) \(scope.currency) -> will update")
                await updateInfo(scope, model: model)
            }
            return exchange
        } else {
            // Yikes❗️  TODO: error?
        }
        return nil
    }

    /// called whenever a new currency pops up - will first load the Exchange and then currencyInfos
    func checkInfo(for scope: ScopeInfo, model: WalletModel) {
        if currencyInfos[scope] == nil {
            Task {
                let exchange = await exchange(for: scope.url, model: model)
                if let scope2 = exchange?.scopeInfo {
                    let exchangeName = scope2.url ?? "UNKNOWN"
                    logger.log("  ❗️got no info for \(scope.currency) -> will update \(exchangeName.trimURL)")
                    await updateInfo(scope2, model: model)
                } else {
                    logger.error("  ❗️got no info for \(scope.currency), and couldn't load the exchange info❗️")
                }
            }
        }
    }

    @MainActor
    func getInfo(from baseUrl: String, model: WalletModel) async throws -> CurrencyInfo? {
        let exchange = try await model.getExchangeByUrl(url: baseUrl)
        let scope = exchange.scopeInfo
        if let info = info(for: scope) {
            return info
        }
        let info = try await model.getCurrencyInfo(scope: scope, delay: 0)
        await setInfo(info, for: scope)
        return info
    }

    @MainActor
    func setInfo(_ newInfo: CurrencyInfo, for scope: ScopeInfo) async {
        await semaphore.wait()
        defer { semaphore.signal() }

        currencyInfos[scope] = newInfo
        currencyTicker += 1         // triggers published view update
    }
// MARK: -
    @MainActor
    func initWalletCore(_ model: WalletModel, setTesting: Bool)
      async throws {
        if backendState == .instantiated {
            backendState = .initing
            do {
                let versionInfo = try await model.initWalletCore(setTesting: setTesting)
                WalletCore.shared.versionInfo = versionInfo
                backendState = .ready                       // dismiss the launch animation
            } catch {       // rethrows
                self.logger.error("\(error.localizedDescription)")
                backendState = .error                       // ❗️Yikes app cannot continue
                throw error
            }
        } else {
            self.logger.fault("Yikes❗️ wallet-core already initialized")
        }
    }
}

// MARK: -
extension Controller {
    func openURL(_ url: URL, stack: CallStack) -> UrlCommand {
#if DEBUG
        symLog.log(url)
#else
        self.logger.trace("openURL(\(url))")
#endif
        guard let scheme = url.scheme else {return UrlCommand.unknown}
        var uncrypted = false
        switch scheme.lowercased() {
            case "taler+http":
                uncrypted = true
                fallthrough
            case "taler", "ext+taler", "web+taler":
                return talerScheme(url, uncrypted)
//            case "payto":
//                messageForSheet = url.absoluteString
//                return paytoScheme(url)
            default:
                self.logger.error("unknown scheme: <\(scheme)>")       // should never happen
        }
        return UrlCommand.unknown
    }
}
// MARK: -
extension Controller {
//    func paytoScheme(_ url:URL) -> UrlCommand {
//        let logItem = "scheme payto:// is not yet implemented"
//        // TODO: write logItem to somewhere in Debug section of SettingsView
//        symLog.log(logItem)        // TODO: symLog.error(logItem)
//        return UrlCommand.unknown
//    }
    
    func talerScheme(_ url:URL,_ uncrypted: Bool = false) -> UrlCommand {
        guard let command = url.host else {return UrlCommand.unknown}
        if uncrypted {
            self.logger.trace("uncrypted http: taler://\(command)")
            // TODO: uncrypted
        }
        switch command.lowercased() {
            case "withdraw":            return .withdraw
            case "withdraw-exchange":   return .withdrawExchange
            case "add-exchange":        return .addExchange
            case "pay":                 return .pay
            case "pay-pull":            return .payPull
            case "pay-push":            return .payPush
            case "pay-template":        return .payTemplate
            case "refund":              return .refund
            default:
                self.logger.error("❗️unknown command taler://\(command)")
        }
        return .unknown
    }
}
