/*
 * This file is part of GNU Taler, ©2022-25 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * Controller
 *
 * @author Marc Stibane
 */
import Foundation
import AVFoundation
import LocalAuthentication
import SwiftUI
import SymLog
import os.log
import CoreHaptics
import Network
import taler_swift

enum BackendState: Equatable {
    case none
    case instantiated
    case initing
    case ready
    case error(EquatableError)

    static func == (lhs: BackendState, rhs: BackendState) -> Bool {
        switch (lhs, rhs) {
            case (.none, .none):
                return true
            case (.instantiated, .instantiated):
                return true
            case (.initing, .initing):
                return true
            case (.ready, .ready):
                return true
            case (.error(let lhsError), .error(let rhsError)):
                return lhsError == rhsError
            default:
                return false
        }
    }
}

enum UrlCommand: String, Codable {
    case unknown
    case withdraw
    case withdrawExchange
    case addExchange
    case pay
    case payPull
    case payPush
    case payTemplate
    case refund
#if GNU_TALER
    case devExperiment
#endif

    var isOutgoing: Bool {
        switch self {
            case .pay, .payPull, .payTemplate:
                true
            default:
                false
        }
    }

    var localizedCommand: String {
        switch self {
            case .unknown:          String(EMPTYSTRING)
            case .withdraw,
                 .withdrawExchange: String(localized: "Withdraw",
                                             comment: "UrlCommand")
            case .addExchange:      String(localized: "Add payment service",
                                             comment: "UrlCommand")
            case .pay:              String(localized: "Pay merchant",
                                             comment: "UrlCommand")
            case .payPull:          String(localized: "Pay others",
                                             comment: "UrlCommand")
            case .payPush:          String(localized: "Receive",
                                             comment: "UrlCommand")
            case .payTemplate:      String(localized: "Pay ...",
                                             comment: "UrlCommand")
            case .refund:           String(localized: "Refund",
                                             comment: "UrlCommand")
#if GNU_TALER
            case .devExperiment:    String("DevExperiment")
#endif
        }
    }
    var transactionType: TransactionType {
        switch self {
            case .unknown:          .dummy
            case .withdraw:         .withdrawal
            case .withdrawExchange: .withdrawal
            case .addExchange:      .withdrawal
            case .pay:              .payment
            case .payPull:          .scanPullDebit
            case .payPush:          .scanPushCredit
            case .payTemplate:      .payment
            case .refund:           .refund
#if GNU_TALER
            case .devExperiment:    .dummy
#endif
        }
    }
}

struct ScannedURL: Identifiable {
    var id: String {
        url.absoluteString
    }
    var url: URL
    var command: UrlCommand
    var amount: Amount?
    var baseURL: String?
    var scope: ScopeInfo?
    var time: Date
}

// MARK: -
class Controller: ObservableObject {
    public static let shared = Controller()
    private let symLog = SymLogC()

    @Published var haveProdBalance: Bool = false
    @Published var balances: [Balance] = []
    @Published var discounts: [TalerToken] = []
    @Published var subscriptions: [TalerToken] = []
    @Published var defaultExchanges: [DefaultExchange] = []
    @Published var scannedURLs: [ScannedURL] = []

    @Published var backendState: BackendState = .none       // only used for launch animation
    @Published var currencyTicker: Int = 0                  // updates whenever a new currency is added
    @Published var userAction: Int = 0                      // make Action button jump

    @Published var isConnected: Bool = true
    @Published var oimModeActive: Bool = false
    @Published var oimSheetActive: Bool = false
    @Published var diagnosticModeEnabled: Bool = false
    @Published var talerURI: URL? = nil
    @AppStorage("useHaptics") var useHaptics: Bool = true   // extension mustn't define this, so it must be here
    @AppStorage("playSounds") var playSounds: Bool = false
    @AppStorage("talerFontIndex") var talerFontIndex: Int = 0         // extension mustn't define this, so it must be here
#if DEBUG
    @AppStorage("developerMode") var developerMode: Bool = true
#else
    @AppStorage("developerMode") var developerMode: Bool = false
#endif
    @AppStorage("deviceTokenAPNs") var deviceTokenAPNs: String?
    let hapticCapability = CHHapticEngine.capabilitiesForHardware()
    let logger = Logger(subsystem: "net.taler.gnu", category: "Controller")
    let player = AVQueuePlayer()
    let semaphore = AsyncSemaphore(value: 1)
    private var currencyInfos: [ScopeInfo : CurrencyInfo]
    var exchanges: [Exchange]
    var messageForSheet: String? = nil

    private let monitor = NWPathMonitor()

    private var diagnosticModeObservation: NSKeyValueObservation?
#if OIM
    private var lastOIMmode: UIDeviceOrientation = .portrait
    func setOIMmode(for newOrientation: UIDeviceOrientation, _ sheetActive: Bool) {
        if lastOIMmode == .landscapeRight {
            if newOrientation == .faceUp {
                return
            }
        }
        let isLandscapeRight = newOrientation == .landscapeRight
        lastOIMmode = newOrientation
        oimSheetActive = sheetActive && isLandscapeRight
         oimModeActive = sheetActive ? false
                                     : isLandscapeRight
//        print("😱 oimSheetActive = \(oimSheetActive)")
    }
#endif

    func biometryType() -> LABiometryType? {
        let context = LAContext()
        var error: NSError? = nil
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            return context.biometryType
        }
        // else device has no enabled biometrics
#if DEBUG
        if let error {
            print(error)
        }
#endif
        return nil
    }

    @discardableResult
    func saveURL(_ passedURL: URL, urlCommand: UrlCommand) -> Bool {
        let savedURL = scannedURLs.first { scannedURL in
            scannedURL.url == passedURL
        }
        if savedURL == nil {        // doesn't exist yet
            var save = false
            switch urlCommand {
                case .addExchange:      save = true
                case .withdraw:         save = true
                case .withdrawExchange: save = true
                case .pay:              save = true
                case .payPull:          save = true
                case .payPush:          save = true
                case .payTemplate:      save = true

                default:    break
            }
            if save {
                let scannedURL = ScannedURL(url: passedURL, command: urlCommand, time: .now)
                if scannedURLs.count > 5 {
                    self.logger.trace("removing: \(self.scannedURLs.first?.command.rawValue ?? EMPTYSTRING)")
                    scannedURLs.remove(at: 0)
                }
                scannedURLs.append(scannedURL)
                self.logger.trace("saveURL: \(urlCommand.rawValue)")
                return true
            }
        }
        return false
    }

    func removeURL(_ passedURL: URL) {
        scannedURLs.removeAll { scannedURL in
            scannedURL.url == passedURL
        }
    }
    func removeURLs(after: TimeInterval) {
        let now = Date.now
        scannedURLs.removeAll { scannedURL in
            let timeInterval = now.timeIntervalSince(scannedURL.time)
            self.logger.trace("timeInterval: \(timeInterval)")
            return timeInterval > after
        }
    }
    func updateAmount(_ amount: Amount, forSaved url: URL) {
        if let index = scannedURLs.firstIndex(where: { $0.url == url }) {
            var savedURL = scannedURLs[index]
            savedURL.amount = amount
            scannedURLs[index] = savedURL
        }
    }
    func updateBase(_ baseURL: String, forSaved url: URL) {
        if let index = scannedURLs.firstIndex(where: { $0.url == url }) {
            var savedURL = scannedURLs[index]
            savedURL.baseURL = baseURL
            scannedURLs[index] = savedURL
        }
    }

    func startObserving() {
        let defaults = UserDefaults.standard
        self.diagnosticModeObservation = defaults.observe(\.diagnosticModeEnabled, options: [.new, .old,.prior,.initial]) {  [weak self](_, _) in
            self?.diagnosticModeEnabled = UserDefaults.standard.diagnosticModeEnabled
        }
    }

    func checkInternetConnection() {
        monitor.pathUpdateHandler = { path in
            let status = switch path.status {
                case .satisfied: "active"
                case .unsatisfied: "inactive"
                default: "unknown"
            }
            self.logger.log("Internet connection is \(status)")
#if DEBUG   // TODO: checkInternetConnection hintNetworkAvailabilityT
            DispatchQueue.main.async {
                if path.status == .unsatisfied {
                    self.isConnected = false
                    Task.detached {
                        await WalletModel.shared.hintNetworkAvailabilityT(false)
                    }
                } else {
                    self.stopCheckingConnection()
                    self.isConnected = true
                    Task.detached {
                        await WalletModel.shared.hintNetworkAvailabilityT(true)
                    }
                }
            }
#endif
        }
        self.logger.log("Start monitoring internet connection")
        let queue = DispatchQueue(label: "InternetMonitor")
        monitor.start(queue: queue)
    }
    func stopCheckingConnection() {
        self.logger.log("Stop monitoring internet connection")
        monitor.cancel()
    }

    func printFonts() {
        for family in UIFont.familyNames {
            print(family)
            for names in UIFont.fontNames(forFamilyName: family) {
                print("== \(names)")
            }
        }
    }

    init() {
        backendState = .instantiated
        currencyTicker = 0
        currencyInfos = [:]
        exchanges = []
        balances = []
        discounts = []
        subscriptions = []
        defaultExchanges = []
//        printFonts()
//        checkInternetConnection()
        startObserving()
    }
// MARK: -
    @MainActor
    @discardableResult
    func loadBalances(_ stack: CallStack,_ model: WalletModel) async -> Int? {
        if let response = try? await model.getBalances(stack.push()) {
            let reloaded = response.balances
            if reloaded != balances {
                for balance in reloaded {
                    let scope = balance.scopeInfo
                    checkInfo(for: scope, model: model)
                }
                self.logger.log("••Got new balances, will redraw")
                balances = reloaded         // redraw
            } else {
                self.logger.log("••Same balances, no redraw")
            }
            haveProdBalance = response.haveProdBalance
            return reloaded.count
        }
        return nil
    }

    func balance(for scope: ScopeInfo) -> Balance? {
        for balance in balances {
            if balance.scopeInfo == scope {
                return balance
            }
        }
        return nil
    }
    // MARK: -
    @MainActor
    @discardableResult
    func loadDiscounts(_ stack: CallStack,_ model: WalletModel) async -> Int? {
        if let response = try? await model.listDiscounts(stack.push()) {
            let reloaded = response.discounts
            if reloaded != discounts {
                self.logger.log("••Got new discounts, will redraw")
                discounts = reloaded         // redraw
            } else {
                self.logger.log("••Same discounts, no redraw")
            }
            return reloaded.count
        }
        return nil
    }
    // MARK: -
    @MainActor
    @discardableResult
    func loadSubscriptions(_ stack: CallStack,_ model: WalletModel) async -> Int? {
        if let response = try? await model.listSubscriptions(stack.push()) {
            let reloaded = response.subscriptions
            if reloaded != subscriptions {
                self.logger.log("••Got new passes, will redraw")
                subscriptions = reloaded         // redraw
            } else {
                self.logger.log("••Same passes, no redraw")
            }
            return reloaded.count
        }
        return nil
    }
// MARK: -
    func exchange(for baseUrl: String) -> Exchange? {
        for exchange in exchanges {
            if exchange.exchangeBaseUrl == baseUrl {
                return exchange
            }
        }
        return nil
    }

    func info(for scope: ScopeInfo) -> CurrencyInfo? {
//        return CurrencyInfo.euro()              // Fake EUR instead of the real Currency
//        return CurrencyInfo.francs()            // Fake CHF instead of the real Currency
        return currencyInfos[scope]
    }
    func info(for scope: ScopeInfo, _ ticker: Int) -> CurrencyInfo {
        if ticker != currencyTicker {
            print("  ❗️Yikes - race condition while getting info for \(scope.currency)")
        }
        return info(for: scope) ?? CurrencyInfo.zero(scope.currency)
    }

    func info2(for currency: String) -> CurrencyInfo? {
//        return CurrencyInfo.euro()              // Fake EUR instead of the real Currency
//        return CurrencyInfo.francs()            // Fake CHF instead of the real Currency
        for (scope, info) in currencyInfos {
            if scope.currency == currency {
                return info
            }
        }
//        logger.log("  ❗️ no info for \(currency)")
        return nil
    }
    func info2(for currency: String, _ ticker: Int) -> CurrencyInfo {
        if ticker != currencyTicker {
            print("  ❗️Yikes - race condition while getting info for \(currency)")
        }
        return info2(for: currency) ?? CurrencyInfo.zero(currency)
    }

    func hasInfo(for currency: String) -> Bool {
        for (scope, info) in currencyInfos {
            if scope.currency == currency {
                return true
            }
        }
//        logger.log("  ❗️ no info for \(currency)")
        return false
    }

    @MainActor
    func exchange(for baseUrl: String?, model: WalletModel) async -> Exchange? {
        if let baseUrl {
            if let exchange1 = exchange(for: baseUrl) {
                return exchange1
            }
            if let exchange2 = try? await model.getExchangeByUrl(url: baseUrl) {
//                logger.log("  ❗️ will add \(baseUrl)")
                exchanges.append(exchange2)
                return exchange2
            }
        }
        return nil
    }

    @MainActor
    func updateInfo(_ scope: ScopeInfo, model: WalletModel) async {
        if let info = try? await model.getCurrencyInfo(scope: scope) {
            await setInfo(info, for: scope)
//            logger.log("  ❗️info set for \(scope.currency)")
        }
    }

    func checkCurrencyInfo(for baseUrl: String, model: WalletModel) async -> Exchange? {
        if let exchange = await exchange(for: baseUrl, model: model) {
            let scope = exchange.scopeInfo
            if currencyInfos[scope] == nil {
                logger.log("  ❗️got no info for \(baseUrl.trimURL) \(scope.currency) -> will update")
                await updateInfo(scope, model: model)
            }
            return exchange
        } else {
            // Yikes❗️  TODO: error?
        }
        return nil
    }

    /// called whenever a new currency pops up - will first load the Exchange and then currencyInfos
    func checkInfo(for scope: ScopeInfo, model: WalletModel) {
        if currencyInfos[scope] == nil {
            Task {
                let exchange = await exchange(for: scope.url, model: model)
                if let scope2 = exchange?.scopeInfo {
                    let exchangeName = scope2.url ?? "UNKNOWN"
                    logger.log("  ❗️got no info for \(scope.currency) -> will update \(exchangeName.trimURL)")
                    await updateInfo(scope2, model: model)
                } else {
                    logger.error("  ❗️got no info for \(scope.currency), and couldn't load the exchange info❗️")
                }
            }
        }
    }

    @MainActor
    func getInfo(from baseUrl: String, model: WalletModel) async throws -> CurrencyInfo? {
        let exchange = try await model.getExchangeByUrl(url: baseUrl)
        let scope = exchange.scopeInfo
        if let info = info(for: scope) {
            return info
        }
        let info = try await model.getCurrencyInfo(scope: scope)
        await setInfo(info, for: scope)
        return info
    }

    @MainActor
    func setInfo(_ newInfo: CurrencyInfo, for scope: ScopeInfo) async {
        await semaphore.wait()
        defer { semaphore.signal() }

        currencyInfos[scope] = newInfo
        currencyTicker += 1         // triggers published view update
    }
// MARK: -
    @MainActor
    func initWalletCore(_ model: WalletModel, stage: Bool, setTesting: Bool, delay: TimeInterval)
      async throws {
        if backendState == .instantiated {
            backendState = .initing
            do {
                let versionInfo = try await model.initWalletCore(setTesting: setTesting)
                WalletCore.shared.versionInfo = versionInfo
#if !TALER_WALLET
                if developerMode {
                    try await model.setConfig(setTesting: true)
//                    try? await model.devExperimentT(talerUri: "taler://dev-experiment/default-exchange-demo?val=1")
                    try? await model.devExperimentT(talerUri: "taler://dev-experiment/demo-shortcuts?val=KUDOS:4,KUDOS:8,KUDOS:16,KUDOS:32")
//                    try? await model.devExperimentT(talerUri: "taler://dev-experiment/flag-confirm-pay-no-wait?v=10")
                    try await model.setConfig(setTesting: false)
                }
#endif
                defaultExchanges = await model.getDefaultExchanges(stage: stage)
                if stage, let talerOps = defaultExchanges.first {
                    let stageExc = DefaultExchange(talerUri: "taler://withdraw-exchange/exchange.stage.taler-ops.ch",
                                                   currency: talerOps.currency,
                                               currencySpec: talerOps.currencySpec
                    )
                    defaultExchanges.insert(stageExc, at: 0)
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    self.backendState = .ready              // dismiss the launch animation
                }
            } catch {       // rethrows
                self.logger.error("\(error.localizedDescription)")
                backendState = .error(error as! EquatableError)                       // ❗️Yikes app cannot continue
                throw error
            }
        } else {
            self.logger.fault("Yikes❗️ wallet-core already initialized")
        }
    }
}

// MARK: -
extension Controller {
    func urlCommand(_ url: URL, stack: CallStack) -> UrlCommand {
        guard let scheme = url.scheme else {return UrlCommand.unknown}
#if DEBUG
        symLog.log(url)
#else
        let host = url.host ?? "  <- no command"
        self.logger.trace("urlCommand(\(scheme)\(host)")
#endif
        var uncrypted = false
        var urlCommand = UrlCommand.unknown
        switch scheme.lowercased() {
            case "taler+http":
                uncrypted = true
                fallthrough
            case "taler", "ext+taler", "web+taler":
                urlCommand = talerScheme(url, uncrypted)
//            case "payto":
//                messageForSheet = url.absoluteString
//                return paytoScheme(url)
            default:
                self.logger.error("unknown scheme: <\(scheme)>")       // should never happen
        }
        saveURL(url, urlCommand: urlCommand)
        return urlCommand
    }
}
// MARK: -
extension Controller {
//    func paytoScheme(_ url:URL) -> UrlCommand {
//        let logItem = "scheme payto:// is not yet implemented"
//        // TODO: write logItem to somewhere in Debug section of SettingsView
//        symLog.log(logItem)        // TODO: symLog.error(logItem)
//        return UrlCommand.unknown
//    }
    
    func talerScheme(_ url:URL,_ uncrypted: Bool = false) -> UrlCommand {
      if let command = url.host {
        if uncrypted {
            self.logger.trace("uncrypted http: taler://\(command)")
            // TODO: uncrypted taler+http
        }
        switch command.lowercased() {
            case "withdraw":            return .withdraw
            case "withdraw-exchange":   return .withdrawExchange
            case "add-exchange":        return .addExchange
            case "pay":                 return .pay
            case "pay-pull":            return .payPull
            case "pay-push":            return .payPush
            case "pay-template":        return .payTemplate
            case "refund":              return .refund
#if GNU_TALER
            case "dev-experiment":      return .devExperiment
#endif
            default:
                self.logger.error("❗️unknown command taler://\(command)")
        }
        messageForSheet = command.lowercased()
      } else {
          self.logger.error("❗️No taler command")
      }
      return .unknown
    }
}
