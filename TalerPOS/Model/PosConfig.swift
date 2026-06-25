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

import Foundation
import UIKit

struct MerchantConfig: Codable {
    let baseUrl: String
    let apiKey: String

    enum CodingKeys: String, CodingKey {
        case baseUrl = "base_url"
        case apiKey = "api_key"
    }

    func urlFor(_ endpoint: String) -> String {
        var base = baseUrl
        if !base.hasSuffix("/") { base += "/" }
        return base + endpoint
    }

    func urlForPathComponent(_ prefix: String, segment: String) -> String {
        var base = baseUrl
        if !base.hasSuffix("/") { base += "/" }
        let encoded = segment.addingPercentEncoding(withAllowedCharacters: .urlPathComponentAllowed) ?? segment
        return base + prefix + "/" + encoded
    }
}

struct CurrencySpecification: Codable, Equatable {
    let name: String?
    let numFractionalInputDigits: Int?
    let numFractionalNormalDigits: Int?
    let numFractionalTrailingZeroDigits: Int?
    let altUnitNames: [String: String]?

    var inputDigits: Int { numFractionalInputDigits ?? 2 }
    var displayDigits: Int { numFractionalNormalDigits ?? 2 }
    var trailingZeroDigits: Int { numFractionalTrailingZeroDigits ?? 2 }
    var symbol: String? { altUnitNames?["0"] }

    enum CodingKeys: String, CodingKey {
        case name
        case numFractionalInputDigits = "num_fractional_input_digits"
        case numFractionalNormalDigits = "num_fractional_normal_digits"
        case numFractionalTrailingZeroDigits = "num_fractional_trailing_zero_digits"
        case altUnitNames = "alt_unit_names"
    }
}

struct PosConfig: Codable {
    let categories: [Category]
    let products: [ConfigProduct]
}

struct Category: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let nameI18n: [String: String]?
    var selected: Bool = false

    enum CodingKeys: String, CodingKey {
        case id, name
        case nameI18n = "name_i18n"
    }

    init(id: Int, name: String, nameI18n: [String: String]? = nil, selected: Bool = false) {
        self.id = id
        self.name = name
        self.nameI18n = nameI18n
        self.selected = selected
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        nameI18n = try container.decodeIfPresent([String: String].self, forKey: .nameI18n)
        selected = false
    }

    var localizedName: String {
        guard let i18n = nameI18n else { return name }
        let lang = Locale.current.language.languageCode?.identifier ?? "en"
        return i18n[lang] ?? name
    }

    static func == (lhs: Category, rhs: Category) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct ConfigProduct: Codable, Identifiable, Equatable {
    let id: String
    let productId: String?
    let productName: String?
    let description: String
    let descriptionI18n: [String: String]?
    let price: Amount
    let pricesAreNet: Bool
    let location: String?
    let image: String?
    let taxes: [Tax]?
    let categories: [Int]
    var quantity: Int
    let totalStock: Int?
    let unitTotalStock: String?
    let totalSold: Int?
    let unitTotalSold: String?
    let totalLost: Int?
    let unitTotalLost: String?
    var availableToSell: Bool
    var remainingStock: Int?
    var currencyMismatch: Bool

    enum CodingKeys: String, CodingKey {
        case productId = "product_id"
        case productName = "product_name"
        case description
        case descriptionI18n = "description_i18n"
        case price
        case pricesAreNet = "prices_are_net"
        case location = "delivery_location"
        case image
        case taxes
        case categories
        case quantity
        case totalStock = "total_stock"
        case unitTotalStock = "unit_total_stock"
        case totalSold = "total_sold"
        case unitTotalSold = "unit_total_sold"
        case totalLost = "total_lost"
        case unitTotalLost = "unit_total_lost"
    }

    init(
        id: String = UUID().uuidString,
        productId: String? = nil,
        productName: String? = nil,
        description: String,
        descriptionI18n: [String: String]? = nil,
        price: Amount,
        pricesAreNet: Bool = false,
        location: String? = nil,
        image: String? = nil,
        taxes: [Tax]? = nil,
        categories: [Int],
        quantity: Int = 0,
        totalStock: Int? = nil,
        unitTotalStock: String? = nil,
        totalSold: Int? = nil,
        unitTotalSold: String? = nil,
        totalLost: Int? = nil,
        unitTotalLost: String? = nil,
        availableToSell: Bool = true,
        remainingStock: Int? = nil,
        currencyMismatch: Bool = false
    ) {
        self.id = id
        self.productId = productId
        self.productName = productName
        self.description = description
        self.descriptionI18n = descriptionI18n
        self.price = price
        self.pricesAreNet = pricesAreNet
        self.location = location
        self.image = image
        self.taxes = taxes
        self.categories = categories
        self.quantity = quantity
        self.totalStock = totalStock
        self.unitTotalStock = unitTotalStock
        self.totalSold = totalSold
        self.unitTotalSold = unitTotalSold
        self.totalLost = totalLost
        self.unitTotalLost = unitTotalLost
        self.availableToSell = availableToSell
        self.remainingStock = remainingStock
        self.currencyMismatch = currencyMismatch
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = UUID().uuidString
        self.productId = try container.decodeIfPresent(String.self, forKey: .productId)
        self.productName = try container.decodeIfPresent(String.self, forKey: .productName)
        self.description = try container.decode(String.self, forKey: .description)
        self.descriptionI18n = try container.decodeIfPresent([String: String].self, forKey: .descriptionI18n)
        self.price = try container.decode(Amount.self, forKey: .price)
        self.pricesAreNet = try container.decodeIfPresent(Bool.self, forKey: .pricesAreNet) ?? false
        self.location = try container.decodeIfPresent(String.self, forKey: .location)
        self.image = try container.decodeIfPresent(String.self, forKey: .image)
        self.taxes = try container.decodeIfPresent([Tax].self, forKey: .taxes)
        self.categories = try container.decodeIfPresent([Int].self, forKey: .categories) ?? []
        self.quantity = try container.decodeIfPresent(Int.self, forKey: .quantity) ?? 0
        self.totalStock = try container.decodeIfPresent(Int.self, forKey: .totalStock)
        self.unitTotalStock = try container.decodeIfPresent(String.self, forKey: .unitTotalStock)
        self.totalSold = try container.decodeIfPresent(Int.self, forKey: .totalSold)
        self.unitTotalSold = try container.decodeIfPresent(String.self, forKey: .unitTotalSold)
        self.totalLost = try container.decodeIfPresent(Int.self, forKey: .totalLost)
        self.unitTotalLost = try container.decodeIfPresent(String.self, forKey: .unitTotalLost)
        self.availableToSell = true
        self.remainingStock = nil
        self.currencyMismatch = false
    }

    var totalPrice: Amount {
        price * quantity
    }

    var displayName: String {
        let sanitizedName = productName?.sanitizedVisibleText
        let sanitizedDesc = localizedDescription.sanitizedVisibleText
        return sanitizedName ?? sanitizedDesc
    }

    var displayDescription: String? {
        guard let sanitizedName = productName?.sanitizedVisibleText,
              sanitizedName != localizedDescription.sanitizedVisibleText else { return nil }
        let desc = localizedDescription.sanitizedVisibleText
        return desc.isEmpty ? nil : desc
    }

    var localizedDescription: String {
        guard let i18n = descriptionI18n else { return description }
        let lang = Locale.current.language.languageCode?.identifier ?? "en"
        return i18n[lang] ?? description
    }

    var stockLimit: Int? {
        if totalStock == -1 || unitTotalStock == "-1" { return nil }
        let total: Int?
        if let ts = totalStock {
            total = ts
        } else if let uts = unitTotalStock, let d = Double(uts) {
            total = Int(d)
        } else {
            return nil
        }
        guard let t = total else { return nil }
        let sold: Int
        if let ts = totalSold {
            sold = ts
        } else if let uts = unitTotalSold, let d = Double(uts) {
            sold = Int(d)
        } else {
            sold = 0
        }
        let lost: Int
        if let tl = totalLost {
            lost = tl
        } else if let utl = unitTotalLost, let d = Double(utl) {
            lost = Int(d)
        } else {
            lost = 0
        }
        return max(t - sold - lost, 0)
    }

    var stableKey: String {
        [
            productId?.trimmingCharacters(in: .whitespaces) ?? "",
            productName?.trimmingCharacters(in: .whitespaces) ?? "",
            description.trimmingCharacters(in: .whitespaces),
            price.currency,
            String(price.value),
            String(price.fraction),
            categories.map(String.init).joined(separator: ","),
        ].joined(separator: "|")
    }

    var decodedImage: UIImage? {
        guard let imageData = image, !imageData.isEmpty else { return nil }
        let stripped = imageData
            .replacingOccurrences(of: "data:image/png;base64,", with: "")
            .replacingOccurrences(of: "data:image/jpeg;base64,", with: "")
        guard let data = Data(base64Encoded: stripped) else { return nil }
        return UIImage(data: data)
    }

    func toContractProduct() -> ContractProduct {
        ContractProduct(
            productId: productId,
            productName: productName ?? description,
            description: description,
            descriptionI18n: descriptionI18n?.isEmpty == false ? descriptionI18n : nil,
            price: price,
            pricesAreNet: pricesAreNet,
            quantity: quantity,
            image: image?.isEmpty == false ? image : nil,
            taxes: taxes?.isEmpty == false ? taxes : nil
        )
    }

    static func == (lhs: ConfigProduct, rhs: ConfigProduct) -> Bool {
        lhs.id == rhs.id
    }
}

struct Tax: Codable, Hashable {
    let name: String
    let tax: Amount
}

struct ContractProduct: Codable {
    let productId: String?
    let productName: String?
    let description: String
    let descriptionI18n: [String: String]?
    let price: Amount
    let pricesAreNet: Bool
    let quantity: Int
    let image: String?
    let taxes: [Tax]?

    enum CodingKeys: String, CodingKey {
        case productId = "product_id"
        case productName = "product_name"
        case description
        case descriptionI18n = "description_i18n"
        case price
        case pricesAreNet = "prices_are_net"
        case quantity
        case image
        case taxes
    }
}

private extension String {
    var sanitizedVisibleText: String {
        filter { char in
            !char.unicodeScalars.contains { scalar in
                let cat = scalar.properties.generalCategory
                return cat == .format || cat == .control || cat == .surrogate
                    || cat == .privateUse || cat == .unassigned
            }
        }.trimmingCharacters(in: .whitespaces)
    }
}

extension CharacterSet {
    // .urlPathAllowed permits '/', which would split a single segment into multiple path components.
    static let urlPathComponentAllowed: CharacterSet = {
        var set = CharacterSet.urlPathAllowed
        set.remove("/")
        return set
    }()
}
