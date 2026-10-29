/*
 * This file is part of GNU Taler, ©2022-26 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import Foundation
import AnyCodable
import taler_swift
import SymLog

let TALDIR = "https://taldir.gnunet.org"
let MAILBOX = "https://mailbox.gnunet.org"

// MARK: - Contacts
struct ContactEntry: Codable, Hashable {
    var alias: String
    var aliasType: String               // TaldirAliasType.name
    var mailboxBaseUrl: String          // MAILBOX
    var mailboxAddress: String          // MailboxConfiguration.hAddress
    var source: String                  // source of this contact, may be a URI
    var petname: String                 // local nickname
    var expiration: Timestamp?
    var isSelf: Bool?                   // is this my own alias? TODO: show user if mailboxAddress is not mine
}
extension ContactEntry: Identifiable {
    var id: String { alias }
}
extension ContactEntry {
    init(alias: String,                 // convenience init
         aliasType: String,
         mailboxAddress: String,
         source: String = TALDIR,
         petname: String = EMPTYSTRING,
         expiration: Timestamp? = nil,
         isSelf: Bool = false
    ) {
        self.alias = alias
        self.aliasType = aliasType
        self.mailboxBaseUrl = MAILBOX
        self.mailboxAddress = mailboxAddress
        self.source = source
        self.petname = petname
        self.expiration = expiration
        self.isSelf = isSelf
    }
}
fileprivate struct ContactListResponse: Codable, Hashable {
    var contacts: [ContactEntry]
}
/// A request to get a list of contacts for TalDir.
fileprivate struct GetContacts: WalletBackendFormattedRequest {
    var operation: String { "getContacts" }
    struct Args: Encodable { }
    func args() -> Args { Args() }
    typealias Response = ContactListResponse
}
/// A request to add a contact
fileprivate struct AddContact: WalletBackendFormattedRequest {
    var contact: ContactEntry
    var operation: String { "addContact" }
    struct Args: Encodable {
        var contact: ContactEntry
    }
    func args() -> Args { Args(contact: contact) }
    struct Response: Decodable {}
}
// MARK: - Contact calls
extension WalletModel {
    nonisolated func getContacts(viewHandles: Bool = false)
    async throws -> [ContactEntry] {   // M for MainActor
        let request = GetContacts()
//        let controller = Controller.shared
//        controller.progressOperation = request.operation
//        controller.progressToken = request.operation
        let (response, _) = try await sendRequest(request, viewHandles: viewHandles)
        return response.contacts
    }
    nonisolated func addContact(_ contact: ContactEntry, viewHandles: Bool = false)
      async throws {   // M for MainActor
        let request = AddContact(contact: contact)
//        let controller = Controller.shared
//        controller.progressOperation = request.operation
//        controller.progressToken = request.operation
        let _ = try await sendRequest(request, viewHandles: viewHandles)
    }
}
// MARK: - Alias Types
struct TaldirAliasType: Codable, Hashable {
    var name: String                    // use this for API calls
    var display: String
    var challengeFee: Amount?

    var localized: String {             // show this in UI (localize Phone & Email)
        if name.lowercased() == "phone" {
            return String(localized: "Phone", comment: "Alias type")
        }
        if name.lowercased() == "email" {
            return String(localized: "E-mail", comment: "Alias type")
        }
        return display
    }

    enum CodingKeys: String, CodingKey {
        case name, display
        case challengeFee = "challenge_fee"
    }
}
extension TaldirAliasType: Identifiable {
    var id: String { name }
}
fileprivate struct TaldirAliasTypesResponse: Codable, Hashable {
//    var version: String
//    var name: String
    var supportedAliases: [TaldirAliasType]
//    var monthlyFee: Amount
}

/// A request to get a list of supported alias types for TalDir.
fileprivate struct GetSupportedAliasTypes: WalletBackendFormattedRequest {
    var operation: String { "getSupportedAliasTypes" }
    struct Args: Encodable {
        let taldirBaseUrl: String
        let progressToken: String?
    }
    func args() -> Args { Args(taldirBaseUrl: TALDIR,
                               progressToken: operation) }   // + baseUrl
    typealias Response = TaldirAliasTypesResponse
}
// MARK: - Alias Lookup
struct TaldirLookup: Codable, Hashable {
    var alias: String
    var aliasType: String               // TaldirAliasType.name
//    var taldirBaseUrl: String           // TALDIR
}
struct TaldirLookupResponse: Codable {
    var targetUri: String?              // only if successful
    var validFor: Duration?             // only if known
}

/// A request to lookup an alias using TalDir.
fileprivate struct LookupAlias: WalletBackendFormattedRequest {
    let lookup: TaldirLookup
    var operation: String { "lookupAlias" }
    struct Args: Encodable {
        let alias: String
        let aliasType: String
        let taldirBaseUrl: String
    }
    func args() -> Args { Args(alias: lookup.alias,
                           aliasType: lookup.aliasType,
                       taldirBaseUrl: TALDIR) }
    typealias Response = TaldirLookupResponse
}
// MARK: - Alias Registration
struct TaldirRegistration: Codable, Hashable {
    var alias: String
    var aliasType: String               // TaldirAliasType.name
    var taldirBaseUrl: String           // TALDIR
    var mailboxBaseUrl: String?         // MailboxConfiguration.mailboxBaseUrl - use nil to de-register
    var mailboxAddress: String?         // MailboxConfiguration.hAddress - nil to de-register
    var duration: Duration?             // only for registerAlias (or renew). Set to 0 to update other data
    var challenge: String?              // only for completeRegisterAlias

    init(alias: String, aliasType: String, mailboxAddress: String? = nil,
         duration: Duration? = nil, challenge: String? = nil
    ) {
        self.alias = alias
        self.aliasType = aliasType
        self.taldirBaseUrl = TALDIR
        self.mailboxBaseUrl = mailboxAddress != nil ? MAILBOX : nil
        self.mailboxAddress = mailboxAddress
        self.duration = duration
        self.challenge = challenge
    }
}
fileprivate struct TaldirRegistrationResponse: Codable {
    var validFor: Duration?             // only if called with duration of 0

    enum CodingKeys: String, CodingKey {
        case validFor = "valid_for"
    }
}
/// A request to register an alias for TalDir.
fileprivate struct RegisterAlias: WalletBackendFormattedRequest {
    let register: TaldirRegistration
    var operation: String { "registerAlias" }
    struct Args: Encodable {
        let alias: String
        let aliasType: String
        let taldirBaseUrl: String           // TALDIR
        let mailboxBaseUrl: String?         // MAILBOX
        let mailboxAddress: String?
        let duration: Duration
    }
    func args() -> Args { Args(alias: register.alias,
                           aliasType: register.aliasType,
                       taldirBaseUrl: TALDIR,
                      mailboxBaseUrl: register.mailboxBaseUrl,
                      mailboxAddress: register.mailboxAddress,
                            duration: register.duration!) }
    typealias Response = TaldirRegistrationResponse
}

/// A request to confirm the registration with the alias-challenge
fileprivate struct CompleteRegisterAlias: WalletBackendFormattedRequest {
    let register: TaldirRegistration
    var operation: String { "completeRegisterAlias" }
    struct Args: Encodable {
        let alias: String
        let aliasType: String
        let taldirBaseUrl: String           // TALDIR
        let mailboxBaseUrl: String?         // MAILBOX
        let mailboxAddress: String?
        let challenge: String
    }
    func args() -> Args { Args(alias: register.alias,
                           aliasType: register.aliasType,
                       taldirBaseUrl: TALDIR,
                      mailboxBaseUrl: register.mailboxBaseUrl,
                      mailboxAddress: register.mailboxAddress,
                           challenge: register.challenge!) }
    struct Response: Decodable {}
}
// MARK: - Alias calls
extension WalletModel {
    nonisolated func getSupportedAliasTypes(viewHandles: Bool = false)
      async throws -> [TaldirAliasType] {   // M for MainActor
        let request = GetSupportedAliasTypes()
        let controller = Controller.shared
        controller.progressOperation = request.operation
        controller.progressToken = request.operation
        let (response, _) = try await sendRequest(request, viewHandles: viewHandles)
          return response.supportedAliases.sorted(by: {
              if $0.name == "email" { return true }     // first email
              if $1.name == "email" { return false }
              if $0.name == "phone" { return true }     // then phone
              if $1.name == "phone" { return false }
              return $0.name < $1.name                  // the rest alphabetically
          })
    }

    nonisolated func lookupAlias(_ lookup: TaldirLookup, viewHandles: Bool = false)
      async throws -> TaldirLookupResponse {   // M for MainActor
        let request = LookupAlias(lookup: lookup)
        let (response, _) = try await sendRequest(request, viewHandles: viewHandles)
        return response
    }

    nonisolated func registerAlias(_ register: TaldirRegistration, viewHandles: Bool = false)
      async throws -> Duration? {   // M for MainActor
        if register.duration != nil {
            let request = RegisterAlias(register: register)
            let (response, _) = try await sendRequest(request, viewHandles: viewHandles)
            return response.validFor
        }
        throw WalletBackendError.wrongParameters    // no duration
    }

    nonisolated func completeRegisterAlias(_ register: TaldirRegistration, viewHandles: Bool = false)
      async throws {   // M for MainActor
        if register.challenge != nil {
            let request = CompleteRegisterAlias(register: register)
            let (response, _) = try await sendRequest(request, viewHandles: viewHandles)
            print("completeRegisterAlias: \(response)")
            return
        }
        throw WalletBackendError.wrongParameters    // no challenge
    }
}
// MARK: - Mailbox
struct MailboxConfiguration: Codable, Hashable {
    var mailboxBaseUrl: String          // MAILBOX
    var privateKey: String              // Private EdDSA signing key of the mailbox
    var privateEncryptionKey: String    // Private HPKE encryption key of the mailbox
    var expiration: Timestamp           // Expiration of the current mailbox registration
    var hAddress: String                // Mailbox address (hash of the public signing key)
    var payUri: URL?                    // only if  mailbox service requires payment to complete the registration
}
fileprivate struct GetMailboxResponse: Codable, Hashable {
    var mailboxConfiguration: MailboxConfiguration?
}

/// A request to get the mailbox configuration - if it exists. Otherwise initialize...
/// no network traffic => no progressToken
fileprivate struct GetMailbox: WalletBackendFormattedRequest {
    let mailboxBaseUrl: String
    var operation: String { "getMailbox" }
    struct Args: Encodable {
        let mailboxBaseUrl: String
    }
    func args() -> Args { Args(mailboxBaseUrl: mailboxBaseUrl) }
    typealias Response = GetMailboxResponse
}
/// A request to initialize a mailbox for TalDir.
fileprivate struct InitializeMailbox: WalletBackendFormattedRequest {
    let mailboxBaseUrl: String
    var operation: String { "initializeMailbox" }
    struct Args: Encodable {
        let mailboxBaseUrl: String
        let progressToken: String?
    }
    func args() -> Args { Args(mailboxBaseUrl: mailboxBaseUrl,
                                progressToken: operation + mailboxBaseUrl) }
    typealias Response = GetMailboxResponse
}
// MARK: - Messages
struct MailboxMessage: Codable, Hashable {
    var originMailboxBaseUrl: String    // Origin mailbox
    var downloadedAt: Timestamp         // Time of download
    var talerUri: String
    var subjectHint: String?
}
extension MailboxMessage: Identifiable {
    var id: String { talerUri }
}
struct MailboxMessagesResponse: Codable, Hashable {
    var messages: [MailboxMessage]
    var mailboxExpiration: Timestamp?
}

/// A request to refresh the mailbox / download messages
fileprivate struct RefreshMailbox: WalletBackendFormattedRequest {
    let configuration: MailboxConfiguration
    var operation: String { "refreshMailbox" }
    struct Args: Encodable {
        let mailboxConf: MailboxConfiguration
        let progressToken: String?
    }
    func args() -> Args { Args(mailboxConf: configuration,
                             progressToken: operation + configuration.mailboxBaseUrl) }
    typealias Response = MailboxMessagesResponse
}
/// A request to get the cached messages array of the mailbox.
fileprivate struct GetMailboxMessages: WalletBackendFormattedRequest {
    var operation: String { "getMailboxMessages" }
    struct Args: Encodable {}                           // no arguments needed
    func args() -> Args { Args() }
    typealias Response = MailboxMessagesResponse
}

/// A request to add a new message to the mailbox.
fileprivate struct UpsertMailboxMessage: WalletBackendFormattedRequest {
    let message: MailboxMessage
    var operation: String { "upsertMailboxMessage" }
    struct Args: Encodable {
        let message: MailboxMessage
    }
    func args() -> Args { Args(message: message) }
    struct Response: Decodable {}
}

/// A request to delete a message from the mailbox.
fileprivate struct DeleteMailboxMessage: WalletBackendFormattedRequest {
    let message: MailboxMessage
    var operation: String { "deleteMailboxMessage" }
    struct Args: Encodable {
        let message: MailboxMessage
    }
    func args() -> Args { Args(message: message) }
    struct Response: Decodable {}
}

/// A request to send a message from the mailbox.
fileprivate struct SendTalerUriMailboxMessage: WalletBackendFormattedRequest {
    let contact: ContactEntry
    let talerUri: String
    var operation: String { "sendTalerUriMailboxMessage" }
    struct Args: Encodable {
        let contact: ContactEntry
        let talerUri: String
    }
    func args() -> Args { Args(contact: contact, talerUri: talerUri) }
    struct Response: Decodable {}
}
// MARK: - Mailbox calls
extension WalletModel {
    nonisolated func getMailbox(_ mailboxBaseUrl: String = MAILBOX, viewHandles: Bool = false)
      async throws -> MailboxConfiguration? {   // M for MainActor
        let request = GetMailbox(mailboxBaseUrl: mailboxBaseUrl)
        let (response, _) = try await sendRequest(request, viewHandles: viewHandles)
        return response.mailboxConfiguration
    }
    nonisolated func initializeMailbox(_ mailboxBaseUrl: String = MAILBOX, viewHandles: Bool = false)
      async throws -> MailboxConfiguration? {   // M for MainActor
        let request = InitializeMailbox(mailboxBaseUrl: mailboxBaseUrl)
        let controller = Controller.shared
        controller.progressOperation = request.operation
        controller.progressToken = request.operation + mailboxBaseUrl
        let (response, _) = try await sendRequest(request, viewHandles: viewHandles)
        return response.mailboxConfiguration
    }
    nonisolated func refreshMailbox(_ configuration: MailboxConfiguration, viewHandles: Bool = false)
      async throws -> MailboxMessagesResponse {   // M for MainActor
        let request = RefreshMailbox(configuration: configuration)
        let controller = Controller.shared
        controller.progressOperation = request.operation
        controller.progressToken = request.operation + configuration.mailboxBaseUrl
        let (response, _) = try await sendRequest(request, viewHandles: viewHandles)
        return response
    }
    nonisolated func getMailboxMessages(viewHandles: Bool = false)
      async throws -> [MailboxMessage] {   // M for MainActor
        let request = GetMailboxMessages()
        let (response, _) = try await sendRequest(request, viewHandles: viewHandles)
        return response.messages
    }
    nonisolated func upsertMailboxMessage(message: MailboxMessage, viewHandles: Bool = false)
      async throws {   // M for MainActor
        let request = UpsertMailboxMessage(message: message)
        let _ = try await sendRequest(request, viewHandles: viewHandles)
    }
    nonisolated func deleteMailboxMessage(message: MailboxMessage, viewHandles: Bool = false)
      async throws {   // M for MainActor
        let request = DeleteMailboxMessage(message: message)
        let _ = try await sendRequest(request, viewHandles: viewHandles)
    }
    nonisolated func sendTalerUriMailboxMessage(_ talerUri: String,
                                                to contact: ContactEntry, viewHandles: Bool = false)
      async throws {   // M for MainActor
        let request = SendTalerUriMailboxMessage(contact: contact,
                                                talerUri: talerUri)
        let _ = try await sendRequest(request, viewHandles: viewHandles)
    }
}
