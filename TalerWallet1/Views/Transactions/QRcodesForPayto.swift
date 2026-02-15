/*
 * This file is part of GNU Taler, ©2022-26 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import SwiftUI
import OrderedCollections
import taler_swift

struct QRcodeCopyShare: View {
    let spec: QrCodeSpec
    let textToShare: String

    @State private var qrImage: UIImage? = nil

    var body: some View {
        Text(spec.type)
        let size = 200.0
        QRGeneratorView(text: spec.qrContent, size: size, image: $qrImage)
            .frame(maxWidth: .infinity, alignment: .center)
            .accessibilityLabel(Text("QR Code", comment: "a11y"))
            .listRowSeparator(.hidden)
        HStack {
            Text(verbatim: "|")       // only reason for this leading-aligned text is to get a nice full length listRowSeparator
                .accessibilityHidden(true)
                .foregroundColor(Color.clear)
            //                  Spacer()
            CopyShare(textToCopy: textToShare, image: qrImage)
                .disabled(false)
        }.listRowSeparator(.automatic)
    }
}

struct QRcodesForPayto: View {
    let stack: CallStack
    @Binding var qrCodeSpecs: [QrCodeSpec]
    let receiverStr: String
    let amountStr: String
    let messageStr: String?

    let navTitle = String(localized: "Wire transfer", comment: "ViewTitle of wire-transfer QR codes")

    @AppStorage("minimalistic") var minimalistic: Bool = false

    var body: some View {
        let message = messageStr ?? EMPTYSTRING
        let textToShare = String(receiverStr + "\n" + amountStr + "\n" + message)
        List {
            if !minimalistic {
                Text("If your banking software runs on another device, you can scan one of these QR codes:")
                    .listRowSeparator(.hidden)
            }
            ForEach(qrCodeSpecs, id: \.self) { spec in
                QRcodeCopyShare(spec: spec, textToShare: textToShare)
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
