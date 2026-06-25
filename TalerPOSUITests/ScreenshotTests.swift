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

import XCTest

final class ScreenshotTests: XCTestCase {

    private func launchAndCapture(scenario: String) {
        let app = XCUIApplication()
        app.launchArguments += ["-SCREENSHOT_SCENARIO", scenario]
        app.launch()

        sleep(2)

        let screenshot = app.windows.firstMatch.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = scenario
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testScreenshotAmountEntry() {
        launchAndCapture(scenario: "amount-entry")
    }

    func testScreenshotOrder() {
        launchAndCapture(scenario: "order")
    }

    func testScreenshotPayment() {
        launchAndCapture(scenario: "payment")
    }

    func testScreenshotPaymentSuccess() {
        launchAndCapture(scenario: "payment-success")
    }
}
