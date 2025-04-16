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
    @State private var checkStacks: UInt64 = 0

    var body: some View {
        OIMlayout {
            ForEach(funds){ item in
                var fund = item

                let value = fund.value
                let fundState = fund.state
                let shouldFly = fundState == .shouldFly
                let isFlipped = fundState == .flipping
                let shouldMorph = fundState == .morphingIn
                OIMcurrencyButton(stack: stack.push(),
                                   fund: fund,
                               currency: cash.currency,
                           availableVal: value,
                                canEdit: canEdit && !isFlipped,
                                    pct: shouldFly ? 0.0 : 1.0
                ) {   // remove on button press
                    if amountVal >= fund.value {
                        amountVal -= fund.value
                    } else {
                        symLog.log("  ❗️Yikes - trying to make amount negative")
                        amountVal = 0
                    }
                    withAnimation(.basic1) {
                        fund.state = .flipping
                        cash.updateFund(fund)
                    }
                    DispatchQueue.main.async {
                        withAnimation(.remove1) {
                            symLog.log("    OIMlayoutView remove \(value)")
                            cash.removeCash(id: fund.id, value: fund.value)
                        }
                    }
                }
                .zIndex(Double(fund.id))
                .id(fund.id)
                .oimValue(value)
                .oimID(fund.id)
                .oimFundState(fundState)
                .matchedGeometryEffect(id: fund.targetID, in: wrapper.namespace, isSource: false)    // !isFlying
                .onAppear {
                    if shouldFly {
//                        print("    ->OIMlayoutView.onAppear stop matching \(value), \(fund.id)")
                        withAnimation(.fly1) {
                            print("*** start flying:", value, fund.id)
                            fund.state = .isFlying               // switch off matching
                            cash.updateFund(fund)
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + (fastAnimations ? 0.6 : 1.0)) {
                            withAnimation(.fly1) {
                                print("*** end flying:", value, fund.id)
                                fund.state = .idle              // move onto stack
                                cash.updateFund(fund)
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + (fastAnimations ? 0.6 : 1.0)) {
                                checkStacks = value
                            }
                        }
                    } else if isFlipped {
                        withAnimation(.fly1) {
                            print("*** start flipping:", value, fund.id)
                            fund.state = .idle
                            cash.updateFund(fund)
                        }
                    } else if shouldMorph {
                        withAnimation(.fly1) {
                            print("*** start morphing:", value, fund.id)
                            fund.state = .isMorphing
                            cash.updateFund(fund)
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + (fastAnimations ? 0.6 : 1.0)) {
                            withAnimation(.fly1) {
                                print("*** end morphing:", value, fund.id)
                                fund.state = .idle              // move onto stack
                                cash.updateFund(fund)
                            }
                        }
//                    } else {
//                        print("    ->OIMlayoutView.onAppear ignore \(value), \(fund.id)")
                    }
                }
            }
        }
        .onChange(of: checkStacks) { value in
            if value > 0 {
                print("*** check:", value)
                var firstCheck = value
                if let moreThan4 = cash.checkStacks(first: firstCheck) {
                    firstCheck = 0
//                    withAnimation(.fly1) {
                        cash.compactStacks(moreThan4)
//                    }
                }
                checkStacks = 0
            }
        }
    }
}
// MARK: -
@available(iOS 16.4, *)
struct OIMlayout: Layout {
//    struct CacheData {
////        var maxHeight: CGFloat
//        var spaces: [CGSize]
//    }
//
//    func computeMaxHeight(sorted: [LayoutSubview]) -> CGFloat {
//
//        return sorted.map { $0.sizeThatFits(.unspecified) }.reduce(0) { max($0, $1.height) }
//    }
//
//    func computeSpaces(_ sorted: [LayoutSubview]) -> [CGSize] {
//        //
//        return sorted.indices.map { idx in
//            guard idx < sorted.count - 1 else { return CGSize.zero }
//
//            return
//        }
//    }
//
//    func makeCache(subviews: Subviews) -> CacheData {
//        let sorted = sortByValue(subviews)
//        return CacheData(maxHeight: computeMaxHeight(sorted),
//                            spaces: computeSpaces(subviews: sorted))
//    }
//
//    func updateCache(_ cache: inout CacheData, subviews: Subviews) {
//        cache.maxHeight = computeMaxHeight(subviews: subviews)
//        cache.spaces = computeSpaces(subviews: subviews)
//    }

    func sortByValue(_ subviews: LayoutSubviews) -> [LayoutSubview] {
        // sorts DESCENDING - we render the denominations top-down
        subviews.sorted(by: { ($0.oimValue > $1.oimValue) ||
                            ( ($0.oimValue == $1.oimValue) && ($0.oimID < $1.oimID) ) })
    }

    func computeSpaces(_ sorted: [LayoutSubview], _ max: Int = MAXSTACK) -> [Int] {
        /// returns array of stackIndexes
        /// 0  ==> next view starts a new stack
        /// 1..3  ==> next view is on the stack
        var spaces: [Int] = []

        let count = sorted.count

        var stackIndex = 0
        var lastValue: UInt64 = 0
        for (index, subview) in sorted.enumerated() {
            let value = subview.oimValue
            let state = subview.oimFundState
            if state == .shouldFly || state == .isFlying        // flying can not go on the stack
                                   || state == .morphingIn      // nor can morphing in...
                                   || state == .morphingOut {   // ...or morphing out
                // we always morph out from the end, thus there will be no more idling funds with the same value
                lastValue = 0                                   // let the next subview...
                stackIndex = 0                                  // ...start a new stack
            } else if lastValue != value {                      // different value?
                lastValue = value                               // save this value for the next subview
                stackIndex = 0                                  // start a new stack
            } else {
                stackIndex += 1                                 // Yay, we found one to add to this stack
                if stackIndex == max {                          // max 4 subviews per stack
                    stackIndex = 0                              // stack is full, start a new one but keep the value
            }   }
            if index > 0 {
                spaces.append(stackIndex)
            }
        }
        return spaces
    }

    func accumulate(spaces: [Int], _ viewSizes: [CGSize], spacing: CGFloat, xOffset: CGFloat) -> CGFloat {
        var accumulatedSpaces: CGFloat = .zero
        for (idx, stackIndex) in spaces.enumerated() {
            if stackIndex > 0 {
                accumulatedSpaces += (xOffset - viewSizes[idx].width)
            } else {
                accumulatedSpaces += spacing
            }
        }
        return accumulatedSpaces
    }

    func spacing(for proposal: ProposedViewSize) -> (CGFloat, CGPoint) {
        switch proposal {
            case .infinity:                         // max size: just place all views in one row
                (10, CGPoint(x: 10, y: 0))
            case .zero:                             // minimum size: tight spacing
                (8, CGPoint(x: 8, y: 20))
            default:                                // TODO: compute offset - in the meantime => ideal size
//            case .unspecified:                      // => ideal size
                (10, CGPoint(x: 16, y: 16))
        }
    }

    func accumulate(views: [LayoutSubview], sizes: [CGSize]) -> CGFloat {
        var result = CGFloat.zero
        for (index, subview) in views.enumerated() {
            let state = subview.oimFundState
            if state != .morphingOut {
                let size = sizes[index]
                result += size.width
            }
        }
        return result
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard subviews.count > 0 else { return CGSize.zero }
        let (spacing, offset) = spacing(for: proposal)
        let sorted = sortByValue(subviews)
        let viewSizes = sorted.map { $0.sizeThatFits(proposal) }        // <- THIS takes time...
        let maxHeight = viewSizes.reduce(0) { max($0, $1.height) }      // get the max height
//        let viewWidths = viewSizes.reduce(0) { $0 + $1.width }          // add up all widths
        let viewWidths = accumulate(views: sorted, sizes: viewSizes)    // add up all widths

        let spaces = computeSpaces(sorted)
        let maxStackIndex = spaces.reduce(0) { max($0, $1) }

        var accumulatedSpaces: CGFloat = .zero
        var stackHeight: CGFloat = .zero
        switch proposal {
            case .infinity:         // max size: just place all views in one row
//                print("MAX:", proposal)
                accumulatedSpaces = spacing * CGFloat(sorted.count - 1)
                break
            case .zero:             // minimum size:
//                print("min:", proposal)
                // all stacks with offset x = 8, y = 20
                stackHeight = offset.y * CGFloat(maxStackIndex)
                accumulatedSpaces = accumulate(spaces: spaces, viewSizes, spacing: spacing, xOffset: offset.x)
                break
            case .unspecified:    // => ideal size
//                print("Ideal:", proposal)
                stackHeight = offset.y * CGFloat(maxStackIndex)
                accumulatedSpaces = accumulate(spaces: spaces, viewSizes, spacing: spacing, xOffset: offset.x)
                break
            default:
                if var spaceToFill = proposal.width {
                    if var heightToFill = proposal.height {
            //            print("Yikes❗️ width + height:", spaceToFill, heightToFill)
//                      // TODO: compute the inner-stack offsets
//                      spaceToFill -= viewWidths       // might be negative
                    } else { // unspecified
                        print("Yikes❗️ width only:", spaceToFill)
                    }
                } else if var heightToFill = proposal.height {
                    print("Yikes❗️ height only:", heightToFill)
                } else { // unspecified
                    print("Yikes❗️ should NEVER happen:", proposal)
                }

                // while inner-stack offsets is not yet implemented, return ideal size
                stackHeight = offset.y * CGFloat(maxStackIndex)
                accumulatedSpaces = accumulate(spaces: spaces, viewSizes, spacing: spacing, xOffset: offset.x)
                break
        }
        let result = CGSize(width: viewWidths + accumulatedSpaces,
                      height: maxHeight + stackHeight)
//        print("   ***sizeThatFits:", result)
        return result
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let (spacing, offset) = spacing(for: proposal)
        let sorted = sortByValue(subviews)
        let spaces = computeSpaces(sorted)
        let isMax = proposal == .infinity

        var pt = CGPoint(x: bounds.minX, y: bounds.minY)
        var morphPt = CGPoint.zero
        for idx in sorted.indices {
            let subview = sorted[idx]
            let state = subview.oimFundState
            if state == .morphingIn || state == .isMorphing {
                print("morphing into ク\(subview.oimValue),\(subview.oimID) at", pt)
                morphPt = pt
            }
            subview.place(at: pt, anchor: .topLeading, proposal: proposal)
            if state == .morphingOut {
                if morphPt != CGPoint.zero {
                    print("morphing ク\(subview.oimValue),\(subview.oimID) from \(pt) to", morphPt)
                    subview.place(at: morphPt, anchor: .topLeading, proposal: proposal)
                } else {
                    print("Yikes: no morphing point for ク", subview.oimValue, subview.oimID)
                }
            } else if state != .morphingIn && state != .isMorphing {
                print("placing ク\(subview.oimValue),\(subview.oimID) at", pt)
            }

            if idx < sorted.count - 1 {
                let space = spaces[idx]
                let nextView = sorted[idx+1]
                let state = nextView.oimFundState
                if state != .morphingOut {
                    if space == 0 || isMax {
                        // next subview starts a new stack
                        let width = subview.sizeThatFits(proposal).width
                        pt.x += width + spacing
                        pt.y = bounds.minY
                    } else {
                        // netx subview is on this stack
                        pt.x += offset.x
                        pt.y += offset.y
                    }
                } // place subviews morphing out at position of view morphing in
            }
        }
    }
}


