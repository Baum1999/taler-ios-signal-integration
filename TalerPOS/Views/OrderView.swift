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

struct OrderView: View {
    @EnvironmentObject var orderManager: OrderManager
    @EnvironmentObject var paymentManager: PaymentManager
    @EnvironmentObject var configManager: ConfigManager
    let onNavigate: (PosDestination) -> Void
    var openDrawer: (() -> Void)?

    @State private var showCustomProduct = false
    @State private var refreshTimer: Timer?
    @State private var toastMessage: String?
    @State private var manualReloadTriggered = false

    private var liveOrder: LiveOrder? { orderManager.currentLiveOrder }
    private var isTablet: Bool { UIDevice.current.userInterfaceIdiom == .pad }

    var body: some View {
        VStack(spacing: 0) {
            orderTopBar
            threeColumnLayout
        }
        .navigationBarHidden(true)
        .onAppear {
            startInventoryRefresh()
            if ScreenshotController.showCustomDialog {
                showCustomProduct = true
            }
        }
        .onDisappear { stopInventoryRefresh() }
        .sheet(isPresented: $showCustomProduct) {
            CustomProductDialog(currency: orderManager.currentLiveOrder?.order.currency ?? configManager.currency ?? "", currencySpec: configManager.currencySpec)  { product in
                if let orderId = liveOrder?.id {
                    orderManager.addProduct(orderId: orderId, product: product)
                }
            }
        }
        .toast(message: $toastMessage)
        .onChange(of: configManager.isLoading) { loading in
            if !loading && manualReloadTriggered {
                manualReloadTriggered = false
                toastMessage = S.toastReloaded
            }
        }
    }

    private var orderTopBar: some View {
        PosTopBar(
            title: liveOrder.map { S.orderLabelTitle("\($0.id)") } ?? "Order",
            onMenuTap: { openDrawer?() }
        ) {
            HStack(spacing: 8) {
                topBarButton(
                    label: liveOrder?.restartState == .undo ? S.orderUndo : S.orderRestart,
                    enabled: liveOrder?.restartState != .disabled || liveOrder?.order.products.isEmpty == false
                ) {
                    liveOrder?.restartOrUndo()
                }

                topBarButton(
                    label: S.orderPrevious,
                    enabled: orderManager.hasPreviousOrder()
                ) {
                    orderManager.previousOrder()
                }

                topBarButton(
                    label: S.orderNext,
                    enabled: orderManager.hasNextOrder()
                ) {
                    orderManager.nextOrder()
                }

                topBarButton(
                    label: S.menuReload,
                    enabled: true
                ) {
                    manualReloadTriggered = true
                    toastMessage = S.toastReloading
                    configManager.reloadConfig()
                }
            }
        }
    }

    private func topBarButton(label: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.subheadline)
                .fontWeight(.medium)
                .padding(.vertical, 8)
                .padding(.horizontal, 14)
                .frame(minHeight: 40)
                .background(enabled ? Color.posSecondaryContainer : Color.posSurfaceVariant)
                .foregroundColor(enabled ? .posOnSecondaryContainer : .posOnSurfaceVariant)
                .clipShape(RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    private var threeColumnLayout: some View {
        GeometryReader { geo in
            let catWeight: CGFloat = isTablet ? 0.25 : 0.22
            let prodWeight: CGFloat = isTablet ? 0.50 : 0.43
            let orderWeight: CGFloat = isTablet ? 0.25 : 0.35
            let compact = !isTablet

            HStack(spacing: 0) {
                CategoriesPane(
                    categories: orderManager.categories,
                    onSelect: { orderManager.selectCategory($0) }
                )
                .frame(width: geo.size.width * catWeight)

                Color.posOutlineVariant.frame(width: 1)

                ProductsPane(
                    products: orderManager.products,
                    currencySpec: configManager.currencySpec,
                    compact: compact,
                    onTap: { product in
                        if let orderId = liveOrder?.id {
                            orderManager.addProduct(orderId: orderId, product: product)
                        }
                    }
                )
                .frame(width: geo.size.width * prodWeight)

                Color.posOutlineVariant.frame(width: 1)

                OrderColumnPane(
                    liveOrder: liveOrder,
                    currencySpec: configManager.currencySpec,
                    compact: compact,
                    onSelectLine: { product in liveOrder?.selectOrderLine(product) },
                    onIncrease: { liveOrder?.increaseSelectedOrderLine() },
                    onDecrease: { liveOrder?.decreaseSelectedOrderLine() },
                    onCustom: { showCustomProduct = true },
                    onComplete: {
                        guard let lo = liveOrder, !lo.order.products.isEmpty else { return }
                        paymentManager.createPayment(order: lo.order)
                        onNavigate(.processPayment)
                    }
                )
                .frame(width: geo.size.width * orderWeight)
            }
            .padding(.horizontal, isTablet ? 0 : 8)
            .padding(.vertical, isTablet ? 0 : 10)
        }
    }

    private func startInventoryRefresh() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
            configManager.refreshInventory()
        }
    }

    private func stopInventoryRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
}

struct CategoriesPane: View {
    let categories: [Category]
    let onSelect: (Category) -> Void

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 6) {
                ForEach(categories) { category in
                    Button {
                        onSelect(category)
                    } label: {
                        Text(category.localizedName)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 8)
                            .background(category.selected ? Color.posSecondary : Color.posSecondaryContainer)
                            .foregroundColor(category.selected ? .posOnSecondary : .posOnSecondaryContainer)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(Color.posOutlineVariant, lineWidth: 1))
                    }
                }
            }
            .padding(8)
        }
    }
}

struct ProductsPane: View {
    let products: [ConfigProduct]
    var currencySpec: CurrencySpecification?
    var compact: Bool = false
    let onTap: (ConfigProduct) -> Void

    var body: some View {
        GeometryReader { geo in
            let spacing: CGFloat = compact ? 6 : 8
            let minTileWidth: CGFloat = compact ? 96 : 150
            let columns = max(1, Int((geo.size.width + spacing) / (minTileWidth + spacing)))
            let rows = products.chunked(into: columns)

            ScrollView {
                VStack(spacing: spacing) {
                    ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                        let rowHasImage = row.contains { $0.image != nil && !$0.image!.isEmpty }
                        HStack(spacing: spacing) {
                            ForEach(row) { product in
                                ProductCard(
                                    product: product,
                                    currencySpec: currencySpec,
                                    compact: compact,
                                    rowHasImage: rowHasImage
                                ) {
                                    onTap(product)
                                }
                            }
                            if row.count < columns {
                                ForEach(0..<(columns - row.count), id: \.self) { _ in
                                    Color.clear.frame(maxWidth: .infinity)
                                }
                            }
                        }
                    }
                }
                .padding(compact ? 4 : 8)
                .padding(.top, compact ? 8 : 12)
            }
        }
    }
}

struct ProductCard: View {
    let product: ConfigProduct
    var currencySpec: CurrencySpecification?
    var compact: Bool = false
    var rowHasImage: Bool = false
    let onTap: () -> Void

    private var imageSize: CGFloat { compact ? 40 : 64 }

    private var unavailableReason: String? {
        guard !product.availableToSell else { return nil }
        if product.currencyMismatch { return S.productWrongCurrency }
        if product.remainingStock == 0 { return S.productOutOfStock }
        return S.productUnavailable
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: compact ? 3 : 4) {
                if let uiImage = product.decodedImage {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: imageSize, height: imageSize)
                        .frame(maxWidth: .infinity)
                } else if rowHasImage {
                    Spacer()
                        .frame(height: imageSize)
                        .frame(maxWidth: .infinity)
                }

                Text(product.displayName)
                    .font(compact ? .caption : .subheadline)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity)

                if let desc = product.displayDescription {
                    Text(desc)
                        .font(compact ? .caption2 : .caption)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity)
                }

                Spacer(minLength: 0)

                Text(product.price.readableAmount(spec: currencySpec))
                    .font(compact ? .caption : .subheadline)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)

                if let reason = unavailableReason {
                    Text(reason)
                        .font(compact ? .caption2 : .caption)
                        .fontWeight(.bold)
                        .foregroundColor(.posError)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(compact ? 6 : 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(product.availableToSell ? Color.posSurface : Color.posSurfaceVariant)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(
                        product.availableToSell ? Color.posOutlineVariant : Color.posError.opacity(0.4),
                        lineWidth: 1
                    )
            )
            .shadow(color: .black.opacity(0.04), radius: 1, y: 1)
        }
        .buttonStyle(.plain)
        .disabled(!product.availableToSell)
    }
}

struct OrderColumnPane: View {
    let liveOrder: LiveOrder?
    var currencySpec: CurrencySpecification?
    var compact: Bool = false
    let onSelectLine: (ConfigProduct?) -> Void
    let onIncrease: () -> Void
    let onDecrease: () -> Void
    let onCustom: () -> Void
    let onComplete: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            if let lo = liveOrder {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(lo.order.products) { product in
                            OrderRow(
                                product: product,
                                currencySpec: currencySpec,
                                isSelected: lo.selectedProductKey == product.id,
                                compact: compact
                            ) {
                                onSelectLine(product)
                            }
                            Color.posOutlineVariant.frame(height: 1)
                        }
                    }
                }

                Color.posOutlineVariant.frame(height: 1)

                OrderActionBar(
                    modifyAllowed: lo.modifyOrderAllowed,
                    increaseAllowed: lo.increaseOrderAllowed,
                    hasProducts: !lo.order.products.isEmpty,
                    totalAmount: lo.order.total.readableAmount(spec: currencySpec),
                    compact: compact,
                    onIncrease: onIncrease,
                    onDecrease: onDecrease,
                    onCustom: onCustom,
                    onComplete: onComplete
                )
            }
        }
    }
}

struct OrderRow: View {
    let product: ConfigProduct
    var currencySpec: CurrencySpecification?
    let isSelected: Bool
    var compact: Bool = false
    let onTap: () -> Void

    private var imageSize: CGFloat { compact ? 28 : 36 }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: compact ? 6 : 8) {
                Text("\(product.quantity)")
                    .font(compact ? .caption : .subheadline)
                    .fontWeight(.semibold)
                    .frame(width: 24, alignment: .trailing)

                if let uiImage = product.decodedImage {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: imageSize, height: imageSize)
                } else {
                    Color.clear.frame(width: imageSize, height: imageSize)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(product.displayName)
                        .font(compact ? .caption : .subheadline)
                        .lineLimit(2)
                    if let desc = product.displayDescription {
                        Text(desc)
                            .font(compact ? .caption2 : .caption)
                            .foregroundColor(.posOnSurfaceVariant)
                            .lineLimit(1)
                    }
                }

                Spacer()

                Text((product.price * product.quantity).readableAmount(spec: currencySpec))
                    .font(compact ? .caption : .subheadline)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, compact ? 6 : 10)
            .padding(.vertical, compact ? 4 : 8)
            .contentShape(Rectangle())
            .background(isSelected ? Color.posSecondaryContainer : Color.clear)
        }
        .buttonStyle(.plain)
    }
}

struct OrderActionBar: View {
    let modifyAllowed: Bool
    let increaseAllowed: Bool
    let hasProducts: Bool
    var totalAmount: String = ""
    var compact: Bool = false
    let onIncrease: () -> Void
    let onDecrease: () -> Void
    let onCustom: () -> Void
    let onComplete: () -> Void

    var body: some View {
        VStack(spacing: compact ? 8 : 12) {
            HStack(spacing: compact ? 8 : 12) {
                orderControlButton(label: "+1", enabled: modifyAllowed && increaseAllowed, action: onIncrease)
                orderControlButton(label: "-1", enabled: modifyAllowed, action: onDecrease)
                Button(action: onCustom) {
                    Image(systemName: "square.grid.3x3")
                        .font(compact ? .body : .title3)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Color.posPrimaryContainer)
                        .foregroundColor(.posOnPrimaryContainer)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(S.orderCustom)
            }

            Button(action: onComplete) {
                Text(hasProducts ? S.orderCompleteWithAmount(totalAmount) : S.orderComplete)
                    .font(compact ? .body : .title3)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .frame(height: compact ? 72 : 96)
                    .background(hasProducts ? Color.posPrimary : Color.posSurfaceVariant)
                    .foregroundColor(hasProducts ? .posOnPrimary : .posOnSurfaceVariant)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
            }
            .buttonStyle(.plain)
            .disabled(!hasProducts)
        }
        .padding(12)
    }

    private func orderControlButton(label: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(compact ? .body : .title3)
                .fontWeight(.medium)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(enabled ? Color.posPrimaryContainer : Color.posSurfaceVariant)
                .foregroundColor(enabled ? .posOnPrimaryContainer : .posOnSurfaceVariant)
                .clipShape(RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

struct CustomProductDialog: View {
    let currency: String
    let currencySpec: CurrencySpecification?
    let onAdd: (ConfigProduct) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name = S.orderCustomProductDefault
    @State private var amount: Amount = .zero("")
    @FocusState private var nameFieldFocused: Bool

    private var numInputDigits: Int {
        currencySpec?.numFractionalInputDigits ?? 2
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                ScrollView {
                    VStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(S.orderCustomProduct)
                                .font(.caption)
                                .foregroundColor(.posOnSurfaceVariant)
                            TextField(S.orderCustomProduct, text: $name)
                                .focused($nameFieldFocused)
                                .submitLabel(.done)
                                .onSubmit { nameFieldFocused = false }
                                .padding(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.posOutline, lineWidth: 1)
                                )
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 8)

                        HStack {
                            Spacer()
                            Text(amount.amountStr(numDigits: numInputDigits))
                                .font(.system(size: 40, weight: .bold))
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                            Text(currency)
                                .font(.title3)
                                .foregroundColor(.posOnSurfaceVariant)
                            Spacer()
                        }
                        .padding(.vertical, 8)
                        .onTapGesture { nameFieldFocused = false }

                        AmountNumpad(
                            amount: $amount,
                            currency: currency,
                            numInputDigits: numInputDigits,
                            isCompact: true,
                            onKeyPressed: { nameFieldFocused = false }
                        )
                        .frame(height: geo.size.height * 0.55)
                        .padding(.horizontal, 20)

                        Button {
                            guard !name.isEmpty, !amount.isZero else { return }
                            let product = ConfigProduct(
                                description: name,
                                price: amount,
                                categories: [Int.min],
                                quantity: 1
                            )
                            onAdd(product)
                            dismiss()
                        } label: {
                            Text(S.orderCustomAdd)
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(!name.isEmpty && !amount.isZero ? Color.posPrimary : Color.posSurfaceVariant)
                                .foregroundColor(!name.isEmpty && !amount.isZero ? .posOnPrimary : .posOnSurfaceVariant)
                                .cornerRadius(12)
                        }
                        .disabled(name.isEmpty || amount.isZero)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 12)
                    }
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle(S.orderCustom)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(S.refundAbort) { dismiss() }
                }
            }
            .onAppear {
                amount = .zero(currency)
            }
        }
    }
}
