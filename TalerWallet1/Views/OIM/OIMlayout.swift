/*
 * This file is part of GNU Taler, ©2022-25 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import SwiftUI
import SymLog
import os.log

struct OIMid: LayoutValueKey {
    static let defaultValue = 0
}
struct OIMmorph: LayoutValueKey {
    static let defaultValue = 0
}
struct OIMvalue: LayoutValueKey {
    static let defaultValue: UInt64 = 0
}
struct OIMflippedval: LayoutValueKey {
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
    func oimMorph(_ value: Int) -> some View {
        self.layoutValue(key: OIMmorph.self, value: value)
    }
    func oimValue(_ value: UInt64) -> some View {
        self.layoutValue(key: OIMvalue.self, value: value)
    }
    func oimFlippedVal(_ value: UInt64) -> some View {
        self.layoutValue(key: OIMflippedval.self, value: value)
    }
    func oimFundState(_ value: FundState) -> some View {
        self.layoutValue(key: OIMfundState.self, value: value)
    }
}

@available(iOS 16.4, *)
extension LayoutSubview {
    var oimID: Int { self[OIMid.self] }
    var oimValue: UInt64 { self[OIMvalue.self] }
    var oimFlippedVal: UInt64 { self[OIMflippedval.self] }
    var oimFundState: FundState { self[OIMfundState.self] }
}

// MARK: -
// renders a stack of funds (banknotes, coins)
@available(iOS 16.4, *)
struct OIMlayoutView: View {
    private let symLog = SymLogV()
//    let logger = Logger(subsystem: "net.taler.gnu", category: "OIMlayoutView")
    let stack: CallStack
    let cash: OIMcash
    let funds: OIMfunds
    @Binding var amountVal: UInt64
    let canEdit: Bool

    @EnvironmentObject private var wrapper: NamespaceWrapper
    @State private var checkStacks: UInt64 = 0

    func endFlying(_ index: Int, after delay: Double) {
        var fund = funds[index]
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            symLog.log("*** end flying:\(fund.value) \(fund.id)")
            withAnimation(.move1) {
                fund.state = .idle              // move onto stack
                cash.updateFund(fund)
            }
            if checkStacks > fund.value || checkStacks == 0 {
                symLog.log("*** checkStacks:\(fund.value)")
                checkStacks = fund.value
            }
        }
    }

    func startFlying(fundID: Int, fromChest: Bool = false) {
        if let index = funds.firstIndex(where: { $0.id == fundID }) {
            var fund = funds[index]
            symLog.log("*** start flying:\(fund.value) \(fundID)")
            if fromChest && fund.delay > 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + fund.delay) {
                    withAnimation(.move1) {
                        fund.state = .curve
                        cash.updateFund(fund)
                    }
                    endFlying(index, after: cash.flyDelay / 3)
                }
            } else {
                endFlying(index, after: cash.flyDelay)
            }
            withAnimation(.move1) {
                fund.state = fromChest ? .reveal : .isFlying               // switch off matching
                cash.updateFund(fund)
            }
        }
    }

    func flyBack(fundID: Int) {
        if let index = funds.firstIndex(where: { $0.id == fundID }) {
            var fund = funds[index]
            symLog.log("*** fly back:\(fund.value) \(fundID)")
            withAnimation(.move1) {
                fund.state = .returning
                cash.updateFund(fund)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + cash.flyDelay) {
                symLog.log("*** remove:\(fund.value) \(fundID)")
                withAnimation(.move1) {
                    cash.removeCash(id: fundID, value: fund.value)
                }
            }
        }
    }

    var body: some View {
        OIMlayout {
            ForEach(funds) { fund in
                let value = fund.value
                let fundID = fund.id
                let fundState = fund.state
                let shouldFly = fundState.shouldFly
//                let willMutate = fundState == .arriving || fundState == .mutating
                OIMcurrencyButton(stack: stack.push(),
                                   fund: fund,
                               currency: cash.currency,
                           availableVal: value,
                                canEdit: canEdit,
                               isDrawer: false,
                                    pct: shouldFly ? 0.0 : 1.0
                ) {   // remove on button press
                    if amountVal >= fund.value {
                        amountVal -= fund.value
                    } else {
                        symLog.log("  ❗️Yikes - trying to subtract \(fund.value) from amount \(amountVal)")
                        amountVal = 0
                    }
                    flyBack(fundID: fundID)
                }
                .zIndex(Double(fundID))
                .id(fundID)
                .oimValue(value)
                .oimFlippedVal(fund.flippedVal ?? 0)
                .oimID(fundID)
                .oimFundState(fundState)
                .matchedGeometryEffect(id: fund.targetID, in: wrapper.namespace, isSource: false)
                .onAppear {
                    if fundState.chestOpening {
                        startFlying(fundID: fundID, fromChest: true)
                    } else if fundState.shouldFly {
                        startFlying(fundID: fundID)
                    } else {
//                      print("    ->OIMlayout ForEach fund.onAppear ignore \(value), \(fundID)")
                    }
                }
            }
        }
        .onChange(of: checkStacks) { value in
            if value > 0 {
                symLog.log("*** onChange(of: checkStacks) \(value)")
                var firstCheck = value
                if let moreThan4 = cash.checkStacks(first: firstCheck) {
                    firstCheck = 0
                    cash.compactStacks(moreThan4)
                }
                checkStacks = 0
            }
        }
    }
}
// MARK: -
@available(iOS 16.4, *)
struct OIMlayout: Layout {

    func sortByValue(_ subviews: LayoutSubviews) -> [LayoutSubview] {
        // sorts DESCENDING - we render the denominations top-down
        subviews.sorted(by: {
            let state0 = $0.oimFundState
            let state1 = $1.oimFundState
            let value0 = $0.oimValue
            let value1 = $1.oimValue
            let flipV0 = $0.oimFlippedVal
            let flipV1 = $1.oimFlippedVal
            let id0 = $0.oimID
            let id1 = $1.oimID
            let isSameVal = value0 == value1
            let id0isSmaller = id0 < id1
            let id0isBigger = id1 < id0

            let isMorphing1 = state1 == .position
                           || state1 == .morphing
                           || state1 == .arriving
                           || state1 == .mutating
            if isMorphing1 {
                if flipV1 > 0 {
                    let firstIsBigger = value0 > flipV1
                    let sameFlip = value0 == flipV1

                    let sameFlip_ID0smaller = sameFlip && id0isSmaller
                    let result = firstIsBigger || sameFlip_ID0smaller
                    return result
                }
            }

            let isMorphing0 = state0 == .position
                           || state0 == .morphing
                           || state0 == .arriving
                           || state0 == .mutating
            if isMorphing0 {
                if flipV0 > 0 {
                    let firstIsBigger = flipV0 > value1
                    let sameFlip = value1 == flipV0

                    let sameFlip_ID0smaller = sameFlip && id0isSmaller
                    let result = firstIsBigger || sameFlip_ID0smaller
                    return result
                }
            }
            let firstIsBigger = value0 > value1
            // but keep the order of the IDs for identical values
            let sameVal_ID0smaller = isSameVal && id0isSmaller
            let result = firstIsBigger || sameVal_ID0smaller
            return result
        })
    }

    func computeSpaces(_ sorted: [LayoutSubview], _ max: Int = MAXSTACK) -> [Int] {
        /// same algorithm as OIMcash.checkStacks
        /// returns array of stackIndexes
        /// 0  ==> next view starts a new stack
        /// 1..3  ==> next view is on the stack
        /// -1 ==> view is invisible, will be deleted
        var spaces: [Int] = []

        var stackIndex = 0
        var lastValue: UInt64 = 0
        for (index, subview) in sorted.enumerated() {
            let value = subview.oimValue
            let state = subview.oimFundState
            let id = subview.oimID
//            let flippedVal = subview.oimFlippedVal ?? 0
            var ignore = 0
            if state.shouldFly || state.isFlying                // flying can not go on the stack
                               || state.position                // nor can the position where we morph...
                               || state.morphing  {             // ...or the morphing fund
                // we always morph out from the end, thus there will be no more idling funds with the same value
                lastValue = 0                                   // let the next subview...
                stackIndex = 0                                  // ...start a new stack
            } else if state.moving || state.hiding {
                ignore = -1
            } else if lastValue != value {                      // different value?
                lastValue = value                               // save this value for the next subview
                stackIndex = 0                                  // start a new stack
            } else {
                stackIndex += 1                                 // Yay, we found one to add to this stack
                if stackIndex == max {                          // max 4 subviews per stack
                    stackIndex = 0                              // stack is full, start a new one but keep the value
            }   }
            if index > 0 {
                spaces.append(ignore == 0 ? stackIndex : ignore)
            }
        }
        return spaces
    }

    func accumulate(spaces: [Int], _ viewSizes: [CGSize], spacing: CGFloat, xOffset: CGFloat) -> CGFloat {
        var accumulatedSpaces: CGFloat = .zero
        for (idx, stackIndex) in spaces.enumerated() {
            if stackIndex > 0 {             // next view is on the stack, add xOffset, subtract width
                accumulatedSpaces += (xOffset - viewSizes[idx].width)
            } else if stackIndex == 0 {     // start a new stack, add spacing
                accumulatedSpaces += spacing
            } // else ignore view
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
            if state != .moving && state != .hiding {
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
//                        print("Yikes❗️ width only:", spaceToFill)
                    }
                } else if var heightToFill = proposal.height {
//                    print("Yikes❗️ height only:", heightToFill)
                } else { // unspecified
//                    print("Yikes❗️ should NEVER happen:", proposal)
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
            let id = subview.oimID
            let state = subview.oimFundState
            if state.position || state.morphing {
//                if morphPt != pt { print("set morphPt \(morphPt) to ク\(subview.oimValue),\(subview.oimID) at", pt) }
                morphPt = pt
            }
            subview.place(at: pt, anchor: .topLeading, proposal: proposal)
            if state.moving || state.hiding  {
                if morphPt != CGPoint.zero {
//                    print("morphing ク\(subview.oimValue) \(subview.oimID) \(state) from \(pt) to", morphPt)
                    subview.place(at: morphPt, anchor: .topLeading, proposal: proposal)
                } else {
//                    symLog.log("Yikes: no morphing point for ク", subview.oimValue, subview.oimID, state)
                }
//            } else if state != .morphingIn && state != .morphedIn {
//                print("placing ク\(subview.oimValue),\(subview.oimID) at", pt)
            }

            if idx < sorted.count - 1 {
                let space = spaces[idx]
                let nextView = sorted[idx+1]
                let state = nextView.oimFundState
                if state != .moving && state != .hiding {
                    if space == 0 || isMax {
//                        print("Start new stack for ク", nextView.oimValue, nextView.oimID, state)
                        let width = subview.sizeThatFits(proposal).width
                        pt.x += width + spacing
                        pt.y = bounds.minY
                    } else if space > 0 {
//                        print("  place on stack ク", nextView.oimValue, nextView.oimID, state)
                        pt.x += offset.x
                        pt.y += offset.y
//                    }  else {
//                        print("ignore ク", nextView.oimValue, nextView.oimID, state)
                    }
                } // place subviews morphing out at position of view morphing in
            }
        }
    }
}
