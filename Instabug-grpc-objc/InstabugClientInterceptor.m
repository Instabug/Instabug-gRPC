//
//  InstabugClientInterceptor.m
//  Instabug-grpc-objc
//
//  Created by Hussein Kishk on 27/01/2022.
//

#import "InstabugClientInterceptor.h"

@interface GRPCNetworkLog : NSObject
@property NSString *url;
@property NSString *requestBody;
@property NSInteger requestSize;
@property NSString *responseBody;
@property NSInteger responseBodySize;
@property NSInteger statusCode;
@property NSDictionary<NSString *, NSString *> *requestHeaders;
@property NSDictionary<NSString *, NSString *> *responseHeaders;
@property NSString *contentType;
@property NSString *errorDomain;
@property NSInteger errorCode;
@property NSInteger duration;
@property NSString *gRPCMethod;
@property NSString *serverErrorMessage;
@property double startTime;
@property BOOL isServerSideError;
@end

@implementation GRPCNetworkLog

@end

@implementation InstabugClientInterceptor

GRPCNetworkLog *networkLog;

- (void)startWithRequestOptions:(GRPCRequestOptions *)requestOptions callOptions:(GRPCCallOptions *)callOptions {
    [super startWithRequestOptions:requestOptions callOptions:callOptions];
    networkLog = [[GRPCNetworkLog alloc] init];
    
    networkLog.url = [NSString stringWithFormat:@"grpc://%@/%@",[requestOptions host], [requestOptions path].pathComponents[1]];
    networkLog.gRPCMethod = [requestOptions path].pathComponents[2];
    networkLog.startTime = [[NSDate date] timeIntervalSince1970];
    networkLog.requestHeaders = callOptions.initialMetadata;
}

- (void)writeData:(id)data {
    [super writeData:data];
    networkLog.requestBody = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    networkLog.requestSize = [data length];
}

- (void)didReceiveData:(id)data {
    [super didReceiveData:data];
    networkLog.responseBody = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    networkLog.responseBodySize = [data length];
}

- (void)didReceiveInitialMetadata:(NSDictionary *)initialMetadata {
    [super didReceiveInitialMetadata:initialMetadata];
    networkLog.responseHeaders = initialMetadata;
    networkLog.isServerSideError = YES;
}

- (void)didCloseWithTrailingMetadata:(NSDictionary *)trailingMetadata error:(NSError *)error {
    [super didCloseWithTrailingMetadata:trailingMetadata error:error];
    networkLog.duration = ([[NSDate date] timeIntervalSince1970] - networkLog.startTime) * 1000000;
    if (error == nil) {
        networkLog.statusCode = 0;
    } else {
        if (networkLog.isServerSideError) {
            networkLog.statusCode = error.code;
            networkLog.serverErrorMessage = error.localizedDescription;
        } else {
            networkLog.errorCode = error.code;
            networkLog.errorDomain = error.localizedDescription;
        }
    }

    [IBGNetworkLogger addGrpcNetworkLogWithUrl:networkLog.url
                                   requestBody:networkLog.requestBody
                               requestBodySize:networkLog.requestSize
                                  responseBody:networkLog.responseBody
                              responseBodySize:networkLog.responseBodySize
                                  responseCode:(int)networkLog.statusCode
                                requestHeaders:networkLog.requestHeaders
                               responseHeaders:networkLog.responseHeaders
                                   contentType:networkLog.contentType
                                     startTime:networkLog.startTime
                                   errorDomain:networkLog.errorDomain
                                     errorCode:(int)networkLog.errorCode
                                      duration:networkLog.duration
                                    gRPCMethod:networkLog.gRPCMethod
                            serverErrorMessage:networkLog.serverErrorMessage];
}

- (void)finish {
    [super finish];
}

- (void)cancel {
    [super cancel];
}

- (void)didWriteData {
    [super didWriteData];
}


@end
