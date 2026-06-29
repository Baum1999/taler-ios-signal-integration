//
//  apdu.swift
//  HCEtest
//
//  Created by Marc Stibane on 2024-07-27.
//

import Foundation
import os.log

@MainActor
class APDU {
    let talerUri: String
    nonisolated let logger = Logger(subsystem: "net.taler.gnu", category: "APDU")
    private var readCapabilityContainerCheck = false

    init(_ talerUri: String) {
        self.talerUri = talerUri
    }

    private var APDU_SELECT: Data {
        Data(fromUInt8Array: [
            0x00, // CLA    - Class - Class of instruction
            0xA4, // INS    - Instruction - Instruction code
            0x04, // P1    - Parameter 1 - Instruction parameter 1
            0x00, // P2    - Parameter 2 - Instruction parameter 2
            0x07, // Lc field - Number of bytes present in the data field of the command
            0xD2, // NDEF Tag Application name
            0x76,
            0x00,
            0x00,
            0x85,
            0x01,
            0x01,
            0x00, // Le field - Maximum number of bytes expected in the data field of the response to the command
        ])
    } // 00a4 0400 07 d2760000850101 00

    private var CAPABILITY_CONTAINER_OK: Data {
        Data(fromUInt8Array: [
            0x00, // CLA    - Class - Class of instruction
            0xA4, // INS    - Instruction - Instruction code
            0x00, // P1    - Parameter 1 - Instruction parameter 1
            0x0C, // P2    - Parameter 2 - Instruction parameter 2
            0x02, // Lc field    - Number of bytes present in the data field of the command
            0xE1, // file identifier of the CC file
            0x03,
        ])
    } // 00a4 000c 02 e103

    private var READ_CAPABILITY_CONTAINER: Data {
        Data(fromUInt8Array: [
            0x00, // CLA    - Class - Class of instruction
            0xB0, // INS    - Instruction - Instruction code
            0x00, // P1    - Parameter 1 - Instruction parameter 1
            0x00, // P2    - Parameter 2 - Instruction parameter 2
            0x0F, // Lc field    - Number of bytes present in the data field of the command
        ])
    } // 00b0 0000 0f

    private var READ_CAPABILITY_CONTAINER_RESPONSE: Data {
        Data(fromUInt8Array: [
            0x00, 0x0f,     // CCLEN length of the CC file
            0x20,           // Mapping Version 2.0
            0x00, 0x3B,     // MLe maximum
            0x00, 0x34,     // MLc maximum
            0x04,           // T field of the NDEF File Control TLV
            0x06,           // L field of the NDEF File Control TLV
            0xE1, 0x04,     // File Identifier of NDEF file
            0x00, 0xFE,     // Maximum NDEF file size of 65534 bytes    // 254 bytes
            0x00,           // Read access without any security
            0xFF,           // Write access without any security
            0x90, 0x00,     // A_OKAY
        ])
    } //000f 20 003b 0034 04 06 e104 00ff 00ff9000

    private var NDEF_SELECT_OK: Data {
        Data(fromUInt8Array: [
            0x00, // CLA    - Class - Class of instruction
            0xA4, // Instruction byte (INS) for Select command
            0x00, // Parameter byte (P1), select by identifier
            0x0C, // Parameter byte (P2), select by identifier
            0x02, // Lc field    - Number of bytes present in the data field of the command
            0xE1,
            0x04, // file identifier of the NDEF file retrieved from the CC file
        ])
    } // 00a4 000c 02 e104

    private var NDEF_READ_BINARY_NLEN: Data {
        Data(fromUInt8Array: [
            0x00, // Class byte (CLA)
            0xB0, // Instruction byte (INS) for ReadBinary command
            0x00,
            0x00, // Parameter byte (P1, P2), offset inside the CC file
            0x02, // Le field
        ])
    } // 00b0 0000 02

    private var NDEF_READ_BINARY: Data {
        Data(fromUInt8Array: [
            0x00, // Class byte (CLA)
            0xB0, // Instruction byte (INS) for ReadBinary command
        ])
    } // 00b0
//  private let NDEF_READ_BINARY_DATA = Data(fromUInt8Array: NDEF_READ_BINARY)

    private var NDEF_RECORD_HEADER_SHORT: Data {
        Data(fromUInt8Array: [
            0xD1,   // 1101 + 0001 = MessageBegin, MessageEnd, ShortRecord + Format "Well-Known" (but no ID Length)
            0x01,   // TypeLength
      //    0x00,   // Payload Length 1 byte only since ShortRecord is true
                    // no ID Length byte since the IDlength flag is false
      //    0x55,   // Payload Type = “U” for URI, 1 byte as specified in the TypeLength field
                    // since we have no ID length, there is no Payload ID
        ])
    } // d101

    private var A_OKAY_ARRAY: [UInt8] {
        [
            0x90, // SW1    Status byte 1 - Command processing status
            0x00, // SW2    Status byte 2 - Command processing qualifier
        ]
    } // 9000 = OK
    private var A_OKAY: Data {
        Data(fromUInt8Array: A_OKAY_ARRAY)
    }

    private var A_ERROR: Data {
        Data(fromUInt8Array: [
            0x6A, // SW1    Status byte 1 - Command processing status
            0x82, // SW2    Status byte 2 - Command processing qualifier
        ])
    } // 6A82 = File not found

    private var APPLICATION_ERROR: Data {
        Data(fromUInt8Array: [
            0x6A, // SW1    Status byte 1 - Command processing status
            0x88, // SW2    Status byte 2 - Command processing qualifier
        ])
    } // 6A88 = no application ID

    private var GET_VERSION: Data {
        Data(fromUInt8Array: [
            0x90, // CLA    - Class - Class of instruction
            0x60, // INS    - Instruction - Instruction code
            0x00, // P1    - Parameter 1 - Instruction parameter 1
            0x00, // P2    - Parameter 2 - Instruction parameter 2
            0x00, // Lc field - Number of bytes present in the data field of the command
        ])
    } // 9060 0000 00

    private var GET_VERSION_RESPONSE: Data {
        Data(fromUInt8Array: [
            0x00,           // fixed header
            0x04,           // vendor ID (04 = NXP Semiconductors)
            0x04,           // product type (04 = NTAG)
            0x02,           // product subtype (02 = NTAG215)
            0x01,           // major product version
            0x00,           // minor product version
            0x11,           // storage size
            0x03,           // protocol type: ISO/IEC 14443-3 compliant
            0x90, 0x00,     // A_OKAY
        ])
    } //

    private var MORE_INFO: Data {
        Data(fromUInt8Array: [
            0x90, // CLA    - Class - Class of instruction
            0xAF, // INS    - Instruction - Instruction code
            0x00, // P1    - Parameter 1 - Instruction parameter 1
            0x00, // P2    - Parameter 2 - Instruction parameter 2
            0x00, // Lc field - Number of bytes present in the data field of the command
        ])
    } // 90af 0000 00

    /// process the received data and return a response as Data.
    func processAPDU(_ commandApdu: Data) -> Data {
        /// The following flow is based on Appendix E "Example of Mapping Version 2.0 Command Flow"
        /// in the NFC Forum specification
        logger.info("incoming commandApdu: \(commandApdu.hexEncodedString())")

        /// First command: NDEF Tag Application select
        if APDU_SELECT == commandApdu {
            logger.info("APDU_SELECT triggered. Our Response: A_OKAY")
            return A_OKAY
        } // 00a4040007d276000085010100

        /// Second command: Capability Container select
        if CAPABILITY_CONTAINER_OK == commandApdu {
            logger.info("CAPABILITY_CONTAINER_OK triggered. Our Response: A_OKAY")
            return A_OKAY
        } // 00a4000c02e103

        /// Third command: ReadBinary data from CC file
        if READ_CAPABILITY_CONTAINER == commandApdu && !readCapabilityContainerCheck {
            logger.info("READ_CAPABILITY_CONTAINER triggered. Our Response:  READ_CAPABILITY_CONTAINER_RESPONSE")
            readCapabilityContainerCheck = true
            return READ_CAPABILITY_CONTAINER_RESPONSE
        } // 00b000000f

        /// Fourth command: NDEF Select command
        if NDEF_SELECT_OK == commandApdu {
            logger.info("NDEF_SELECT_OK triggered. Our Response: A_OKAY")
            return A_OKAY
        } // 00a4000c02e104

        let uriCount = talerUri.count
        let ndefLen = UInt16(uriCount + 5)     // NDEF_RECORD_HEADER is 4 bytes
        /// Fifth Command: Read the Length of the NDEF File     // 00b0 00 00 02
        if NDEF_READ_BINARY_NLEN == commandApdu {
            logger.info("NDEF_READ_BINARY_NLEN triggered. Our Response: length \(ndefLen) + A_OKAY")
            readCapabilityContainerCheck = false

            let ndefLenHi = UInt8(ndefLen >> 8)
            let ndefLenLo = UInt8(ndefLen & 0xff)
            let ndefLenLoData = withUnsafeBytes(of: ndefLenLo) { Data($0) }
            var lenData = withUnsafeBytes(of: ndefLenHi) { Data($0) }
            lenData.append(ndefLenLoData)
            lenData.append(A_OKAY_ARRAY, count: 2)
            return lenData
        } // 00b0000002

        guard commandApdu.count >= 2 else { return A_ERROR }
        /// Sixth (and seventh) Command: Read the NDEF File       // 00b0 00 02 3b, and 00b0 00 3d 27
        if NDEF_READ_BINARY == commandApdu[0..<2] {
            let count = commandApdu.count
            if count > 4 {
                var arrayApdu = Array<UInt8>(repeating: 0, count: count)
                _ = arrayApdu.withUnsafeMutableBytes { commandApdu.copyBytes(to: $0) }

                let wantedLength = UInt(arrayApdu[4])
                let offset = UInt(arrayApdu[3]) + (UInt(arrayApdu[2]) << 8)

                var data = NDEF_RECORD_HEADER_SHORT                             // 2 bytes
                let uriCount8 = UInt8((uriCount + 1) & 0xff)
                let lenData = withUnsafeBytes(of: uriCount8) { Data($0) }
                data.append(lenData)                                            // 1 byte
                data.append("U".data(using: .utf8)!)                            // 1 byte
                let zero: UInt8 = 0
                let zeroData = withUnsafeBytes(of: zero) { Data($0) }
                data.append(zeroData)                                           // 1 byte
                data.append(talerUri.data(using: .utf8)!)

                var result = A_ERROR
                let lengthBytes = UInt(2)
                // ensure wanted data starts after two length bytes
                if offset >= lengthBytes {
                    // Swift.Data doesn't have the length bytes within the data
                    let diffOffset = offset - lengthBytes
                    let count = UInt(data.count)
                    // ensure wanted data doesn't exceed buffer
                    if diffOffset + wantedLength <= count {
                        logger.info("NDEF_READ_BINARY offset \(offset), length \(wantedLength) triggered. Our Response: data + A_OKAY")
                        result = Data(fromData: data,
                                        offset: diffOffset,
                                          size: wantedLength)
                        result.append(A_OKAY)                                   // 2 bytes
                    }
                }
                readCapabilityContainerCheck = false
                return result
            }
        }

        // Reject GET_VERSION and MORE_INFO
        if GET_VERSION == commandApdu {
            logger.info("❗️GET_VERSION triggered. Our Response: GET_VERSION_RESPONSE❗️")
            return GET_VERSION_RESPONSE
        }
        if MORE_INFO == commandApdu {
            logger.info("❗️MORE_INFO triggered. Our Response: A_OKAY❗️")
            return A_OKAY
        }

        //
        // We're doing something outside our scope
        //
        logger.error("❗️processAPDU() | not yet implemented!")
        return A_ERROR
    } // processAPDU()

}
