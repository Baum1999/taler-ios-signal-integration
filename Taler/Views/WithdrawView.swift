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

struct TransferView: View {
    @ObservedObject var model: ManualTransferModel
    
    var body: some View {
        VStack {
            Text("Exchange is ready for withdrawal!")
            Text("To complete the process you need to wire \(self.model.details.amountRaw.readableDescription) to the exchange bank account.")
            HStack {
                Text("IBAN: ")
                Text(paytoUriGetIban(uri: self.model.paytoUri))
            }
            HStack {
                Text("Subject: ")
                Text(paytoUriGetSubject(uri: self.model.paytoUri))
            }
            HStack {
                Text("Chosen Amount: ")
                Text(self.model.details.amountRaw.readableDescription)
            }
            HStack {
                Text("Exchange: ")
                Text(self.model.exchange.exchangeBaseUrl)
            }
            Text("Make sure to use the correct subject, otherwise the money will not arrive in this wallet.")
        }
            .navigationTitle("Manual Transfer")
    }
}

struct PromptWithdrawView: View {
    @ObservedObject var model: PromptWithdrawModel
    
    var body: some View {
        VStack {
            NavigationLink("", isActive: $model.nav) {
                TransferView(model: model.manualTransferModel)
                    .onDisappear {
                        self.model.nav = false
                    }
            }
            if model.loading {
                ProgressView()
            } else {
                if model.tosAccepted {
                    Text("Withdraw")
                    Text(self.model.details.amountEffective.readableDescription)
                    Text("Chosen Amount")
                    Text(self.model.details.amountRaw.readableDescription)
                    Text("Fee")
                    Text("- \((try! self.model.details.amountRaw - self.model.details.amountEffective).readableDescription)")
                    Text("Exchange")
                    Text(model.exchange.name)
                    Button {
                        self.model.acceptWithdraw()
                    } label: {
                        Text("Confirm Withdraw")
                    }
                } else {
                    Text("Withdraw")
                    Text(self.model.details.amountEffective.readableDescription)
                    Text("Chosen Amount")
                    Text(self.model.details.amountRaw.readableDescription)
                    Text("Fee")
                    Text("- \((try! self.model.details.amountRaw - self.model.details.amountEffective).readableDescription)")
                    Text("Exchange")
                    Text(model.exchange.name)
                    NavigationLink(isActive: $model.navTos) {
                        VStack {
                            ScrollView {
                                Text(model.tosDetails!.content)
                            }
                            Button {
                                model.acceptTos()
                            } label: {
                                Text("Accept Terms of Service")
                            }
                        }
                            .navigationTitle("Review Terms of Service")
                    } label: {
                        Text("Review Terms")
                    }
                }
            }
        }
            .navigationTitle("Review Withdraw")
    }
}

struct WithdrawView: View {
    @ObservedObject var model: WithdrawModel
    @State var amount: String = ""
    
    var body: some View {
        VStack {
            NavigationLink("", isActive: $model.nav) {
                PromptWithdrawView(model: model.promptModel)
                    .onDisappear {
                        self.model.nav = false
                    }
            }
            if self.model.loading {
                ProgressView()
            } else {
                Button {
                    
                } label: {
                    Text("Scan Taler QR Code")
                }
                Text("Or transfer manually:")
                HStack {
                    TextField(model.exchange.currency, text: $amount)
                }
                Button {
                    // TODO: Handle when the user inputs a non-valid amount
                    model.getWithdrawDetails(amountStr: model.exchange.currency + ":" + amount)
                } label: {
                    Text("Check Fees")
                }
            }
        }
            .navigationTitle("Withdraw")
    }
}
