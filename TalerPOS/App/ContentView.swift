/*
 * This file is part of GNU Taler
 * (C) 2026 Bohdan, Volodymyr Potuzhnyi
 *
 * GNU Taler is free software; you can redistribute it and/or modify it under the
 * terms of the GNU General Public License as published by the Free Software
 * Foundation; either version 3, or (at your option) any later version.
 *
 * GNU Taler is distributed in the hope that it will be useful, but WITHOUT ANY
 * WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
 * A PARTICULAR PURPOSE. See the GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along with
 * GNU Taler; see the file COPYING. If not, see <http://www.gnu.org/licenses/>
 */

import SwiftUI

enum PosDestination: Hashable {
    case amountEntry
    case order
    case history
    case settings
    case config
    case processPayment
    case paymentSuccess
    case refund(OrderHistoryEntry)
    case refundUri

    func hash(into hasher: inout Hasher) {
        switch self {
        case .amountEntry: hasher.combine("amountEntry")
        case .order: hasher.combine("order")
        case .history: hasher.combine("history")
        case .settings: hasher.combine("settings")
        case .config: hasher.combine("config")
        case .processPayment: hasher.combine("processPayment")
        case .paymentSuccess: hasher.combine("paymentSuccess")
        case .refund(let item): hasher.combine("refund"); hasher.combine(item.orderId)
        case .refundUri: hasher.combine("refundUri")
        }
    }

    static func == (lhs: PosDestination, rhs: PosDestination) -> Bool {
        switch (lhs, rhs) {
        case (.amountEntry, .amountEntry), (.order, .order), (.history, .history),
             (.settings, .settings), (.config, .config), (.processPayment, .processPayment),
             (.paymentSuccess, .paymentSuccess), (.refundUri, .refundUri):
            return true
        case (.refund(let a), .refund(let b)):
            return a.orderId == b.orderId
        default: return false
        }
    }

    var title: String {
        switch self {
        case .amountEntry: return S.menuAmountEntry
        case .order: return S.menuOrder
        case .history: return S.menuHistory
        case .settings: return S.menuSettings
        case .config: return S.configLabel
        case .processPayment: return S.paymentProcessLabel
        case .paymentSuccess: return S.paymentReceived
        case .refund: return S.historyRefund
        case .refundUri: return S.historyRefund
        }
    }

    var icon: String {
        switch self {
        case .amountEntry: return "circle.grid.3x3"
        case .order: return "cart"
        case .history: return "clock"
        case .settings: return "gearshape"
        default: return "circle"
        }
    }

    var isMainDestination: Bool {
        switch self {
        case .amountEntry, .order, .history, .settings: return true
        default: return false
        }
    }

    var savedKey: String {
        switch self {
        case .amountEntry: return "amountEntry"
        case .order: return "order"
        case .history: return "history"
        case .settings: return "settings"
        default: return ""
        }
    }

    static func from(savedKey: String) -> PosDestination? {
        switch savedKey {
        case "amountEntry": return .amountEntry
        case "order": return .order
        case "history": return .history
        case "settings": return .settings
        default: return nil
        }
    }
}

struct NavigationDrawer: View {
    let currentRoot: PosDestination
    let destinations: [PosDestination]
    let onSelect: (PosDestination) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image("talerpos-logo")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .padding(.horizontal, 8)
                .padding(.vertical, 8)

            ForEach(destinations, id: \.self) { dest in
                Button {
                    onSelect(dest)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: dest.icon)
                            .font(.body)
                            .frame(width: 24)
                        Text(dest.title)
                            .font(.body)
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                    .background(
                        currentRoot == dest
                            ? Color.posSecondaryContainer
                            : Color.clear
                    )
                    .foregroundColor(
                        currentRoot == dest
                            ? .posOnSecondaryContainer
                            : .posOnSurface
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 28))
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
        .padding(12)
        .frame(width: 280)
        .frame(maxHeight: .infinity)
        .background(Color.posSurface)
    }
}

struct PosTopBar<Actions: View>: View {
    let title: String
    let onMenuTap: () -> Void
    let actions: Actions

    init(title: String, onMenuTap: @escaping () -> Void, @ViewBuilder actions: () -> Actions) {
        self.title = title
        self.onMenuTap = onMenuTap
        self.actions = actions()
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Button {
                    onMenuTap()
                } label: {
                    Image(systemName: "line.3.horizontal")
                        .font(.title2)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                        .foregroundColor(.posOnSurface)
                }
                .buttonStyle(.plain)

                Text(title)
                    .font(.title3)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .foregroundColor(.posOnSurface)

                Spacer(minLength: 0)

                actions
                    .fixedSize(horizontal: true, vertical: false)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
        }
        .background(Color.posSurface)
        .shadow(color: .black.opacity(0.12), radius: 2, y: 1)
    }
}

extension PosTopBar where Actions == EmptyView {
    init(title: String, onMenuTap: @escaping () -> Void) {
        self.title = title
        self.onMenuTap = onMenuTap
        self.actions = EmptyView()
    }
}

struct ContentView: View {
    @EnvironmentObject var configManager: ConfigManager
    @EnvironmentObject var orderManager: OrderManager
    @EnvironmentObject var paymentManager: PaymentManager
    @EnvironmentObject var historyManager: HistoryManager
    @EnvironmentObject var refundManager: RefundManager
    @State private var navigationPath = NavigationPath()
    @State private var currentRoot: PosDestination = .amountEntry
    @State var drawerOpen = false
    @AppStorage("pos_current_root") private var savedRoot: String = ""

    private var mainDestinations: [PosDestination] {
        let preferred: PosDestination = configManager.initialOrderScreen.destination
        var items: [PosDestination] = [.amountEntry, .order, .history, .settings]
        items.removeAll { $0 == preferred }
        items.insert(preferred, at: 0)
        return items
    }

    private var appState: AppState {
        if !configManager.isValid {
            return .needsConfig
        }
        if configManager.isConfigured {
            return .configured
        }
        return .fetching
    }

    private enum AppState {
        case needsConfig
        case fetching
        case configured
    }

    var body: some View {
        Group {
            switch appState {
            case .configured:
                mainView
            case .fetching:
                NavigationStack {
                    configFetcherView
                }
            case .needsConfig:
                NavigationStack {
                    ConfigView(onConfigured: {
                        currentRoot = configManager.initialOrderScreen.destination
                    })
                }
            }
        }
        .onAppear {
            if let scenario = ScreenshotController.activeScenario {
                let dest = scenario.destination
                if dest.isMainDestination {
                    currentRoot = dest
                } else {
                    currentRoot = .order
                    DispatchQueue.main.async {
                        navigationPath.append(dest)
                    }
                }
            } else if let restored = PosDestination.from(savedKey: savedRoot), restored.isMainDestination {
                currentRoot = restored
            } else {
                currentRoot = configManager.initialOrderScreen.destination
            }
        }
        .onChange(of: currentRoot) { newRoot in
            savedRoot = newRoot.savedKey
        }
        .alert(S.sessionExpiredToast, isPresented: $configManager.sessionExpired) {
            Button(S.configOk) {
                configManager.sessionExpired = false
            }
        } message: {
            Text(S.sessionExpiredToast)
        }
        .onChange(of: refundManager.refundResult) { result in
            if case .success = result {
                navigateTo(.refundUri)
            }
        }
        .onChange(of: refundManager.refundReceived) { received in
            if received {
                navigationPath.removeLast(navigationPath.count)
                currentRoot = .history
            }
        }
        .onChange(of: paymentManager.payment?.paid) { paid in
            guard paid == true else { return }
            if let order = paymentManager.payment?.order {
                orderManager.onOrderPaid(order.id)
            }
            historyManager.fetchHistory()
            navigationPath.removeLast(navigationPath.count)
            navigateTo(.paymentSuccess)
        }
        .onChange(of: configManager.isConfigured) { configured in
            if !configured {
                navigationPath.removeLast(navigationPath.count)
            }
        }
        .onChange(of: configManager.isValid) { valid in
            if !valid {
                navigationPath.removeLast(navigationPath.count)
            }
        }
    }

    private var configFetcherView: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
                .scaleEffect(1.5)
            Text(S.configFetching)
                .font(.title3)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .navigationTitle(S.configLabel)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if configManager.savePassword {
                configManager.fetchConfig(
                    url: configManager.merchantUrl,
                    token: configManager.accessToken,
                    save: false
                )
            }
        }
        .onChange(of: configManager.configResult) { result in
            if case .success = result {
                currentRoot = configManager.initialOrderScreen.destination
            }
        }
    }

    private var mainView: some View {
        ZStack(alignment: .leading) {
            NavigationStack(path: $navigationPath) {
                rootView(for: currentRoot)
                    .id(currentRoot)
                    .navigationDestination(for: PosDestination.self) { destination in
                        destinationView(for: destination)
                    }
            }

            if drawerOpen {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.25)) { drawerOpen = false }
                    }
                    .transition(.opacity)
                    .zIndex(1)

                NavigationDrawer(
                    currentRoot: currentRoot,
                    destinations: mainDestinations,
                    onSelect: { dest in
                        withAnimation(.easeInOut(duration: 0.25)) { drawerOpen = false }
                        currentRoot = dest
                        navigationPath.removeLast(navigationPath.count)
                    }
                )
                .transition(.move(edge: .leading))
                .zIndex(2)
            }
        }
    }

    private func openDrawerAnimated() {
        withAnimation(.easeInOut(duration: 0.25)) { drawerOpen = true }
    }

    @ViewBuilder
    private func rootView(for destination: PosDestination) -> some View {
        switch destination {
        case .amountEntry:
            AmountEntryView(onNavigate: navigateTo, openDrawer: openDrawerAnimated)
        case .order:
            OrderView(onNavigate: navigateTo, openDrawer: openDrawerAnimated)
        case .history:
            HistoryView(onNavigate: navigateTo, openDrawer: openDrawerAnimated)
        case .settings:
            SettingsView(onNavigate: navigateTo, openDrawer: openDrawerAnimated)
        default:
            OrderView(onNavigate: navigateTo, openDrawer: openDrawerAnimated)
        }
    }

    @ViewBuilder
    private func destinationView(for destination: PosDestination) -> some View {
        switch destination {
        case .processPayment:
            ProcessPaymentView(onNavigate: navigateTo)
        case .paymentSuccess:
            PaymentSuccessView(onNavigate: navigateTo)
        case .refund(let item):
            RefundFormView(item: item)
        case .refundUri:
            RefundUriView()
        case .config:
            ConfigView(onConfigured: {
                navigationPath.removeLast(navigationPath.count)
                currentRoot = configManager.initialOrderScreen.destination
            })
        default:
            rootView(for: destination)
        }
    }

    func navigateTo(_ destination: PosDestination) {
        if destination.isMainDestination {
            currentRoot = destination
            navigationPath.removeLast(navigationPath.count)
        } else {
            navigationPath.append(destination)
        }
    }

    func navigateBack() {
        if !navigationPath.isEmpty {
            navigationPath.removeLast()
        }
    }
}
