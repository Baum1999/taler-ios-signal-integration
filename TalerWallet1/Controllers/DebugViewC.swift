/* MIT License
 * Copyright (c) 2023 Marc Stibane
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */
import SwiftUI
import SymLog
import os.log

// Numbering Scheme for Views
// MARK: - Main View
public let VIEW_EMPTY_WALLET = 10                                   // 10 WalletEmptyView
public let VIEW_BALANCES = VIEW_EMPTY_WALLET + 1                    // 11 BalancesListView
public let VIEW_SETTINGS = VIEW_BALANCES + 1                        // 12 SettingsView
public let VIEW_ABOUT = VIEW_SETTINGS + 1                           // 13 AboutView
public let VIEW_PAYMENT_SERVICES = VIEW_ABOUT + 1                   // 14 ExchangeListView

// MARK: Transactions
public let VIEW_EMPTY_HISTORY = VIEW_EMPTY_WALLET + 10              // 20 TransactionsEmptyView
public let VIEW_TRANSACTIONLIST = VIEW_EMPTY_HISTORY + 1            // 21 TransactionsListView
public let VIEW_TRANSACTIONSUMMARY = VIEW_TRANSACTIONLIST + 1       // 22 TransactionSummary
public let VIEW_TRANSACTIONDETAIL = VIEW_TRANSACTIONSUMMARY + 1     // 23 TransactionDetail


// MARK: - (Manual) Withdrawal (from Actions)
// receive coins from bank ==> shows payee, IBAN + Purpose/Subject for manual wire transfer
public let VIEW_WITHDRAWAL = VIEW_EMPTY_HISTORY + 10                // 30 WithdrawAmount
public let VIEW_WITHDRAW_TOS = VIEW_WITHDRAWAL + 1                  // 31 WithdrawTOSView
public let VIEW_WITHDRAW_ACCEPT = VIEW_WITHDRAW_TOS + 1             // 32 ManualWithdrawDone
public let VIEW_WITHDRAW_INSTRUCTIONS = VIEW_WITHDRAW_ACCEPT + 1    // 33 ManualDetailsWireV
public let VIEW_WITHDRAW_QRCODES = VIEW_WITHDRAW_INSTRUCTIONS + 1   // 34 QRcodesForPayto

// MARK: (Manual) Deposit (from Actions)
// send coins back to customer ==> instruct exchange to make the wire transfer to the customer's bank account
public let VIEW_DEPOSIT = VIEW_WITHDRAWAL + 10                      // 40 Deposit Coins
//public let VIEW_DEPOSIT_TOS                                       // - user already accepted the ToS at withdrawal, invoice or receive
public let VIEW_DEPOSIT_ACCEPT = VIEW_DEPOSIT + 2                   // 42

// MARK: Send (from Actions)
// push debit to another wallet ==> shows QR code to be scanned / link to be sent by mail or messenger
public let VIEW_P2P_SEND = VIEW_DEPOSIT + 10                        // 50 Send Coins
//public let VIEW_SEND_TOS                                          // - user already accepted the ToS at withdrawal, invoice or receive
public let VIEW_P2P_SUBJECT = VIEW_P2P_SEND + 2                     // 52 Send / Request Subject
public let VIEW_P2P_READY = VIEW_P2P_SUBJECT + 1                    // 53 Send / Request Ready

// MARK: Request (from Actions)
// pull credit from another wallet ==> shows QR code to be scanned / link to be sent by mail or messenger
public let VIEW_P2P_REQUEST = VIEW_P2P_SEND + 10                    // 60 Request Amount
public let VIEW_P2P_TOS = VIEW_P2P_REQUEST + 1                      // 61 Request ToS

// MARK: Business Invoice (from Actions)
// TBD
//public let VIEW_INVOICE_P2P = VIEW_REQUEST_P2P + 10                 // 70 Invoice Amount
//public let VIEW_INVOICE_TOS = VIEW_INVOICE_P2P + 1                  // 71 Invoice ToS
//public let VIEW_INVOICE_PURPOSE = VIEW_INVOICE_TOS + 1              // 72 Invoice Purpose


// MARK: - Bank-Integrated Withdrawal
// openURL (Link or scan QR) ==> obtains coins from bank
public let SHEET_WITHDRAWAL = VIEW_WITHDRAWAL + 100                 // 130 WithdrawURIView
public let SHEET_WITHDRAW_TOS = SHEET_WITHDRAWAL + 1                // 131 WithdrawTOSView
public let SHEET_WITHDRAW_ACCEPT = SHEET_WITHDRAW_TOS + 1           // 132 WithdrawAcceptView
public let SHEET_WITHDRAW_AUTHORIZE = SHEET_WITHDRAW_ACCEPT + 1     // 133 waiting for bank confirmation

public let SHEET_WITHDRAW_EXCHANGE = SHEET_WITHDRAWAL + 5           // 135 WithdrawExchangeV


// MARK: Merchant Payment
// openURL (Link, NFC or scan QR) ==> pays merchant
public let SHEET_PAYMENT = SHEET_WITHDRAWAL + 10                    // 140 Pay Merchant
public let SHEET_PAY_TEMPLATE = SHEET_PAYMENT + 1                   // 141 Pay Merchant Template
public let SHEET_PAY_TEMPL_AMOUNT = SHEET_PAY_TEMPLATE + 1          // 142 Pay Template Amount
public let SHEET_PAY_TEMPL_SUBJECT = SHEET_PAY_TEMPL_AMOUNT + 1     // 143 Pay Template Subject
public let SHEET_PAY_CONFIRM = SHEET_PAY_TEMPL_SUBJECT + 1          // 144 Pay Confirm

// MARK: Pay Request
// peer pull debit - openURL (Link or scan QR)
public let SHEET_PAY_P2P = SHEET_PAYMENT + 10                       // 150 Pay P2P Request
public let SHEET_PAY_P2P_CONFIRM = SHEET_PAY_P2P + 2                // 152 Pay P2P Confirm

// MARK: Receive
// peer push credit - openURL (Link or scan QR)
public let SHEET_RCV_P2P = SHEET_PAY_P2P + 10                       // 160 Receive Money
public let SHEET_RCV_P2P_TOS = SHEET_RCV_P2P + 1                    // 161 Receive TOSView
public let SHEET_RCV_P2P_ACCEPT = SHEET_RCV_P2P_TOS + 1             // 162 Receive AcceptView

// MARK: Refund - Get Coins back from merchant
// openURL (Link, NFC or scan QR) ==> receive coins from merchant
public let SHEET_REFUND = SHEET_RCV_P2P + 10                        // 170 Receive Refunds


// MARK: -
extension UIDevice {
    var hasNotch: Bool {
        let bottom = UIApplication.shared.keyWindow?.safeAreaInsets.bottom ?? 0
        return bottom > 0
    }
}
// MARK: -
struct DebugViewV: View {
    private let symLog = SymLogV(0)
    @EnvironmentObject private var debugViewC: DebugViewC

    var body: some View {
#if PRINT_CHANGES
//        let _ = Self._printChanges()
//        let _ = symLog.vlog()       // just to get the # to compare it with .onAppear & onDisappear
#endif
        let viewIDString = debugViewC.viewID > 0 ? String(debugViewC.viewID)
                                                 : EMPTYSTRING
        HStack {
            Spacer()
            Spacer()
            if UIDevice.current.hasNotch {
                Spacer()
                Spacer()
            }
            Text(viewIDString)
                .foregroundColor(.red)
                .font(.system(size: 11))        // no talerFont
                .monospacedDigit()
                .id("viewID")
            Spacer()
        }
        .accessibilityHidden(true)
        .edgesIgnoringSafeArea(.top)
    }
}
// MARK: -
class DebugViewC: ObservableObject {
    private let symLog = SymLogC(0)                         // 0 to switch off viewID change logging
    public static let shared = DebugViewC()
#if DEBUG
    @AppStorage("developerMode") var developerMode: Bool = true
#else
    @AppStorage("developerMode") var developerMode: Bool = false
#endif
    let logger = Logger(subsystem: "net.taler.gnu", category: "DebugView")

    @Published var viewID: Int = 0
    @Published var sheetID: Int = 0

//    func announce(_ this: String) {
//        if UIAccessibility.isVoiceOverRunning {
//            UIAccessibility.post(notification: .announcement, argument: this)
//        }
//    }

    @MainActor func setViewID(_ newID: Int, stack: CallStack) -> Void {
        if developerMode {
            if viewID == 0 {
                logger.log("switching ON, \(newID, privacy: .public)")
                viewID = newID                              // publish ON
//                announce("Current view is: \(newID).")
            } else if viewID != newID {
                logger.log("switching from \(self.viewID, privacy: .public) to \(newID, privacy: .public)")
//                announce("View switched from \(self.viewID) to \(newID).")
                viewID = newID                              // publish new viewID
            } else {
                logger.log("\(newID, privacy: .public) stays")
                // don't set viewID to the same value, it would just trigger an unneccessary redraw
            }
        } else {
            logger.log("view \(newID, privacy: .public)")
            if viewID > 0 {
                viewID = 0                                      // publish OFF
            }
        }
    }
    
    @MainActor func setSheetID(_ newID: Int) -> Void {
        if developerMode {
            if sheetID != newID {
                logger.log("sheet switching from \(self.sheetID, privacy: .public) to \(newID, privacy: .public)")
                sheetID = newID                             // publish new sheetID
            } else {
                logger.log("sheet \(newID, privacy: .public) stays")
                // don't set sheetID to the same value, it would just trigger an unneccessary redraw
            }
        } else {
            logger.log("sheet \(newID, privacy: .public)")
            if sheetID > 0 {
                // might happen after switching DevMode off, if sheetID still has the old value of the last sheet
                sheetID = 0                                     // publish OFF
            }
        }
    }
}
