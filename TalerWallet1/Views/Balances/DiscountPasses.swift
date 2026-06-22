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
struct DiscountsPassesList: View {
    private let symLog = SymLogV(0)
    let stack: CallStack
    let isDiscount: Bool
    let navTitle: String

    @EnvironmentObject private var model: WalletModel
    @EnvironmentObject private var controller: Controller
    @AppStorage("myListStyle") var myListStyle: MyListStyle = .automatic
    @State private var activeExpired: Int = 0

    func refresh() async {
//        symLog.log("refreshing balances")
        if isDiscount {
            await controller.loadDiscounts(stack.push("refreshing discounts"), model)
        } else {
            await controller.loadSubscriptions(stack.push("refreshing passes"), model)
        }
    }

    var body: some View {
        let count = isDiscount ? controller.discounts.count : 0
        let list = List {
            let strings = [String(localized: "Active", comment: "segmented control for passes & discounts"),
                           String(localized: "Expired", comment: "segmented control for passes & discounts")]
            SegmentControl2(value: $activeExpired, strings: strings) { index in
                //
            }
            .listRowSeparator(.hidden)
            .padding(.bottom, 10)

            ForEach(0..<count, id: \.self) { index in
//                DiscountPassesItem(stack: stack, isDiscount: isDiscount, index: index)
            }
        }
            .listStyle(myListStyle.style).anyView
            .background(FullBackground())
            .refreshable {
                controller.hapticNotification(.success)
                await refresh()
            }
            .navigationTitle(navTitle)
        list
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
        let activeColor = WalletColors().talerColor
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
                                               isDiscount: true,
                                                 navTitle: discText)
            let passesDest = DiscountsPassesList(stack: stack.push(),
                                            isDiscount: false,
                                              navTitle: passText)
            NavigationLink(destination: discountsDest) { discountsLabel }
            NavigationLink(destination: passesDest) { passesLabel }
        }
        .listRowSeparator(.hidden)
        .talerFont(.title2)
    }
}
