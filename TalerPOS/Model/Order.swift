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

struct Order {
    let id: Int
    let currency: String
    let availableCategories: [Int: Category]
    var products: [ConfigProduct]

    var title: String { String(id) }

    var summary: String {
        if products.count == 1 { return products[0].description }
        let catQuantities = getCategoryQuantities()
        return catQuantities.map { (cat, qty) in
            "\(qty) x \(cat.localizedName)"
        }.joined(separator: ", ")
    }

    var summaryI18n: [String: String]? {
        if products.count == 1 { return products[0].descriptionI18n }
        let catQuantities = getCategoryQuantities()
        var availableLocales: Set<String>?
        for (cat, _) in catQuantities {
            guard let nameI18n = cat.nameI18n else { return nil }
            if availableLocales == nil {
                availableLocales = Set(nameI18n.keys)
            } else {
                availableLocales = availableLocales!.intersection(nameI18n.keys)
            }
            if availableLocales?.isEmpty == true { return nil }
        }
        guard let locales = availableLocales, !locales.isEmpty else { return nil }
        var result: [String: String] = [:]
        for locale in locales {
            result[locale] = catQuantities.map { (cat, qty) in
                "\(qty) x \(cat.nameI18n![locale]!)"
            }.joined(separator: ", ")
        }
        return result
    }

    var total: Amount {
        var result = Amount.zero(currency)
        for product in products {
            result = result + (product.price * product.quantity)
        }
        return result
    }

    func adding(_ product: ConfigProduct) -> Order {
        var updated = products
        if let i = updated.firstIndex(where: { $0.id == product.id }) {
            updated[i].quantity += 1
        } else {
            var newProduct = product
            newProduct.quantity = 1
            updated.append(newProduct)
        }
        return Order(id: id, currency: currency, availableCategories: availableCategories, products: updated)
    }

    func removing(_ product: ConfigProduct) -> Order {
        var updated = products
        guard let i = updated.firstIndex(where: { $0.id == product.id }) else { return self }
        if updated[i].quantity <= 1 {
            updated.remove(at: i)
        } else {
            updated[i].quantity -= 1
        }
        return Order(id: id, currency: currency, availableCategories: availableCategories, products: updated)
    }

    private func getCategoryQuantities() -> [(Category, Int)] {
        var result: [(Category, Int)] = []
        var seen: [Int: Int] = [:]
        for product in products {
            guard let catId = product.categories.first,
                  let cat = availableCategories[catId] else { continue }
            if let idx = seen[catId] {
                result[idx].1 += product.quantity
            } else {
                seen[catId] = result.count
                result.append((cat, product.quantity))
            }
        }
        return result
    }

    func toContractTerms(includeProducts: Bool = true) -> ContractTerms {
        ContractTerms(
            summary: summary,
            summaryI18n: summaryI18n,
            amount: total,
            products: includeProducts ? products.map { $0.toContractProduct() } : nil
        )
    }
}

struct ContractTerms: Codable {
    let summary: String
    let summaryI18n: [String: String]?
    let amount: Amount
    let products: [ContractProduct]?

    enum CodingKeys: String, CodingKey {
        case summary
        case summaryI18n = "summary_i18n"
        case amount
        case products
    }
}
