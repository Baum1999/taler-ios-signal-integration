/*
 * This file is part of GNU Taler, ©2022-26 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import SwiftUI
import taler_swift

fileprivate func formattedAmount(_ balance: Balance, _ currencyInfo: CurrencyInfo) -> (String, String) {
    let amount = balance.available
    return amount.formatted(currencyInfo, isNegative: false, useISO: false)
}

fileprivate func urlOrCurrency(_ balance: Balance) -> String {
    balance.scopeInfo.url?.trimURL ?? balance.scopeInfo.currency
}

fileprivate func pickerRow(_ balance: Balance, _ currencyInfo: CurrencyInfo) -> (String, String) {
    let formatted = formattedAmount(balance, currencyInfo)
    let urlOrCurrency = urlOrCurrency(balance)
    return (String("\(urlOrCurrency):\t\(formatted.0.nbs)"),
            String("\(urlOrCurrency): \(formatted.1)"))
}

struct CurrencyPicker: View {
    let stack: CallStack
    @Binding var value: Int
    let exchanges: [DefaultExchange]
    let action: (Int) -> Void

    @State private var selected = 0

    var body: some View {
#if PRINT_CHANGES
        let _ = Self._printChanges()
#endif
        let count = exchanges.count
        if (count > 0) {
            Picker(EMPTYSTRING, selection: $selected) {
                ForEach(0..<count, id: \.self) { index in
                    let exchange = exchanges[index]
                    Text(exchange.currencySpec.name)
                        .tag(index)
                }
            }
            .talerFont(.title3)
            .task() {
                // FIXME: check balance for non-zero and disable-peer-payments
                withAnimation { selected = value }
            }
            .onChange(of: selected) { newValue in
                action(newValue)
            }

        }
    }
}
struct ScopePicker: View {
//    private let symLog = SymLogV(0)
    let stack: CallStack
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
            let availableA11y = available.formatted(currencyInfo, isNegative: false,
                                                    useISO: true, a11yDecSep: ".")
            let url = balance.scopeInfo.url?.trimURL ?? EMPTYSTRING
//            let a11yLabel = url + ", " + availableA11y
            let chooseHint = String(localized: "Choose the payment service:", comment: "a11y")
            let disabled = (count == 1)

            HStack(alignment: .firstTextBaseline) {
                Text("via", comment: "ScopePicker")
                    .accessibilityHidden(true)
                    .foregroundColor(disabled ? .secondary : .primary)

                if #available(iOS 16.4, *) {
                    ScopeDropDown(selection: $selected,
                                onlyNonZero: onlyNonZero,
                                   disabled: disabled)
                } else {
                    Picker(EMPTYSTRING, selection: $selected) {
                        ForEach(0..<count, id: \.self) { index in
                            let balance = controller.balances[index]
                            let currencyInfo = controller.info(for: balance.scopeInfo, controller.currencyTicker)
                            let pickerRow = pickerRow(balance, currencyInfo)
                            Text(pickerRow.0)
                                .accessibilityLabel(pickerRow.1)
                                .tag(index)
//                              .selectionDisabled(balance.available.isZero)    needs iOS 17
                        }
                    }
                    .disabled(disabled)
                    .frame(maxWidth: .infinity)
//                    .border(.red)                 // debugging
                    .pickerStyle(.menu)
//                  .accessibilityLabel(a11yLabel)
                    .labelsHidden()                 // be sure to use valid labels for a11y
                }
            }
            .talerFont(.picker)
//            .accessibilityLabel(a11yLabel)
            .accessibilityHint(disabled ? EMPTYSTRING : chooseHint)
            .task() {
                // FIXME: check balance for non-zero and disable-peer-payments
                withAnimation { selected = value }
            }
            .onChange(of: selected) { newValue in
                action(newValue)
            }
        }
    }
}
// MARK: -
@available(iOS 16.4, *)
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
    func dropDownRow(_ balance: Balance, _ currencyInfo: CurrencyInfo, _ first: Bool = false) -> some View {
        let urlOrCurrency = urlOrCurrency(balance)
        let text = Text(urlOrCurrency)
        let formatted = formattedAmount(balance, currencyInfo)
        let amount = Text(formatted.0.nbs)
        if first {
            let a11yLabel = String(localized: "via \(urlOrCurrency)", comment: "a11y")
            text
                .accessibilityLabel(a11yLabel)
        } else {
            let a11yLabel = "\(urlOrCurrency), \(formatted.1)"
            let hLayout = HStack(alignment: .firstTextBaseline) {
                text
                Spacer()
                amount
            }.padding(.vertical, 4)
            let vLayout = VStack(alignment: .leading) {
                text
                HStack {
                    Spacer()
                    amount
                    Spacer()
                }
            }
            ViewThatFits(in: .horizontal) {
                hLayout
                vLayout
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(a11yLabel)
        }
    }

    var body: some  View {
        let radius = 8.0
        VStack {
            let chevron = Image(systemName: CHEVRON_UP)     // 􀆇
            let foreColor = disabled ? Color.secondary : Color.primary
            let backColor = disabled ? WalletColors().backgroundColor : WalletColors().gray4
            let otherBalances = controller.balances.filter { $0 != controller.balances[selection] }
            let theList = LazyVStack(spacing: 0) {
                ForEach(0..<otherBalances.count, id: \.self) { index in
                    let balance = otherBalances[index]
                    let disablePeerPayments = balance.disablePeerPayments ?? false
                    let rowDisabled = disablePeerPayments || (onlyNonZero ? balance.available.isZero : false)
                    Button(action: {
                        withAnimation {
                            showDropdown.toggle()
                            selection = controller.balances.firstIndex(of: balance) ?? selection
                        }
                    }, label: {
                        let currencyInfo = controller.info(for: balance.scopeInfo, controller.currencyTicker)
                        HStack(alignment: .top) {
                            dropDownRow(balance, currencyInfo)   // .border(.random)
                                .foregroundColor(rowDisabled ? .secondary : .primary)
                            Spacer()
                            chevron.foregroundColor(.clear)
                                .accessibilityHidden(true)
                        }
                    })
                    .disabled(rowDisabled)
                    .padding(.horizontal, radius / 2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            VStack {
                // selected item
                let balance = controller.balances[selection]
                let currencyInfo = controller.info(for: balance.scopeInfo, controller.currencyTicker)
                let noAmount = !showDropdown
                Group {
                    if disabled {
                        dropDownRow(balance, currencyInfo, noAmount)
                    } else {
                        Button(action: buttonAction) {
                            HStack(alignment: .firstTextBaseline) {
                                dropDownRow(balance, currencyInfo, noAmount)
                                    .accessibilityAddTraits(.isSelected)
                                Spacer()
                                chevron.rotationEffect(.degrees((showDropdown ?  -180 : 0)))
                                    .accessibilityHidden(true)
                            }
                        }
                    }
                }
                    .padding(.vertical, 4)
                    .padding(.horizontal, radius / 2)
                    .frame(maxWidth: .infinity, alignment: .leading)
//                  .border(.red)
                if (showDropdown) {
                    if #available(iOS 17.0, *) {
                        let count = controller.balances.count
//                      let toomany = count > maxItemDisplayed
//                      let scrollViewHeight = buttonHeight * CGFloat(toomany ? maxItemDisplayed
//                                                                            : count)
                        ScrollView {
                            theList
                                .scrollTargetLayout()
                        }
//                      .border(.red)
                        .scrollPosition(id: $scrollPosition)
                        .scrollDisabled(count <= 3)
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
