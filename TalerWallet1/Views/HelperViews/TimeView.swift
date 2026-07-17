/*
 * This file is part of GNU Taler, ©2022-26 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import SwiftUI

struct TimeView: View {
    let title: String
    let seconds: Int
    let trailer: String
    @Binding var isFinished: Bool?

    init(_ title: String, seconds: Int,_ trailer: String? = nil, isFinished: Binding<Bool?> = .constant(nil)) {
        self.title = title
        self.seconds = seconds
        self.trailer = trailer ?? String(localized: "seconds")
        self._isFinished = isFinished
    }

    func remainingTime(_ elapsed: Int) -> Int {
        let remaining = seconds - elapsed
        if remaining <= 0 {
            if isFinished != nil {
                DispatchQueue.main.async {
                    isFinished = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) {
                        isFinished = nil
                    }
                }
            }
        }
        return remaining
    }

    var body: some View {
        let startDate = Date()
        HStack {
            Text(title)
            TimelineView(.animation) { context in
                let elapsed = Int(context.date.timeIntervalSince(startDate))
                let remaining = remainingTime(elapsed)
                let text = Text(verbatim: "\(remaining)")
                if #available(iOS 17.0, *) {
                    text
                        .contentTransition(.numericText(countsDown: true))
                        .animation(.default, value: elapsed)
                } else if #available(iOS 16.4, *) {
                    text
                        .animation(.default, value: elapsed)
                } else {
                    text
                }
            }.monospacedDigit()
            Text(trailer)
        }.accessibilityElement(children: .combine)
    }
}
