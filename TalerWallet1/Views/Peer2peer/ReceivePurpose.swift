/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import SwiftUI
import taler_swift
import SymLog

struct ReceivePurpose: View {
    private let symLog = SymLogV()
    @FocusState private var isFocused: Bool
    @State var peerPullCheck: CheckPeerPullCreditResponse?

    var scopeInfo: ScopeInfo
    var centsToTransfer: UInt64
    @Binding var purpose: String
    @Binding var expireDays: UInt
    var deactivateAction: () -> Void

    let formatter = CurrencyFormatter.shared    // TODO: based on currency

    let buttonFont: Font = .title2
    private var label: String {
        let mag = pow(10, formatter.maximumFractionDigits)
        return formatter.string(for: Decimal(centsToTransfer) / mag) ?? ""
    }

    func pullFee(ppCheck: CheckPeerPullCreditResponse?) -> String {
        do {
            if let p2pcheck = ppCheck {
                let fee = try p2pcheck.amountRaw - p2pcheck.amountEffective
                return fee.readableDescription
            }
        } catch {}
        return ""
    }

    var body: some View {
        let amount = Amount.amountFromCents(scopeInfo.currency, centsToTransfer)
        let model = Peer2peerModel.model(baseURL: scopeInfo.currency)

        let fee = pullFee(ppCheck: peerPullCheck)
        VStack (spacing: 6) {
            Text(amount.readableDescription)
            Text("+ \(fee) payment fee")
                .foregroundColor(.red)
            VStack(alignment: .leading, spacing: 6) {
                Text("Purpose:")
                    .padding(.top)
                    .font(.title3)

                TextField("Purpose", text: $purpose)
                    .font(.title)
                    .foregroundColor(WalletColors().fieldForeground)     // text color
                    .background(WalletColors().fieldBackground)
                    .border(.primary)
                    .focused($isFocused)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                            isFocused = true        // make first responder - raise keybord
                        }
                    }

                HStack{
                    Spacer()
                    Text("\(purpose.count)/100")
                } // maximum 100 characters

                Text("Expires in:")
                    .font(.title3)

                SelectDays(selected: $expireDays, maxExpiration: 35)
                    .disabled(false)
                    .padding(.bottom)

                let buttonTitle = "Invoice \(label) \(scopeInfo.currency)"
                let disabled = (expireDays == 0) || (purpose.count < 1)

                NavigationLink(destination: LazyView {
                    SendNow(amountToSend: amount, purpose: purpose, expireDays: expireDays, model: model)
                }) {
                    Text(buttonTitle)
                        .font(buttonFont)
                }
                .buttonStyle(TalerButtonStyle(type: .prominent))
                .disabled(disabled)

                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
        }
        .navigationTitle("Invoice another Wallet")
        .background(WalletColors().backgroundColor.edgesIgnoringSafeArea(.all))
        .onAppear {
            DebugViewC.shared.setSheetID(VIEW_INVOICE_PURPOSE)
            print("❗️ ReceivePurpose onAppear")
        }
        .onDisappear {
            print("❗️ ReceivePurpose onDisappear")
            deactivateAction()
        }
        .task {
            symLog.log(".task")
            do {
                peerPullCheck = try await model.checkPeerPullCreditM(amount, exchangeBaseUrl: scopeInfo.exchangeBaseUrl ?? nil)   // TODO: exchangeBaseUrl!
            } catch {    // TODO: error
                symLog.log(error.localizedDescription)
            }
        }
    }

}
// MARK: -
#if DEBUG
struct ReceivePurpose_Previews: PreviewProvider {
    static var previews: some View {
        let scopeInfo = ScopeInfo(type: ScopeInfo.ScopeInfoType.exchange, exchangeBaseUrl: DEMOEXCHANGE, currency: LONGCURRENCY)
        @State var purpose: String = "pUrPoSe"
        @State var expireDays: UInt = 0
        ReceivePurpose(scopeInfo: scopeInfo,
                 centsToTransfer: 5,
                         purpose: $purpose,
                      expireDays: $expireDays) {
            print("deactivateAction")
        }
    }
}
#endif
