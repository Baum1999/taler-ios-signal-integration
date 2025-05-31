//
//  TagEmulation.swift
//  HCEtest
//
//  Created by Marc Stibane on 2024-09-01.
//

import CoreNFC
import os.log

@available(iOS 18.3, *)
@MainActor
class TagEmulation: ObservableObject {
    public static let shared = TagEmulation()
    @Published var canUseHCE: Bool = false

    nonisolated let logger = Logger(subsystem: "net.taler.gnu", category: "TagEmulation")
    private var cardSession: CardSession? = nil
    private var presentmentIntent: NFCPresentmentIntentAssertion? = nil

    init() {
        if NFCReaderSession.readingAvailable {
            if CardSession.isSupported {
                Task {
                    if await CardSession.isEligible {
                        logger.info("CardSession is eligible")
                        canUseHCE = true
                    } else { logger.error("❗️CardSession is not eligible"); canUseHCE = false }
                }
            } else { logger.error("❗️CardSession is not supported"); canUseHCE = false }
        } else { logger.error("❗️NFCReaderSession is not available"); canUseHCE = false }
    }

    func emulateTag(_ emulatedData: String) {
        Task() {
            let result = await startEmulation(emulatedData)
            if result {
                logger.info("Emulation was successful")
            } else {
                logger.warning("❗️Emulation was not successful")
            }
        }
    }

    private func startEmulation(_ emulatedData: String) async -> Bool {
        // Hold a presentment intent assertion reference to prevent the
        // default contactless app from launching. In a real app, monitor
        // presentmentIntent.isValid to ensure the assertion remains active.
        var result = false

        do {
            if presentmentIntent == nil {
                presentmentIntent = try await NFCPresentmentIntentAssertion.acquire()
                logger.info("NFCPresentmentIntentAssertion acquired")
            } else {
                logger.info("NFCPresentmentIntentAssertion exists")
            }
            if cardSession == nil {
                cardSession = try await CardSession()
                logger.info("CardSession launched")
            } else {
                logger.info("❗️Yikes! CardSession exists")
            }
            if let cardSession {
                logger.info("cardSession.startEmulation (without waiting for reader)")
                try await cardSession.startEmulation()

                logger.info("starting eventStream")
                try await eventStream(cardSession, data: emulatedData)
                logger.info("eventStream finished")

                logger.info("cardSession.invalidate")
                await cardSession.invalidate()
                result = true
            }
            cardSession = nil
        } catch let error {
            // Handle failure to acquire NFC presentment intent assertion or card session.
            logger.error("❗️NFCPresentmentIntentAssertion not possible: \(error.localizedDescription)")
            presentmentIntent = nil /// Release presentment intent assertion.
            return false
        }
        return result
    }

    func killEmulation() {
        Task() {
            if let session = cardSession {
                await session.invalidate()
                cardSession = nil
            }
            logger.info("NFCPresentmentIntentAssertion released")
            presentmentIntent = nil /// Release presentment intent assertion
        }
    }

    private func eventStream(_ mySession: CardSession, data emulatedData: String) async throws {
        let apdu = APDU(emulatedData)
        // Iterate over events as the card session produces them.
        for try await event in mySession.eventStream {
//            if presentmentIntent?.isValid ?? false {
                switch event {
                    case .sessionStarted:
                        let message = "sessionStarted"
                        mySession.alertMessage = message
                        logger.info("\(message)")
                        break

                    case .readerDetected:
                        /// Start card emulation on first detection of an external reader.
                        logger.info("readerDetected")
//                        logger.info("cardSession.startEmulation")
//                        try await mySession.startEmulation()

                    case .readerDeselected:
                        /// Stop emulation on first notification of RF link loss.
                        logger.info("❗️readerDeselected. cardSession.stopEmulation")
                        await mySession.stopEmulation(status: .success)
                        return

                    case .received(let cardAPDU):
                        do {
                            /// Call handler to process received input and produce a response.
                            let responseAPDU = apdu.processAPDU(cardAPDU.payload)

                            logger.info("sending back data: \(responseAPDU.hexEncodedString())")
                            try await cardAPDU.respond(response: responseAPDU)
                        } catch {
                            /// Handle the error from respond(response:). If the error is
                            /// CardSession.Error.transmissionError, then retry by calling
                            /// CardSession.APDU.respond(response:) again.
                            logger.error("❗️Error while responding: \(error)")
                        }

                    case .sessionInvalidated(reason: _):
                        mySession.alertMessage = "Ending communication with card reader."
                        logger.info("❗️cardSession invalidation")
                        /// Handle the reason for session invalidation.
                        await mySession.stopEmulation(status: .failure)
                        return

                    default:
                        let message = "Unknown event from card reader."
                        mySession.alertMessage = message
                        logger.info("❗️\(message)")
                }
//            } else {
//                logger.error("❗️presentmentIntent is not valid")
//                await mySession.stopEmulation(status: .failure)
//                presentmentIntent = nil /// Release presentment intent assertion.
//                                        // TODO: stop eventStream?
//            }
        } // cardSession.eventStream
    }
}
