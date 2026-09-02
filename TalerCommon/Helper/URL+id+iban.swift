/*
 * This file is part of GNU Taler, ©2022-25 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import SwiftUI

extension URL: Identifiable {
    public var id: URL {self}
}

extension URL {
    init(_ string: StaticString) {
        self.init(string: "\(string)")!
    }

    var trimmedString: String {
        absoluteString.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var cyclos: String? {
        /// "payto://cyclos/" host ["/" fpath] "/" account-id [ "?" opts ]
        if scheme == "payto", let host = host {
            let path = path.dropFirst(1)
            if host == "cyclos" {
                return String(path)
            } else if host.hasPrefix("cyclos") {
                let cyclos = host.dropFirst(6)
                if path.hasPrefix("/") {
                    return String(cyclos + path)
                }
                return String(cyclos + "/" + path)
            }
        }
        return nil
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
        /// payto://x-taler-bank/BANK-HOST/ACCOUNT?receiver-name=…
        /// The bank host is part of the target, so return "BANK-HOST/ACCOUNT" —
        /// returning only lastPathComponent silently dropped the bank and made
        /// the account unaddressable when it was written back out.
        if scheme == "payto" && host == "x-taler-bank" {
            let target = path.hasPrefix("/") ? String(path.dropFirst()) : path
            return target.isEmpty ? nil : target
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

    static var docDirUrl: URL? {                    // accessible by FileSharing
        if #available(iOS 16.4, *) {
            return URL.documentsDirectory
        } else {
            let docDirNr: FileManager.SearchPathDirectory = .documentDirectory
            if let documentsDir = FileManager.default.urls(for: docDirNr, in: .userDomainMask).first {
                return documentsDir
            }
        }
        return nil
    }

    static var appSuppUrl: URL? {
        if #available(iOS 16.4, *) {
            return URL.applicationSupportDirectory
        } else {
            let appDirNr: FileManager.SearchPathDirectory = .applicationSupportDirectory
            if let appSupportDir = FileManager.default.urls(for: appDirNr, in: .userDomainMask).first {
                return appSupportDir
            }
        }
        return nil
    }

    static var tempDirUrl: URL? {
        if #available(iOS 16.4, *) {
            return URL.temporaryDirectory
        } else { // iOS 15 doesn't have a temp dir
            let tmpDirNr: FileManager.SearchPathDirectory = .cachesDirectory
            if let cachesDir = FileManager.default.urls(for: tmpDirNr, in: .userDomainMask).first {
                return cachesDir
            }
        }
        return nil
    }

    func path(withSlash: Bool) -> String {
        let path: String
        if #available(iOS 16.4, *) {
            path = self.path(percentEncoded: false)
        } else {
            path = self.path
        }
        if let char = path.last {
            let slash: String.Element = "/"

            if withSlash {
                if char != slash {
                    return path + String(slash)
                }
            } else {
                if char == slash {
                    return String(path.dropLast())
                }
            }
        }
        return path
    }
}
