/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import Foundation
import AVFoundation
import SwiftUI
import SymLog
import os.log
import CoreHaptics

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
    case pay
    case payPull
    case payPush
    case payTemplate
    case refund
    case reward
}

// MARK: -
class Controller: ObservableObject {
    public static let shared = Controller()
    private let symLog = SymLogC()

    @Published var backendState: BackendState = .none       // only used for launch animation
    @Published var currencyTicker: Int = 0                  // updates whenever a new currency is added
    @AppStorage("useHaptics") var useHaptics: Bool = true   // extension mustn't define this, so it must be here
    @AppStorage("playSoundsI") var playSoundsI: Int = 1     // extension mustn't define this, so it must be here
    @AppStorage("playSoundsB") var playSoundsB: Bool = true
    @AppStorage("talerFont") var talerFont: Int = 0         // extension mustn't define this, so it must be here
    let hapticCapability = CHHapticEngine.capabilitiesForHardware()
    let logger = Logger(subsystem: "net.taler.gnu", category: "Controller")
    let player = AVQueuePlayer()
    let semaphore = AsyncSemaphore(value: 1)
    var currencyInfos: [CurrencyInfo]

    var messageForSheet: String? = nil

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
    }
// MARK: -
    func hasInfo(for currency: String) -> CurrencyInfo? {
        for info in currencyInfos {
            if info.scope.currency == currency {
                return info
            }
        }
        return nil
    }

    func info(for currency: String) -> CurrencyInfo? {
//        return CurrencyInfo.euro()            // FAKE EURO instead of the real Currency
        for info in currencyInfos {
            if info.scope.currency == currency {
                return info
            }
        }
        return nil
    }
    func info(for currency: String, _ ticker: Int) -> CurrencyInfo {
        if ticker != currencyTicker {
            print("❗️Yikes")
        }
        return info(for: currency) ?? CurrencyInfo.zero(currency)
    }

    @MainActor
    func getInfo(from exchangeBaseUrl: String, model: WalletModel) async -> CurrencyInfo? {
        if let exchange = await model.getExchangeByUrl(url: exchangeBaseUrl) {
//            let scopeInfo = exchange.scopeInfo
//            if let info = hasInfo(for: scopeInfo.currency) {
//                return info
//            }
//            do {
//                let info = try await model.getCurrencyInfoM(scope: scopeInfo, delay: 0)
//                await setInfo(info)
//                return info
//            } catch {
//                return nil
//            }

            if let scopeInfo = exchange.scopeInfo {
                if let info = hasInfo(for: scopeInfo.currency) {
                    return info
                }
                do {
                    let info = try await model.getCurrencyInfoM(scope: scopeInfo, delay: 0)
                    await setInfo(info)
                    return info
                } catch {
                    return nil
                }
            } else {
                // TODO: Error "Can't get scopeInfo"
            }
        } else {
            // TODO: Error "Can't get Exchange Info"
        }
        return nil
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
    func initWalletCore(_ model: WalletModel, sqlite3: Bool)
      async throws {
        if backendState == .instantiated {
            backendState = .initing
            do {
                let versionInfo = try await model.initWalletCoreT(sqlite3: sqlite3)
                WalletCore.shared.versionInfo = versionInfo
                backendState = .ready                       // dismiss the launch animation
            } catch {       // rethrows
                symLog.log(error.localizedDescription)      // TODO: .error
                backendState = .error                       // ❗️Yikes app cannot continue
                throw error
            }
        } else {
            symLog.log("Yikes❗️ wallet-core already initialized")     // TODO: .fault
        }
    }
}

// MARK: -
extension Controller {
    func openURL(_ url: URL, stack: CallStack) -> UrlCommand {
        symLog.log(url)
        guard let scheme = url.scheme else {return UrlCommand.unknown}
        var uncrypted = false
        switch scheme.lowercased() {
            case "taler+http":
                uncrypted = true
                fallthrough
            case "taler", "ext+taler", "web+taler":
                return talerScheme(url, uncrypted)
            case "payto":
                messageForSheet = url.absoluteString
                return paytoScheme(url)
            default:
                symLog.log("unknown scheme: <\(scheme)>")       // should never happen
        }
        return UrlCommand.unknown
    }
}
// MARK: -
extension Controller {
    func paytoScheme(_ url:URL) -> UrlCommand {
        let logItem = "scheme payto:// is not yet implemented"
        // TODO: write logItem to somewhere in Debug section of SettingsView
        symLog.log(logItem)        // TODO: symLog.error(logItem)
        return UrlCommand.unknown
    }
    
    func talerScheme(_ url:URL,_ uncrypted: Bool = false) -> UrlCommand {
        guard let command = url.host else {return UrlCommand.unknown}
        if uncrypted {
            symLog.log("uncrypted: taler://\(command)")
            // TODO: uncrypted
        }
        switch command.lowercased() {
            case "withdraw":
                return .withdraw
            case "withdraw-exchange":
                return .withdrawExchange
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
                symLog.log("unknown command taler://\(command)")
        }
        return .unknown
    }
}
