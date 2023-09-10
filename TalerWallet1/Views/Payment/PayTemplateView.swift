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
    private let symLog = SymLogV()
    let navTitle = String(localized: "Confirm Payment", comment:"pay merchant")

    @EnvironmentObject private var controller: Controller
    @AppStorage("myListStyle") var myListStyle: MyListStyle = .automatic

    // the scanned URL
    let url: URL

    @EnvironmentObject private var model: WalletModel

    func acceptAction(preparePayResult: PreparePayResult) {
        Task {
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
                if let effective {
                    // TODO: already paid
                    let fee = try! Amount.diff(raw, effective)      // TODO: different currencies
                    ThreeAmountsView(topTitle: topTitle,
                                     topAmount: raw, fee: fee,
                                     bottomTitle: String(localized: "\(currency) to be spent:"),
                                     bottomAmount: effective,
                                     large: false, pending: false, incoming: false,
                                     baseURL: baseURL)
                    // TODO: payment: popup with all possible exchanges, check fees
                } else if let balanceDetails = preparePayResult.balanceDetails {    // Insufficient
                    Text("You don't have enough \(currency)")
                        .accessibilityFont(.body)
                    ThreeAmountsView(topTitle: topTitle,
                                     topAmount: raw, fee: nil,
                                     bottomTitle: String(localized: "\(currency) available:"),
                                     bottomAmount: balanceDetails.balanceAvailable,
                                     large: false, pending: false, incoming: false,
                                     baseURL: baseURL)
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
            let badURL = "Error in Link: \(url)"
            WithdrawProgressView(message: url.host ?? badURL)
                .navigationTitle("Find Exchange")
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
