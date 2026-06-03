/*
 * This file is part of GNU Taler, ©2022-25 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import Foundation
import taler_swift
import AnyCodable
//import SymLog

// MARK: - ContractTerms

//  export interface TalerProtocolDuration {
//      readonly d_us: number | "forever";
//  }

struct TokenIssuePublicKey: Codable {
    let cipher: String          // "RSA", "CS"

    // RSA public key
    let rsaPub: String?         // RSA public key converted to Crockford Base32

    // CS public key
    let csPub: String?          // 32-byte value representing a point on Curve25519

    // Start time of this key's signatures validity period
    let signatureValidityStart: Timestamp

    // End time of this key's signatures validity period
    let signatureValidityEnd: Timestamp

    enum CodingKeys: String, CodingKey {
        case cipher
        case rsaPub = "rsa_pub"
        case csPub = "cs_pub"
        case signatureValidityStart = "signature_validity_start"
        case signatureValidityEnd = "signature_validity_end"
    }
}

struct ContractTokenDetails: Codable {
    let clazz: String                           // "subscription", "discount"

    // Array of domain names where this subscription can be safely used
    // (e.g. the issuer warrants that these sites will re-issue tokens of this type
    // if the respective contract says so).  May contain "*" for any domain or subdomain.
    let trustedDomains: [String]?               // only for subscription

    // Array of domain names where this discount token is intended to be used.
    // May contain "*" for any domain or subdomain.  Users should be warned about sites
    // proposing to consume discount tokens of this type that are not in this list that
    // the merchant is accepting a coupon from a competitor and thus may be attaching
    // different semantics (like get 20% discount for my competitors 30% discount token).
    let expectedDomains: [String]?              // only for discount

    enum CodingKeys: String, CodingKey {
        case clazz = "class"
        case trustedDomains = "trusted_domains"
        case expectedDomains = "expected_domains"
    }
}

struct ContractTokenFamily: Codable {
    // Human-readable name of the token family.
    let name: String

    // Human-readable description of the semantics of this token family (for display).
    let description: String

    // Map from IETF BCP 47 language tags to localized descriptions.
    let descriptionI18n: [String: String]?

    // Public keys used to validate tokens issued by this token family.
    let keys: [TokenIssuePublicKey]

    // Kind-specific information of the token
    let details: ContractTokenDetails

    // Must a wallet understand this token type to
    // process contracts that use or issue it?
    let critical: Bool

    enum CodingKeys: String, CodingKey {
        case name, description
        case descriptionI18n = "description_i18n"
        case keys, details, critical
    }
}

struct ContractInput: Codable, Hashable {
    let type: String                            // "token"

    // Slug of the token family in the token_families map on the order
    let tokenFamilySlug: String?

    // Number of tokens of this type required.
    // Defaults to one if the field is not provided.
    let count: Int?

    enum CodingKeys: String, CodingKey {
        case type, count
        case tokenFamilySlug = "token_family_slug"
    }
}

struct ContractOutput: Codable, Hashable {
    let type: String                            // "token"

    // Slug of the token family in the token_families map on the order
    let tokenFamilySlug: String?

    // Number of tokens of this type required.
    // Defaults to one if the field is not provided.
    let count: Int?

    // Index of the public key for this output token
    // in the ContractTokenFamily keys array.
    let keyIndex: Int

    enum CodingKeys: String, CodingKey {
        case type, count
        case tokenFamilySlug = "token_family_slug"
        case keyIndex = "key_index"
    }
}

struct ContractOutputTaxReceipt: Codable {
    let type: String                            // "tax-receipt"

    // Array of base URLs of donation authorities that can be
    // used to issue the tax receipts. The client must select one.
    let donauUrls: [String]

    // Total amount that will be on the tax receipt.
    let amount: Amount

    enum CodingKeys: String, CodingKey {
        case type, amount
        case donauUrls = "donau_urls"
    }
}

struct ContractChoice: Codable, Hashable {
    let amount: Amount                          // Total amount payable
    let maxFee: Amount                          // Maximum deposit fee covered by the merchant
    let description: String?                    //
    let descriptionI18n: [String: String]?      //      "      localized     "
    let inputs: [ContractInput]
    let outputs: [ContractOutput]

    enum CodingKeys: String, CodingKey {
        case amount, description
        case maxFee = "max_fee"
        case descriptionI18n = "description_i18n"
        case inputs, outputs
    }
}

struct MerchantContractTerms: Codable {
    let version: Int?                   // v0 doesn't know this

    // ContractTermsV0
    let amount: Amount?                 // Total amount payable
    let maxFee: Amount?                 // Maximum deposit fee covered by the merchant

    // ContractTermsCommon
    let summary: String                 // Human-readable short summary of the contract
    let summaryI18n: [String: String]?  //      "      localized     "
    let orderID: String                 // uniquely identify the purchase within one merchant instance
    let publicReorderURL: String?       // URL meant to share the shopping cart
    let fulfillmentURL: String?         // Fulfillment URL to view the product or delivery status
    let fulfillmentMessage: String?     // Plain text fulfillment message in the merchant's default language
    let fulfillmentMessageI18n: String? // Plain text fulfillment message in the merchant's default language
    let products: [Product]?            // Products that are sold in this contract
    let timestamp: Timestamp            // Time when the contract was generated by the merchant
    let refundDeadline: Timestamp?      // Deadline for refunds
    let payDeadline: Timestamp          // Deadline to pay for the contract
    let wireTransferDeadline: Timestamp?// Deadline for the wire transfer
    let merchantPub: String             // Public key of the merchant
    let merchantBaseURL: String         // Base URL of the merchant's backend
    let merchant: Merchant
    let hWire: String                   // Hash of the merchant's wire details
    let wireMethod: String              // merchant wants to use
    let exchanges: [ExchangeForPay]
    let deliveryLocation: Location?     // Delivery location for (all!) products
    let deliveryDate: Timestamp?        // indicating when the order should be delivered
    let nonce: String                   // used to ensure freshness
    let autoRefund: Duration?
    let extra: Extra?                   // Extra data, interpreted by the merchant only
    let minimumAge: Int?

// deprecated   let wireFeeAmortization: Int?       // Share of the wire fee that must be settled with one payment
//    let maxWireFee: Amount?             // Maximum wire fee that the merchant agrees to pay for
//    let auditors: [Auditor]?

    // ContractTermsV1
    let choices: [ContractChoice]?
    // Map of storing metadata and issue keys of
    // token families referenced in this contract.
    // @since protocol **vSUBSCRIBE**
    let tokenFamilies: [String: ContractTokenFamily]?   // token_family_slug: String

    enum CodingKeys: String, CodingKey {
        case version
        case amount
        case maxFee = "max_fee"

        case summary
        case summaryI18n = "summary_i18n"
        case orderID = "order_id"
        case publicReorderURL = "public_reorder_url"
        case fulfillmentURL = "fulfillment_url"
        case fulfillmentMessage = "fulfillment_message"
        case fulfillmentMessageI18n = "fulfillment_message_i18n"
        case products
        case timestamp
        case refundDeadline = "refund_deadline"
        case payDeadline = "pay_deadline"
        case wireTransferDeadline = "wire_transfer_deadline"
        case merchantPub = "merchant_pub"
        case merchantBaseURL = "merchant_base_url"
        case merchant
        case hWire = "h_wire"
        case wireMethod = "wire_method"
        case exchanges
        case deliveryLocation = "delivery_location"
        case deliveryDate = "delivery_date"
        case nonce
        case autoRefund = "auto_refund"
        case extra
        case minimumAge = "minimum_age"

//        case wireFeeAmortization = "wire_fee_amortization"
//        case maxWireFee = "max_wire_fee"
//        case auditors
        case choices
        case tokenFamilies = "token_families"
    }
}
// MARK: - Auditor
struct Auditor: Codable {
    let name: String
    let auditorPub: String
    let url: String

    enum CodingKeys: String, CodingKey {
        case name
        case auditorPub = "auditor_pub"
        case url
    }
}
// MARK: - Exchange
struct ExchangeForPay: Codable {
    let url: String
    let masterPub: String

    enum CodingKeys: String, CodingKey {
        case url
        case masterPub = "master_pub"
    }
}
// MARK: - Extra
struct Extra: Codable {
    let articleName: String?

    enum CodingKeys: String, CodingKey {
        case articleName = "article_name"
    }
}
// MARK: -
enum PreparePayResultType: String, Codable {
    case paymentPossible = "payment-possible"
    case alreadyConfirmed = "already-confirmed"
    case insufficientBalance = "insufficient-balance"
    case choiceSelection = "choice-selection"
}

struct PayMerchantInsufficientBalanceDetails: Codable {
    let amountRequested: Amount
    let balanceAvailable: Amount
    let balanceMaterial: Amount
    let balanceAgeAcceptable: Amount
    let balanceReceiverAcceptable: Amount
    let balanceReceiverDepositable: Amount
    let perExchange: [String:ExchangeFeeGapEstimate]
    let causeHint: InsufficientBalanceHint
}

struct ExchangeFeeGapEstimate: Codable {
    let balanceAvailable: Amount
    let balanceMaterial: Amount
    let balanceExchangeDepositable: Amount
    let balanceAgeAcceptable: Amount
    let balanceReceiverAcceptable: Amount
    let balanceReceiverDepositable: Amount
    let maxEffectiveSpendAmount: Amount
}

struct PerScopeDetails: Codable {
    let scopeInfo: ScopeInfo
}
/// The result from PreparePayForUri
struct PreparePayResult: Codable {
    let status: PreparePayResultType                            // InsufficientBalance, AlreadyConfirmed, PaymentPossible, ChoiceSelection
    let transactionId: String
    let contractTerms: MerchantContractTerms
    let contractTermsHash: String?                              // not for InsufficientBalance
    let scopes: [ScopeInfo]?                                    // not for ChoiceSelection
//  let detailsPerScope: [ScopeInfo : PreparePayDetails]
    let amountRaw: Amount                                       // TODO: not for ChoiceSelection

    let amountEffective: Amount?                                // only if status != insufficientBalance
    let paid: Bool?                                             // only if status == alreadyConfirmed
    let talerUri: String?
    let balanceDetails: PayMerchantInsufficientBalanceDetails?  // only if status == insufficientBalance
}
/// A request to get an exchange's payment contract terms.
fileprivate struct PreparePayForUri: WalletBackendFormattedRequest {
    typealias Response = PreparePayResult
    func operation() -> String { "preparePayForUri" }
    func args() -> Args { Args(talerPayUri: talerPayUri) }

    var talerPayUri: String
    struct Args: Encodable {
        var talerPayUri: String
    }
}

/**
 * Forced coin selection for deposits/payments.
 */
struct ValueContribution: Codable {
    var value: Amount
    var contribution: Amount
}
struct ForcedCoinSel: Codable {
    var coins: [ValueContribution]
}

enum ChoiceSelectionDetailStatus: String, Codable {
    case paymentPossible = "payment-possible"
    case insufficientBalance = "insufficient-balance"
}

enum TokenAvailabilityHint: String, Codable {
    case walletTokensAvailableInsufficient = "wallet-tokens-available-insufficient"
    case merchantUnexpected = "merchant-unexpected"
    case merchantUntrusted = "merchant-untrusted"

}
struct TokenFamily: Codable, Hashable, Equatable {
    var causeHint: TokenAvailabilityHint?
    var requested: Int
    var available: Int
    var unexpected: Int
    var untrusted: Int
}

struct TokenDetails: Codable, Hashable, Equatable {
    var tokensRequested: Int
    var tokensAvailable: Int
    var tokensUnexpected: Int
    var tokensUntrusted: Int
    var perTokenFamily: [String: TokenFamily]
}

struct ChoiceSelectionDetail: Codable, Hashable, Sendable {
    var status: ChoiceSelectionDetailStatus
    var amountRaw: Amount
    var amountEffective: Amount?                                // only if possible
    var tokenDetails: TokenDetails?                             // only if possible
    var balanceDetails: PaymentInsufficientBalanceDetails?      // only if insufficient
}

struct GetChoicesForPaymentResult: Codable {
    var choices: [ChoiceSelectionDetail]
    /**
     * Index of the choice in @e choices array to present to the user as default.
     * Won´t be set if no default selection is configured or no choice is payable,
     * otherwise, it will always be 0 for v0 orders.
     */
    var defaultChoiceIndex: Int?
    /**
     * Whether the choice referenced by @e automaticExecutableIndex
     * should be confirmed automatically without user interaction.
     *
     * If true, the wallet should call `confirmPay' immediately afterwards
     * If false, the user should be first prompted to select and confirm a choice.
     * Undefined when no choices are payable.
     */
    var automaticExecution: Bool?
    var automaticExecutableIndex: Int?

    var contractTerms: MerchantContractTerms
}

/// A request to get an exchange's payment contract terms.
fileprivate struct GetChoicesForPayment: WalletBackendFormattedRequest {
    typealias Response = GetChoicesForPaymentResult
    func operation() -> String { "getChoicesForPayment" }
    func args() -> Args { Args(transactionId: transactionId, forcedCoinSel: forcedCoinSel) }

    var transactionId: String
    var forcedCoinSel: ForcedCoinSel?
    struct Args: Encodable {
        var transactionId: String
        var forcedCoinSel: ForcedCoinSel?
    }
}

struct TemplateParams: Codable {
    let amount: Amount?                     // Total amount payable
    let summary: String?                    // Human-readable short summary of the contract
}
/// A request to get an exchange's payment contract terms.
fileprivate struct PreparePayForTemplateRequest: WalletBackendFormattedRequest {
    typealias Response = PreparePayResult
    func operation() -> String { "preparePayForTemplate" }
    func args() -> Args { Args(talerPayTemplateUri: talerPayTemplateUri, templateParams: templateParams) }

    var talerPayTemplateUri: String
    var templateParams: TemplateParams
    struct Args: Encodable {
        var talerPayTemplateUri: String
        var templateParams: TemplateParams
    }
}
// MARK: -
struct TemplateContractDetails: Codable {
    let summary: String?                // Human-readable short summary of the contract. Editable if nil
    let currency: String?               // specify currency when amount is nil - unspecified if nil
    let amount: Amount?                 // Total amount payable. Fixed if this field exists, editable if nil
    let scopeInfo: ScopeInfo?
    let minimumAge: Int?
    let payDuration: Duration?
    let websiteRegex: String?
    let choices: [OrderChoice]?
    let templateType: String?

    enum CodingKeys: String, CodingKey {
        case summary, currency, amount
        case scopeInfo, choices
        case minimumAge = "minimum_age"
        case payDuration = "pay_duration"
        case websiteRegex = "website_regex"
        case templateType = "template_type"
    }
}

struct OrderChoice: Codable {
    let amount: Amount
    let tip: Amount?
    let description: String?
    let descriptionI18n: String?
    let inputs: [OrderInput]?
    let outputs: [OrderOutput]?     // TODO: OrderOutputTaxReceipt
    let maxFee: Amount?

    enum CodingKeys: String, CodingKey {
        case amount, tip, description
        case descriptionI18n = "description_i18n"
        case inputs, outputs
        case maxFee = "max_fee"
    }
}

struct OrderInput: Codable {    // see ContractInput
    let type: String                            // "token"

    // Token family slug as configured in the merchant backend.
    // Slug is unique across all configured tokens of a merchant.
    let tokenFamilySlug: String?

    // How many units of the input are required.
    // Defaults to 1 if not specified.
    // Output with count == 0 are ignored by the merchant backend.
    let count: Int?

    enum CodingKeys: String, CodingKey {
        case type, count
        case tokenFamilySlug = "token_family_slug"
    }
}

struct OrderOutput: Codable {   // TODO: ContractOutput
    let type: String                            // "token"

    // Token family slug as configured in the merchant backend.
    // Slug is unique across all configured tokens of a merchant.
    let tokenFamilySlug: String?

    // How many units of the output are issued by the merchant.
    // Defaults to 1 if not specified.
    // Output with count == 0 are ignored by the merchant backend.
    let count: Int?

    // When should the output token be valid. Can be specified if the
    // desired validity period should be in the future (like selling
    // a subscription for the next month). Optional. If not given,
    // the validity is supposed to be "now" (time of order creation).
    let validAt: Timestamp?

    enum CodingKeys: String, CodingKey {
        case type, count
        case tokenFamilySlug = "token_family_slug"
        case validAt = "valid_at"
    }
}
struct OrderOutputTaxReceipt: Codable {
    let type: String                            // "tax-receipt"
}

struct TemplateContractDetailsDefaults: Codable {
    let summary: String?                // Default 'Human-readable summary' when editable: empty if nil
    let currency: String?               // Default currency when unspecified: any if nil (e.g. donations)
    let amount: Amount?                 // Default amount when editable: unspecified if nil
}
struct TalerMerchantTemplateDetails: Codable {
    let templateContract: TemplateContractDetails
    let editableDefaults: TemplateContractDetailsDefaults?
//    let requiredCurrency: String?
    enum CodingKeys: String, CodingKey {
        case templateContract = "template_contract"
        case editableDefaults = "editable_defaults"
//        case requiredCurrency = "required_currency"
    }
}

/// The result from checkPayForTemplate
struct WalletTemplateDetails: Codable {
    let templateDetails: TalerMerchantTemplateDetails
    let supportedCurrencies: [String]
}
/// A request to get an exchange's payment contract terms.
fileprivate struct CheckPayForTemplate: WalletBackendFormattedRequest {
    typealias Response = WalletTemplateDetails
    func operation() -> String { "checkPayForTemplate" }
    func args() -> Args { Args(talerPayTemplateUri: talerPayTemplateUri) }

    var talerPayTemplateUri: String
    struct Args: Encodable {
        var talerPayTemplateUri: String
    }
}
// MARK: -
/// The result from confirmPayForUri
struct ConfirmPayResult: Decodable {
    var type: String                                // done || pending
    var contractTerms: MerchantContractTerms?       // only if type==done
    var transactionId: String
    var lastError: TalerErrorDetail?                // might, but only if type==pending
}
/// A request to get an exchange's payment details.
fileprivate struct ConfirmPayForUri: WalletBackendFormattedRequest {
    typealias Response = ConfirmPayResult
    func operation() -> String { "confirmPay" }
    func args() -> Args { Args(transactionId: transactionId) }

    var transactionId: String
    struct Args: Encodable {
        var transactionId: String
    }
}
// MARK: -
extension WalletModel {
    /// load payment details. Networking involved
    nonisolated func checkPayForTemplate(_ talerPayTemplateUri: String, viewHandles: Bool = false)
      async throws -> WalletTemplateDetails {
        let request = CheckPayForTemplate(talerPayTemplateUri: talerPayTemplateUri)
        let response = try await sendRequest(request, viewHandles: viewHandles)
        return response
    }

    nonisolated func preparePayForTemplate(_ talerPayTemplateUri: String, amount: Amount?, summary: String?, viewHandles: Bool = false)
      async throws -> PreparePayResult {
        let templateParams = TemplateParams(amount: amount, summary: summary)
        let request = PreparePayForTemplateRequest(talerPayTemplateUri: talerPayTemplateUri, templateParams: templateParams)
        let response = try await sendRequest(request, viewHandles: viewHandles)
        return response
    }

    nonisolated func getChoicesForPayment(_ transactionId: String, viewHandles: Bool = false)
      async throws -> GetChoicesForPaymentResult {
        let request = GetChoicesForPayment(transactionId: transactionId, forcedCoinSel: nil)
        let response = try await sendRequest(request, viewHandles: viewHandles)
        return response
    }

    nonisolated func preparePayForUri(_ talerPayUri: String, viewHandles: Bool = false)
      async throws -> PreparePayResult {
        let request = PreparePayForUri(talerPayUri: talerPayUri)
        let response = try await sendRequest(request, viewHandles: viewHandles)
        return response
    }

    nonisolated func confirmPay(_ transactionId: String, viewHandles: Bool = false)
      async throws -> ConfirmPayResult {
        let request = ConfirmPayForUri(transactionId: transactionId)
        let response = try await sendRequest(request, viewHandles: viewHandles)
        return response
    }
}
