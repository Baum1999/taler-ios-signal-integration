/*
 * This file is part of GNU Taler
 * (C) 2022 Taler Systems S.A.
 *
 * GNU Taler is free software; you can redistribute it and/or modify it under the
 * terms of the GNU General Public License as published by the Free Software
 * Foundation; either version 3, or (at your option) any later version.
 *
 * GNU Taler is distributed in the hope that it will be useful, but WITHOUT ANY
 * WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
 * A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along with
 * GNU Taler; see the file COPYING.  If not, see <http://www.gnu.org/licenses/>
 */
import Foundation
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

class Controller: ObservableObject {
    public static var shared = Controller()
    private let symLog = SymLogC()

    @Published var backendState: BackendState = .none

    var walletCore: WalletCore
    var exchangeModel: ExchangeModel
    var balancesModel: BalancesModel
    var transactionsModel: TransactionsModel
    var pendingModel: PendingModel
    var withdrawURIModel: WithdrawURIModel
    var paymentURIModel: PaymentURIModel
//    @Published var withdrawTestModel: WithdrawTestModel

    var messageForSheet: String? = nil

    init() {
        symLog.log("init wallet-core")
        walletCore = try! WalletCore()          // will (and should) crash on failure
        symLog.log("wallet-core done")
        exchangeModel = ExchangeModel(walletCore: walletCore)
        balancesModel = BalancesModel(walletCore: walletCore)
        transactionsModel = TransactionsModel(walletCore: walletCore)
        pendingModel = PendingModel(walletCore: walletCore)
        withdrawURIModel = WithdrawURIModel(walletCore: walletCore)
        paymentURIModel = PaymentURIModel(walletCore: walletCore)
//      withdrawTestModel = WithdrawTestModel(walletCore: walletCore)
        symLog.log("models inited")
        backendState = .instantiated
    }

    @MainActor func initWalletCore() async throws {
        if backendState == .instantiated {
            backendState = .initing
            do {
                let walletInitModel = WalletInitModel(walletCore: walletCore)
                let versionInfo = try await walletInitModel.initWallet()
                walletCore.versionInfo = versionInfo
                backendState = .ready               // dismiss the launch animation
            } catch {
                backendState = .error
                throw error
            }
        } else {
            symLog.log("Yikes\(logSymbol(-1)) wallet-core already initialized")     // TODO: .warning
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
            print("uncrypted")
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
