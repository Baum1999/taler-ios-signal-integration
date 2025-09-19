/*
 * This file is part of GNU Taler, ©2022-25 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import SwiftUI
import taler_swift

@available(iOS 16.4, *)
struct HistoryDetailView: View {
    let stack: CallStack
    let currency: OIMcurrency
    let balance: Double
    let talerTX: TalerTransaction
    let effective: Amount

    @StateObject private var cash: OIMcash
    @State var amountVal: UInt64 = 0
    @Namespace var namespace

    init(stack: CallStack,
      currency: OIMcurrency,
       balance: Double,
       talerTX: TalerTransaction
    ) {
        self.stack = stack
        self.currency = currency
        self.balance = balance
        self.talerTX = talerTX
        let oimCash = OIMcash(currency)
        self._cash = StateObject(wrappedValue: { oimCash }())
        let common = talerTX.common
        let eff = common.amountEffective
        self.effective = eff
        let cents = eff.centValue
        self._amountVal = State(wrappedValue: { cents }())
//        print("ChartOverlayV init:", cents)
    }

    var imageID: String? {
        switch talerTX {
            case .peer2peer(let p2pTransaction):
                return p2pTransaction.details.info.iconId
            default:
                break
        }
        return nil
    }

    var body: some View {
        // TODO: hero animation from index
        VStack {
            Spacer()
            let balance2 =  balance * Double(currency.factor)
            let incoming = talerTX.common.isIncoming
            VStack {
                VStack(alignment: .trailing) {
                    HStack {
                        if let imageID {
                            Image(imageID)
                                .resizable()
                                .background(Color.white)
                                .scaledToFit()
                            //                          .matchedGeometryEffect(id: imageID, in: wrapper.namespace)
                                .padding(.horizontal)
                        }
                        VStack(alignment: .trailing) {
                            Text("Balance: \(balance2.pTwo)")
                                .foregroundStyle(WalletColors().gray2)
                            Spacer()
                            OIMamountV(amount: effective, currencyName: currency.currencyStr,
                                       factor: currency.factor, mayChangeSpeed: false)
                        }
                    }
                }
                OIMlineView(stack: stack.push(),
                             cash: cash,
                        amountVal: $amountVal,
                          canEdit: false)
//                .opacity(isOpen ? 1 : INVISIBLE)
//                .scaleEffect(scaleMoney ? 0.6 : 1)
            }.environmentObject(NamespaceWrapper(namespace))         // keep OIMviews apart
            .padding()
            .onAppear {
                cash.update2(amountVal)             // set cash to talerTX.common.effective
            }
            .onChange(of: effective) { newVal in
                print("ChartOverlayV onChange of:", newVal)
                let cents = newVal.centValue
                cash.update2(cents)                 // set cash to talerTX.common.effective
            }
            .background(
                RoundedRectangle(cornerRadius: 30)
                .style(
                    withStroke: Color.primary,
                    lineWidth: 2,
                    fill: LinearGradient(
//                        gradient: Gradient(colors: [WalletColors().talerColor, .white]),
                        gradient: Gradient(colors: [WalletColors().transactionColor(incoming), .white]),
                      startPoint: .top,
                        endPoint: .bottom
                    ).opacity(0.85)
                )
                .background(
                    RoundedRectangle(cornerRadius: 30)
                        .fill(Color.white
                                   .opacity(0.8))
                )
            )
            Spacer()
        }
    }
}
