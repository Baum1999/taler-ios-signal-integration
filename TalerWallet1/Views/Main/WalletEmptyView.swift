/*
 * This file is part of GNU Taler, ©2022-26 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import SwiftUI
import SymLog
import taler_swift

struct ProdSectionView: View {
    let stack: CallStack
    let isEmpty: Bool
    let disabled: Bool

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @EnvironmentObject private var controller: Controller
    @EnvironmentObject private var model: WalletModel
#if DEBUG
    @AppStorage("developerMode") var developerMode: Bool = true
#else
    @AppStorage("developerMode") var developerMode: Bool = false
#endif

    @State private var selectedCurrency: Int = 0
    @State private var showDropdown = true

    func buttonAction() {
        withAnimation {
            showDropdown.toggle()
        }
    }

    var body: some View {
        let defaultExchanges = controller.defaultExchanges
        let count = defaultExchanges.count
        Section {
            let chevron = Image(systemName: CHEVRON_UP)     // 􀆇
            if isEmpty {
                Text("Welcome to Taler Wallet!")
                    .talerFont(.headline)
                Text("To make your first payment, withdraw digital cash.")
                    .talerFont(.body)
            } else {
                Button(action: buttonAction) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Currently you have only demo cash.")
                            .talerFont(.body)
                            .accessibilityAddTraits(.isSelected)
                        Spacer()
                        chevron.rotationEffect(.degrees((showDropdown ?  -180 : 0)))
                            .accessibilityHidden(true)
                    }
                    .contentShape(.rect)    // can tap in background also
                }   .buttonStyle(.plain)
                if (showDropdown) {
                    Text("Withdraw real digital cash:")
                        .talerFont(.body)
                        .padding(.vertical, -16)
                }
            }
#if false
            let qrButton = Image(systemName: QRBUTTON)                      // 􀎻 "qrcode.viewfinder"
            let settings = Image(systemName: SETTINGS)                      // 􀍟 "gear"
            Text("Use «\(qrButton) Scan QR code» in the Actions menu to start a withdrawal if your bank already supports Taler payments.", comment: "« 􀎻 » 'qrcode.viewfinder'")
                .talerFont(.body)
            Text("You can also add a payment service manually in the \(settings) Settings tab.", comment: "« 􀍟 » 'gear'")
                .talerFont(.body)
#endif
            if (showDropdown) {
#if !TALER_WALLET
                if developerMode {
                    if defaultExchanges.count > 1 {
                        CurrencyPicker(stack: stack.push(), value: $selectedCurrency,
                                   exchanges: defaultExchanges) { index in
                            selectedCurrency = index
                        }
                    }
                }
#endif
                let defaultExchange = defaultExchanges[selectedCurrency < count ? selectedCurrency : 0]
                let currency = defaultExchange.currency
                let title = String(localized: "LinkTitle_Withdraw", defaultValue: "Withdraw \(currency)")
                Button(title) {
                    if let talerUri = URL(string: defaultExchange.talerUri) {
                        controller.talerURI = talerUri
                    }
                }
                .buttonStyle(TalerButtonStyle(type: isEmpty ? .prominent : .bordered,
                                            narrow: false,
                                          disabled: disabled,
                                           aligned: .center))
                .padding(.top, -6)
                .padding(.bottom, 6)
            } // showDropdown
        } header: {
            if isEmpty {
                let firstHeader = EMPTYSTRING
                Text(firstHeader)
                    .talerFont(.badge)
//                    .foregroundColor(.primary)
                /// YIKES! when not specifying this color, the Text in the BarGraphHeader vanishes!!!
                    .foregroundColor(WalletColors().secondary(colorScheme, colorSchemeContrast))
//                    .listRowInsets(EdgeInsets())  // << here !!
            }
        }
        .listRowSeparator(.hidden)
//        .listSectionSpacing(.compact) iOS 17
    }
}

/// This view shows hints if a wallet is empty
/// It is the very first thing the user sees after installing the app

struct WalletEmptyHeader: View {
    let stack: CallStack

    @EnvironmentObject private var model: WalletModel
    @EnvironmentObject private var controller: Controller

    func refresh() async {
        controller.hapticNotification(.success)
//        symLog.log("refreshing balances")
        await controller.loadBalances(stack.push("refreshing balances"), model)
    }

    var body: some View {
        let talerLogo = HStack(spacing: 2) {
            Image(TALER_LOGO_FULL)
            //                        .border(Color.gray, width: 1)
            //                    Text("TALER Wallet")
            Text("Wallet")
            //                        .font(.logo(27, weight: .medium))
                .font(.logo("Atkinson Hyperlegible Next", size: 27, weight: .medium))
                .kerning(1.0)
        }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            .accessibilityLabel(Text("Taler Wallet", comment: "a11y"))

        let emptyView =  WalletEmptyView(stack: stack.push("isEmpty"))
        //                  .navigationTitle("Taler Wallet")
            .refreshable {
                await refresh()
            }

        let logoItem = ToolbarItem(placement: .principal) {
            talerLogo
                .padding(.top, 10)
        }
        if #available(iOS 26.0, *) {
            emptyView
                .toolbar {
                    logoItem
                    ToolbarItem(placement: .primaryAction) {        // Settings button
                        Button {
                            NotificationCenter.default.post(name: .SettingsAction, object: nil)   // will trigger NavigationLink
                        } label: {
                            Label(TalerTab.settings.title, systemImage: TalerTab.settings.sysImg)
                                .labelStyle(.iconOnly)
                        }
                        //                                  .padding()
                        .buttonStyle(.glass)
                        .accessibilitySortPriority(0)

                    }
                }
        } else { // iOS 15..18 Settings is the 3rd tab
            emptyView
                .toolbar { logoItem }
        }
    }
}

struct WalletEmptyView: View {
    private let symLog = SymLogV(0)
    let stack: CallStack

    @EnvironmentObject private var controller: Controller
    @EnvironmentObject private var model: WalletModel
    @AppStorage("myListStyle") var myListStyle: MyListStyle = .automatic
    @State private var withDrawStarted = false
    @State private var urlToOpen: URL? = nil

    var body: some View {
        let list = List {
            if !controller.defaultExchanges.isEmpty {
                ProdSectionView(stack: stack.push(), isEmpty: true, disabled: withDrawStarted)
            }
#if GNU_TALER
                Text("If you don't have a Swiss bank account, you can simply try out the demo…")
                    .talerFont(.body)
#endif

#if DEBUG
//              if developerMode {
//                Text("Either deposit or send your money to a friend before you delete the app, or it will be lost.")
//                    .talerFont(.body)
//              }
#endif
            Section {
//                Text("Demo")
//                    .talerFont(.headline)
//                Text("Get digital cash to experience how easy you can pay online, and send money to friends & family.")
                Text("Get demo cash to experience how to pay with digital cash.")
//                Text("Get digital cash to experience how to pay with the money of the future.")
                    .talerFont(.body)
                    .listRowSeparator(.hidden)
                let title = String(localized: "LinkTitle_Test_Money", defaultValue: "Get demo cash")
                Button(title) {
                    withDrawStarted = true    // don't run twice
                    Task { // runs on MainActor
                        let amount = Amount(currency:  DEMOCURRENCY, cent: 2500)
                        symLog.log("Withdraw KUDOS")
                        try? await model.loadTestKudos(0, amount: amount)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                            withDrawStarted = false
                        }
                    }
                }
                .buttonStyle(TalerButtonStyle(type: .prominent, narrow: false, disabled: withDrawStarted, aligned: .center))
                .disabled(withDrawStarted)
//            } header: {
//                let secondHeader = String(localized: "Demo", comment: "section header")
//                Text(secondHeader)
//                    .talerFont(.title3)
//                    .foregroundColor(WalletColors().secondary(colorScheme, colorSchemeContrast))
            }
        }
            .listStyle(myListStyle.style).anyView
            .talerFont(.title2)
            .background(FullBackground())
        ZStack {
            list
            if withDrawStarted {
                RotatingTaler(size: 150, progress: true, once: false, rotationEnabled: $withDrawStarted)
            }
        }
        .onAppear() {
            DebugViewC.shared.setViewID(VIEW_EMPTY_WALLET, stack: stack.push("onAppear"))     // 10
        }
    }
}

struct WalletEmptyView_Previews: PreviewProvider {
    static var previews: some View {
        WalletEmptyView(stack: CallStack("Preview"))
    }
}
