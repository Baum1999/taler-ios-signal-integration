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
import SwiftUI
import taler_swift
import SymLog

struct WithdrawAcceptView: View {
    private let symLog = SymLogV()
    var url: URL
    @ObservedObject var model: WithdrawURIModel

//    @Environment(\.dismiss) var dismiss     // call dismiss() to get rid of the sheet
    let navTitle = "Accept Withdrawal"
    var cancelButton: some View {
        Button("Cancel4") { dismissTop() }
    }

    let detailsForAmount: WithdrawalDetailsForAmount
    let baseURL: String

    var body: some View {
        symLog { Group {
            switch model.withdrawState {
                case .receivedAmountDetails, .receivedTOS, .receivedTOSAck:
                    let raw = detailsForAmount.amountRaw
                    let effective = detailsForAmount.amountEffective
                    let fee = try! raw - effective
                    Form {
                        AmountView(title: "Chosen amount to withdraw:",
                                   value: raw.readableDescription, color: Color(UIColor.label))
                            .padding(.bottom)
                        AmountView(title: "Exchange fee:",
                                   value: "- " + fee.readableDescription, color: Color("Outgoing"))
                            .padding(.bottom)
                        AmountView(title: "Coins to be withdrawn:",
                                   value: effective.readableDescription, color: Color("Incoming"))
                    }
                    AwesomeButton(title: "Accept") {
                        Task {
                            do {
                                let bankConfirmationUrl = try await model.sendAcceptIntWithdrawal(baseURL, withdrawURL: url.absoluteString)
                                symLog.log(bankConfirmationUrl as Any)
                                // TODO: Show Hints that User should Confirm on bank website
                            } catch {
                                symLog.log(error.localizedDescription)
                            }
                            dismissTop()
                        }
                    }
                default:
                    ErrorView()
            }
        }
            .navigationBarItems(leading: cancelButton)
            .navigationTitle(navTitle)
        }
    }
}
