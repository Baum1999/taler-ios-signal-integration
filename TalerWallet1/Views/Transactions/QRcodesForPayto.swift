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
    let option: TransferOption
    @State private var qrImage: UIImage? = nil

    func textToShare() -> String? {
        if let paytoUri = option.paytoUri {
            let payto = PayTo(paytoUri)
            if let receiverStr = payto.receiver {
                if let amountStr = payto.amountStr {
                    if let messageStr = option.qrReferenceNumber ?? payto.messageStr {
                        return String(receiverStr + LINEFEED + amountStr + LINEFEED + messageStr)
                    }
                }
            }
        }
        return nil
    }

    var body: some View {
//        Text(spec.type)
        if let qrCodes = option.qrCodes {
            ForEach(qrCodes, id: \.self) { qrCodeSpec in
                let logo = qrCodeSpec.type == "spc" ? Image(SWISS_QR) : nil
                let size = 276.0    // 46x46mm, swiss flag = 7x7mm plus border  276*9/46 = 54
                QRGeneratorView(text: qrCodeSpec.qrContent, size: size,
                                logo: logo, logoSize: size * 9 / 46,
                               image: $qrImage)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .listRowSeparator(.hidden)
            }
        }
        if let textToShare = textToShare() {
            HStack {
//                Text(verbatim: "|")       // only reason for this leading-aligned text is to get a nice full length listRowSeparator
//                    .accessibilityHidden(true)
//                    .foregroundColor(Color.clear)
//              Spacer()
                CopyShare(textToShare, image: qrImage)
                    .disabled(false)
            }
        }
    }
}

struct QRcodesForPayto: View {
    let stack: CallStack
    var transferOptions: [TransferOption]

    let navTitle = String(localized: "Wire transfer", comment: "ViewTitle of wire-transfer QR codes")

    @AppStorage("minimalistic") var minimalistic: Bool = false

    var body: some View {
        List {
            if !minimalistic {
                Text("If your banking software runs on another device, you can scan one of these QR codes:")
                    .listRowSeparator(.hidden)
            }
            ForEach(transferOptions, id: \.self) { option in
                QRcodeCopyShare(option: option)
                    .listRowSeparator(.automatic)
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
