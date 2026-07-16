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

    init(_ title: String, seconds: Int,_ trailer: String? = nil) {
        self.title = title
        self.seconds = seconds
        self.trailer = trailer ?? String(localized: "seconds")
    }

    var body: some View {
        let startDate = Date()
        HStack {
            Text(title)
            TimelineView(.animation) { context in
                let elapsed = Int(context.date.timeIntervalSince(startDate))
                let remaining = seconds - elapsed
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
