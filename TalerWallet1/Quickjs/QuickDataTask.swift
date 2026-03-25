/*
 * This file is part of GNU Taler, ©2022-25 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import Foundation
//import "Foundation/NSURLError.h"
import os.log

import FTalerWalletcore

// will be called from wallet-core for networking
func request_create(userdata: Optional<UnsafeMutableRawPointer>,
                 requestInfo: Optional<UnsafeMutablePointer<JSHttpRequestInfo>>) -> Int32 {
    let quickjs = Unmanaged<Quickjs>.fromOpaque(userdata!).takeUnretainedValue()

    if let requestInfo {
        if let url = URL(string: String(cString: requestInfo.pointee.url)) {
            let responseCb = requestInfo.pointee.response_cb
            let responseCbCls = requestInfo.pointee.response_cb_cls
            let method = String(cString: requestInfo.pointee.method)
            let requestHeaders = requestInfo.pointee.request_headers
                let redirect = requestInfo.pointee.redirect             // TODO: redirect
            let timeoutMs = requestInfo.pointee.timeout_ms
                let debug = requestInfo.pointee.debug                   // TODO: debug
            let reqBody = requestInfo.pointee.req_body
            let bodyLen = requestInfo.pointee.req_body_len

            var request = URLRequest(url: url)
            request.httpMethod = method
            request.timeoutInterval = TimeInterval(timeoutMs)
            if let reqBody {        // caller will deallocate the req_body after dataTask finish or cancel
                let body = Data(bytesNoCopy: reqBody, count: Int(bodyLen), deallocator: .none)
                request.httpBody = body
            }
            if var ptr = requestHeaders {
                while let cString = ptr.pointee {
                    let string = String(cString: cString)
                    if let index = string.firstIndex(of: ":") {
                        let headerField = string.prefix(upTo: index)
                        let nextIndex = string.index(index, offsetBy: 1)        // skip the ":"
                        let value = string.suffix(from: nextIndex)
                        request.addValue(String(value), forHTTPHeaderField: String(headerField))
                    }
                    ptr += 1
                }
            }

            return quickjs.reqCreate(request, responseCb, responseCbCls)
        }
    }
    return 0
}

func request_cancel(userdata: Optional<UnsafeMutableRawPointer>,
                   requestID: Int32) -> Int32 {
    let quickjs = Unmanaged<Quickjs>.fromOpaque(userdata!).takeUnretainedValue()
    return quickjs.reqCancel(requestID)
}
// MARK: -
extension Error {
    var errorCode:Int? {
        return (self as NSError).code
    }
}
// MARK: -
class QuickDataTask: NSObject {
    let urlSession: URLSession
    let request: URLRequest
    let requestID: Int32
    var requests: [Int32: QuickDataTask]
    let responseCb: JSHttpResponseCb?
    let responseCbCls: Optional<UnsafeMutableRawPointer>

    var dataTask: URLSessionDataTask? = nil
    var logger: Logger

    init(urlSession: URLSession,
            request: URLRequest,
          requestID: Int32,
           requests: inout [Int32: QuickDataTask],
         responseCb: JSHttpResponseCb?,
      responseCbCls: Optional<UnsafeMutableRawPointer>
    ) {
        self.logger = Logger(subsystem: "net.taler.gnu", category: "Networking")
        self.urlSession = urlSession
        self.request = request
        self.requestID = requestID
        self.requests = requests
        self.responseCb = responseCb
        self.responseCbCls = responseCbCls
    }

    func run() {
        if let responseCb, let responseCbCls {
            let method = self.request.httpMethod ?? "Unknown"
            let url = self.request.url?.absoluteString ?? EMPTYSTRING
            logger.trace("❓\(self.requestID, privacy: .public)  \(method, privacy: .public) \(url, privacy: .public)")
            dataTask = urlSession.dataTask(with: request) { [self] data, response, error in
                if let response = response as? HTTPURLResponse {
                    var headerArray: [String] = []
                    var numHeaders: Int32 = 0
                    let status = Int32(response.statusCode)
                    let errmsg = HTTPURLResponse.localizedString(forStatusCode: Int(status))
                    let errmsg_p0 = UnsafeMutablePointer<CChar>(mutating: errmsg.cString(using: .utf8))
              // Initialization of 'UnsafeMutablePointer<CChar>' (aka 'UnsafeMutablePointer<Int8>') results in a dangling pointer
                    let headers = response.allHeaderFields
                    for (key,value) in headers {
                        headerArray.append("\(key): \(value)")
                        numHeaders += 1
                    }
                    let cHeaders = CStringArray(headerArray)

                    if let data {
                        let ndata:NSData = data as NSData
                        let bodyPtr = UnsafeMutableRawPointer(mutating: ndata.bytes)
                        var responseInfo = JSHttpResponseInfo(request_id: self.requestID,
                                                              status: status,
                                                              errmsg: errmsg_p0,
                                                    response_headers: cHeaders.pointer,
                                                num_response_headers: numHeaders,
                                                                body: bodyPtr,
                                                            body_len: UInt32(data.count))
                        let responseInfoPtr = UnsafeMutablePointer<JSHttpResponseInfo>(&responseInfo)
                        // Initialization of 'UnsafeMutablePointer<JSHttpResponseInfo>' results in a dangling pointer
                        logger.trace("❗️ \(self.requestID, privacy: .public) \(url, privacy: .public)")
                        responseCb(responseCbCls, responseInfoPtr)
                        return
                    } else { // data == nil
                        logger.error("‼️\(self.requestID, privacy: .public)  \(method, privacy: .public) \(response.statusCode, privacy: .public) \(errmsg, privacy: .public)")
                        var responseInfo = JSHttpResponseInfo(request_id: self.requestID,
                                                                  status: status,
                                                                  errmsg: errmsg_p0,
                                                        response_headers: cHeaders.pointer,
                                                    num_response_headers: numHeaders,
                                                                    body: nil,
                                                                body_len: 0)
                        let responseInfoPtr = UnsafeMutablePointer<JSHttpResponseInfo>(&responseInfo)
                        responseCb(responseCbCls, responseInfoPtr)
                    }
                } else {    // pass error to walletCore
                    Task.detached {
                        self.logger.error("⁉️ \(self.requestID, privacy: .public)  \(method, privacy: .public)  \(error, privacy: .public)")
                        Controller.shared.checkInternetConnection()
                        let errmsg = error?.localizedDescription
                        let errmsg_p0 = if let errmsg { UnsafeMutablePointer<CChar>(mutating: errmsg.cString(using: .utf8)) }
                                        else { UnsafeMutablePointer<CChar>(nil) }
                        var responseInfo = JSHttpResponseInfo(request_id: self.requestID,
                                                                  status: 0,
                                                                  errmsg: errmsg_p0,
                                                        response_headers: nil,
                                                    num_response_headers: 0,
                                                                    body: nil,
                                                                body_len: 0)
                        let responseInfoPtr = UnsafeMutablePointer<JSHttpResponseInfo>(&responseInfo)
                        responseCb(responseCbCls, responseInfoPtr)
                    }
                }
                requests[requestID] = nil
            }
            dataTask?.resume()
        }
    }
}
