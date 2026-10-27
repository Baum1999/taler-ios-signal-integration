/*
 * This file is part of GNU Taler, ©2022-26 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * Finds taler:// URIs in pasted text
 *
 * Mirrors net.taler.wallet.link.TalerUriExtractor (taler-android): the
 * clipboard often holds more than a bare URI - a message copied from a
 * messenger ("Payment: taler://... thanks!"), several URIs of a group split,
 * or an https link after DD 103 (https://wallet.taler.net/link#pay-push/...).
 */
import Foundation

enum TalerURIExtractor {
    /// Domains whose https://<host>/link#... links carry a taler:// URI (DD 103).
    /// Forks with their own link domain only change this list.
    static let linkHosts = ["wallet.taler.net"]

    // Stops before typical surrounding characters (closing brackets, quotes,
    // punctuation), so "(taler://pay-push/X)" yields "taler://pay-push/X".
    private static let endChars = #"[^\s"')\]}<>,;]+"#

    private static let schemeRegex = try! NSRegularExpression(
        pattern: #"(?:ext\+)?taler://"# + endChars,
        options: [.caseInsensitive])

    private static let linkRegex = try! NSRegularExpression(
        pattern: "https://(?:"
            + linkHosts.map { NSRegularExpression.escapedPattern(for: $0) }.joined(separator: "|")
            + ")/link/?#" + endChars,
        options: [.caseInsensitive])

    /// All taler:// URIs found in `text`, deduplicated, in order of appearance.
    /// https links are unwrapped, ext+taler:// is mapped to taler://.
    static func extractAll(_ text: String) -> [URL] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return [] }

        // The whole text IS the URI: take it unchanged, since a lone URI may
        // contain characters (",", ")" ...) that endChars excludes.
        if !trimmed.contains(where: \.isWhitespace),
           let uri = normalize(trimmed), let whole = url(uri) {
            return [whole]
        }

        let range = NSRange(trimmed.startIndex..., in: trimmed)
        var matches: [(Int, String)] = []
        for regex in [schemeRegex, linkRegex] {
            for match in regex.matches(in: trimmed, range: range) {
                guard let swiftRange = Range(match.range, in: trimmed) else { continue }
                // a trailing "." ends the sentence, not the link
                var value = String(trimmed[swiftRange])
                while value.hasSuffix(".") { value.removeLast() }
                if let uri = normalize(value) {
                    matches.append((match.range.location, uri))
                }
            }
        }
        var seen = Set<String>()
        return matches
            .sorted { $0.0 < $1.0 }
            .map(\.1)
            .filter { seen.insert($0.lowercased()).inserted }
            .compactMap(url)
    }

    /// taler:// form of `value`, or nil if it is neither a taler:// URI nor a
    /// DD 103 link on one of `linkHosts`.
    static func normalize(_ value: String) -> String? {
        let lower = value.lowercased()
        if lower.hasPrefix("taler://") {
            return value
        }
        if lower.hasPrefix("ext+taler://") {
            return String(value.dropFirst("ext+".count))
        }
        let range = NSRange(value.startIndex..., in: value)
        guard let match = linkRegex.firstMatch(in: value, range: range),
              match.range == range,
              let hashIndex = value.firstIndex(of: "#") else { return nil }
        var fragment = String(value[value.index(after: hashIndex)...])
        if fragment.lowercased().hasPrefix("taler://") {
            return fragment
        }
        if fragment.lowercased().hasPrefix("ext+taler://") {
            return String(fragment.dropFirst("ext+".count))
        }
        if fragment.hasPrefix("/") {
            fragment.removeFirst()
        }
        // must start with an action ("pay-push/..."), so "javascript:..."
        // never becomes "taler://javascript:..."
        guard let slash = fragment.firstIndex(of: "/"),
              slash > fragment.startIndex,
              fragment[..<slash].allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-") })
        else { return nil }
        return "taler://" + fragment
    }

    private static func url(_ uri: String) -> URL? {
        uri.toURL
    }
}
