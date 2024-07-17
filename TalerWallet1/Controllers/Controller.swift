/*
 * This file is part of GNU Taler, ©2022-24 Taler Systems S.A.
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
    case termsExchange
    case pay
    case payPull
    case payPush
    case payTemplate
    case refund
}

// MARK: -
class Controller: ObservableObject {
    public static let shared = Controller()
    private let symLog = SymLogC()

    @Published var backendState: BackendState = .none       // only used for launch animation
    @Published var currencyTicker: Int = 0                  // updates whenever a new currency is added
    @Published var isConnected: Bool = true
    @AppStorage("useHaptics") var useHaptics: Bool = true   // extension mustn't define this, so it must be here
    @AppStorage("playSoundsI") var playSoundsI: Int = 1     // extension mustn't define this, so it must be here
    @AppStorage("playSoundsB") var playSoundsB: Bool = false
    @AppStorage("talerFontIndex") var talerFontIndex: Int = 0         // extension mustn't define this, so it must be here
    let hapticCapability = CHHapticEngine.capabilitiesForHardware()
    let logger = Logger(subsystem: "net.taler.gnu", category: "Controller")
    let player = AVQueuePlayer()
    let semaphore = AsyncSemaphore(value: 1)
    var currencyInfos: [CurrencyInfo]
    var exchanges: [Exchange]
    var messageForSheet: String? = nil

    private let monitor = NWPathMonitor()

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
        currencyInfos = []
        exchanges = []
//        checkInternetConnection()
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

    func info(for currency: String) -> CurrencyInfo? {
//        return CurrencyInfo.euro()              // Fake EUR instead of the real Currency
//        return CurrencyInfo.francs()            // Fake CHF instead of the real Currency
        for info in currencyInfos {
            if info.scope.currency == currency {
                return info
            }
        }
        logger.log("  ❗️ no info for \(currency)")
        return nil
    }
    func info(for currency: String, _ ticker: Int) -> CurrencyInfo {
        if ticker != currencyTicker {
            print("  ❗️Yikes - race condition while getting info for \(currency)")
        }
        return info(for: currency) ?? CurrencyInfo.zero(currency)
    }

    func hasInfo(for currency: String) -> Bool {
        for info in currencyInfos {
            if info.scope.currency == currency {
                return true
            }
        }
        logger.log("  ❗️ no info for \(currency)")
        return false
    }

    func checkInfo(for scope: ScopeInfo, model: WalletModel) {
        for info in currencyInfos {
            if info.scope == scope {
                return  // got it, nothing to do
            }
        }
        Task {
            if let baseUrl = scope.url {
                if exchange(for: baseUrl) == nil {
                    let exchange = try await model.getExchangeByUrl(url: baseUrl)
                    exchanges.append(exchange)
                }
            }
            let info = try await model.getCurrencyInfoM(scope: scope, delay: 0)
            await setInfo(info)
            logger.log("  ❗️info set for \(scope.currency)")
        }
    }

    @MainActor
    func getInfo(from exchangeBaseUrl: String, model: WalletModel) async throws -> CurrencyInfo? {
        let exchange = try await model.getExchangeByUrl(url: exchangeBaseUrl)
        let scopeInfo = exchange.scopeInfo
        if let info = info(for: scopeInfo.currency) {
            return info
        }
        let info = try await model.getCurrencyInfoM(scope: scopeInfo, delay: 0)
        await setInfo(info)
        return info
    }

    @MainActor
    func setInfo(_ newInfo: CurrencyInfo) async {
        await semaphore.wait()
        defer { semaphore.signal() }

        var replaced = false
        var newInfos = currencyInfos.map { currencyInfo in
            if currencyInfo.scope.currency == newInfo.scope.currency {
                replaced = true
                return newInfo
            } else {
                return currencyInfo
            }
        }
        if !replaced {
            newInfos.append(newInfo)
        }
        currencyInfos = newInfos
        currencyTicker += 1         // triggers published view update
    }
// MARK: -
    @MainActor
    func initWalletCore(_ model: WalletModel, setTesting: Bool)
      async throws {
        if backendState == .instantiated {
            backendState = .initing
            do {
                let versionInfo = try await model.initWalletCoreT(setTesting: setTesting)
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
            case "withdraw":
                return .withdraw
            case "withdraw-exchange":
                return .withdrawExchange
            case "terms-exchange":
                return .termsExchange
            case "pay":
                return .pay
            case "pay-pull":
                return .payPull
            case "pay-push":
                return .payPush
            case "pay-template":
                return .payTemplate
            case "refund":
                return .refund
            default:
                self.logger.error("unknown command taler://\(command)")
        }
        return .unknown
    }
}
