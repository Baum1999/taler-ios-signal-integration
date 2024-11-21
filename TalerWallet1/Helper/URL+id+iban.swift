/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import SwiftUI

extension URL: Identifiable {
    public var id: URL {self}
}

extension URL {
    init(_ string: StaticString) {
        self.init(string: "\(string)")!
    }

    var iban: String? {
        /// https://datatracker.ietf.org/doc/rfc8905/
        /// payto://iban/DE75512108001245126199?amount=EUR:200.0&message=hello
        if scheme == "payto" && host == "iban" {
            return lastPathComponent
        }
        return nil
    }

    var xTaler: String? {
        /// https://datatracker.ietf.org/doc/rfc8905/
        /// payto://iban/DE75512108001245126199?amount=EUR:200.0&message=hello
        if scheme == "payto" && host == "x-taler-bank" {
            return lastPathComponent
        }
        return nil
    }

    /// SwifterSwift: Dictionary of the URL's query parameters.
    var queryParameters: [String:String]? {
        guard let components = URLComponents(url: self, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else { return nil }

        var items: [String:String] = [:]

        for queryItem in queryItems {
            items[queryItem.name] = queryItem.value
        }
        return items
    }
}
