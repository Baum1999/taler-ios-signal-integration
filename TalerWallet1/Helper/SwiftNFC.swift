//  MIT License
//  Copyright © Ming
//  https://github.com/1998code/SwiftNFC
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy of this software
//  and associated documentation files (the "Software"), to deal in the Software without restriction,
//  including without limitation the rights to use, copy, modify, merge, publish, distribute,
//  sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all copies or
//  substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING
//  BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
//  NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
//  DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//
/**
 * @author Marc Stibane
 */
import SwiftUI
import CoreNFC

@available(iOS 15.0, *)
public class NFCWriter: NSObject, ObservableObject, NFCNDEFReaderSessionDelegate {
    
    public var startAlert = String(localized: "Hold your iPhone near the tag.")
    public var endAlert = ""
    public var msg = ""
    public var type = "T"   // T=Text - U=URL
    public var data: Data? = nil

    public var session: NFCNDEFReaderSession?
    
    public func write(_ data: Data? = nil) {
        guard NFCNDEFReaderSession.readingAvailable else {
            print("Error readingAvailable")
            return
        }
        self.data = data
        session = NFCNDEFReaderSession(delegate: self, queue: nil, invalidateAfterFirstRead: false)
        if let session {
            session.alertMessage = self.startAlert
            session.begin()
        } else {
            print("Error NFCNDEFReaderSession")
        }
    }
    
    public func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
        print("didDetectNDEFs", messages)
    }

    public func readerSession(_ session: NFCNDEFReaderSession, didDetect tags: [NFCNDEFTag]) {
        if tags.count > 1 {
            let retryInterval = DispatchTimeInterval.milliseconds(500)
            session.alertMessage = "Detected more than 1 tag. Please try again."
            DispatchQueue.global().asyncAfter(deadline: .now() + retryInterval, execute: {
                session.restartPolling()
            })
            return
        }
        
        let tag = tags.first!
        session.connect(to: tag, completionHandler: { (error: Error?) in
            if nil != error {
                session.alertMessage = "Unable to connect to tag."
                session.invalidate()
                return
            }
            
            tag.queryNDEFStatus(completionHandler: { (ndefStatus: NFCNDEFStatus, capacity: Int, error: Error?) in
                guard error == nil else {
                    session.alertMessage = "Unable to query the status of the tag."
                    session.invalidate()
                    return
                }

                switch ndefStatus {
                case .notSupported:
                    session.alertMessage = "Tag is not NDEF compliant."
                    session.invalidate()
                case .readOnly:
                    session.alertMessage = "Read only tag detected."
                    session.invalidate()
                case .readWrite:
                    let payload: NFCNDEFPayload?
                    if self.type == "T" {
                        payload = NFCNDEFPayload.init(
                            format: .nfcWellKnown,
                            type: Data("\(self.type)".utf8),
                            identifier: Data(),
                            payload: self.data ?? Data("\(self.msg)".utf8)
                        )
                    } else {
                        payload = NFCNDEFPayload.wellKnownTypeURIPayload(string: "\(self.msg)")
                    }
                    let message = NFCNDEFMessage(records: [payload].compactMap({ $0 }))
                    tag.writeNDEF(message, completionHandler: { (error: Error?) in
                        if nil != error {
                            session.alertMessage = "Write to tag failed: \(error!)"
                        } else {
                            session.alertMessage = self.endAlert != "" ? self.endAlert : "Write \(self.msg) to tag successful."
                        }
                        session.invalidate()
                    })
                @unknown default:
                    session.alertMessage = "Unknown tag status."
                    session.invalidate()
                }
            })
        })
    }
    
    public func readerSessionDidBecomeActive(_ session: NFCNDEFReaderSession) {
    }

    public func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        print("Session did invalidate with error: \(error)")
        self.session = nil
    }
}
