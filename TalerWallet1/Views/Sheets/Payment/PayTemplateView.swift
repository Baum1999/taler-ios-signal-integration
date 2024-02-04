/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import SwiftUI
import taler_swift
import SymLog

// Will be called either by the user scanning a QR code or tapping the provided link,
// both from the shop's website. We show the payment details
struct PayTemplateView: View {
    private let symLog = SymLogV(0)
    let stack: CallStack
    let navTitle = String(localized: "Confirm Payment", comment:"pay merchant")

    // the scanned URL
    let url: URL

    @EnvironmentObject private var controller: Controller
    @EnvironmentObject private var model: WalletModel
    @AppStorage("myListStyle") var myListStyle: MyListStyle = .automatic

    func acceptAction(preparePayResult: PreparePayResult) {
        Task { // runs on MainActor
            do {
                let confirmPayResult = try await model.confirmPayM(preparePayResult.transactionId)
                //                symLog.log(confirmPayResult as Any)
                if confirmPayResult.type != "done" {
                    controller.playSound(0)
                    // TODO: show error
                }
            } catch {
                controller.playSound(0)
                // TODO: error
                symLog.log(error.localizedDescription)
            }
            dismissTop()
        }
    }

    @State var preparePayResult: PreparePayResult? = nil

    func query(url: URL) -> String? {
        if let query = url.query {
            let array = query.components(separatedBy: "&")
        }
        return nil
    }

    var body: some View {
        if let preparePayResult {
            let effective = preparePayResult.amountEffective
            List {
                let baseURL = preparePayResult.contractTerms.exchanges.first?.url
                let raw = preparePayResult.amountRaw
                let currency = raw.currencyStr
                let topTitle = String(localized: "Amount to pay:")
                let topAbbrev = String(localized: "Pay:", comment: "mini")
                if let effective {
                    // TODO: already paid
                    let fee = try! Amount.diff(raw, effective)      // TODO: different currencies
                    ThreeAmountsV(topTitle: topTitle,
                                 topAbbrev: topAbbrev,
                                 topAmount: raw, fee: fee,
                               bottomTitle: String(localized: "Amount to spend:"),
                              bottomAbbrev: String(localized: "Effective:", comment: "mini"),
                              bottomAmount: effective,
                                     large: false, pending: false, incoming: false,
                                   baseURL: baseURL,
                                    status: nil,
                                   summary: nil,
                                  merchant: nil)
                    // TODO: payment: popup with all possible exchanges, check fees
                } else if let balanceDetails = preparePayResult.balanceDetails {    // Insufficient
                    Text("You don't have enough \(currency)")
                        .accessibilityFont(.body)
                    ThreeAmountsV(topTitle: topTitle,
                                 topAbbrev: topAbbrev,
                                 topAmount: raw, fee: nil,
                               bottomTitle: String(localized: "Amount available:"),
                              bottomAbbrev: String(localized: "Available:", comment: "mini"),
                              bottomAmount: balanceDetails.balanceAvailable,
                                     large: false, pending: false, incoming: false,
                                   baseURL: baseURL,
                                    status: nil,
                                   summary: nil,
                                  merchant: nil)
                } else {
                    // TODO: Error - neither effective nor balanceDetails
                    Text("Error")
                        .accessibilityFont(.body)
                }
            }
            .listStyle(myListStyle.style).anyView
            .safeAreaInset(edge: .bottom) {
                if let effective {
                    Button(navTitle, action: { acceptAction(preparePayResult: preparePayResult) })
                        .buttonStyle(TalerButtonStyle(type: .prominent))
                        .padding(.horizontal)
                } else {
                    Button("Cancel", action: { dismissTop() })
                        .buttonStyle(TalerButtonStyle(type: .bordered))
                        .padding(.horizontal)
                }
            }
            .navigationTitle(navTitle)
            .onAppear() {
                symLog.log("onAppear")
                DebugViewC.shared.setSheetID(SHEET_PAY_TEMPLATE)
            }
        } else {
            LoadingView(url: url, message: nil)
                .task {
                    do {
                        symLog.log(".task")
                        let result = try await model.preparePayForTemplateM(url.absoluteString)
                        preparePayResult = result
                    } catch {    // TODO: error
                        symLog.log(error.localizedDescription)
                    }
                }
        }
    }
}
