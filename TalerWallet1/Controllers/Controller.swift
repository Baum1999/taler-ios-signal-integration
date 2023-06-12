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
}

// MARK: -
class Controller: ObservableObject {
    public static let shared = Controller()
    private let symLog = SymLogC()

    @Published var backendState: BackendState = .none       // only used for launch animation

    var messageForSheet: String? = nil

    init() {
        backendState = .instantiated
    }

    @MainActor func initWalletCoreM()
      async throws {           // M for MainActor
        if backendState == .instantiated {
            backendState = .initing
            do {
                let walletInitModel = WalletInitModel()
                let versionInfo = try await walletInitModel.initWalletT()
                WalletCore.shared.versionInfo = versionInfo
                backendState = .ready                       // dismiss the launch animation
            } catch {       // rethrows
                symLog.log(error.localizedDescription)
                backendState = .error                       // TODO: ❗️Yikes app cannot continue
                throw error
            }
        } else {
            symLog.log("Yikes❗️ wallet-core already initialized")     // TODO: .warning
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
            default:
                symLog.log("unknown command taler://\(command)")
        }
        return UrlCommand.unknown
    }
}
