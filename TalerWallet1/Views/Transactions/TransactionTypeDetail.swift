/*
 * This file is part of GNU Taler, ©2022-26 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import SwiftUI
import taler_swift
import SymLog


struct TransactionTypeDetail: View {
    private let symLog = SymLogV(0)
    let stack: CallStack
    @Binding var transaction: TalerTransaction
    @Binding var payNow: Bool
    @Binding var selectedChoice: Int
    @Binding var scope: ScopeInfo?
    @Binding var effective: Amount?
    let hasDone: Bool
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @AppStorage("minimalistic") var minimalistic: Bool = false
    @State private var rotationEnabled = true
    @State private var ignoreAccept: Bool = false         // accept could be set by OIM to trigger accept
    @State private var isCopied: Bool = false
    @State var isLoadingChoices: Bool? = nil

    func refreshFee(input: Amount, output: Amount) -> Amount? {
        do {
            let fee = try input - output
            return fee
        } catch {

        }
        return nil
    }

    func abortedHint(_ delay: Duration?) -> UInt? {
        if let delay {
            if let microseconds = try? delay.microseconds() {
                let days = microseconds / (24 * 3600 * 1000 * 1000)
                if days > 0 {
                    return UInt(days)
                }
            }
            return 0
        }
        return nil
    }

    var body: some View {
        let _ = Self._printChanges()
        let _ = symLog.vlog()
        let common = transaction.common
        let pending = transaction.isPending
        let isDialog = transaction.isDialog
        Group {
            switch transaction {
                case .dummy(_): Group {
                    let title = EMPTYSTRING
                    Text(title)
                        .talerFont(.body)
                    RotatingTaler(size: 100, progress: true, once: false, rotationEnabled: $rotationEnabled)
                        .frame(maxWidth: .infinity, alignment: .center)
                        // has its own accessibilityLabel
                }
                case .withdrawal(let withdrawalTransaction): Group {
                    let details = withdrawalTransaction.details
                    if common.isAborted && details.withdrawalDetails.type == .manual {
                        if let days = abortedHint(details.withdrawalDetails.reserveClosingDelay) {
                            let wireBack = days > 0 ? String(localized: "If you have already sent money to the payment service, it will wire it back in \(days) days.")
                                                    : String(localized: "If you have already sent money to the payment service, it will wire it back in a few days.")
                            Text("The withdrawal was aborted.\n\n\(wireBack)")
                                .talerFont(.callout)
                        }
                    }
                    if pending {
                        PendingWithdrawalDetails(stack: stack.push(),
                                           transaction: $transaction,
                                               details: details)
                    } // ManualDetails or Confirm now (with bank)
                    ThreeAmountsSheet(stack: stack.push(),
                                      scope: scope,
                                     common: common,
                                  topAbbrev: String(localized: "Chosen:", comment: "mini"),
                                   topTitle: String(localized: "Chosen amount to withdraw:"),
                                    baseURL: details.exchangeBaseUrl,
                                     noFees: nil,               // TODO: noFees
                              feeIsNegative: true,
                                      large: false,
                                    summary: nil)
                }
                case .deposit(let depositTransaction): Group {
                    if transaction.common.isPendingKYCauth {
                        KYCauth(stack: stack.push(), common: common)
                    } else if transaction.isPendingKYC {
                        KYCbutton(kycUrl: common.kycUrl)
                    }
                    ThreeAmountsSheet(stack: stack.push(),
                                      scope: scope,
                                     common: common,
                                  topAbbrev: String(localized: "Deposit:", comment: "mini"),
                                   topTitle: String(localized: "Amount to deposit:"),
                                    baseURL: nil,               // TODO: baseURL
                                     noFees: nil,               // TODO: noFees
                              feeIsNegative: false,
                                      large: true,
                                    summary: nil)
                }

                case .payment(let paymentTransaction):
                    /// this will always be recreated, thus we need to pass isLoadingChoices as Binding
                    PaymentTransactionView(stack: stack.push(),
                                          common: common,
                              paymentTransaction: paymentTransaction,
                                           scope: $scope,
                                       effective: $effective,
                                          payNow: $payNow,
                                isLoadingChoices: $isLoadingChoices,
                                  selectedChoice: $selectedChoice)

                case .refund(let refundTransaction): Group {
                    let details = refundTransaction.details                 // TODO: more details, details.info?.merchant.name
                    ThreeAmountsSheet(stack: stack.push(),
                                      scope: scope,
                                     common: common,
                                  topAbbrev: String(localized: "Refunded:", comment: "mini"),
                                   topTitle: String(localized: "Refunded amount:"),
                                    baseURL: nil,               // TODO: baseURL
                                     noFees: nil,               // TODO: noFees
                              feeIsNegative: true,
                                      large: true,
                                    summary: details.info?.summary)
                }
                case .refresh(let refreshTransaction): Group {
                    let labelColor = WalletColors().labelColor
                    let errorColor = WalletColors().errorColor
                    let details = refreshTransaction.details
                    Section {
                        Text(details.refreshReason.localizedRefreshReason)
                            .talerFont(.title)
                        let input = details.refreshInputAmount
                        AmountRowV(stack: stack.push(),
                                   title: minimalistic ? "Refreshed:" : "Refreshed amount:",
                                  amount: input,
                                   scope: scope,
                              isNegative: nil,
                                   color: labelColor,
                                   large: true)
                        if let fee = refreshFee(input: input, output: details.refreshOutputAmount) {
                            AmountRowV(stack: stack.push(),
                                       title: minimalistic ? "Fee:" : "Refreshed fee:",
                                      amount: fee,
                                       scope: scope,
                                  isNegative: fee.isZero ? nil : true,
                                       color: labelColor,
                                       large: true)
                        }
                        if let error = details.error {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(error.hint)
                                        .talerFont(.headline)
                                        .foregroundColor(errorColor)
                                        .listRowSeparator(.hidden)
                                    if let stack = error.stack {
                                        Text(stack)
                                            .talerFont(.body)
                                            .foregroundColor(errorColor)
                                            .listRowSeparator(.hidden)
                                    }
                                }
                                let stackStr = error.stack ?? EMPTYSTRING
                                let errorStr = error.hint + "\n" + stackStr
                                CopyButton(textToCopy: errorStr, isCopied: $isCopied, vertical: true)
                                    .accessibilityLabel(Text("Copy the error", comment: "a11y"))
                                    .disabled(false)
                            }
                        }
                    }
                }

                case .peer2peer(let p2pTransaction): Group {
                    let details = p2pTransaction.details
                    if transaction.isPendingKYC {
                        KYCbutton(kycUrl: common.kycUrl)
                    }
                    if !transaction.isDone {
                        ExpiresView(expiration: details.info.expiration)
                    }
                    if transaction.isRcvCoins && common.isDialog {
                        PeerPushCreditView(stack: stack.push(),
                                             raw: common.amountRaw,
                                       effective: common.amountEffective,
                                           scope: scope,
                                         summary: details.info.summary)
                        PeerPushCreditAccept(stack: stack.push(), url: nil,
                                     transactionId: common.transactionId,
                                            accept: $ignoreAccept)
                    } else if transaction.isPayInvoice && common.isDialog {
                        PeerPullDebitView(stack: stack.push(),
                                            raw: common.amountRaw,
                                      effective: common.amountEffective,
                                          scope: scope,
                                        summary: details.info.summary)
                        PeerPullDebitConfirm(stack: stack.push(), url: nil,
                                     transactionId: common.transactionId)
                    } else {
                    // TODO: isSendCoins should show QR only while not yet expired  - either set timer or wallet-core should do so and send a state-changed notification
                        // TODO: details.info.summary
                    if pending {
                        if transaction.isPendingReady {
                            QRCodeDetails(transaction: transaction)
                            if hasDone {
                                Text("QR code and link can also be scanned or copied / shared from Transactions later.")
                                    .multilineTextAlignment(.leading)
                                    .talerFont(.subheadline)
//                                    .padding(.top)
                            }
                        } else {
                            Text("This transaction is not yet ready...")
                                .multilineTextAlignment(.leading)
                                .talerFont(.subheadline)
                        }
                    }
                    let colon = ":"
                    let localizedType = transaction.isDone ? transaction.localizedTypePast
                                                           : transaction.localizedType
                    ThreeAmountsSheet(stack: stack.push(),
                                      scope: scope,
                                     common: common,
                                  topAbbrev: localizedType + colon,
                                   topTitle: localizedType + colon,
                                    baseURL: details.exchangeBaseUrl,
                                     noFees: nil,         // TODO: noFees
                              feeIsNegative: true,
                                      large: false,
                                    summary: details.info.summary)
                    } // else
                } // p2p

                case .recoup(let recoupTransaction): Group {
                    let details = recoupTransaction.details     // TODO: details.recoupReason
                    ThreeAmountsSheet(stack: stack.push(),
                                      scope: scope,
                                     common: common,
                                  topAbbrev: String(localized: "Recoup:", comment: "mini"),
                                   topTitle: String(localized: "Recoup:"),
                                    baseURL: nil,               // TODO: baseURL, noFees
                                     noFees: nil,
                              feeIsNegative: nil,
                                      large: true,
                                    summary: details.recoupReason)
                }
                case .denomLoss(let denomLossTransaction): Group {
                    let details = denomLossTransaction.details              // TODO: more details, details.lossEventType.rawValue
                    ThreeAmountsSheet(stack: stack.push(),
                                      scope: scope,
                                     common: common,
                                  topAbbrev: String(localized: "Lost:", comment: "mini"),
                                   topTitle: String(localized: "Money lost:"),
                                    baseURL: details.exchangeBaseUrl,
                                     noFees: nil,               // TODO: noFees
                              feeIsNegative: nil,
                                      large: true,
                                    summary: details.lossEventType.rawValue)
                }
            } // switch
        } // Group
    }
}
