/*
 * This file is part of GNU Taler, ©2022-25 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import Foundation

#if TALER_WALLET
let TALER_LOGO = "taler-logo-2023-blue"
#elseif TALER_NIGHTLY
let TALER_LOGO = "taler-logo-2023-black"
#else   // GNU_TALER
let TALER_LOGO = "taler-logo-2023-red"
#endif
let TALER_LOGO_FULL = "taler-logo-full"
let TALER_LOGO_QR = "taler-logo-qr"
let EXCHANGE_LOGO = "Exchange-logo-blue"
let SWISS_QR = "swiss_qr"

#if DEBUG
public let TCDELAY = 12000
#else
public let TCDELAY = 5000               // 5 seconds delay after each network call
#endif
public let INVISIBLE = 0.001
public let MAXEXCHANGES = 1000          // per currency
public let CHF_4217 = "CHF"             // ISO-4217 Swiss Francs
public let EUR_4217 = "EUR"             // ISO-4217 Euro
public let HUF_4217 = "HUF"             // ISO-4217 Hungarian Forint

public let TAPPED = 3                   // how often you need to tap on the Actions button before it loses its label
public let DRAGGED = 2                  // #times to drag to stop the auto-dragging
public let DRAGDELAY = 0.5
public let DRAGDURATION = 0.45
public let DRAGSPEED = 0.1
public let MAXRECENT = 4                // # of rows in Recent Transactions
public let HALFDETENT = 0.666           // 2/3 height - in the rest is a (invisible) dismiss button, also for VoiceOver
public let FULLDETENT = 0.999           // leave 0.001 space for dismiss

public let ICONLEADING = CGFloat(-8)
public let HSPACING = CGFloat(10)                  // space between items in HStack

public let LAUNCHDURATION: Double = 1.60
public let BANNERDURATION: Double = 0.666

public let ONEDAY: UInt = 1         // 1..3
public let SEVENDAYS: UInt = 7      // 3..9
public let THIRTYDAYS: UInt = 30    // 10..30

public let EMPTYSTRING = ""                         // avoid automatic translation of empty "" textLiterals in Text()
public let SPACE = " "
public let SPACECHAR: Character = " "
public let NONBREAKING: Character = "\u{00A0}"
public let LINEFEED = "\n"
public let UNKNOWN = String(localized: "UNKNOWN", comment: "merchant didn't specify the currency, use ALL CAPS")
public let LINK = "link"                            // 􀉣                       1.0 (iOS 13)
public let MAPPIN = "mappin.and.ellipse"            // 􀎫                       1.0 (iOS 13)
public let HAMBURGER = "line.3.horizontal"          // 􀌇                       3.0 (iOS 15)
public let EXCLAMATION = "exclamationmark.circle"   // 􀁞                       1.0 (iOS 13)
public let WARNING = "exclamationmark.triangle"     // 􀇾                       1.0 (iOS 13)
public let CHEVRON = "chevron.forward"              // 􀯻  􀯶                     2.0 (iOS 14)   reverses for RTL
public let CHEVRON_UP = "chevron.up"                // 􀆇                       1.0 (iOS 13)

public let BANKNOTE = "banknote.fill"               // 􀮀                       2.0 (iOS 14)
public let MORE = "ellipsis"                        // 􀍠                       1.0 (iOS 13)
public let PLUS = "plus"                            // 􀅼                       1.0 (iOS 13)
public let XMARK = "xmark"                          // 􀆄                       1.0 (iOS 13)
public let LIGHT_OFF = "lightbulb"                  // 􀛭                       1.0 (iOS 13)
public let LIGHT_ON = "lightbulb.fill"              // 􀛮                       1.0 (iOS 13)
public let CHECKMARK = "checkmark"                  // 􀆅                       1.0 (iOS 13)
public let ARROW_TOP = "arrow.up.to.line"           // 􀄿                       1.0 (iOS 13)
public let ARROW_BOT = "arrow.down.to.line"         // 􀅀                       1.0 (iOS 13)
public let RELOAD = "arrow.clockwise"               // 􀅈                       1.0 (iOS 13)
public let COPY1 = "doc.on.doc"                     // 􀉁                       1.0 (iOS 13)
//public let COPY6 = "document.on.clipboard"        // 􀉃                       6.0 (iOS 18)
public let PASTE = "doc.on.clipboard"               // 􀉃                       1.0 (iOS 13)
public let SHARE = "square.and.arrow.up"            // 􀈂                       1.0 (iOS 13)
public let RETURN = "return"                        // 􀅇 􁂇                    1.0 (iOS 13)   reverses for RTL
public let MERCHANT14 = "handbag"                   // 􁞸                       2.0 (iOS 14)
public let MERCHANT17 = "storefront"                // 􁽇                       5.0 (iOS 17)


public let BALANCES = "chart.bar.xaxis"             // 􀣉                       2.0 (iOS 14)
public let SETTINGS = "gear"                        // 􀍟                       1.0 (iOS 13)
public let QRBUTTON = "qrcode.viewfinder"           // 􀎻                       1.0 (iOS 13)
public let QRCODE = "qrcode"                        // 􀖂                       1.0 (iOS 13)
public let NFCLOGO = "wave.3.right.circle"          // 􀭹                       2.0 (iOS 14)
public let NOTIFICATION1 = "bell"                   // 􀋙 􀋚                    1.0 (iOS 13)
public let NOTIFICATION2 = "bell.badge"             // 􀝖 􀝗                    2.0 (iOS 14)   reverses for RTL

public let CONFIRM_BANK = "circle.fill"             // 􀀁 badge in PendingRow, TransactionRow and TransactionSummary
public let NEEDS_KYC = "star.fill"                  // 􀋃 badge in PendingRow, TransactionRow and TransactionSummary
//public let PENDING_INCOMING = "plus.diamond"      // 􀡿 􀢀                    2.0 (iOS 14)
public let PENDING_INCOMING = "plus"                // 􀅼                       1.0 (iOS 13)
public let PENDING_OUTGOING = "minus.diamond"       // 􀢁 􀢂                    2.0 (iOS 14)
public let DONE_INCOMING = "plus.circle.fill"       // 􀁌 􀁍                    1.0 (iOS 13)
public let DONE_OUTGOING = "minus.circle"           // 􀁎 􀁏                    1.0 (iOS 13)

public let ICONNAME_FILL = ".fill"
public let ICONNAME_DUMMY = "taler.dummy"                           // 􀀀 􀀁
public let SYSTEM_DUMMY1 = "circle"                                 // 􀀀 􀀁    1.0 (iOS 13)

public let ICONNAME_WITHDRAWAL = "taler.withdrawal"                 // 􁾬 􁾭
public let SYSTEM_WITHDRAWAL5 = "arrowshape.down"                   // 􁾬 􁾭    5.0 (iOS 17)
public let FALLBACK_WITHDRAWAL = "arrow.down"                       // 􀄩       1.0 (iOS 13)   no fill variant!
//                             "arrow.down.to.line"                 //    􀅀    1.0 (iOS 13)

public let ICONNAME_BANK = "building.columns"                       // 􀤨 􀤩    2.0 (iOS 14)
public let ICONNAME_PERSON_SMALL = "person.small"                   // 􀉩 􀉪
public let ICONNAME_PERSON_BOTTOM = "person.bottom"                 // 􀉩 􀉪

public let ICONNAME_DEPOSIT = "taler.deposit"                       // 􁾨 􁾩
public let SYSTEM_DEPOSIT5 = "arrowshape.up"                        // 􁾨 􁾩    5.0 (iOS 17)
public let FALLBACK_DEPOSIT = "arrow.up"                            // 􀄨       1.0 (iOS 13)   no fill variant!
//                             "arrow.up.to.line"                   //    􀄿    1.0 (iOS 13)

public let ICONNAME_REFUND = "taler.refund"                         // 􀰚 􀰛
public let SYSTEM_REFUND2 = "arrowshape.turn.up.backward"           // 􀰚 􀰛    2.0 (iOS 14)
public let ICONNAME_PAYMENT = "taler.payment"                       // 􀉐 􀰟
public let SYSTEM_PAYMENT2 = "arrowshape.turn.up.forward"           // 􀉐 􀰟    2.0 (iOS 14)

public let ICONNAME_INCOMING = "taler.incoming"                     // 􁉈 􁉅
public let SYSTEM_INCOMING4 = "arrowshape.backward"                 // 􁉈 􁉅    4.0 (iOS 16)
public let FALLBACK_INCOMING = "arrow.backward"                     // 􀰌       2.0 (iOS 14)   no fill variant!
//                             "arrow.backward.to.line"             //    􁂊    3.0 (iOS 15)

public let ICONNAME_PERSON_LEFT = "person.left"                     // 􁒃
public let ICONNAME_PERSON_RIGHT = "person.right"                   // 􁒄

public let ICONNAME_OUTGOING = "taler.outgoing"                     // 􁉆 􁉇
public let SYSTEM_OUTGOING4 = "arrowshape.forward"                  // 􁉆 􁉇    4.0 (iOS 16)
public let FALLBACK_OUTGOING = "arrow.forward"                      // 􀰑       2.0 (iOS 14)   no fill variant!
//                             "arrow.forward.to.line"              //    􁂎    3.0 (iOS 15)

public let ICONNAME_REFRESH = "taler.refresh"                       // 􀎀 􁣛
public let SYSTEM_REFRESH6 = "arrow.trianglehead.counterclockwise"  // 􀎀       6.0 (iOS 18)
public let SYSTEM_REFRESH6_fill = "checkmark.arrow.trianglehead.counterclockwise"  // 􁣛       6.0 (iOS 18)
public let FALLBACK_REFRESH = "arrow.counterclockwise"              // 􁹠       1.0 (iOS 13)   no fill variant!
//public let SYSTEM_REFRESH1 = "arrow.counterclockwise.circle"    // 􀚃 􀚄
//public let SYSTEM_REFRESH2 = "arrow.counterclockwise.square"    // 􂅟 􂅠
public let ICONNAME_RECOUP = "taler.recoup"                         // 􀁞 􀁟
public let SYSTEM_RECOUP1 = "exclamationmark.circle"                // 􀁞 􀁟    1.0 (iOS 13)
public let ICONNAME_DENOMLOSS = "taler.denomloss"                   // 􀇾 􀇿
public let SYSTEM_DENOMLOSS1 = "exclamationmark.triangle"           // 􀇾 􀇿    1.0 (iOS 13)

public let ICONNAME_ZOOM_IN = "taler.left.and.right.fill"           // 􀟦       3.0 (iOS 15)
public let ICONNAME_ZOOM_OUT = "taler.right.and.left.fill"          // 􀟧       3.0 (iOS 15)
public let SYSTEM_ZOOM_IN = "arrowtriangle.left.and.line.vertical.and.arrowtriangle.right.fill"   // 􀟦   3.0 (iOS 15)
public let SYSTEM_ZOOM_OUT = "arrowtriangle.right.and.line.vertical.and.arrowtriangle.left.fill"  // 􀟧   3.0 (iOS 15)

public let ICONNAME_LOCKCLOCK = "taler.lock.clock"                  // 􂆉
public let SYSTEM_LOCKCLOCK = "lock.badge.clock"                    // 􂆉       5.0 (iOS 17)
public let FALLBACK_LOCK = "lock"                                   // 􀎠       1.0 (iOS 13)

public let ICONNAME_PASSES = "taler.calendar.badge.record"          // 􀉉􀢙     2.0 (iOS 14)
public let SYSTEM_PASSES = "calendar.badge.clock"                   // 􀧞       2.0 (iOS 14)
public let ICONNAME_DISCOUNTS = "taler.percent.seal"                // 􀟆􀘾
public let SYSTEM_DISCOUNTS = "percent"                             // 􀘾       1.0 (iOS 14)

public let SUNFILL = "sun.max.fill"                                 // 􀆮       1.0 (iOS 13)
public let MOONFILL = "moon.fill"                                   // 􀆺       1.0 (iOS 13)

public let HTTPS = "https://"
public let TALER = "taler.net"
public let DEMO = ".demo." + TALER
public let TEST = ".test." + TALER
public let HEAD = ".head." + TALER

public let SANDBOX = "/instances/sandbox/"
public let EXCHANGE = "exchange"
public let BACKEND = "backend"
public let BANK = "bank"
public let SHOP = "shop"
public let DEMOBANK = HTTPS + BANK + DEMO + "/"
public let DEMOSHOP = HTTPS + SHOP + DEMO
public let DEMOBACKEND = HTTPS + BACKEND + DEMO + SANDBOX
public let DEMOEXCHANGE = HTTPS + EXCHANGE + DEMO + "/"
public let TESTBANK = HTTPS + BANK + TEST + "/"
public let TESTSHOP = HTTPS + SHOP + TEST
public let TESTBACKEND = HTTPS + BACKEND + TEST + SANDBOX
public let TESTEXCHANGE = HTTPS + EXCHANGE + TEST + "/"
public let HEADBANK = HTTPS + BANK + HEAD + "/"
public let HEADSHOP = HTTPS + SHOP + HEAD
public let HEADBACKEND = HTTPS + BACKEND + HEAD + "/"
public let HEADEXCHANGE = HTTPS + EXCHANGE + HEAD + "/"

public let ARS_AGE_EXCHANGE = HTTPS + "exchange-age.taler.ar/"
public let ARS_EXP_EXCHANGE = HTTPS + "exchange-expensive.taler.ar/"
public let DEMOCURRENCY = "KUDOS"
public let TESTCURRENCY = "TESTKUDOS"
//public let LONGCURRENCY = "gold-pressed Latinum"                // 20 characters, with dash and space
public let LONGCURRENCY = "GOLDLATINUM"                         // 11 characters, no dash, no space

// MARK: - Titles

public let TITLE_EXCHANGES = String(localized: "TitleExchanges", defaultValue: "Payment Services")

// MARK: - Keys used in JSON

public let PLAINTEXT = "text/plain"
public let MARKDOWN = "text/markdown"
public let HTML = "text/html"

public let EXCHANGEBASEURL = "exchangeBaseUrl"
public let TALERURI = "talerUri"

public let TRANSACTIONTRANSITION = "transactionTransition"
public let TRANSACTIONID = "transactionID"

public let NOTIFICATIONTIME = "notif.time"
public let NOTIFICATIONERROR = "notif.error"
public let NOTIFICATIONPHASE = "notif.phase"
public let NOTIFICATIONANIMATION = "notif.animation"
public let NOTIFICATIONSHARE = "notif.share"
public let NOTIFICATIONPASTE = "notif.paste"
public let NOTIFICATIONPAYLOAD = "notif.payload"

/// Notifications sent by wallet-core
extension Notification.Name {
    static let Idle = Notification.Name("idle")
    static let BalanceChange = Notification.Name("balance-change")
    static let BankAccountChange = Notification.Name(AccountChange.TransitionType.change.rawValue)
    static let DatabaseMaintenance = Notification.Name("database-maintenance-progress")
    static let ExchangeAdded = Notification.Name("exchange-added")
    static let ExchangeDeleted = Notification.Name("exchange-deleted")
    static let ExchangeStateTransition = Notification.Name("exchange-state-transition")
    static let RequestProgressPhase = Notification.Name("request-progress-phase")
    static let RequestProgressError = Notification.Name("request-progress-error")
    static let TransactionStateTransition = Notification.Name("transaction-state-transition")
    static let TransactionDone = Notification.Name("transaction-done")
    static let TransactionExpired = Notification.Name("transaction-expired")
    static let TransactionDeleted = Notification.Name("transaction-deleted")
    static let TransactionScanned = Notification.Name("transaction-scanned")
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

    static let GeneralError = Notification.Name("error")
    static let TransactionError = Notification.Name("txError")
}

/// Notifications for internal synchronization
extension Notification.Name {
    static let SendAction = Notification.Name("sendAction")
    static let RequestAction = Notification.Name("requestAction")
    static let DepositAction = Notification.Name("depositAction")
    static let WithdrawAction = Notification.Name("withdrawAction")
    static let QrScanAction = Notification.Name("qrScanAction")
    static let SettingsAction = Notification.Name("settingsAction")
    static let ShareAction = Notification.Name("shareAction")
    static let PasteAction = Notification.Name("pasteAction")
}
