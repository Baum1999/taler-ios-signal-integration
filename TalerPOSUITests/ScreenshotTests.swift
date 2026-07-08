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

    private static let scenarios = [
        "login",
        "mfa-select",
        "mfa-code",
        "amount-entry",
        "order",
        "order-custom",
        "order-custom-added",
        "payment",
        "payment-success",
        "history",
        "refund",
        "refund-qr",
        "navigation",
        "settings",
    ]

    private var screenshotLocale: String {
        ProcessInfo.processInfo.environment["SCREENSHOT_LOCALE"] ?? "en"
    }

    func testAllScreenshots() {
        runScenarios(Self.scenarios)
    }

    func testSelectedScenarios() {
        let env = ProcessInfo.processInfo.environment["SCREENSHOT_SCENARIOS"] ?? ""
        let selected = env.split(separator: ",").map(String.init)
        guard !selected.isEmpty else {
            XCTFail("SCREENSHOT_SCENARIOS env var is empty")
            return
        }
        runScenarios(selected)
    }

    private func runScenarios(_ scenarios: [String]) {
        for scenario in scenarios {
            let app = XCUIApplication()
            app.launchArguments = ["-SCREENSHOT_SCENARIO", scenario,
                                   "-SCREENSHOT_LOCALE", screenshotLocale]
            app.launch()

            if UIDevice.current.userInterfaceIdiom == .pad {
                XCUIDevice.shared.orientation = .landscapeLeft
            }

            sleep(1)

            let screenshot = XCUIScreen.main.screenshot()
            let attachment = XCTAttachment(screenshot: screenshot)
            attachment.name = scenario
            attachment.lifetime = .keepAlways
            add(attachment)

            app.terminate()
        }
    }
}
