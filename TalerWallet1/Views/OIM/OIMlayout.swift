/*
 * This file is part of GNU Taler, ©2022-25 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import SwiftUI
import SymLog

struct OIMid: LayoutValueKey {
    static let defaultValue = 0
}
struct OIMvalue: LayoutValueKey {
    static let defaultValue: UInt64 = 0
}
struct OIMfundState: LayoutValueKey {
    static let defaultValue: FundState = .idle
}

@available(iOS 16.4, *)
extension View {
    func oimID(_ value: Int) -> some View {
        self.layoutValue(key: OIMid.self, value: value)
    }
    func oimValue(_ value: UInt64) -> some View {
        self.layoutValue(key: OIMvalue.self, value: value)
    }
    func oimFundState(_ value: FundState) -> some View {
        self.layoutValue(key: OIMfundState.self, value: value)
    }
}

@available(iOS 16.4, *)
extension LayoutSubview {
    var oimID: Int { self[OIMid.self] }
    var oimValue: UInt64 { self[OIMvalue.self] }
    var oimFundState: FundState { self[OIMfundState.self] }
}

// MARK: -
// renders a stack of (identical) banknotes with offset 10,20
@available(iOS 16.4, *)
struct OIMlayoutView: View {
    private let symLog = SymLogV(0)
    let stack: CallStack
    let funds: OIMfunds
    @Binding var amountVal: UInt64
    let canEdit: Bool

    @EnvironmentObject private var cash: OIMcash
    @EnvironmentObject private var wrapper: NamespaceWrapper

    var body: some View {
        OIMlayout {
            ForEach(funds){ item in
                var fund = item

                let value = fund.value
                let fundState = fund.state
                let isFlying = fundState == .flying
                let isFlipped = fundState == .flipped
                OIMcurrencyButton(stack: stack.push(),
                                   fund: fund,
                               currency: cash.currency,
                           availableVal: value,
                                canEdit: canEdit && !isFlipped,                               // && isTop,
                                    pct: isFlying ? 0.0 : 1.0
                ) {   // remove on button press
                    if amountVal >= fund.value {
                        amountVal -= fund.value
                    } else {
                        symLog.log("  ❗️Yikes - trying to make amount negative")
                        amountVal = 0
                    }
                    withAnimation(.basic1) {
                        fund.state = .flipped                                       // button animates itself anyway
                        cash.updateFund(fund)
                    }
                    DispatchQueue.main.async {
                        withAnimation(.fly1) {
                            symLog.log("    OIMlayoutView remove \(value)")
                            cash.removeCash(id: fund.id, value: fund.value)
                        }
                    }
                }
                .id(fund.id)
                .oimValue(value)
                .oimID(fund.id)
                .oimFundState(fundState)
                .matchedGeometryEffect(id: fund.targetID, in: wrapper.namespace, isSource: false)    // !isFlying
                .onAppear {
                    if isFlying {
//                        print("    ->OIMlayoutView.onAppear stop matching \(value), \(fund.id)")
                        withAnimation(.fly1) {
                            // OIMnoteV appeared at the position of the currency button, now start flying
                            fund.state = .idle               // switch off matching
                            cash.updateFund(fund)
                        }
                    } else if isFlipped {
                        withAnimation(.fly1) {
                            fund.state = .idle
                            cash.updateFund(fund)
                        }
//                    } else {
//                        print("    ->OIMlayoutView.onAppear ignore \(value), \(fund.id)")
                    }
                }
            }
        }
    }
}
// MARK: -
@available(iOS 16.4, *)
struct OIMlayout: Layout {
    struct CacheData {
        var maxHeight: CGFloat
        var spaces: [CGFloat]
    }

    var spacing: CGFloat? = nil

    func makeCache(subviews: Subviews) -> CacheData {
        return CacheData(maxHeight: computeMaxHeight(subviews: subviews),
                            spaces: computeSpaces(subviews: subviews))
    }

    func updateCache(_ cache: inout CacheData, subviews: Subviews) {
        cache.maxHeight = computeMaxHeight(subviews: subviews)
        cache.spaces = computeSpaces(subviews: subviews)
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout CacheData) -> CGSize {
        let idealViewSizes = subviews.map { $0.sizeThatFits(.unspecified) }
        let accumulatedWidths = idealViewSizes.reduce(0) { $0 + $1.width }
        let accumulatedSpaces = cache.spaces.reduce(0) { $0 + $1 }

        return CGSize(width: accumulatedSpaces + accumulatedWidths,
                     height: cache.maxHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout CacheData) {
        var pt = CGPoint(x: bounds.minX, y: bounds.minY)

        let sorted = subviews.sorted(by: { ($0.oimValue > $1.oimValue) ||
                                         ( ($0.oimValue == $1.oimValue) && ($0.oimID < $1.oimID) ) })
        for idx in sorted.indices {
            sorted[idx].place(at: pt, anchor: .topLeading, proposal: .unspecified)

            if idx < sorted.count - 1 {
                let width = sorted[idx].sizeThatFits(.unspecified).width
                pt.x += width + cache.spaces[idx]
            }
        }
    }

    func computeSpaces(subviews: LayoutSubviews) -> [CGFloat] {
        if let spacing {
            return Array<CGFloat>(repeating: spacing, count: subviews.count - 1)
        } else {
            return subviews.indices.map { idx in
                guard idx < subviews.count - 1 else { return CGFloat(0) }

                return subviews[idx].spacing.distance(to: subviews[idx+1].spacing, along: .horizontal)
            }
        }
    }

    func computeMaxHeight(subviews: LayoutSubviews) -> CGFloat {
        return subviews.map { $0.sizeThatFits(.unspecified) }.reduce(0) { max($0, $1.height) }
    }
}


