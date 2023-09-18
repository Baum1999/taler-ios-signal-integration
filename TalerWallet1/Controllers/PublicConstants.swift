/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import Foundation

public let LAUNCHDURATION: Double = 1.60
public let SLIDEDURATION: Double = 0.45

public let ONEDAY: UInt = 1         // 1..3
public let SEVENDAYS: UInt = 7      // 3..9
public let THIRTYDAYS: UInt = 30    // 10..30

public let HTTPS = "https://"
//public let DEMOBANK = HTTPS + "bAnK.dEmO.tAlEr.nEt"             // should be weird to read, but still work
//public let DEMOEXCHANGE = HTTPS + "eXcHaNgE.dEmO.tAlEr.nEt"
public let DEMOBANK = HTTPS + "bank.demo.taler.net"
public let DEMOSHOP = HTTPS + "shop.demo.taler.net"
public let DEMOBACKEND = HTTPS + "backend.demo.taler.net"
public let DEMOEXCHANGE = HTTPS + "exchange.demo.taler.net"
public let TESTBANK = HTTPS + "bank.test.taler.net"
public let TESTSHOP = HTTPS + "shop.test.taler.net"
public let TESTBACKEND = HTTPS + "backend.test.taler.net"
public let TESTEXCHANGE = HTTPS + "exchange.test.taler.net"
public let ARS_AGE_EXCHANGE = HTTPS + "exchange-age.taler.ar"
public let ARS_EXP_EXCHANGE = HTTPS + "exchange-expensive.taler.ar"
public let DEMOCURRENCY = "KUDOS"
//public let TESTCURRENCY = "TESTKUDOS"
public let TESTCURRENCY = "KUDOS"
//public let LONGCURRENCY = "gold-pressed Latinum"                // 20 characters, with dash and space
public let LONGCURRENCY = "GOLDLATINUM"                         // 11 characters, no dash, no space

// MARK: - Keys used in JSON

public let PLAINTEXT = "text/plain"
public let MARKDOWN = "text/markdown"

public let EXCHANGEBASEURL = "exchangeBaseUrl"
public let TALERURI = "talerUri"

public let TRANSACTIONTRANSITION = "transactionTransition"

/// Notifications sent by wallet-core
extension Notification.Name {
    static let BalanceChange = Notification.Name("balance-change")
    static let TransactionStateTransition = Notification.Name(TransactionTransition.TransitionType.transition.rawValue)
    static let ExchangeAdded = Notification.Name("exchange-added")
    static let PendingOperationProcessed = Notification.Name("pending-operation-processed")
    static let ReserveNotYetFound = Notification.Name("reserve-not-yet-found")
//    static let WithdrawalGroupBankConfirmed = Notification.Name("withdrawal-group-bank-confirmed")
//    static let WithdrawalGroupReserveReady = Notification.Name("withdrawal-group-reserve-ready")
//    static let WithdrawGroupFinished = Notification.Name("withdraw-group-finished")
//    static let PayOperationSuccess = Notification.Name("pay-operation-success")
    static let ProposalAccepted = Notification.Name("proposal-accepted")
    static let ProposalDownloaded = Notification.Name("proposal-downloaded")
}

/// Notifications for internal synchronization
extension Notification.Name {
    static let BalanceReloaded = Notification.Name("balanceReloaded")
}
