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
import os

private let logger = Logger(subsystem: "net.taler.pos", category: "MerchantApi")

enum ApiError: Error, LocalizedError {
    case network(String)
    case unauthorized
    case http(Int, String?, Int?)
    case decodingFailed(String)
    case invalidURL

    var errorDescription: String? {
        switch self {
        case .network(let msg): return msg
        case .unauthorized: return "Unauthorized (401): check your access token."
        case .http(let code, let hint, _):
            if let hint { return "Error \(code): \(hint)" }
            return "HTTP error (\(code))"
        case .decodingFailed(let msg): return "Failed to parse response: \(msg)"
        case .invalidURL: return "Invalid URL"
        }
    }

    var isUnauthorized: Bool {
        switch self {
        case .unauthorized: return true
        case .http(401, _, _): return true
        default: return false
        }
    }

    var isInventoryError: Bool {
        guard case .http(_, let hint, _) = self, let hint else { return false }
        let lower = hint.lowercased()
        return lower.contains("inventory") || lower.contains("stock") ||
               lower.contains("insufficient") || lower.contains("sold out") ||
               lower.contains("out of stock")
    }

    var backendCode: Int? {
        switch self {
        case .http(_, _, let code): return code
        default: return nil
        }
    }

    var isPermanentClientError: Bool {
        switch self {
        case .http(let status, _, _): return (400..<500).contains(status) && status != 401 && status != 408 && status != 429
        default: return false
        }
    }
}

struct ApiErrorResponse: Codable {
    let code: Int?
    let hint: String?
    let detail: String?
}

struct PostOrderRequest: Codable {
    let order: ContractTerms
    let refundDelay: RelativeTime?
    let inventoryProducts: [MinimalInventoryProduct]?
    let createToken: Bool

    enum CodingKeys: String, CodingKey {
        case order
        case refundDelay = "refund_delay"
        case inventoryProducts = "inventory_products"
        case createToken = "create_token"
    }
}

struct RelativeTime: Codable {
    let dUs: UInt64

    enum CodingKeys: String, CodingKey {
        case dUs = "d_us"
    }

    static func hours(_ h: Int) -> RelativeTime {
        RelativeTime(dUs: UInt64(h) * 3_600_000_000)
    }
}

struct MinimalInventoryProduct: Codable {
    let productId: String
    let quantity: Int?

    enum CodingKeys: String, CodingKey {
        case productId = "product_id"
        case quantity
    }
}

struct PostOrderResponse: Codable {
    let orderId: String

    enum CodingKeys: String, CodingKey {
        case orderId = "order_id"
    }
}

enum CheckPaymentResponse {
    case unpaid(talerPayUri: String)
    case claimed
    case paid(refunded: Bool, refundPending: Bool, refundAmount: Amount?)
}

extension CheckPaymentResponse: Decodable {
    enum CodingKeys: String, CodingKey {
        case orderStatus = "order_status"
        case talerPayUri = "taler_pay_uri"
        case paid
        case refunded
        case refundPending = "refund_pending"
        case refundAmount = "refund_amount"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let status = try container.decode(String.self, forKey: .orderStatus)
        switch status {
        case "unpaid":
            let uri = try container.decode(String.self, forKey: .talerPayUri)
            self = .unpaid(talerPayUri: uri)
        case "claimed":
            self = .claimed
        case "paid":
            let refunded = try container.decode(Bool.self, forKey: .refunded)
            let refundPending = try container.decodeIfPresent(Bool.self, forKey: .refundPending) ?? false
            let refundAmount = try container.decodeIfPresent(Amount.self, forKey: .refundAmount)
            self = .paid(refunded: refunded, refundPending: refundPending, refundAmount: refundAmount)
        default:
            throw DecodingError.dataCorruptedError(forKey: .orderStatus, in: container, debugDescription: "Unknown order_status: \(status)")
        }
    }
}

struct RefundRequest: Codable {
    let refund: Amount
    let reason: String
}

struct RefundResponse: Codable {
    let talerRefundUri: String

    enum CodingKeys: String, CodingKey {
        case talerRefundUri = "taler_refund_uri"
    }
}

// MARK: - MFA / Token models

enum TanChannel: String, Codable {
    case sms
    case email
}

struct MfaChallenge: Codable, Identifiable {
    let challengeId: String
    let tanChannel: TanChannel
    let tanInfo: String

    var id: String { challengeId }

    enum CodingKeys: String, CodingKey {
        case challengeId = "challenge_id"
        case tanChannel = "tan_channel"
        case tanInfo = "tan_info"
    }
}

struct ChallengesResponse: Codable {
    let challenges: [MfaChallenge]
    let combiAnd: Bool

    enum CodingKeys: String, CodingKey {
        case challenges
        case combiAnd = "combi_and"
    }
}

struct TokenRequest: Codable {
    let scope: String
    let duration: TokenDuration
}

struct TokenDuration: Codable {
    let dUs: String // "forever" or microseconds as string

    static let forever = TokenDuration(dUs: "forever")

    enum CodingKeys: String, CodingKey {
        case dUs = "d_us"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if dUs == "forever" {
            try container.encode("forever", forKey: .dUs)
        } else if let num = Int64(dUs) {
            try container.encode(num, forKey: .dUs)
        } else {
            try container.encode(dUs, forKey: .dUs)
        }
    }
}

struct LimitedTokenResponse: Codable {
    let token: String
}

struct ChallengeConfirmRequest: Codable {
    let tan: String
}

struct ChallengeRequiredError: Error {
    let challengeResponse: ChallengesResponse
}

struct MerchantBackendConfigResponse: Codable {
    let version: String
    let currency: String
    let currencies: [String: CurrencySpecification]?
}

struct ProductDetail: Codable {
    let totalSold: Int?
    let totalLost: Int?
    let unitTotalSold: String?
    let unitTotalLost: String?

    enum CodingKeys: String, CodingKey {
        case totalSold = "total_sold"
        case totalLost = "total_lost"
        case unitTotalSold = "unit_total_sold"
        case unitTotalLost = "unit_total_lost"
    }
}

class MerchantApi {
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    var onUnauthorized: (() -> Void)?

    init(session: URLSession = .shared) {
        self.session = session
        self.decoder = JSONDecoder()
        self.encoder = JSONEncoder()
    }

    func fetchPosConfig(merchantUrl: String, accessToken: String) async throws -> PosConfig {
        var url = merchantUrl
        if !url.hasSuffix("/") { url += "/" }
        url += "private/pos"
        return try await get(url: url, accessToken: accessToken)
    }

    func fetchBackendConfig(merchantConfig: MerchantConfig) async throws -> MerchantBackendConfigResponse {
        return try await get(url: merchantConfig.urlFor("config"), accessToken: merchantConfig.apiKey)
    }

    func fetchProductDetail(merchantConfig: MerchantConfig, productId: String) async throws -> ProductDetail {
        let url = merchantConfig.urlForPathComponent("private/products", segment: productId)
        return try await get(url: url, accessToken: merchantConfig.apiKey)
    }

    func postOrder(merchantConfig: MerchantConfig, request: PostOrderRequest) async throws -> PostOrderResponse {
        let url = merchantConfig.urlFor("private/orders")
        return try await post(url: url, body: request, accessToken: merchantConfig.apiKey)
    }

    func checkOrder(merchantConfig: MerchantConfig, orderId: String) async throws -> CheckPaymentResponse {
        let url = merchantConfig.urlForPathComponent("private/orders", segment: orderId)
        return try await get(url: url, accessToken: merchantConfig.apiKey)
    }

    func deleteOrder(merchantConfig: MerchantConfig, orderId: String, force: Bool = false) async throws {
        var urlStr = merchantConfig.urlForPathComponent("private/orders", segment: orderId)
        if force { urlStr += "?force=yes" }
        guard let url = URL(string: urlStr) else { throw ApiError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(merchantConfig.apiKey)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await session.data(for: request)
        try checkResponse(response, data: data)
    }

    func getOrderHistory(merchantConfig: MerchantConfig, limit: Int = -20, offset: Int64? = nil) async throws -> OrderHistory {
        var urlStr = merchantConfig.urlFor("private/orders") + "?limit=\(limit)"
        if let offset { urlStr += "&offset=\(offset)" }
        return try await get(url: urlStr, accessToken: merchantConfig.apiKey)
    }

    func giveRefund(merchantConfig: MerchantConfig, orderId: String, request: RefundRequest) async throws -> RefundResponse {
        let url = merchantConfig.urlForPathComponent("private/orders", segment: orderId) + "/refund"
        return try await post(url: url, body: request, accessToken: merchantConfig.apiKey)
    }

    // MARK: - MFA Token Exchange

    func fetchLimitedAccessToken(
        baseUrl: String,
        username: String,
        initialSecret: String,
        duration: TokenDuration = .forever,
        challengeIds: [String] = []
    ) async throws -> String {
        let encodedUser = username.addingPercentEncoding(withAllowedCharacters: .urlPathComponentAllowed) ?? username
        let urlStr = "\(baseUrl)/instances/\(encodedUser)/private/token"
        guard let url = URL(string: urlStr) else { throw ApiError.invalidURL }

        let tokenRequest = TokenRequest(scope: "write", duration: duration)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer secret-token:\(initialSecret)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !challengeIds.isEmpty {
            request.setValue(challengeIds.joined(separator: ","), forHTTPHeaderField: "Taler-Challenge-Ids")
        }
        request.httpBody = try encoder.encode(tokenRequest)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw ApiError.network(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ApiError.network("Invalid response")
        }

        if httpResponse.statusCode == 202 {
            let challengeResponse = try decoder.decode(ChallengesResponse.self, from: data)
            throw ChallengeRequiredError(challengeResponse: challengeResponse)
        }

        if httpResponse.statusCode == 401 {
            throw ApiError.unauthorized
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            var hint: String?
            var backendCode: Int?
            if let errorResp = try? decoder.decode(ApiErrorResponse.self, from: data) {
                hint = errorResp.hint ?? errorResp.detail
                backendCode = errorResp.code
            }
            throw ApiError.http(httpResponse.statusCode, hint, backendCode)
        }

        let tokenResponse = try decoder.decode(LimitedTokenResponse.self, from: data)
        return tokenResponse.token
    }

    /// POST /instances/{username}/challenge/{challengeId}
    /// Requests a challenge (sends TAN to user's phone/email)
    func requestChallenge(baseUrl: String, username: String, challengeId: String) async throws {
        let encodedUser = username.addingPercentEncoding(withAllowedCharacters: .urlPathComponentAllowed) ?? username
        let encodedChallenge = challengeId.addingPercentEncoding(withAllowedCharacters: .urlPathComponentAllowed) ?? challengeId
        let urlStr = "\(baseUrl)/instances/\(encodedUser)/challenge/\(encodedChallenge)"
        guard let url = URL(string: urlStr) else { throw ApiError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data("{}".utf8)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw ApiError.network(error.localizedDescription)
        }
        try checkResponse(response, data: data)
    }

    /// POST /instances/{username}/challenge/{challengeId}/confirm
    /// Confirms a challenge with the TAN code
    /// HTTP 409 = invalid code, HTTP 429 = rate limited
    func confirmChallenge(baseUrl: String, username: String, challengeId: String, tan: String) async throws {
        let encodedUser = username.addingPercentEncoding(withAllowedCharacters: .urlPathComponentAllowed) ?? username
        let encodedChallenge = challengeId.addingPercentEncoding(withAllowedCharacters: .urlPathComponentAllowed) ?? challengeId
        let urlStr = "\(baseUrl)/instances/\(encodedUser)/challenge/\(encodedChallenge)/confirm"
        guard let url = URL(string: urlStr) else { throw ApiError.invalidURL }

        let confirmRequest = ChallengeConfirmRequest(tan: tan)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(confirmRequest)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw ApiError.network(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ApiError.network("Invalid response")
        }

        switch httpResponse.statusCode {
        case 200..<300:
            return // success
        case 409:
            throw ApiError.http(409, "Invalid verification code", nil)
        case 429:
            throw ApiError.http(429, "Too many attempts. Please request a new code.", nil)
        default:
            try checkResponse(response, data: data)
        }
    }

    // MARK: - Private

    private func get<T: Decodable>(url: String, accessToken: String) async throws -> T {
        guard let url = URL(string: url) else { throw ApiError.invalidURL }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        logger.warning("GET \(url.absoluteString)")
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            logger.error("GET \(url.absoluteString) network error: \(error.localizedDescription)")
            throw ApiError.network(error.localizedDescription)
        }
        if let http = response as? HTTPURLResponse {
            logger.warning("GET \(url.absoluteString) -> \(http.statusCode)")
        }
        try checkResponse(response, data: data)
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            logger.error("GET \(url.absoluteString) decode \(String(describing: T.self)) failed: \(error)")
            throw ApiError.decodingFailed(error.localizedDescription)
        }
    }

    private func post<T: Decodable, B: Encodable>(url: String, body: B, accessToken: String) async throws -> T {
        guard let url = URL(string: url) else { throw ApiError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(body)
        logger.warning("POST \(url.absoluteString)")
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            logger.error("POST \(url.absoluteString) network error: \(error.localizedDescription)")
            throw ApiError.network(error.localizedDescription)
        }
        if let http = response as? HTTPURLResponse {
            logger.warning("POST \(url.absoluteString) -> \(http.statusCode)")
        }
        try checkResponse(response, data: data)
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            logger.error("POST \(url.absoluteString) decode \(String(describing: T.self)) failed: \(error)")
            throw ApiError.decodingFailed(error.localizedDescription)
        }
    }

    private func checkResponse(_ response: URLResponse, data: Data? = nil) throws {
        guard let httpResponse = response as? HTTPURLResponse else { return }
        switch httpResponse.statusCode {
        case 200..<300: return
        case 401:
            onUnauthorized?()
            throw ApiError.unauthorized
        default:
            var hint: String?
            var backendCode: Int?
            if let data {
                if let errorResp = try? JSONDecoder().decode(ApiErrorResponse.self, from: data) {
                    hint = errorResp.hint ?? errorResp.detail
                    backendCode = errorResp.code
                }
            }
            throw ApiError.http(httpResponse.statusCode, hint, backendCode)
        }
    }
}
