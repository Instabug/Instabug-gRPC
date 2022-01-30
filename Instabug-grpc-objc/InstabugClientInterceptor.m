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
@property NSMutableDictionary<NSString *, NSString *> *responseHeaders;
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
    networkLog = [[GRPCNetworkLog alloc] init];
    
    networkLog.url = [NSString stringWithFormat:@"grpc://%@/%@",[requestOptions host], [requestOptions path].pathComponents[1]];
    networkLog.gRPCMethod = [requestOptions path].pathComponents[2];
    networkLog.startTime = [[NSDate date] timeIntervalSince1970];
    networkLog.requestHeaders = callOptions.initialMetadata;
    [super startWithRequestOptions:requestOptions callOptions:callOptions];
}

- (void)writeData:(id)data {
    networkLog.requestBody = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    networkLog.requestSize = [data length];
    [super writeData:data];
}

- (void)didReceiveData:(id)data {
    networkLog.responseBody = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    networkLog.responseBodySize = [data length];
    [super didReceiveData:data];
}

- (void)didReceiveInitialMetadata:(NSDictionary *)initialMetadata {
    networkLog.responseHeaders = [NSMutableDictionary dictionary];
    [networkLog.responseHeaders addEntriesFromDictionary:[initialMetadata copy]];

    networkLog.isServerSideError = YES;
    [super didReceiveInitialMetadata:initialMetadata];
}

- (void)didCloseWithTrailingMetadata:(NSDictionary *)trailingMetadata error:(NSError *)error {
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
    
    [networkLog.responseHeaders addEntriesFromDictionary:[trailingMetadata copy]];
    if (networkLog.responseHeaders[@"content-type"] == nil) {
        [networkLog.responseHeaders setObject:@"application/grpc" forKey:@"content-type"];
    }
    networkLog.contentType = networkLog.responseHeaders[@"content-type"];

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
    [super didCloseWithTrailingMetadata:trailingMetadata error:error];
}

@end
