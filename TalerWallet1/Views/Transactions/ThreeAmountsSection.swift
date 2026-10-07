/*
 * This file is part of GNU Taler, ©2022-25 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import SwiftUI
import taler_swift

struct ThreeAmountsSheet: View {    // should be in a separate file
    let stack: CallStack
    let scope: ScopeInfo?
    var common: TransactionCommon
    var topAbbrev: String
    var topTitle: String
    var bottomTitle: String?
    var bottomAbbrev: String?
    let baseURL: String?
    let noFees: Bool?                       // true if exchange charges no fees at all
    var feeIsNegative: Bool?                // show fee with minus (or plus) sign, or no sign if nil
    let large: Bool               // set to false for QR or IBAN
    let summary: String?

#if DEBUG
    @AppStorage("developerMode") var developerMode: Bool = true
#else
    @AppStorage("developerMode") var developerMode: Bool = false
#endif

    var body: some View {
        let incoming = common.isIncoming
        let pending = common.isPending || common.isFinalizing
        let dialog = common.isDialog
        let isDone = common.isDone
        let incomplete = !(isDone || pending || dialog)
        let raw = common.amountRaw
        let effective: Amount? = incomplete ? nil : common.amountEffective
        let fee: Amount? = incomplete ? nil : common.fee()

        let defaultBottomTitle  = incoming ? (pending ? String(localized: "Pending amount to obtain:")
                                                      : String(localized: "Obtained amount:") )
                                           : (pending ? String(localized: "Amount to pay:")
                                                      : String(localized: "Paid amount:") )
        let defaultBottomAbbrev = incoming ? (pending ? String(localized: "Pending:", comment: "mini")
                                                      : String(localized: "Obtained:", comment: "mini") )
                                           : (pending ? String(localized: "Pay:", comment: "mini")
                                                      : String(localized: "Paid:", comment: "mini") )
        let majorLcl = common.txState.major.localizedState
        let txStateLcl = developerMode && pending ? (common.txState.minor?.localizedState ?? majorLcl)
                                                  : majorLcl
        ThreeAmountsSection(stack: stack.push(),
                            scope: scope,
                         topTitle: topTitle,
                        topAbbrev: topAbbrev,
                        topAmount: raw,
                           noFees: noFees,
                              fee: fee,
                    feeIsNegative: feeIsNegative,
                      bottomTitle: bottomTitle ?? defaultBottomTitle,
                     bottomAbbrev: bottomAbbrev ?? defaultBottomAbbrev,
                     bottomAmount: effective,
                            large: large,
                    pendingDialog: pending || dialog,
                           isDone: isDone,
                         incoming: incoming,
                          baseURL: baseURL,
                       txStateLcl: txStateLcl,
                          summary: summary)
    }
}

struct ProductImage: Codable, Hashable {
    var imageBase64: String

    var image: Image? {
        Image(imageBase64)
    }
}

// MARK: -
struct ThreeAmountsSection: View {
    let stack: CallStack
    let scope: ScopeInfo?
    var topTitle: String
    var topAbbrev: String
    var topAmount: Amount
    let noFees: Bool?                       // true if exchange charges no fees at all
    var fee: Amount?                        // nil = don't show fee line, zero = no fee for this tx
    var feeIsNegative: Bool?                // show fee with minus (or plus) sign, or no sign if nil
    var bottomTitle: String
    var bottomAbbrev: String
    var bottomAmount: Amount?               // nil = incomplete (aborted, timed out)
    let large: Bool
    let pendingDialog: Bool
    let isDone: Bool
    let incoming: Bool
    let baseURL: String?
    let txStateLcl: String?                 // localizedState
    let summary: String?

    @EnvironmentObject private var controller: Controller
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @AppStorage("minimalistic") var minimalistic: Bool = false

    @State private var currencyInfo: CurrencyInfo = CurrencyInfo.zero(UNKNOWN)

    @MainActor
    private func viewDidLoad() async {
        if let scope {
            currencyInfo = controller.info(for: scope) ?? CurrencyInfo.zero(UNKNOWN)
        }
    }


    var body: some View {
        let currency = currencyInfo.currency
        let labelColor = WalletColors().labelColor
        let bottomColor = pendingDialog ? WalletColors().pendingColor(incoming)
                                        : WalletColors().transactionColor(incoming)
        let hasNoFees = noFees ?? false
        Section {
            if let summary {
//                if productImages.isEmpty {  // otherwise we already have rendered the images
                    Text(summary)           // and thus don't need a summary
                        .talerFont(.title3)
                        .padding(.bottom)
//                }
            }

            if currency != "UNKNOWN" {
                if pendingDialog || isDone {
                    Text(pendingDialog ? "Payment will be made in \(currency)"
                                       : "Payment was made in \(currency)")
                        .talerFont(.callout)
                        .padding(.top, 4)
                }
                AmountRowV(stack: stack.push(),
                           title: minimalistic ? topAbbrev : topTitle,
                          amount: topAmount,
                           scope: scope,
                      isNegative: nil,
                           color: labelColor,
                           large: false)
                    .padding(.bottom, 4)
                if hasNoFees == false {     // otherwise raw==effective
                    if let fee {
                        let title = minimalistic ? String(localized: "Exchange fee (short):", defaultValue: "Fee:",     comment: "short version")
                                                 : String(localized: "Exchange fee (long):", defaultValue: "Fee:",     comment: "long version")
                        AmountRowV(stack: stack.push(),
                                   title: title,
                                  amount: fee,
                                   scope: scope,
                              isNegative: fee.isZero ? nil : feeIsNegative,
                                   color: labelColor,
                                   large: false)
                        .padding(.bottom, 4)
                    }
                    if let bottomAmount {
                        AmountRowV(stack: stack.push(),
                                   title: minimalistic ? bottomAbbrev : bottomTitle,
                                  amount: bottomAmount,
                                   scope: scope,
                              isNegative: nil,
                                   color: bottomColor,
                                   large: large)
                    }
                }
                let serviceURL = scope?.url ?? baseURL
                if let serviceURL {
                    VStack(alignment: .leading) {
                                   // TODO: "Issued by" for withdrawals
                        Text(minimalistic ? "Payment service:" : "Using payment service:")
                            .multilineTextAlignment(.leading)
                            .talerFont(.body)
                        Text(serviceURL.trimURL)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .multilineTextAlignment(.center)
                            .talerFont(large ? .title3 : .body)
//                            .fontWeight(large ? .medium : .regular)  // @available(iOS 16.0, *)
                            .foregroundColor(labelColor)
                    }
                    .padding(.top, 4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .listRowSeparator(.hidden)
                    .accessibilityElement(children: .combine)
                }
            }
        } header: {
            let header = scope?.url?.trimURL ?? scope?.currency ?? (summary != nil ? "Summary" : nil)
            if let header {
                Text(header)
                    .talerFont(.title3)
                    .foregroundColor(WalletColors().secondary2(colorScheme, colorSchemeContrast))
            }
        }
        .task { await viewDidLoad() }
        .onChange(of: scope) { newVal in
            if let newVal {
                currencyInfo = controller.info(for: newVal) ?? CurrencyInfo.zero(UNKNOWN)
            }
        }
    }
}
// MARK: -
#if  DEBUG
struct ThreeAmounts_Previews: PreviewProvider {
    @MainActor
    struct StateContainer: View {
//        @State private var previewD: CurrencyInfo = CurrencyInfo.zero(DEMOCURRENCY)
//        @State private var previewT: CurrencyInfo = CurrencyInfo.zero(TESTCURRENCY)

        var body: some View {
            let scope = ScopeInfo.zero(LONGCURRENCY)
            let common = TransactionCommon(type: .withdrawal,
                                  transactionId: "someTxID",
                                      timestamp: Timestamp(from: 1_666_666_000_000),
                                         scopes: [scope],
                                        txState: TransactionState(major: .done),
                                      txActions: [],
                                      amountRaw: Amount(currency: LONGCURRENCY, cent: 20),
                                amountEffective: Amount(currency: LONGCURRENCY, cent: 10))
//            let test = Amount(currency: TESTCURRENCY, cent: 123)
//            let demo = Amount(currency: DEMOCURRENCY, cent: 123456)
            List {
                ThreeAmountsSheet(stack: CallStack("Preview"),
                                  scope: scope,
                                 common: common, 
                              topAbbrev: "Withdrawal",
                               topTitle: "Withdrawal",
                                baseURL: DEMOEXCHANGE,
                                 noFees: false,
                                  large: 1==0, summary: nil)
                .safeAreaInset(edge: .bottom) {
                    Button(String("Preview")) {}
                        .buttonStyle(TalerButtonStyle(type: .prominent))
                        .padding(.horizontal)
                        .disabled(true)
                }
            }
        }
    }

    static var previews: some View {
        StateContainer()
//          .environment(\.sizeCategory, .extraExtraLarge)    Canvas Device Settings
    }
}
#endif
