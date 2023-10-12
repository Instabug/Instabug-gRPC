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
@property NSMutableDictionary<NSString *, NSString *> *requestHeaders;
@property NSMutableDictionary<NSString *, NSString *> *responseHeaders;
@property NSString *contentType;
@property NSString *errorDomain;
@property NSInteger errorCode;
@property NSTimeInterval duration;
@property NSString *gRPCMethod;
@property NSString *serverErrorMessage;
@property NSTimeInterval startTime;
@property BOOL receivedInitialMetadata;
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
    networkLog.requestHeaders = [[NSMutableDictionary alloc] initWithDictionary:[callOptions.initialMetadata copy]];
    if (networkLog.requestHeaders[@"content-type"] == nil) {
        [networkLog.requestHeaders setObject:@"application/grpc" forKey:@"content-type"];
    }
    [super startWithRequestOptions:requestOptions callOptions:callOptions];
}

- (void)writeData:(id)data {
    //networkLog.requestBody = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    networkLog.requestSize += [data length];
    [super writeData:data];
}

- (void)didReceiveData:(id)data {
    //networkLog.responseBody = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    networkLog.responseBodySize += [data length];
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
    [networkLog.responseHeaders addEntriesFromDictionary:[trailingMetadata copy]];
    if (error == nil) {
        networkLog.statusCode = 0;
        if (networkLog.responseHeaders[@"content-type"] == nil) {
            [networkLog.responseHeaders setObject:@"application/grpc" forKey:@"content-type"];
        }
    } else {
        networkLog.statusCode = error.code;
        if (networkLog.isServerSideError) {
            networkLog.serverErrorMessage = error.description;
            if (networkLog.responseHeaders[@"content-type"] == nil) {
                [networkLog.responseHeaders setObject:@"application/grpc" forKey:@"content-type"];
            }
        } else {
            networkLog.errorCode = error.code;
            networkLog.errorDomain = error.description;
        }
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
                                     startTime:(networkLog.startTime * 1000000)
                                   errorDomain:networkLog.errorDomain
                                     errorCode:(int)networkLog.errorCode
                                      duration:networkLog.duration
                                    gRPCMethod:networkLog.gRPCMethod
                            serverErrorMessage:networkLog.serverErrorMessage];
    [super didCloseWithTrailingMetadata:trailingMetadata error:error];
}

@end
