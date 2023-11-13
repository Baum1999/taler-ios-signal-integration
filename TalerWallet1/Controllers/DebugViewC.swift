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
public let VIEW_EMPTY = 10                                          // 10 WalletEmptyView
public let VIEW_BALANCES = VIEW_EMPTY + 1                           // 11 BalancesListView
public let VIEW_EXCHANGES = VIEW_BALANCES + 1                       // 12 ExchangeListView
public let VIEW_SETTINGS = VIEW_EXCHANGES + 1                       // 13 SettingsView
public let VIEW_ABOUT = VIEW_SETTINGS + 1                           // 14 AboutView
public let VIEW_PENDING = VIEW_ABOUT + 1                            // 15 PendingOpsListView

// MARK: Transactions
public let VIEW_TRANSACTIONLIST = VIEW_EMPTY + 10                   // 20 TransactionsListView
public let VIEW_TRANSACTIONDETAIL = VIEW_TRANSACTIONLIST + 1        // 21 TransactionDetail



// MARK: - Manual Withdrawal (from ExchangeList)
// receive coins from bank ==> shows IBAN + Purpose/Subject for manual wire transfer
public let VIEW_WITHDRAWAL = VIEW_TRANSACTIONLIST + 10              // 30 WithdrawAmount
public let VIEW_WITHDRAW_TOS = VIEW_WITHDRAWAL + 1                  // 31 WithdrawTOSView
public let VIEW_WITHDRAW_ACCEPT = VIEW_WITHDRAW_TOS + 1             // 32

// MARK: Manual Deposit (from ExchangeList)
// send coins back to bank account ==> orders exchange to make the wire transfer
public let VIEW_DEPOSIT = VIEW_WITHDRAWAL + 10                      // 40 Deposit Coins
//public let VIEW_DEPOSIT_TOS                                       // - user already accepted the ToS at withdrawal, invoice or receive
public let VIEW_DEPOSIT_ACCEPT = VIEW_DEPOSIT + 2                   // 42

// MARK: P2P Send Coins (from Balances)
// push debit to another wallet ==> shows QR code to be scanned / link to be sent by mail or messenger
public let VIEW_SEND_P2P = VIEW_DEPOSIT + 10                        // 50 Send Coins
//public let VIEW_SEND_TOS                                          // - user already accepted the ToS at withdrawal, invoice or receive
public let VIEW_SEND_PURPOSE = VIEW_SEND_P2P + 2                    // 52 Send Purpose

// MARK: P2P Private Receive (from Balances)
// pull credit from another wallet ==> shows QR code to be scanned / link to be sent by mail or messenger
public let VIEW_REQUEST_P2P = VIEW_SEND_P2P + 10                    // 60 Request Amount
public let VIEW_REQUEST_TOS = VIEW_REQUEST_P2P + 1                  // 61 Request ToS
public let VIEW_REQUEST_PURPOSE = VIEW_REQUEST_TOS + 1              // 62 Request Purpose

// MARK: P2P Business Invoice (from Balances)
// TBD
//public let VIEW_INVOICE_P2P = VIEW_REQUEST_P2P + 10                 // 70 Invoice Amount
//public let VIEW_INVOICE_TOS = VIEW_INVOICE_P2P + 1                  // 71 Invoice ToS
//public let VIEW_INVOICE_PURPOSE = VIEW_INVOICE_TOS + 1              // 72 Invoice Purpose


// MARK: - Bank-Integrated Withdrawal
// openURL (Link or scan QR) ==> obtains coins from bank
public let SHEET_WITHDRAWAL = VIEW_WITHDRAWAL + 100                 // 130 WithdrawURIView
public let SHEET_WITHDRAW_TOS = SHEET_WITHDRAWAL + 1                // 131 WithdrawTOSView
public let SHEET_WITHDRAW_ACCEPT = SHEET_WITHDRAW_TOS + 1           // 132 WithdrawAcceptView
public let SHEET_WITHDRAW_CONFIRM = SHEET_WITHDRAW_ACCEPT + 1       // 133 waiting for bank confirmation

// MARK: Merchant Payment
// openURL (Link, NFC or scan QR) ==> pays merchant
public let SHEET_PAYMENT = SHEET_WITHDRAWAL + 10                    // 140 Pay Merchant
public let SHEET_PAY_TEMPLATE = SHEET_PAYMENT + 2                   // 142 Pay Merchant Template

// MARK: P2P Pay Invoice
// p2p pull debit - openURL (Link or scan QR)
public let SHEET_PAY_P2P = SHEET_PAYMENT + 10                       // 150 Pay P2P Invoice
public let SHEET_PAY_P2P_ACCEPT = SHEET_PAY_P2P + 2                 // 152 Pay P2P AcceptView

// MARK: P2P Receive Coins
// p2p push credit - openURL (Link or scan QR)
public let SHEET_RCV_P2P = SHEET_PAY_P2P + 10                       // 160 Receive P2P Coins
public let SHEET_RCV_P2P_TOS = SHEET_RCV_P2P + 1                    // 161 Receive P2P TOSView
public let SHEET_RCV_P2P_ACCEPT = SHEET_RCV_P2P_TOS + 1             // 162 Receive P2P AcceptView

// MARK: Reward - Receive Coins (from merchant)
// openURL (Link, NFC or scan QR) ==> receive coins from merchant
public let SHEET_RCV_REWARD = SHEET_RCV_P2P + 10                    // 170 Receive Reward

public let SHEET_REFUND = SHEET_RCV_REWARD + 10                     // 180 Receive Refunds

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
#if DEBUG
//        let _ = Self._printChanges()
//        let _ = symLog.vlog()       // just to get the # to compare it with .onAppear & onDisappear
#endif
        let viewIDString = debugViewC.viewID > 0 ? String(debugViewC.viewID)
                                                 : ""
        HStack {
            Spacer()
            Spacer()
            if UIDevice.current.hasNotch {
                Spacer()
                Spacer()
            }
            Text(viewIDString)
                .foregroundColor(.red)
                .font(.system(size: 11))        // no accessibilityFont
                .monospacedDigit()
                .id("viewID")
                .accessibilityLabel(Text("View.ID.", comment: "AccessibilityLabel"))
                .accessibilityValue(viewIDString)
                .accessibilityHint("Shows which view you currently are on.")
            Spacer()
        }
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

    func announce(this: String) {
        if UIAccessibility.isVoiceOverRunning {
            UIAccessibility.post(notification: .announcement, argument: this)
        }
    }

    @MainActor func setViewID(_ newID: Int, stack: CallStack) -> Void {
        if developerMode {
            if viewID == 0 {
                logger.log("switching ON, \(newID, privacy: .public)")
                viewID = newID                              // publish ON
                announce(this: "Current view is: \(newID).")
            } else if viewID != newID {
                logger.log("switching from \(self.viewID, privacy: .public) to \(newID, privacy: .public)")
                announce(this: "View switched from \(self.viewID) to \(newID).")
                viewID = newID                              // publish new viewID
            } else {
                logger.log("\(newID, privacy: .public) stays")
                // don't set viewID to the same value, it would just trigger an unneccessary redraw
            }
        } else if viewID > 0 {
            logger.log("switching OFF, will not use \(newID, privacy: .public)")
            viewID = 0                                      // publish OFF
        } else {
            logger.log("off, will not use \(newID, privacy: .public)")
            // don't set viewID from 0 to 0 again, it would just trigger an unneccessary redraw
        }
    }
    
    @MainActor func setSheetID(_ newID: Int) -> Void {
        if developerMode {
            if sheetID != newID {
                logger.log("switching from \(self.sheetID, privacy: .public) to \(newID, privacy: .public) for sheet")
                sheetID = newID                             // publish new sheetID
            } else {
                logger.log("\(newID, privacy: .public) stays for sheet")
                // don't set sheetID to the same value, it would just trigger an unneccessary redraw
            }
        } else if sheetID > 0 {
            // might happen after switching DevMode off, if sheetID still has the old value of the last sheet
            logger.log("switching OFF, will not use \(newID, privacy: .public) for sheet")
            sheetID = 0                                     // publish OFF
        } else {
            logger.log("off, will not use \(newID, privacy: .public) for sheet")
            // don't set sheetID from 0 to 0 again, it would just trigger an unneccessary redraw
        }
    }
}
