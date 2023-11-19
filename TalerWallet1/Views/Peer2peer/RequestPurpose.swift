/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import SwiftUI
import taler_swift
import SymLog

struct RequestPurpose: View {
    private let symLog = SymLogV(0)
    let stack: CallStack

    let amountToTransfer: Amount
    let fee: Amount?
    @Binding var summary: String
    @Binding var expireDays: UInt

    @EnvironmentObject private var controller: Controller
    @AppStorage("iconOnly") var iconOnly: Bool = false
    let navTitle = String(localized: "NavTitle_Request_Subject",
                       defaultValue: "Request", comment: "NavTitle for entering the subject for Request-Payment")

    @State private var transactionStarted: Bool = false
    @FocusState private var isFocused: Bool

    var body: some View {
        let currencyInfo = controller.info(for: amountToTransfer.currencyStr, controller.currencyTicker)
        ScrollView { VStack (spacing: 6) {
            Text(amountToTransfer.string(currencyInfo))
            if let fee {
                let feeStr = fee.string(currencyInfo)
                Text("+ \(feeStr) payment fee")
                    .foregroundColor(.red)
            }
            VStack(alignment: .leading, spacing: 6) {
                if !iconOnly {
                    Text("Subject:")
                        .accessibilityFont(.title3)
                        .padding(.top)
                }
                TextField("Subject", text: $summary)
                    .accessibilityFont(.title)
                    .foregroundColor(WalletColors().fieldForeground)     // text color
                    .background(WalletColors().fieldBackground)
                    .textFieldStyle(.roundedBorder)
                    .focused($isFocused)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                            isFocused = true        // make first responder - raise keybord
                        }
                    }

                HStack{
                    Spacer()
                    Text(verbatim: "\(summary.count)/100")
                } // maximum 100 characters

                SelectDays(selected: $expireDays, maxExpiration: THIRTYDAYS)
                    .disabled(false)
                    .padding(.bottom)

                let disabled = (expireDays == 0) || (summary.count < 1)
                NavigationLink(destination: LazyView {
                    SendDoneV(stack: stack.push(),
                       amountToSend: nil,
                    amountToReceive: amountToTransfer,
                            summary: summary,
                         expireDays: expireDays,
                 transactionStarted: $transactionStarted)
                }) {
                    Text("Request \(amountToTransfer.readableDescription)")     // TODO: formatter
//                        .accessibilityFont(buttonFont)
                }
                .buttonStyle(TalerButtonStyle(type: .prominent))
                .disabled(disabled)
                .accessibilityHint(disabled ? "enabled when subject and expiration are set" : EMPTYSTRING)

                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
        } } // ScrollVStack
        .navigationTitle(navTitle)
        .background(WalletColors().backgroundColor.edgesIgnoringSafeArea(.all))
        .onAppear {
            DebugViewC.shared.setViewID(VIEW_REQUEST_PURPOSE, stack: stack.push())
//            print("❗️ RequestPurpose onAppear")
        }
        .onDisappear {
//            print("❗️ RequestPurpose onDisappear")
        }
    }

}
// MARK: -
#if DEBUG
//struct RequestPurpose_Previews: PreviewProvider {
//    static var previews: some View {
//        let scopeInfo = ScopeInfo(type: .exchange, exchangeBaseUrl: DEMOEXCHANGE, currency: LONGCURRENCY)
//        @State var summary: String = "pUrPoSe"
//        @State var expireDays: UInt = 0
//        RequestPurpose(scopeInfo: scopeInfo,
//                 amountToReceive: 5,
//                             fee: "fee",
//                         summary: $summary,
//                      expireDays: $expireDays)
//    }
//}
#endif
