/*
 * This file is part of GNU Taler, ©2022-26 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 * @author codex gpt5.6-sol
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
            switch timeoutMs {
                case 0:         // leave URLSession's default
                    break
                case ..<0:      // "no timeout"
                    request.timeoutInterval = 60 * 60 * 24
                default:
                    request.timeoutInterval = TimeInterval(timeoutMs) / 1000.0
            }
            if let reqBody, bodyLen > 0 {   // qtart frees req_body as soon as request_create returns,
                request.httpBody = Data(bytes: reqBody, count: Int(bodyLen))    // thus we must copy it
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
    let logger = Logger(subsystem: "net.taler.gnu", category: "Networking Failure")
    logger.error("Failed to create URLRequest for >>\(String(describing: requestInfo?.pointee.url))<<")
    return -1
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
final class QuickDataTask: NSObject, @unchecked Sendable {
    let urlSession: URLSession
    let request: URLRequest
    let requestID: Int32
    let responseCb: JSHttpResponseCb?
    let responseCbCls: Optional<UnsafeMutableRawPointer>

    private let state = NSCondition()
    private let onFinish: (Int32) -> Void
    private var dataTask: URLSessionDataTask?
    private var isCancelled = false
    private var isCallbackActive = false
    private var isFinished = false
#if DEBUG || TALER_NIGHTLY
    private let logger: Logger
#endif

    init(urlSession: URLSession,
            request: URLRequest,
          requestID: Int32,
         responseCb: JSHttpResponseCb?,
      responseCbCls: Optional<UnsafeMutableRawPointer>,
           onFinish: @escaping (Int32) -> Void
    ) {
#if DEBUG || TALER_NIGHTLY
        self.logger = Logger(subsystem: "net.taler.gnu", category: "Networking")
#endif
        self.urlSession = urlSession
        self.request = request
        self.requestID = requestID
        self.responseCb = responseCb
        self.responseCbCls = responseCbCls
        self.onFinish = onFinish
    }

    func run() {
        guard responseCb != nil, responseCbCls != nil else {
            finish()
            return
        }

        let method = request.httpMethod ?? "Unknown"
        let url = request.url?.trimmedString ?? EMPTYSTRING
#if DEBUG || TALER_NIGHTLY
        logger.trace("❓\(self.requestID, privacy: .public)  \(method, privacy: .public) \(url, privacy: .public)")
#endif
        let task = urlSession.dataTask(with: request) { [self] data, response, error in
            handleCompletion(data: data,
                         response: response,
                            error: error,
                           method: method,
                              url: url)
        }

        state.lock()
        guard !isFinished else {
            state.unlock()
            task.cancel()
            return
        }
        dataTask = task
        let shouldStart = !isCancelled
        state.unlock()

        if shouldStart {
            task.resume()
        } else {
            task.cancel()
            finish()
        }
    }

    /// Cancels the request and does not return until a native callback that had
    /// already started has completed. A URLSession completion may still arrive
    /// later, but `isCancelled` prevents it from entering the native callback.
    func cancel() {
        state.lock()
        guard !isFinished else {
            state.unlock()
            return
        }
        isCancelled = true
        let task = dataTask
        state.unlock()

        task?.cancel()

        var shouldNotify = false
        state.lock()
        while isCallbackActive {
            state.wait()
        }
        if !isFinished {
            isFinished = true
            dataTask = nil
            shouldNotify = true
        }
        state.unlock()

        if shouldNotify {
            onFinish(requestID)
        }
    }

    private func handleCompletion(data: Data?,
                              response: URLResponse?,
                                 error: Error?,
                                method: String,
                                   url: String) {
        guard beginCallback() else {
            finish()
            return
        }
        defer { endCallback() }

        if let response = response as? HTTPURLResponse {
            deliver(response: response, data: data ?? Data(), method: method, url: url)
        } else {
#if DEBUG || TALER_NIGHTLY
            logger.error("⁉️ \(self.requestID, privacy: .public)  \(method, privacy: .public)  \(error, privacy: .public)")
#endif
            Task.detached {
                Controller.shared.checkInternetConnection()
            }
            deliver(error: error)
        }
    }

    private func deliver(response: HTTPURLResponse,
                             data: Data,
                           method: String,
                              url: String) {
        guard let responseCb, let responseCbCls else {
            return
        }

        let status = Int32(response.statusCode)
        let errmsg = HTTPURLResponse.localizedString(forStatusCode: response.statusCode)
        let headerArray = response.allHeaderFields.map { "\($0.key): \($0.value)" }
        let cHeaders = CStringArray(headerArray)

#if DEBUG || TALER_NIGHTLY
        if data.isEmpty {
            logger.error("‼️\(self.requestID, privacy: .public)  \(method, privacy: .public) \(response.statusCode, privacy: .public) \(errmsg, privacy: .public)")
        } else {
            logger.trace("❗️ \(self.requestID, privacy: .public) \(url, privacy: .public)")
        }
#endif

        errmsg.withCString { errmsgPtr in
            data.withUnsafeBytes { bodyBytes in
                var responseInfo = JSHttpResponseInfo(
                       request_id: requestID,
                           status: status,
                           errmsg: UnsafeMutablePointer(mutating: errmsgPtr),
                 response_headers: cHeaders.pointer,
             num_response_headers: Int32(headerArray.count),
                             body: UnsafeMutableRawPointer(mutating: bodyBytes.baseAddress),
                         body_len: numericCast(data.count)
                )
                withUnsafeMutablePointer(to: &responseInfo) { responseInfoPtr in
                    responseCb(responseCbCls, responseInfoPtr)
                }
            }
        }
    }

    private func deliver(error: Error?) {
        guard let responseCb, let responseCbCls else {
            return
        }

        let errmsg = error?.localizedDescription ?? "Network request failed"
        errmsg.withCString { errmsgPtr in
            var responseInfo = JSHttpResponseInfo(
                   request_id: requestID,
                       status: 0,
                       errmsg: UnsafeMutablePointer(mutating: errmsgPtr),
             response_headers: nil,
         num_response_headers: 0,
                         body: nil,
                     body_len: 0
            )
            withUnsafeMutablePointer(to: &responseInfo) { responseInfoPtr in
                responseCb(responseCbCls, responseInfoPtr)
            }
        }
    }

    private func beginCallback() -> Bool {
        state.lock()
        defer { state.unlock() }
        guard !isCancelled, !isFinished else {
            return false
        }
        isCallbackActive = true
        return true
    }

    private func endCallback() {
        var shouldNotify = false
        state.lock()
        isCallbackActive = false
        if !isFinished {
            isFinished = true
            dataTask = nil
            shouldNotify = true
        }
        state.broadcast()
        state.unlock()

        if shouldNotify {
            onFinish(requestID)
        }
    }

    private func finish() {
        var shouldNotify = false
        state.lock()
        if !isFinished {
            isFinished = true
            dataTask = nil
            shouldNotify = true
        }
        state.broadcast()
        state.unlock()

        if shouldNotify {
            onFinish(requestID)
        }
    }
}
