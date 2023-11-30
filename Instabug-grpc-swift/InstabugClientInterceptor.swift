//
//  InstabugClientInterceptor.swift
//  InstabugClientInterceptor
//
//  Created by Hussein Kishk on 09/01/2022.
//

import Foundation
import GRPC
import NIO
import NIOHPACK
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
        
        let partToSend: GRPCClientRequestPart<Request>
        switch part {
        case let .metadata(headers):
            let updatedHeaders = addingExternalTraceIDHeader(to: headers)
            partToSend = .metadata(updatedHeaders)
        default:
            partToSend = part
        }
        
        switch partToSend {
        case let .metadata(headers):
            networkLog.startTime = Date().timeIntervalSince1970
            for header in headers {
                networkLog.requestHeaders[header.name] = header.value
            }
            
            if networkLog.requestHeaders["content-type"] == nil {
                networkLog.requestHeaders["content-type"] = "application/grpc"
            }

        case let .message(request, _):
            if let dataCount = request.gRPCRequestData?.count {
                networkLog.requestBodySize = dataCount
            }
        case .end: break
        }
        
        // Forward the request part to the next interceptor.
        context.send(partToSend, promise: promise)
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
            if let dataCount = response.gRPCRequestData?.count {
                networkLog.responseBodySize = dataCount
            }

        case let .end(status, trailers):
            networkLog.responseCode = status.code.rawValue
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
                networkLog.errorCode = status.code.rawValue
                networkLog.errorDomain = status.description
            }
            if let startTime = networkLog.startTime {
                networkLog.duration = Date().timeIntervalSince1970 - startTime
            }
            addGrpcNetworkLog()
        }

        // Forward the response part to the next interceptor.
        context.receive(part)
    }

    open override func errorCaught(_ error: Error, context: ClientInterceptorContext<Request, Response>) {
        networkLog.responseCode = nil
        networkLog.serverErrorMessage = nil
        networkLog.errorCode = (error as NSError).code
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
            requestBodySize: networkLog.requestBodySize ?? 0,
            responseBodySize: networkLog.responseBodySize ?? 0,
            responseCode: networkLog.responseCode ?? 0,
            requestHeaders: networkLog.requestHeaders,
            responseHeaders: networkLog.responseHeaders,
            contentType: networkLog.contentType,
            startTime: (networkLog.startTime ?? 0) * 1_000_000,
            errorDomain: networkLog.errorDomain,
            errorCode: networkLog.errorCode ?? 0,
            duration: (networkLog.duration ?? 0) * 1_000_000,
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
    
    private func addingExternalTraceIDHeader(to metadataHeaders: HPACKHeaders) -> HPACKHeaders {
        let externalTraceIDHeader = NetworkLogger.newExternalTraceIDHeader()
        guard let externalTraceIDHeader = externalTraceIDHeader else {
            return metadataHeaders
        }
        var updatedHeaders = metadataHeaders
        for aHeader in externalTraceIDHeader {
            updatedHeaders.add(name: aHeader.key, value: aHeader.value)
        }
        return updatedHeaders
    }
    
}

struct GRPCNetworkLog {
    var url: String?
    var port: Int?
    var requestBodySize: Int?
    var responseBodySize: Int?
    var responseCode: Int?
    var requestHeaders: [String: String] = [:]
    var responseHeaders: [String: String] = [:]
    var contentType: String?
    var errorDomain: String?
    var errorCode: Int?
    var startTime: TimeInterval?
    var duration: TimeInterval?
    var gRPCMethod: String?
    var serverErrorMessage: String?
}

public protocol InstabugGRPCDataProtocol {
    var gRPCRequestData: Data? { get }
}
