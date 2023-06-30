/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import Foundation
import SwiftUI
import SymLog

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
    case pay
    case payPull
    case payPush
}

// MARK: -
class Controller: ObservableObject {
    public static let shared = Controller()
    private let symLog = SymLogC()

    @Published var backendState: BackendState = .none       // only used for launch animation
    @AppStorage("playSounds") var playSounds: Bool = false

    var messageForSheet: String? = nil

    init() {
        backendState = .instantiated
    }

    @MainActor
    func initWalletCore(_ model: WalletModel)
      async throws {
        if backendState == .instantiated {
            backendState = .initing
            do {
                let versionInfo = try await model.initWalletCoreT()
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
    func openURL(_ url:URL) -> UrlCommand {
        guard let scheme = url.scheme else {return UrlCommand.unknown}
        var uncrypted = false
        switch scheme {
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
        switch command {
            case "withdraw":
                return UrlCommand.withdraw
            case "pay":
                return UrlCommand.pay
            case "pay-pull":
                return UrlCommand.payPull
            case "pay-push":
                return UrlCommand.payPush
            default:
                symLog.log("unknown command taler://\(command)")
        }
        return UrlCommand.unknown
    }
}
