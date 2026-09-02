/*
 * This file is part of GNU Taler, ©2022-25 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import Foundation
import taler_swift
import SymLog
import os.log

enum InsufficientBalanceHint: String, Codable {
    /// Merchant doesn't accept money from exchange(s) that the wallet supports
    case merchantAcceptInsufficient = "merchant-accept-insufficient"
    /// Merchant accepts funds from a matching exchange, but the funds can't be deposited with the wire method
    case merchantDepositInsufficient = "merchant-deposit-insufficient"
    /// While in principle the balance is sufficient, the age restriction on coins causes the spendable balance to be insufficient
    case ageRestricted = "age-restricted"
    /// Wallet has enough available funds, but the material funds are insufficient
    /// Usually because there is a pending refresh operation
    case walletBalanceMaterialInsufficient = "wallet-balance-material-insufficient"
    /// The wallet simply doesn't have enough available funds
    case walletBalanceAvailableInsufficient = "wallet-balance-available-insufficient"
    /// Exchange is missing the global fee configuration, thus fees are unknown
    /// and funds from this exchange can't be used for p2p payments
    case exchangeMissingGlobalFees = "exchange-missing-global-fees"
    /// Even though the balance looks sufficient for the instructed amount,
    /// the fees can be covered by neither the merchant nor the remaining wallet  balance
    case feesNotCovered = "fees-not-covered"
    /// wallet-core keeps adding hints (feesNotCovered and exchangeMissingGlobalFees were
    /// added after this enum was written). Throwing on the next one would take the whole
    /// error message down with it - and an error that fails to decode never resumes the
    /// Task waiting for that request.
    case unknown

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = InsufficientBalanceHint(rawValue: raw) ?? .unknown
    }

    func localizedCause(_ currency: String) -> String {
        switch self {
            case .merchantAcceptInsufficient:
                String(localized: "payment_balance_insufficient_hint_merchant_accept_insufficient",
                    defaultValue: "Merchant doesn't accept money from one or more providers in this wallet")
            case .merchantDepositInsufficient:
                String(localized: "payment_balance_insufficient_hint_merchant_deposit_insufficient",
                    defaultValue: "Merchant doesn't accept the wire method of the provider, this likely means it is misconfigured")
            case .ageRestricted:
                String(localized: "payment_balance_insufficient_hint_age_restricted",
                    defaultValue: "Purchase not possible due to age restriction")
            case .walletBalanceMaterialInsufficient:
                String(localized: "payment_balance_insufficient_hint_wallet_balance_material_insufficient",
                    defaultValue: "Some of the digital cash needed for this purchase is currently unavailable")
            case .walletBalanceAvailableInsufficient:
                String(localized: "payment_balance_insufficient_max",
                    defaultValue: "Balance insufficient! You don't have enough \(currency).")
            case .exchangeMissingGlobalFees:
                String(localized: "payment_balance_insufficient_hint_exchange_missing_global_fees",
                    defaultValue: "Provider is missing the global fee configuration, this likely means it is misconfigured")
            case .feesNotCovered:
                String(localized: "payment_balance_insufficient_hint_fees_not_covered",
                    defaultValue: "Not enough funds to pay the provider fees not covered by the merchant")
            case .unknown:      // we don't know the reason, but we do know the balance is insufficient
                String(localized: "payment_balance_insufficient_max",
                    defaultValue: "Balance insufficient! You don't have enough \(currency).")
        }
    }
}

struct InsufficientBalanceDetailsPerExchange: Codable, Hashable {
    var balanceAvailable: Amount
    var balanceMaterial: Amount
    var balanceExchangeDepositable: Amount
    var balanceAgeAcceptable: Amount
    var balanceReceiverAcceptable: Amount?          // deprecated
    var balanceReceiverDepositable: Amount
    var maxEffectiveSpendAmount: Amount
    /// Exchange doesn't have global fees configured for the relevant year, p2p payments aren't possible.
    var missingGlobalFees: Bool?                    // deprecated
}

///  Detailed reason for why the wallet's balance is insufficient.
struct PaymentInsufficientBalanceDetails: Codable, Hashable {
    /// Amount requested by the merchant.
    var amountRequested: Amount
    var causeHint: InsufficientBalanceHint?
    /// Balance of type "available" (see balance.ts for definition).
    var balanceAvailable: Amount
    /// Balance of type "material" (see balance.ts for definition).
    var balanceMaterial: Amount
    /// Balance of type "age-acceptable" (see balance.ts for definition).
    var balanceAgeAcceptable: Amount
    /// Balance of type "merchant-acceptable" (see balance.ts for definition).
    var balanceReceiverAcceptable: Amount
    /// Balance of type ...
    var balanceReceiverDepositable: Amount
    var balanceExchangeDepositable: Amount
    /// Maximum effective amount that the wallet can spend, when all fees are paid by the wallet.
    var maxEffectiveSpendAmount: Amount
    var perExchange: [String : InsufficientBalanceDetailsPerExchange]
}
// MARK: -
struct TalerErrorInfo: Codable, Hashable {
    /// Numeric error code defined in the GANA gnu-taler-error-codes registry.
    /// Optional: this is the response of some *other* server, which need not
    /// be a Taler error object at all.
    var code: Int?
    // all other fields are optional:
    var when: Timestamp?
    /// English description of the error code.
    var hint: String?
    var message: String?
}
struct TalerErrorDetail: Codable, Hashable {
    /// Numeric error code defined in the GANA gnu-taler-error-codes registry.
    var code: Int
    // all other fields are optional:
    var when: Timestamp?
    /// English description of the error code.
    var hint: String?

    /// Error details, type depends on `talerErrorCode`.
    var detail: String?

    /// HTTPError
    var requestUrl: String?
    var requestMethod: String?
    var httpStatusCode: Int?
    var stack: String?
    var errorResponse: TalerErrorInfo?

    var insufficientBalanceDetails: PaymentInsufficientBalanceDetails?

    enum CodingKeys: String, CodingKey {
        case code, when, hint, detail
        case requestUrl, requestMethod, httpStatusCode, stack
        case errorResponse, insufficientBalanceDetails
    }
}
extension TalerErrorDetail {
    /// In wallet-core a TalerErrorDetail is an open dictionary: besides code, when and
    /// hint it carries whatever the throwing code put there, and the shape of that
    /// differs per error code - `detail`, for instance, is a string for some codes and a
    /// nested error object for others.
    /// Throwing here is not survivable: the error arrives inside the top-level message
    /// envelope, so if it doesn't decode then WalletCore never finds the request id and
    /// the continuation awaiting that request is never resumed - the sheet spins forever.
    /// Therefore decode the optional extras defensively and drop what we cannot read.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        code = try container.decode(Int.self, forKey: .code)
        when = try? container.decodeIfPresent(Timestamp.self, forKey: .when)
        hint = try? container.decodeIfPresent(String.self, forKey: .hint)
        detail = try? container.decodeIfPresent(String.self, forKey: .detail)
        requestUrl = try? container.decodeIfPresent(String.self, forKey: .requestUrl)
        requestMethod = try? container.decodeIfPresent(String.self, forKey: .requestMethod)
        httpStatusCode = try? container.decodeIfPresent(Int.self, forKey: .httpStatusCode)
        stack = try? container.decodeIfPresent(String.self, forKey: .stack)
        errorResponse = try? container.decodeIfPresent(TalerErrorInfo.self, forKey: .errorResponse)
        insufficientBalanceDetails = try? container.decodeIfPresent(PaymentInsufficientBalanceDetails.self,
                                                            forKey: .insufficientBalanceDetails)
    }
}
// MARK: -
/// Communicate with wallet-core
final class WalletModel: ObservableObject, Sendable {
    public static let shared = WalletModel()
    let logger = Logger(subsystem: "net.taler.gnu", category: "WalletModel")

    @Published var error2: ErrorData? = nil

    @MainActor func setError(_ theError: Error?) {
        if let theError {
            self.error2 = .error(theError)
        } else {
            self.error2 = nil
        }
    }
    @MainActor func setMessage(_ title: String,_ theMessage: String?) {
        if let theMessage {
            self.error2 = .message(title: title, message: theMessage)
        } else {
            self.error2 = nil
        }
    }

    func sendRequest<T: WalletBackendFormattedRequest> (_ request: T, viewHandles: Bool = false, asJSON: Bool = false)
      async throws -> T.Response {    // T for any Thread
#if !DEBUG
        logger.log("sending: \(request.operation, privacy: .public)")
#endif
        let sendTime = Date.now
        do {
            let (response, id) = try await WalletCore.shared.sendFormattedRequest(request, asJSON: asJSON)
#if !DEBUG
            let timeUsed = Date.now - sendTime
            logger.log("received: \(request.operation, privacy: .public) (\(id, privacy: .public)) after \(timeUsed.milliseconds, privacy: .public) ms")
#endif
            return response
        } catch {       // rethrows
            let timeUsed = Date.now - sendTime
            logger.error("\(request.operation, privacy: .public) failed after \(timeUsed.milliseconds, privacy: .public) ms\n\(error, privacy: .public)")
            if !viewHandles {
                // TODO: symlog + controller sound
                await setError(error)
            }
            throw error
        }
    }
}
// MARK: -
struct DbStatus: Decodable, Sendable {
    var dbReadHealthy: Bool
    var dbWriteHealthy: Bool
}
/// A request to tell wallet-core about the network.
fileprivate struct ApplicationResumedRequest: WalletBackendFormattedRequest {
    typealias Response = DbStatus
    var operation: String { "hintApplicationResumed" }
    func args() -> Args { Args() }

    struct Args: Encodable {}                           // no arguments needed
}

fileprivate struct NetworkAvailabilityRequest: WalletBackendFormattedRequest {
    struct Response: Decodable {}
    var operation: String { "hintNetworkAvailability" }
    func args() -> Args { Args(isNetworkAvailable: isNetworkAvailable) }

    var isNetworkAvailable: Bool

    struct Args: Encodable {
        var isNetworkAvailable: Bool
    }
}

extension WalletModel {
    func hintNetworkAvailabilityT(_ isNetworkAvailable: Bool = false) async {
        // T for any Thread
        let request = NetworkAvailabilityRequest(isNetworkAvailable: isNetworkAvailable)
        _ = try? await sendRequest(request)
    }
    func hintApplicationResumedT() async throws -> DbStatus {
        // T for any Thread
        let request = ApplicationResumedRequest()
        return try await sendRequest(request)
    }
}
// MARK: -
/// A request to cancel a wallet transaction by token.
fileprivate struct CancelProgressToken: WalletBackendFormattedRequest {
    struct Response: Decodable {}
    var operation: String { "cancelProgressToken" }
    func args() -> Args { Args(operation: op, progressToken: token) }

    var op: String
    var token: String

    struct Args: Encodable {
        var operation: String
        var progressToken: String
    }
}
/// A request to retry a wallet transaction by token.
fileprivate struct RetryProgressTokenNow: WalletBackendFormattedRequest {
    struct Response: Decodable {}
    var operation: String { "retryProgressTokenNow" }
    func args() -> Args { Args(operation: op, progressToken: token) }

    var op: String
    var token: String

    struct Args: Encodable {
        var operation: String
        var progressToken: String
    }
}
// MARK: -
/// A request to get a wallet transaction by ID.
fileprivate struct GetTransactionById: WalletBackendFormattedRequest {
    typealias Response = TalerTransaction
    var operation: String { "getTransactionById" }
    func args() -> Args { Args(transactionId: txId, includeContractTerms: inclTerms) }

    var txId: String
    var inclTerms: Bool?

    struct Args: Encodable {
        var transactionId: String
        var includeContractTerms: Bool?
    }
}

fileprivate struct JSONTransactionById: WalletBackendFormattedRequest {
    typealias Response = String
    var operation: String { "getTransactionById" }
    func args() -> Args { Args(transactionId: transactionId, includeContractTerms: includeContractTerms) }

    var transactionId: String
    var includeContractTerms: Bool?

    struct Args: Encodable {
        var transactionId: String
        var includeContractTerms: Bool?
    }
}

extension WalletModel {
    nonisolated func cancelProgressToken(_ op: String, token: String)
      async throws {
        let request = CancelProgressToken(op: op, token: token)
        _ = try await sendRequest(request)
    }
    nonisolated func retryProgressTokenNow(_ op: String, token: String)
      async throws {
        let request = RetryProgressTokenNow(op: op, token: token)
        _ = try await sendRequest(request)
    }
    /// get the specified transaction from Wallet-Core. No networking involved
    nonisolated func getTransactionById(_ transactionId: String, includeContractTerms: Bool? = nil, viewHandles: Bool = false)
      async throws -> TalerTransaction {
        let request = GetTransactionById(txId: transactionId, inclTerms: includeContractTerms)
        return try await sendRequest(request, viewHandles: viewHandles)
    }
    nonisolated func jsonTransactionById(_ transactionId: String, includeContractTerms: Bool? = nil, viewHandles: Bool = false)
      async throws -> String {
        let request = JSONTransactionById(transactionId: transactionId, includeContractTerms: includeContractTerms)
        return try await sendRequest(request, viewHandles: viewHandles, asJSON: true)
    }
}
// MARK: -
/// The info returned from Wallet-core init
struct VersionInfo: Decodable {
    var implementationSemver: String?
    var implementationGitHash: String?
    var version: String
    var exchange: String
    var merchant: String
    var bank: String
}
// MARK: -
fileprivate struct Testing: Encodable {
    var denomselAllowLate: Bool
    var devModeActive: Bool
    var insecureTrustExchange: Bool
    var preventThrottling: Bool
    var skipDefaults: Bool
    var emitObservabilityEvents: Bool
    // more to come...

    init(devModeActive: Bool) {
        self.denomselAllowLate = false
        self.devModeActive = devModeActive
        self.insecureTrustExchange = false
        self.preventThrottling = false
        self.skipDefaults = false
        self.emitObservabilityEvents = devModeActive
    }
}

fileprivate struct Builtin: Encodable {
    var exchanges: [String]
    // more to come...
}

fileprivate struct Features: Encodable {
    var migrateNativeDb: Bool           // obsolete - use migrateDatabase() instead
    var useNativeDb: Bool
}

fileprivate struct Config: Encodable {
    var testing: Testing
    var builtin: Builtin
    var features: Features
}
// MARK: -
///  A request to re-configure Wallet-core
fileprivate struct ConfigRequest: WalletBackendFormattedRequest {
    var setTesting: Bool

    var operation: String { "setWalletRunConfig" }
    func args() -> Args {
        let testing = Testing(devModeActive: setTesting)
        let builtin = Builtin(exchanges: [])
        let features = Features(migrateNativeDb: false, useNativeDb: true)
        let config = Config(testing: testing, builtin: builtin, features: features)
        return Args(config: config)
    }

    struct Args: Encodable {
        var config: Config
    }
    struct Response: Decodable {
        var versionInfo: VersionInfo
    }
}

extension WalletModel {
    /// initalize Wallet-Core. Will do networking
    @discardableResult
    nonisolated func setConfig(setTesting: Bool) async throws -> VersionInfo {
        let request = ConfigRequest(setTesting: setTesting)
        let response = try await sendRequest(request)
        return response.versionInfo
    }
}
// MARK: -
struct InitResponse: Decodable {
    var versionInfo: VersionInfo
    var databaseBackend: String?
}
///  A request to initialize Wallet-core
fileprivate struct InitRequest: WalletBackendFormattedRequest {
    var persistentStoragePath: String
    var setTesting: Bool

    var operation: String { "init" }
    func args() -> Args {
        let testing = Testing(devModeActive: setTesting)
        let builtin = Builtin(exchanges: [])
        let features = Features(migrateNativeDb: false, useNativeDb: true)
        let config = Config(testing: testing, builtin: builtin, features: features)
        return Args(persistentStoragePath: persistentStoragePath,
#if DEBUG
        let logLevel = "info"       // trace, info, message, warn, error, none
#else
        let logLevel = "message"    // less logging for AppStore builds
#endif
//                       cryptoWorkerType: "sync",  qtart can ONLY use sync, that's the default anyway
                                 logLevel: logLevel,
                                   config: config,
                         useNativeLogging: true)
    }

    struct Args: Encodable {
        var persistentStoragePath: String
//        var cryptoWorkerType: String
        var logLevel: String
        var config: Config
        var useNativeLogging: Bool
    }
    typealias Response = InitResponse
}

extension WalletModel {
    /// initalize Wallet-Core. Might do networking
    nonisolated func initWalletCore(setTesting: Bool, viewHandles: Bool = false) async throws -> InitResponse {
        let dbPath = try dbPath()
//        logger.debug("dbPath: \(dbPath)")
        let request = InitRequest(persistentStoragePath: dbPath, setTesting: setTesting)
        let response = try await sendRequest(request, viewHandles: viewHandles)    // no Delay
        return response
    }

    private func dbUrl(_ folder: URL) -> URL {
        let DATABASE = "talerwalletdb-v30"
        let dbUrl = folder.appendingPathComponent(DATABASE, isDirectory: false)
                          .appendingPathExtension("sqlite3")
        return dbUrl
    }

    private func checkAppSupport(_ url: URL) {
        let fileManager = FileManager.default
        var resultStorage: ObjCBool = false

        if !fileManager.fileExists(atPath: url.path, isDirectory: &resultStorage) {
            do {
                try fileManager.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
                logger.debug("created \(url.path)")
            } catch {
                logger.error("creation failed \(error.localizedDescription)")
            }
        } else {
//            logger.debug("\(url.path) exists")
        }
    }

    private func migrate(from source: URL, to target: URL) {
        let fileManager = FileManager.default
        let sourceUrl = dbUrl(source)
        let sourcePath = sourceUrl.path
        let targetUrl = dbUrl(target)
        let targetPath = targetUrl.path

        checkAppSupport(target)
        if fileManager.fileExists(atPath: sourcePath) {
            do {
                try fileManager.moveItem(at: sourceUrl, to: targetUrl)
                logger.debug("migrate: moved to \(target.path)")
            } catch {
                logger.error("migrate: move failed \(error.localizedDescription)")
            }
//        } else {
//            logger.debug("migrate: nothing to do, no db at \(sourcePath)")
        }

//        if fileManager.fileExists(atPath: targetPath) {
//            logger.debug("found db at \(targetPath)")
//        } else {
//            logger.debug("migrate: nothing to do, no db at \(targetPath)")
//        }
    }

    private func dbPath() throws -> String {
        if let docDirUrl = URL.docDirUrl {
            if let appSupport = URL.appSuppUrl {
#if DEBUG || GNU_TALER
                migrate(from: appSupport, to: docDirUrl)
                return docDirUrl.path(withSlash: true)
#else // TALER_WALLET or TALER_NIGHTLY
                migrate(from: docDirUrl, to: appSupport)
                return appSupport.path(withSlash: true)
#endif
            } else { // should never happen
                logger.error("dbPath: No applicationSupportDirectory")
            }
        } else { // should never happen
            logger.error("dbPath: No documentDirectory")
        }
        throw WalletBackendError.initializationError
    }

    private func cachePath() throws -> String {
        let fileManager = FileManager.default
        if let cachesURL = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first {
            let cacheURL = cachesURL.appendingPathComponent("cache.json")
            let cachePath = cacheURL.path
            logger.debug("cachePath: \(cachePath)")

            if !fileManager.fileExists(atPath: cachePath) {
                let contents = Data()       /// Initialize an empty `Data`.
                fileManager.createFile(atPath: cachePath, contents: contents)
                print("❗️ File \(cachePath) created")
            } else {
                print("❗️ File \(cachePath) already exists")
            }

            return cachePath
        } else {    // should never happen
            logger.error("cachePath: No cachesDirectory")
            throw WalletBackendError.initializationError
        }
    }
}
// MARK: -
///  A request to migrate the Wallet-core DB from indexed to native sqlite.
fileprivate struct MigrateRequest: WalletBackendFormattedRequest {
    var operation: String { "migrateDatabase" }
    func args() -> Args { Args(progressToken: operation) }

    struct Args: Encodable {
        var progressToken: String
    }
    typealias Response = MigrationResult                      // plus notifications
}

struct MigrationResult: Decodable {
    var migrated: Bool?
    var databaseBackend: String?
}

extension WalletModel {
    /// reset Wallet-Core
    nonisolated func migrateDatabase(viewHandles: Bool = false)
      async throws -> MigrationResult {
        let request = MigrateRequest()
        let controller = Controller.shared
        controller.progressOperation = request.operation
        controller.progressToken = request.operation
        let result = try await sendRequest(request, viewHandles: viewHandles)
        return result
    }
}
// MARK: -
///  A request to reset Wallet-core to a virgin DB. WILL DESTROY ALL COINS
fileprivate struct ResetRequest: WalletBackendFormattedRequest {
    var operation: String { "clearDb" }
    func args() -> Args { Args() }

    struct Args: Encodable {}                           // no arguments needed
    struct Response: Decodable {}
}

extension WalletModel {
    /// reset Wallet-Core
    nonisolated func resetWalletCore(viewHandles: Bool = false) async throws {
        let request = ResetRequest()
        _ = try await sendRequest(request, viewHandles: viewHandles)
    }
}
// MARK: -
fileprivate struct ExportDbToFile: WalletBackendFormattedRequest {
    var operation: String { "exportDbToFile" }
    func args() -> Args { Args(directory: directory, stem: stem, forceFormat: asJSON ? "json" : nil) }

    var directory: String
    var stem: String
    var asJSON: Bool
    struct Args: Encodable {
        var directory: String
        var stem: String
        var forceFormat: String?
    }
    struct Response: Decodable, Sendable {              // path of the copied DB
        var path: String
    }
}

fileprivate struct ImportDbFromFile: WalletBackendFormattedRequest {
    var operation: String { "importDbFromFile" }
    func args() -> Args { Args(path: path ) }

    var path: String
    struct Args: Encodable {
        var path: String
    }
    struct Response: Decodable {}
}

fileprivate struct GetDiagnostics: WalletBackendFormattedRequest {
    var operation: String { "getDiagnostics" }
    func args() -> Args { Args() }
    struct Args: Encodable {}                           // no arguments needed
    typealias Response = String
}

fileprivate struct GetPerformanceStats: WalletBackendFormattedRequest {
    var operation: String { "testingGetPerformanceStats" }
    func args() -> Args { Args() }
    struct Args: Encodable {}                           // no arguments needed
    typealias Response = String
}

extension WalletModel {
    /// export, import DB, get diagnostics
    nonisolated func exportDbToFile(stem: String, asJSON: Bool = true, viewHandles: Bool = false)
      async throws -> String? {
        if let docDirUrl = URL.docDirUrl {
            let dbPath = docDirUrl.path(withSlash: false)
            let request = ExportDbToFile(directory: dbPath, stem: stem, asJSON: asJSON)
    print(dbPath, stem)
            let response = try await sendRequest(request, viewHandles: viewHandles)
            return response.path
        } else {
            return nil
        }
    }
    nonisolated func importDbFromFile(path: String, viewHandles: Bool = false)
      async throws {
        let request = ImportDbFromFile(path: path)
        _ = try await sendRequest(request, viewHandles: viewHandles)
    }
    nonisolated func getDiagnostics(viewHandles: Bool = false)
      async throws -> String {
        let request = GetDiagnostics()
        let response = try await sendRequest(request, viewHandles: viewHandles, asJSON: true)
        return response
    }
    nonisolated func getPerformanceStats(viewHandles: Bool = false)
    async throws -> String {
        let request = GetPerformanceStats()
        let response = try await sendRequest(request, viewHandles: viewHandles, asJSON: true)
        return response
    }
}
// MARK: -
fileprivate struct DevExperimentRequest: WalletBackendFormattedRequest {
    var operation: String { "applyDevExperiment" }
    func args() -> Args { Args(devExperimentUri: talerUri) }

    var talerUri: String

    struct Args: Encodable {
        var devExperimentUri: String
    }
    struct Response: Decodable {}
}

extension WalletModel {
    /// tell wallet-core to mock new transactions
    nonisolated func devExperimentT(_ talerUri: String, viewHandles: Bool = false) async throws {
        // T for any Thread
        let request = DevExperimentRequest(talerUri: talerUri)
        _ = try await sendRequest(request, viewHandles: viewHandles)
    }
}
