/*
 * This file is part of GNU Taler, ©2022-24 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import Foundation

public let MAXRECENT = 4
public let ICONLEADING = CGFloat(-8)
public let HSPACING = CGFloat(10)                  // space between items in HStack

public let LAUNCHDURATION: Double = 1.60
public let SLIDEDURATION: Double = 0.45

public let ONEDAY: UInt = 1         // 1..3
public let SEVENDAYS: UInt = 7      // 3..9
public let THIRTYDAYS: UInt = 30    // 10..30

public let EMPTYSTRING = ""                         // avoid automatic translation of empty "" textLiterals in Text()
public let NONBREAKING: Character = "\u{00A0}"
public let UNKNOWN = String(localized: "UNKNOWN", comment: "merchant didn't specify the currency, use ALL CAPS")


public let CONFIRM_BANK = "circle.fill"             // badge in PendingRow, TransactionRow and TransactionSummary
public let NEEDS_KYC = "star.fill"                  // badge in PendingRow, TransactionRow and TransactionSummary
//public let PENDING_INCOMING = "plus.diamond"      // 􀡿 􀢀
public let PENDING_INCOMING = "plus"                // 􀅼 􀢀
public let PENDING_OUTGOING = "minus.diamond"       // 􀢁 􀢂
public let DONE_INCOMING = "plus.circle.fill"       // 􀁌 􀁍
public let DONE_OUTGOING = "minus.circle"           // 􀁎 􀁏

public let ICONNAME_FILL = ".fill"
public let ICONNAME_DUMMY = "taler.circle"                          // 􀀀 􀀁
public let ICONNAME_WITHDRAWAL = "taler.down"                       // 􁾬 􁾭
public let ICONNAME_DEPOSIT = "taler.up"                            // 􁾨 􁾩
public let ICONNAME_REFUND = "taler.turn.up.backward"               // 􀰚 􀰛
public let ICONNAME_PAYMENT = "taler.turn.up.forward"               // 􀉐 􀰟
public let ICONNAME_INCOMING_P2P = "taler.backward"                 // 􁉈 􁉅
public let ICONNAME_OUTGOING_P2P = "taler.forward"                  // 􁉆 􁉇
public let ICONNAME_REFRESH = "taler.counterclockwise"              // 􁹠   no fill variant!
//public let ICONNAME_REFRESH1 = "arrow.counterclockwise.circle"    // 􀚃 􀚄
//public let ICONNAME_REFRESH2 = "arrow.counterclockwise.square"    // 􂅟 􂅠
public let ICONNAME_RECOUP = "taler.exclamationmark.circle"         // 􀁞 􀁟
public let ICONNAME_DENOMLOSS = "taler.exclamationmark.triangle"    // 􀇾 􀇿

public let HTTPS = "https://"
//public let DEMOBANK = HTTPS + "bAnK.dEmO.tAlEr.nEt"             // should be weird to read, but still work
//public let DEMOEXCHANGE = HTTPS + "eXcHaNgE.dEmO.tAlEr.nEt"
public let TALER = "taler.net/"
public let TALER_NET = HTTPS + TALER
public let DEMO = ".demo." + TALER
public let TEST = ".test." + TALER
public let HEAD = ".head." + TALER

public let SANDBOX = "instances/sandbox/"
public let DEMOBANK = HTTPS + "bank" + DEMO
public let DEMOSHOP = HTTPS + "shop" + DEMO
public let DEMOBACKEND = HTTPS + "backend" + DEMO + SANDBOX
public let DEMOEXCHANGE = HTTPS + "exchange" + DEMO
public let TESTBANK = HTTPS + "bank" + TEST
public let TESTSHOP = HTTPS + "shop" + TEST
public let TESTBACKEND = HTTPS + "backend" + TEST + SANDBOX
public let TESTEXCHANGE = HTTPS + "exchange" + TEST
public let HEADBANK = HTTPS + "bank" + HEAD
public let HEADSHOP = HTTPS + "shop" + HEAD
public let HEADBACKEND = HTTPS + "backend" + HEAD
public let HEADEXCHANGE = HTTPS + "exchange" + HEAD

public let ARS_AGE_EXCHANGE = HTTPS + "exchange-age.taler.ar/"
public let ARS_EXP_EXCHANGE = HTTPS + "exchange-expensive.taler.ar/"
public let DEMOCURRENCY = "KUDOS"
public let TESTCURRENCY = "TESTKUDOS"
//public let LONGCURRENCY = "gold-pressed Latinum"                // 20 characters, with dash and space
public let LONGCURRENCY = "GOLDLATINUM"                         // 11 characters, no dash, no space

// MARK: - Keys used in JSON

public let PLAINTEXT = "text/plain"
public let MARKDOWN = "text/markdown"
public let HTML = "text/html"

public let EXCHANGEBASEURL = "exchangeBaseUrl"
public let TALERURI = "talerUri"

public let TRANSACTIONTRANSITION = "transactionTransition"
public let TRANSACTIONID = "transactionID"

public let NOTIFICATIONERROR = "error"

/// Notifications sent by wallet-core
extension Notification.Name {
    static let Idle = Notification.Name("idle")
    static let BalanceChange = Notification.Name("balance-change")
    static let ExchangeAdded = Notification.Name("exchange-added")
    static let ExchangeDeleted = Notification.Name("exchange-deleted")
    static let ExchangeStateTransition = Notification.Name(ExchangeTransition.TransitionType.transition.rawValue)
    static let TransactionStateTransition = Notification.Name(TransactionTransition.TransitionType.transition.rawValue)
    static let TransactionDone = Notification.Name("transaction-done")
    static let TransactionExpired = Notification.Name("transaction-expired")
    static let PendingReady = Notification.Name("pending-ready")
    static let WaitReserve = Notification.Name("wait-reserve")
    static let WithdrawCoins = Notification.Name("withdraw-coins")
    static let KYCrequired = Notification.Name("kyc-required")
    static let DismissSheet = Notification.Name("dismiss-sheet")
    static let PendingOperationProcessed = Notification.Name("pending-operation-processed")
    static let ReserveNotYetFound = Notification.Name("reserve-not-yet-found")
//    static let WithdrawalGroupBankConfirmed = Notification.Name("withdrawal-group-bank-confirmed")
//    static let WithdrawalGroupReserveReady = Notification.Name("withdrawal-group-reserve-ready")
//    static let WithdrawGroupFinished = Notification.Name("withdraw-group-finished")
//    static let PayOperationSuccess = Notification.Name("pay-operation-success")
    static let ProposalAccepted = Notification.Name("proposal-accepted")
    static let ProposalDownloaded = Notification.Name("proposal-downloaded")
    static let TaskObservabilityEvent = Notification.Name("task-observability-event")
    static let RequestObservabilityEvent = Notification.Name("request-observability-event")

    static let Error = Notification.Name("error")
    static let TransactionError = Notification.Name("txError")
}

/// Notifications for internal synchronization
extension Notification.Name {
    static let BalanceReloaded = Notification.Name("balanceReloaded")
}
