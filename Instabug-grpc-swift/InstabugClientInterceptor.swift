//
//  InstabugClientInterceptor.swift
//  InstabugClientInterceptor
//
//  Created by Hussein Kishk on 09/01/2022.
//

import Foundation
import GRPC
import NIO
import Instabug

open class InstabugClientInterceptor<Request: InstabugGRPCDataProtocol, Response: InstabugGRPCDataProtocol>: ClientInterceptor<Request, Response> {

    public init(port: Int? = nil) {
        super.init()
        networkLog.port = port
    }
    
    lazy var networkLog: GRPCNetworkLog = GRPCNetworkLog()

    open override func send(
        _ part: GRPCClientRequestPart<Request>,
        promise: EventLoopPromise<Void>?,
        context: ClientInterceptorContext<Request, Response>
    ) {
        let authority = getHost(context: context)
        var serviceName: String = ""
        if context.path.components(separatedBy: "/").count > 1 {
            serviceName = context.path.components(separatedBy: "/")[1]
        }

        var portStr: String = ""
        if let port = networkLog.port {
            portStr = ":\(port)"
        }
        networkLog.url = "grpc://\(authority)\(portStr)/\(serviceName)"
        networkLog.gRPCMethod = context.path.components(separatedBy: "/").last
        switch part {
        case let .metadata(headers):
            networkLog.startTime = Date().timeIntervalSince1970
            for header in headers {
                networkLog.requestHeaders[header.name] = header.value
            }
            
            if networkLog.requestHeaders["content-type"] == nil {
                networkLog.requestHeaders["content-type"] = "application/grpc"
            }

        case let .message(request, _):
            if let data = request.gRPCRequestData {
                networkLog.requestBody = String(data: data, encoding: .utf8)
                networkLog.requestBodySize = Int64(data.count)
            }
        case .end: break
        }
        
        // Forward the request part to the next interceptor.
        context.send(part, promise: promise)
    }

    open override func receive(
        _ part: GRPCClientResponsePart<Response>,
        context: ClientInterceptorContext<Request, Response>
    ) {
        switch part {
        case let .metadata(headers):
            for header in headers {
                networkLog.responseHeaders[header.name] = header.value
            }
            if networkLog.responseHeaders["content-type"] == nil {
                networkLog.responseHeaders["content-type"] = "application/grpc"
            }

        case let .message(response):
            if let data = response.gRPCRequestData {
                networkLog.responseBody = String(data: data, encoding: .utf8)
                networkLog.responseBodySize = Int64(data.count)
            }

        case let .end(status, trailers):
            networkLog.responseCode = Int32(status.code.rawValue)
            if !trailers.isEmpty {
                for header in trailers {
                    networkLog.responseHeaders[header.name] = header.value
                }
        
                if networkLog.responseHeaders["content-type"] == nil {
                    networkLog.responseHeaders["content-type"] = "application/grpc"
                }
                if status.code.rawValue != 0 {
                    networkLog.serverErrorMessage = status.description
                }
            } else {
                networkLog.errorCode = Int32(status.code.rawValue)
                networkLog.errorDomain = status.description
            }
            if let startTime = networkLog.startTime {
                networkLog.duration = Int64((Date().timeIntervalSince1970 - startTime) * 1000000)
            }
            addGrpcNetworkLog()
        }

        // Forward the response part to the next interceptor.
        context.receive(part)
    }

    open override func errorCaught(_ error: Error, context: ClientInterceptorContext<Request, Response>) {
        networkLog.responseCode = nil
        networkLog.serverErrorMessage = nil
        networkLog.errorCode = Int32((error as NSError).code)
        networkLog.errorDomain = (error as NSError).domain
        addGrpcNetworkLog()
    }

    func addGrpcNetworkLog() {
        if networkLog.responseHeaders["content-type"] != nil {
            networkLog.requestHeaders["content-type"] = networkLog.responseHeaders["content-type"]
        }
        networkLog.contentType = networkLog.responseHeaders["content-type"]
        
        NetworkLogger.addGrpcNetworkLog(
            withUrl: networkLog.url,
            requestBody: networkLog.requestBody,
            requestBodySize: networkLog.requestBodySize ?? 0,
            responseBody: networkLog.responseBody,
            responseBodySize: networkLog.responseBodySize ?? 0,
            responseCode: networkLog.responseCode ?? 0,
            requestHeaders: networkLog.requestHeaders,
            responseHeaders: networkLog.responseHeaders,
            contentType: networkLog.contentType,
            startTime: Int64((networkLog.startTime ?? 0) * 1000000),
            errorDomain: networkLog.errorDomain,
            errorCode: networkLog.errorCode ?? 0,
            duration: networkLog.duration ?? 0,
            gRPCMethod: networkLog.gRPCMethod,
            serverErrorMessage:networkLog.serverErrorMessage)
    }
    
    func getHost(context: ClientInterceptorContext<Request, Response>) -> String {
        let defaultIP = "0.0.0.0"
        
        guard let pipelineMirrorValue = Mirror(reflecting: context).children.first(where: {$0.label == "_pipeline"})?.value else {
            return defaultIP
        }

        let pipelineMirror = Mirror(reflecting: pipelineMirrorValue)
        
        guard let detailsMirrorValue = pipelineMirror.children.first(where: { $0.label == "details"})?.value else {
            return defaultIP
        }

        let detailsMirror = Mirror(reflecting: detailsMirrorValue)

        guard let authority = detailsMirror.children.first(where: { $0.label == "authority"})?.value as? String else {
            return defaultIP
        }

        return authority
    }
}

struct GRPCNetworkLog {
    var url: String?
    var port: Int?
    var requestBody: String?
    var requestBodySize: Int64?
    var responseBody: String?
    var responseBodySize: Int64?
    var responseCode: Int32?
    var requestHeaders: [String: String] = [:]
    var responseHeaders: [String: String] = [:]
    var contentType: String?
    var errorDomain: String?
    var errorCode: Int32?
    var startTime: Double?
    var duration: Int64?
    var gRPCMethod: String?
    var serverErrorMessage: String?
}

public protocol InstabugGRPCDataProtocol {
    var gRPCRequestData: Data? { get }
}
