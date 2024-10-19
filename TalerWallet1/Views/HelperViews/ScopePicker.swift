/*
 * This file is part of GNU Taler, ©2022-24 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import SwiftUI
import taler_swift

fileprivate func formattedAmount(_ balance: Balance, _ currencyInfo: CurrencyInfo) -> String {
    let amount = balance.available
    return amount.formatted(currencyInfo, isNegative: false, useISO: false)
}

fileprivate func urlOrCurrency(_ balance: Balance) -> String {
    balance.scopeInfo.url?.trimURL ?? balance.scopeInfo.currency
}

fileprivate func pickerRow(_ balance: Balance, _ currencyInfo: CurrencyInfo) -> String {
    String("\(urlOrCurrency(balance)):\t\(formattedAmount(balance, currencyInfo).nbs)")
}

struct ScopePicker: View {
//    private let symLog = SymLogV(0)
    @Binding var value: Int
    let onlyNonZero: Bool
    let action: (Int) -> Void

    @EnvironmentObject private var controller: Controller

    @State private var selected = 0

    var body: some View {
#if PRINT_CHANGES
        let _ = Self._printChanges()
#endif
        let count = controller.balances.count
        if (count > 0) {
            let balance = controller.balances[selected]
            let currencyInfo = controller.info(for: balance.scopeInfo, controller.currencyTicker)
            let available = balance.available
            let availableA11y = available.formatted(currencyInfo, isNegative: false, useISO: true, a11y: ".")
            let url = balance.scopeInfo.url?.trimURL ?? EMPTYSTRING
            let a11yLabel = url + ", " + availableA11y

            HStack(alignment: .top) {
                let disabled = (count == 1)
                Text("via", comment: "ScopePicker")
                    .accessibilityHidden(true)
                    .foregroundColor(disabled ? .secondary : .primary)

                if #available(iOS 16.0, *) {
                    ScopeDropDown(selection: $selected,
                                onlyNonZero: onlyNonZero,
                                   disabled: disabled)
                } else {
                    Picker(EMPTYSTRING, selection: $selected) {
                        ForEach(0..<controller.balances.count, id: \.self) { index in
                            let balance = controller.balances[index]
                            let currencyInfo = controller.info(for: balance.scopeInfo, controller.currencyTicker)
                            Text(pickerRow(balance, currencyInfo))
                                .tag(index)
//                              .selectionDisabled(balance.available.isZero)    needs iOS 17
                        }
                    }
                    .disabled(disabled)
                    .frame(maxWidth: .infinity)
//                    .border(.red)                 // debugging
                    .pickerStyle(.menu)
                    .labelsHidden()
                }
            }
            .talerFont(.picker)
            .accessibilityLabel(a11yLabel)
            .accessibilityHint(String(localized: "Choose the payment provider.", comment: "a11y"))
            .task() {
                withAnimation { selected = value }
            }
            .onChange(of: selected) { newValue in
                action(newValue)
            }
        }
    }
}
// MARK: -
@available(iOS 16.0, *)
struct  ScopeDropDown: View {
    @Binding  var selection: Int
    let onlyNonZero: Bool
    let disabled: Bool

//    var maxItemDisplayed: Int = 3

    @EnvironmentObject private var controller: Controller

    @State private var scrollPosition: Int?
    @State private var showDropdown = false

    func buttonAction() {
        withAnimation {
            showDropdown.toggle()
        }
    }

    @ViewBuilder
    func dropDownRow(_ balance: Balance, _ currencyInfo: CurrencyInfo) -> some View {
        let hLayout = HStack(alignment: .top) {
            Text(urlOrCurrency(balance))
            Spacer()
            Text(formattedAmount(balance, currencyInfo).nbs)
        }
        let vLayout = VStack(alignment: .leading) {
            Text(urlOrCurrency(balance))
            HStack {
                Spacer()
                Text(formattedAmount(balance, currencyInfo).nbs)
                Spacer()
            }
        }
        ViewThatFits(in: .horizontal) {
            hLayout
            vLayout
        }
    }

    var body: some  View {
        let radius = 8.0
        VStack {
            let chevron = Image(systemName: "chevron.up")
            let foreColor = disabled ? Color.secondary : Color.primary
            let backColor = disabled ? WalletColors().backgroundColor : WalletColors().gray4
            let otherBalances = controller.balances.filter { $0 != controller.balances[selection] }
            let theList = LazyVStack(spacing: 0) {
                ForEach(0..<otherBalances.count, id: \.self) { index in
                    let item = otherBalances[index]
                    let rowDisabled = onlyNonZero ? item.available.isZero : false
                    Button(action: {
                        withAnimation {
                            showDropdown.toggle()
                            selection = controller.balances.firstIndex(of: item) ?? selection
                        }
                    }, label: {
                        let currencyInfo = controller.info(for: item.scopeInfo, controller.currencyTicker)
                        HStack(alignment: .top) {
                            dropDownRow(item, currencyInfo)   // .border(.random)
                                .foregroundColor(rowDisabled ? .secondary : .primary)
                            Spacer()
                            chevron.foregroundColor(.clear)
                                .accessibilityHidden(true)
                        }


                    }) // .accessibilityElement(children: .combine)
                    .disabled(rowDisabled)
                    .padding(.horizontal, radius / 2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            VStack {
                // selected item
                let balance = controller.balances[selection]
                let currencyInfo = controller.info(for: balance.scopeInfo, controller.currencyTicker)
                Button(action: buttonAction) {
                    HStack(alignment: .firstTextBaseline) {
                        dropDownRow(balance, currencyInfo)
                            .accessibilityAddTraits(.isSelected)
                        Spacer()
                        if !disabled {
                            chevron.rotationEffect(.degrees((showDropdown ?  -180 : 0)))
                                .accessibilityHidden(true)
                        }
                    }
                }
                    .padding(.horizontal, radius / 2)
                    .frame(maxWidth: .infinity, alignment: .leading)
//                .border(.red)
                if (showDropdown) {
                    if #available(iOS 17.0, *) {
//                      let toomany = controller.balances.count > maxItemDisplayed
//                      let scrollViewHeight = buttonHeight * CGFloat(toomany ? maxItemDisplayed
//                                                                            : controller.balances.count)
                        ScrollView {
                            theList
                                .scrollTargetLayout()
                        }
//                      .border(.red)
                        .scrollPosition(id: $scrollPosition)
                        .scrollDisabled(controller.balances.count <= 3)
//                      .frame(height: scrollViewHeight)
                        .onAppear {
                            scrollPosition = selection
                        }
                    } else {
                        // Fallback on earlier versions
                        ScrollView {
                            theList
                        }
                    }

                }
            }
            .foregroundStyle(foreColor)
            .background(RoundedRectangle(cornerRadius: radius).fill(backColor))
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .zIndex(100)
    }
}
