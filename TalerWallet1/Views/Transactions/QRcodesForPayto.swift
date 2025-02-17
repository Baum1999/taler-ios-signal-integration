/*
 * This file is part of GNU Taler, ©2022-25 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import SwiftUI
import OrderedCollections
import taler_swift

struct QRcodesForPayto: View {
    let stack: CallStack
    @Binding var qrCodeSpecs: [QrCodeSpec]
    let navTitle = String(localized: "Wire transfer", comment: "ViewTitle of wire-transfer QR codes")

    @AppStorage("minimalistic") var minimalistic: Bool = false

    var body: some View {
        List {
            if !minimalistic {
                Text("If your banking software runs on another device, you can scan one of these QR codes:")
                    .listRowSeparator(.hidden)
            }
            ForEach(qrCodeSpecs, id: \.self) { spec in
                Text(spec.type)
                QRGeneratorView(text: spec.qrContent)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .accessibilityLabel("QR Code")
                    .listRowSeparator(.hidden)
                HStack {
                    Text(verbatim: "|")       // only reason for this leading-aligned text is to get a nice full length listRowSeparator
                        .accessibilityHidden(true)
                        .foregroundColor(Color.clear)
                    //                              Spacer()
                    CopyShare(textToCopy: spec.qrContent)
                        .disabled(false)
                }.listRowSeparator(.automatic)
            }
        }
        .navigationTitle(navTitle)
        .onAppear() {
//            symLog.log("onAppear")
            DebugViewC.shared.setViewID(VIEW_WITHDRAW_QRCODES, stack: stack.push())
        }
    }
}
// MARK: -
#if DEBUG
//struct QRcodesForPayto_Previews: PreviewProvider {
//    static var previews: some View {
//        let common = TransactionCommon(type: .withdrawal,
//                                    txState: TransactionState(major: .done),
//                            amountEffective: Amount(currency: LONGCURRENCY, cent: 110),
//                                  amountRaw: Amount(currency: LONGCURRENCY, cent: 220),
//                              transactionId: "someTxID",
//                                  timestamp: Timestamp(from: 1_666_666_000_000),
//                                  txActions: [])
//        let payto = "payto://iban/SANDBOXX/DE159593?receiver-name=Exchange+Company"
//        let details = WithdrawalDetails(type: .manual, 
//                                  reservePub: "ReSeRvEpUbLiC_KeY_FoR_WiThDrAwAl",
//                              reserveIsReady: false,
//                                   confirmed: false)
//        List {
//            QRcodesForPayto(stack: CallStack("Preview"), qrCodeSpecs: details)
//        }
//    }
//}
#endif
