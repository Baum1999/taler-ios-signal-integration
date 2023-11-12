/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import SwiftUI
import taler_swift
import SymLog

struct SendPurpose: View {
    private let symLog = SymLogV(0)
    let stack: CallStack

    let amountAvailable: Amount
    let amountToTransfer: Amount
    let fee: String
    @Binding var summary: String
    @Binding var expireDays: UInt
    @AppStorage("iconOnly") var iconOnly: Bool = false
    let navTitle = String(localized: "NavTitle_Send_Subject", defaultValue: "Subject", comment: "NavTitle for entering the subject for Send-Money")

    @State private var transactionStarted: Bool = false
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack (spacing: 6) {
            Text(amountToTransfer.readableDescription)              // TODO: curreny formatter
            Text("+ \(fee) payment fee")
                .accessibilityFont(.body)
                .foregroundColor(.red)
            VStack(alignment: .leading, spacing: 6) {
                if !iconOnly {
                    Text("Subject:")    // Purpose
                        .accessibilityFont(.title2)
                        .padding(.top)
                }
                if #available(iOS 16.0, *) {
                    TextField("Subject", text: $summary, axis: .vertical)
                        .accessibilityFont(.title2)
                        .lineLimit(2...)
                        .foregroundColor(WalletColors().fieldForeground)     // text color
                        .background(WalletColors().fieldBackground)
                        .textFieldStyle(.roundedBorder)
                        .focused($isFocused)
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                                isFocused = true        // make first responder - raise keybord
                            }
                        }
                } else {
                    TextField("Subject", text: $summary)
                        .accessibilityFont(.title)
//                        .lineLimit(2...5)   // lineLimit' is only available in iOS 16.0 or newer
                        .foregroundColor(WalletColors().fieldForeground)     // text color
                        .background(WalletColors().fieldBackground)
                        .textFieldStyle(.roundedBorder)
                        .focused($isFocused)
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                                isFocused = true        // make first responder - raise keybord
                            }
                        }
                } // #available

                HStack{
                    Spacer()
                    Text(verbatim: "\(summary.count)/100")
                        .accessibilityFont(.body)
                        .accessibilityValue("\(summary.count) characters of 100")
                } // maximum 100 characters

                // TODO: compute max Expiration day from peerPushCheck to disable 30 (and even 7)
                SelectDays(selected: $expireDays, maxExpiration: THIRTYDAYS)
                    .disabled(false)
                    .padding(.bottom)

                let disabled = (expireDays == 0) || (summary.count < 1)    // TODO: check amountAvailable
                NavigationLink(destination: LazyView {
                    SendDoneV(stack: stack.push(),
                       amountToSend: amountToTransfer,
                    amountToReceive: nil,
                            summary: summary,
                         expireDays: expireDays,
                 transactionStarted: $transactionStarted)
                }) {
                    Text("Send \(amountToTransfer.readableDescription) now", comment: "amountToTransfer")  // TODO: currency formatter
                }
                .buttonStyle(TalerButtonStyle(type: .prominent))
                .disabled(disabled)
                .accessibilityHint(disabled ? "enabled when subject and expiration are set" : EMPTYSTRING)

                Spacer()
            }
            .textFieldStyle(.roundedBorder)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
        }
        .navigationTitle(navTitle)
        .background(WalletColors().backgroundColor.edgesIgnoringSafeArea(.all))
        .onAppear {
            DebugViewC.shared.setViewID(VIEW_SEND_PURPOSE, stack: stack.push())
//            print("❗️ SendPurpose onAppear")
        }
        .onDisappear {
//            print("❗️ SendPurpose onDisappear")
        }
        .task {
            symLog.log(".task")
            do {

            } catch {    // TODO: error
                symLog.log(error.localizedDescription)
            }
        }
    }

}
// MARK: -
#if DEBUG
//struct SendPurpose_Previews: PreviewProvider {
//    static var previews: some View {
//        @State var summary: String = ""
//        @State var expireDays: UInt = 0
//        let amount = Amount(currency: LONGCURRENCY, integer: 10, fraction: 0)
//        SendPurpose(amountAvailable: amount,
//                   amountToTransfer: 543,
//                                fee: "0,43",
//                            summary: $summary,
//                         expireDays: $expireDays)
//    }
//}
#endif
