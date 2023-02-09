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

struct PaymentAcceptView: View {
    private let symLog = SymLogV()
    @ObservedObject var viewModel: PaymentURIModel

    var detailsForAmount: PaymentDetailsForUri

//    @Environment(\.dismiss) var dismiss     // call dismiss() to get rid of the sheet
    let navTitle = "Accept Payment"
    var cancelButton: some View {
        Button("Cancel6") { dismissTop() }
    }

    @State var confirmPayResult: ConfirmPayResult?

    var body: some View {
        symLog { Group {
            let raw = detailsForAmount.amountRaw
            let effective = detailsForAmount.amountEffective
            let fee = try! Amount.diff(raw, effective)      // TODO: different currencies
            Form {
                AmountView(title: "Amount to pay:",
                           value: raw.readableDescription, color: Color(UIColor.label))
                .padding(.bottom)
                AmountView(title: "Exchange fee:",
                           value: fee.readableDescription, color: Color("Outgoing"))
                .padding(.bottom)
                AmountView(title: "Coins to be spent:",
                           value: effective.readableDescription, color: Color("Outgoing"))
            }
            AwesomeButton(title: "Accept") {
                Task {
                    do {
                        confirmPayResult = try await viewModel.confirmPay(detailsForAmount.proposalId)
                        symLog.log(confirmPayResult as Any)
                        if confirmPayResult?.type == "done" {
                            // TODO: Show Hints that Payment was successfull
                            // success
                        } else {
                            // TODO: show error
                        }
                    } catch {
                        symLog.log(error.localizedDescription)                // TODO: error
                    }
                    dismissTop()
                }
            }
        }
            .navigationBarItems(leading: cancelButton)
            .navigationTitle(navTitle)
        }
    }
}
