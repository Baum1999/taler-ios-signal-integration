/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import XCTest
@testable import taler_swift

class AmountTests: XCTestCase {
    func testParsing() {
        var str = "TESTKUDOS:23.42"
        var amt = try! Amount(fromString: str)
        XCTAssert(str == amt.description)
        XCTAssert("TESTKUDOS" == amt.currencyStr)
        // `value` is a lossy Double convenience (23.42 here), never the integer part.
        // Assert on the exact integer/fraction pair instead — money must not be compared
        // through Double.
        XCTAssert(23 == amt.integer)
        XCTAssert(UInt64(0.42 * 1e8) == amt.fraction)
        
        str = "EUR:500000000.00000001"
        amt = try! Amount(fromString: str)
        XCTAssert(str == amt.description)
        XCTAssert("EUR" == amt.currencyStr)
        XCTAssert(500000000 == amt.value)
        XCTAssert(1 == amt.fraction)
        
        str = "EUR:1500000000.00000003"
        amt = try! Amount(fromString: str)
        XCTAssert(str == amt.description)
        XCTAssert("EUR" == amt.currencyStr)
        XCTAssert(1500000000 == amt.value)
        XCTAssert(3 == amt.fraction)
        
        let maxValue = 4503599627370496                 // 16 significant digits are 1 too many for double
        str = "TESTKUDOS123:\(maxValue).99999999"
        amt = try! Amount(fromString: str)
        XCTAssert(str == amt.description)
        XCTAssert("TESTKUDOS123" == amt.currencyStr)
        // At 2^52 the spacing of Double is 1.0, so `value` cannot represent
        // maxValue + 0.99999999 — it rounds up to maxValue + 1. That is exactly the
        // precision loss the `maxValue` comment warns about, so assert on the exact
        // fields and pin the lossiness rather than asserting a false identity.
        XCTAssert(UInt64(maxValue) == amt.integer)
        XCTAssert(99999999 == amt.fraction)
        XCTAssert(Double(maxValue) != amt.value)

        XCTAssertThrowsError(try Amount(fromString: "TESTKUDOS1234:\(maxValue).99999999"))
        XCTAssertThrowsError(try Amount(fromString: "TESTKUDOS123:\(maxValue + 1).99999999"))
        XCTAssertThrowsError(try Amount(fromString: "TESTKUDOS123:\(maxValue).999999990"))
        XCTAssertThrowsError(try Amount(fromString: "TESTKUDOS:0,5"))
        XCTAssertThrowsError(try Amount(fromString: "+TESTKUDOS:0.5"))
        XCTAssertThrowsError(try Amount(fromString: "0.5"))
        XCTAssertThrowsError(try Amount(fromString: ":0.5"))
        XCTAssertThrowsError(try Amount(fromString: "EUR::0.5"))
        XCTAssertThrowsError(try Amount(fromString: "EUR:.5"))
    }
    
    func testAddition() {
        XCTAssert(try Amount(fromString: "EUR:1") + Amount(fromString: "EUR:1") == Amount(fromString: "EUR:2"))
        XCTAssert(try Amount(fromString: "EUR:1.5") + Amount(fromString: "EUR:1.5") == Amount(fromString: "EUR:3"))
        XCTAssert(try Amount(fromString: "EUR:500000000.00000001") + Amount(fromString: "EUR:0.00000001") == Amount(fromString: "EUR:500000000.00000002"))
        XCTAssertThrowsError(try Amount(fromString: "EUR:1") + Amount(fromString: "USD:1"))
        XCTAssertThrowsError(try Amount(fromString: "EUR:4503599627370496.99999999") + Amount(fromString: "EUR:4503599627370496.99999999"))
        XCTAssertThrowsError(try Amount(fromString: "EUR:4000000000000000") + Amount(fromString: "EUR:4000000000000000"))
    }
    
    func testSubtraction() {
        XCTAssert(try Amount(fromString: "EUR:1") - Amount(fromString: "EUR:1") == Amount(fromString: "EUR:0"))
        XCTAssert(try Amount(fromString: "EUR:3") - Amount(fromString: "EUR:1.5") == Amount(fromString: "EUR:1.5"))
        XCTAssert(try Amount(fromString: "EUR:500000000.00000002") - Amount(fromString: "EUR:0.00000001") == Amount(fromString: "EUR:500000000.00000001"))
        XCTAssertThrowsError(try Amount(fromString: "EUR:3") - Amount(fromString: "USD:1.5"))
        XCTAssertThrowsError(try Amount(fromString: "EUR:23.42") - Amount(fromString: "EUR:42.23"))
        XCTAssertThrowsError(try Amount(fromString: "EUR:0.5") - Amount(fromString: "EUR:0.50000001"))
    }
    
    func testMultiplication() {
        XCTAssert(try Amount(fromString: "EUR:2") * 1 == Amount(fromString: "EUR:2"))
        XCTAssert(try Amount(fromString: "EUR:1") * 2 == Amount(fromString: "EUR:2"))
        XCTAssert(try Amount(fromString: "EUR:1.5") * 3 == Amount(fromString: "EUR:4.5"))
        XCTAssert(try Amount(fromString: "EUR:1.11") * 0 == Amount(fromString: "EUR:0"))
        XCTAssert(try Amount(fromString: "EUR:1.11") * 1 == Amount(fromString: "EUR:1.11"))
        XCTAssert(try Amount(fromString: "EUR:1.11") * 2 == Amount(fromString: "EUR:2.22"))
        XCTAssert(try Amount(fromString: "EUR:1.11") * 3 == Amount(fromString: "EUR:3.33"))
        XCTAssert(try Amount(fromString: "EUR:1.11") * 4 == Amount(fromString: "EUR:4.44"))
        XCTAssert(try Amount(fromString: "EUR:1.11") * 5 == Amount(fromString: "EUR:5.55"))
        XCTAssert(try Amount(fromString: "EUR:500000000.00000001") * 3 == Amount(fromString: "EUR:1500000000.00000003"))
        XCTAssertThrowsError(try Amount(fromString: "4000000000000000") * 2)
    }

    func testMultiplicationOverflow() {
        // 2^52 is the largest integer part the protocol allows, so it can be parsed and
        // then multiplied. Neither the overflow of `integer * factor` nor a product that
        // is merely out of range may escape as a trap or as an invalid Amount.
        let maxValue = 4503599627370496                 // 2^52
        XCTAssertThrowsError(try Amount(fromString: "EUR:\(maxValue)") * 2)
        XCTAssertThrowsError(try Amount(fromString: "EUR:\(maxValue)") * 5000)
        XCTAssertThrowsError(try Amount(fromString: "EUR:\(maxValue).99999999") * UInt32.max)
        XCTAssertThrowsError(try Amount(fromString: "EUR:2251799813685249") * 2)

        // the carry from the fraction still works, and the result is normalized
        XCTAssert(try Amount(fromString: "EUR:0.00000001") * UInt32.max == Amount(fromString: "EUR:42.94967295"))
        XCTAssert(try Amount(fromString: "EUR:2251799813685248") * 2 == Amount(fromString: "EUR:\(maxValue)"))
    }
    
    func testDivision() {
        XCTAssert(try Amount(fromString: "EUR:2") / 1 == Amount(fromString: "EUR:2"))
        XCTAssert(try Amount(fromString: "EUR:2") / 2 == Amount(fromString: "EUR:1"))
        XCTAssert(try Amount(fromString: "EUR:4.5") / 3 == Amount(fromString: "EUR:1.5"))
        XCTAssert(try Amount(fromString: "EUR:0") / 5 == Amount(fromString: "EUR:0"))
        XCTAssert(try Amount(fromString: "EUR:1.11") / 1 == Amount(fromString: "EUR:1.11"))
        XCTAssert(try Amount(fromString: "EUR:2.22") / 2 == Amount(fromString: "EUR:1.11"))
        XCTAssert(try Amount(fromString: "EUR:3.33") / 3 == Amount(fromString: "EUR:1.11"))
        XCTAssert(try Amount(fromString: "EUR:4.44") / 4 == Amount(fromString: "EUR:1.11"))
        XCTAssert(try Amount(fromString: "EUR:5.55") / 5 == Amount(fromString: "EUR:1.11"))
        XCTAssert(try Amount(fromString: "EUR:1500000000.00000003") / 3 == Amount(fromString: "EUR:500000000.00000001"))
        XCTAssert(try Amount(fromString: "EUR:0.00000003") / 2 == Amount(fromString: "EUR:0.00000001"))
        XCTAssertThrowsError(try Amount(fromString: "EUR:1") / 0)
    }
    
    func testZero() {
        XCTAssert(try Amount(fromString: "EUR") == Amount.zero(currency: "EUR"))
        XCTAssert(Amount.zero(currency: "EUR").isZero)
        XCTAssert(try Amount(fromString: "EUR:0").isZero)
        XCTAssert(try Amount(fromString: "EUR:0.0").isZero)
        XCTAssert(try Amount(fromString: "EUR:0.00000").isZero)
        XCTAssert(try (Amount(fromString: "EUR:1.001") - Amount(fromString: "EUR:1.001")).isZero)
        XCTAssert(try !Amount(fromString: "EUR:0.00000001").isZero)
        XCTAssert(try !Amount(fromString: "EUR:1.0").isZero)
        XCTAssert(try !Amount(fromString: "EUR:0001.0").isZero)
    }
    
    func testComparison() {
        XCTAssert(try Amount(fromString: "EUR:0") <= Amount(fromString: "EUR:0"))
        XCTAssert(try Amount(fromString: "EUR:0") <= Amount(fromString: "EUR:0.00000001"))
        XCTAssert(try Amount(fromString: "EUR:0") < Amount(fromString: "EUR:0.00000001"))
        XCTAssert(try Amount(fromString: "EUR:0") < Amount(fromString: "EUR:1"))
        XCTAssert(try Amount(fromString: "EUR:0") == Amount(fromString: "EUR:0"))
        XCTAssert(try Amount(fromString: "EUR:42") == Amount(fromString: "EUR:42"))
        XCTAssert(try Amount(fromString: "EUR:42.00000001") == Amount(fromString: "EUR:42.00000001"))
        XCTAssert(try Amount(fromString: "EUR:42.00000001") >= Amount(fromString: "EUR:42.00000001"))
        XCTAssert(try Amount(fromString: "EUR:42.00000002") >= Amount(fromString: "EUR:42.00000001"))
        XCTAssert(try Amount(fromString: "EUR:42.00000002") > Amount(fromString: "EUR:42.00000001"))
        XCTAssert(try Amount(fromString: "EUR:0.00000002") > Amount(fromString: "EUR:0.00000001"))
        XCTAssert(try Amount(fromString: "EUR:0.00000001") > Amount(fromString: "EUR:0"))
        XCTAssert(try Amount(fromString: "EUR:2") > Amount(fromString: "EUR:1"))
        XCTAssertThrowsError(try Amount(fromString: "EUR:0.5") < Amount(fromString: "USD:0.50000001"))
    }
}

// REL-001: the currency field formats after every digit, including rejected edits.
extension AmountTests {
    func testDigitEntryRemainsRepresentableAtEveryPrecision() throws {
        for digits in UInt(0)...8 {
            let amount = Amount.zero(currency: "EUR")
            for _ in 0..<40 {
                amount.shiftLeft(add: 9, digits)
                XCTAssertLessThanOrEqual(amount.integer, 4_503_599_627_370_496)
                XCTAssertLessThan(amount.fraction, 100_000_000)
                _ = amount.plainString(inputDigits: digits)
                XCTAssertEqual(try Amount(fromString: amount.description), amount)
            }
            let before = amount.copy()
            amount.shiftLeft(add: 9, digits)
            XCTAssertEqual(amount, before)
            amount.shiftRight()
            XCTAssertTrue(try amount < before)
            amount.shiftLeft(add: 1, digits)
            _ = amount.plainString(inputDigits: digits)
        }
    }

    func testEighteenthDigitIsRejectedAtomically() throws {
        let amount = Amount.zero(currency: "EUR")
        for _ in 0..<17 { amount.shiftLeft(add: 9, 2) }
        XCTAssertEqual(amount.description, "EUR:999999999999999.99")
        amount.shiftLeft(add: 9, 2)
        XCTAssertEqual(amount.plainString(inputDigits: 2), "99999999999999999")
    }

    func testMaximumAmountEditPreservesValue() throws {
        for digits in UInt(0)...8 {
            let amount = try Amount(fromString: "EUR:4503599627370496.99999999")
            let before = amount.copy()
            amount.shiftLeft(add: 0, digits)
            XCTAssertEqual(amount, before)
        }
        let amount = try Amount(fromString: "EUR:450359962737049")
        amount.shiftLeft(add: 6, 0)
        XCTAssertEqual(amount.integer, 4_503_599_627_370_496)
    }

    func testPlainStringNormalizesWideFractionWithoutOverflow() {
        let amount = Amount(currency: "EUR", integer: 0, fraction: 909_000_000)
        XCTAssertEqual(amount.plainString(inputDigits: 2), "909")
    }
}
