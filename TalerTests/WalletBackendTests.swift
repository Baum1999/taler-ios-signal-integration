/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import XCTest
@testable import Taler

class WalletBackendTests: XCTestCase {
    // TODO: Test multiple backends. This ends up hanging, and this should not happen!
    
    func testX() {
        let _ = try! WalletBackend()
        //let _ = try! WalletBackend()
    }
}
