/*
 * This file is part of GNU Taler, ©2022-26 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import SwiftUI
import os.log
import taler_swift
import SymLog

/// This view shows ...
struct DiscountsPassesItem: View {
    private let symLog = SymLogV(0)
    let stack: CallStack
    let token: TalerToken
    let isPass: Bool                        // false = isDiscount
    let activeExpired: Int
    let index: Int
    let deleteAction: (String) -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @AppStorage("minimalistic") var minimalistic: Bool = false

    @State private var dateToggled: Bool = false

    func validDate(_ isValid: Bool, isExpired: Bool) -> (String, String) {
        if isExpired {
            let (endDateString, endDate) = TalerDater.dateString(token.validityEnd, minimalistic)
            let endA11yDate = TalerDater.accessibilityDate(endDate) ?? endDateString

            let (dateString, date) = TalerDater.dateString(token.validityStart, minimalistic)
            let a11yDate = TalerDater.accessibilityDate(date) ?? dateString

            let result0 = String(localized: "Validity period: \(dateString) - \(endDateString)")
            let result1 = String(localized: "Validity period: \(a11yDate) to \(endA11yDate)")
            return (result0, result1)
        } else if isValid != dateToggled {
            let (dateString, date) = TalerDater.dateString(token.validityEnd, minimalistic)
            let a11yDate = TalerDater.accessibilityDate(date) ?? dateString
            let result0 = String(localized: "Valid until \(dateString)")
            let result1 = String(localized: "Valid until \(a11yDate)")
            return (result0, result1)
        } else {
            let (dateString, date) = TalerDater.dateString(token.validityStart, minimalistic)
            let a11yDate = TalerDater.accessibilityDate(date) ?? dateString
            let result0 = String(localized: "Valid from \(dateString)")
            let result1 = String(localized: "Valid from \(a11yDate)")
            return (result0, result1)
        }
    }
    var body: some View {
        let isValid = token.validityStart < .now()
        let isExpired = token.validityEnd < .now()
        let primary = WalletColors().primary(colorSchemeContrast)
        let secondary = WalletColors().secondary(colorScheme, colorSchemeContrast)
        let primaryAccent = WalletColors().primaryAccent

        let name = Text(token.name)
            .talerFont(.title)
            .foregroundColor(primary)
        let desc = Text(token.description)
            .talerFont(.body)
            .foregroundColor(primary)

        Section {
            let swipe = Button {
                    symLog.log("delete \(token.id)")
                    deleteAction(token.id)
                } label: {
                    Label("Delete", systemImage: "trash")
                }.tint(WalletColors().negative)
            let row = HStack(alignment: .top) {
                name
                Spacer()
                if let available = token.tokensAvailable {
                    // Discount
                    Text("x\(available)")
                        .foregroundColor(primaryAccent)
                } else {
                    // Pass
                    if isValid {
                        Text("active")
                            .foregroundColor(primaryAccent)
                    }
                }
            }
            if isValid {
                row
            } else {
                row.swipeActions(edge: .trailing) { swipe }
            }

            let merchant = token.merchantInfo?.name ?? "Unknown"
            if isExpired {
                Text(isPass ? "Provided by: \(merchant)"
                  : isValid ? "Was redeemable at: \(merchant)"
                            : "Redeemed at: \(merchant)")
                    .talerFont(.footnote)
                    .foregroundColor(secondary)

            } else {
                Text(isPass ? "Provided by: \(merchant)"
                            : "Redeemable at: \(merchant)")
                    .talerFont(.footnote)
                    .foregroundColor(secondary)
            }
            let dateStrings = validDate(isValid, isExpired: isExpired)
            VStack {
                Text(dateStrings.0)
                    .accessibilityLabel(dateStrings.1)
                    .talerFont(.body)
            }.frame(maxWidth: .infinity)
                .background(primaryAccent.opacity(isValid ? 0.1 : 0))
                .onTapGesture {
                    if !isExpired {
                        dateToggled.toggle()
                    }
                }
        }
    }
}
// MARK: -
struct DiscountsPassesList: View {
    private let symLog = SymLogV(0)
    let stack: CallStack
    let isPass: Bool
    let navTitle: String

    @EnvironmentObject private var model: WalletModel
    @EnvironmentObject private var controller: Controller
    @AppStorage("myListStyle") var myListStyle: MyListStyle = .automatic
    @State private var activeExpired: Int = 0

    func delete(_ tokenID: String) async {
        if isPass {
            try? await model.deleteSubscription(tokenID)
        } else {
            try? await model.deleteDiscount(tokenID)
        }
    }
    func refresh() async {
//        symLog.log("refreshing balances")
        if isPass {
            await controller.loadSubscriptions(stack.push("refreshing passes"), model)
        } else {
            await controller.loadDiscounts(stack.push("refreshing discounts"), model)
        }
    }

    func talerTokens() -> [TalerToken] {
        let tokens = isPass ? controller.subscriptions
                            : controller.discounts
        let active = activeExpired == 0

        return tokens.filter {
            let isValid = $0.validityEnd > .now()
            return active ? isValid
                          : !isValid
        }
    }
    var body: some View {
        let tokens = talerTokens()
        let count = tokens.count
        let list = List {
            if count == 0 {
                Text(isPass ? "No passes yet"
                            : "No discounts yet")
                    .talerFont(.headline)
            } else {
                let comment: StaticString = "segmented control for passes & discounts"
                let strings = [String(localized: "Active", comment: comment),
                               String(localized: "Expired", comment: comment)]
                SegmentControl2(value: $activeExpired, strings: strings)
                    .listRowSeparator(.hidden)
                    .padding(.bottom, 10)

                ForEach(0..<count, id: \.self) { index in
                    let token = tokens[index]
                    DiscountsPassesItem(stack: stack.push(),
                                        token: token,
                                       isPass: isPass,
                                activeExpired: activeExpired,
                                        index: index
                    ) { deletionID in
                        Task { // runs on MainActor
                            let _ = await delete(deletionID)
                            await refresh()
                        }
                    }
                }
            }
        }
            .listStyle(myListStyle.style).anyView
            .background(FullBackground())
            .refreshable {
                controller.hapticNotification(.success)
                await refresh()
            }
        list
            .navigationTitle(navTitle)
            .task {
                await refresh()
            }
    }
}
// MARK: -
struct DiscountPassesSection: View {
    let stack: CallStack
    @EnvironmentObject private var controller: Controller
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    @State private var discounts: Bool = false
    @State private var passes: Bool = false

    var body: some View {
        let discText = String(localized: "Discounts")
        let passText = String(localized: "Passes")
        let activeColor = WalletColors().primaryAccent
        let inactiveColor = WalletColors().secondary(colorScheme, colorSchemeContrast)
        Section {
            let discCount = controller.discounts.count
            let discColor = discCount > 0 ? activeColor : inactiveColor
            let discountsLabel = Label {
                                     Text(discText)
                                 } icon: {
                                     Image(ICONNAME_DISCOUNTS, SYSTEM_DISCOUNTS)
                                         .foregroundColor(discColor)
                                 }

            let passCount = controller.subscriptions.count
            let passColor = passCount > 0 ? activeColor : inactiveColor
            let passesLabel = Label {
                                  Text(passText)
                              } icon: {
                                  Image(ICONNAME_PASSES, SYSTEM_PASSES)
                                      .foregroundColor(passColor)
                              }

            let discountsDest = DiscountsPassesList(stack: stack.push(),
                                                   isPass: false,
                                                 navTitle: discText)
            let passesDest = DiscountsPassesList(stack: stack.push(),
                                                isPass: true,
                                              navTitle: passText)
            NavigationLink(destination: discountsDest) { discountsLabel }
            // TODO: a11y for discCount > 0
            NavigationLink(destination: passesDest) { passesLabel }
            // TODO: a11y for passCount > 0
        }
        .listRowSeparator(.hidden)
        .talerFont(.title2)
    }
}
