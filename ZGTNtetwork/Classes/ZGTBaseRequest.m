//
//  ZGTBaseRequest.m
//  ZGTNtetwork
//
//  Created by kidzss on 05/09/2020.
//  Copyright (c) 2020 kidzss. All rights reserved.
//

#import "ZGTBaseRequest.h"
#import <pthread.h>
#import "ZGTRequestDispatcher.h"

static pthread_mutex_t mutex_t;

@interface ZGTBaseRequest ()

@property (nonatomic, strong, readwrite) NSURLSessionTask *task;
@property (nonatomic, strong, readwrite) NSDictionary *responseHeaders;
@property (nonatomic, strong, readwrite) id responseObject;
@property (nonatomic, strong, readwrite) NSError *responseError;
@property (nonatomic, strong, readwrite) NSMutableArray *mutableAccessorys;

@end

@implementation ZGTBaseRequest {
    struct ZGTRequestCompletDelegateFlag _requestCompletDelegateFlag;
}

- (BOOL)isUseHttps {
    return NO;
}

- (BOOL)isUseCDN {
    return NO;
}

- (NSString *)host {
    return @"";
}

- (NSString *)cdnURL {
    return @"";
}

- (ZGTRequestPriority)requestPriority {
    return ZGTRequestPriorityDefault;
}

- (ZGTRequestAPIType)requestApiType {
    return ZGTRequestAPITypeMVC;
}

- (ZGTRequestType)requestType {
    return ZGTRequestTypeDataTask;
}

- (ZGTLogOutputLevel)requestLogLevel {
    return ZGTLogOutputLevelInfo;
}

- (NSString *)requestController {
    return @"";
}

- (NSString *)requestAction {
    return @"";
}

- (NSString *)requestVersion {
    return @"";
}

- (NSString *)requestURL {
    return @"";
}

- (NSString *)requestAbsoluteURL {
    return @"";
}

- (NSString *)downloadURL {
    return @"";
}

- (NSString *)uploadURL {
    return @"";
}

- (ZGTRequestMethod)requestMethod {
    return  ZGTRequestMethodGET;
}

- (NSDictionary *)requestHeaderFieldValueDictionary {
    return nil;
}

- (NSArray *)requestAuthorizationHeaderFieldArray {
    return nil;
}

- (ZGTRequestSerializerType)requestSerialzerType {
    return ZGTRequestSerializerTypeHTTP;
}

- (ZGTResponseSerializerType)responseSerialzerType {
    return ZGTResponseSerializerTypeJSON;
}

- (NSURLRequest *)buildDownloadUrlRequest {
    return nil;
}

- (NSURL *)saveDownloadDataUrl {
    return nil;
}

- (AFMultipartFormDataBlock)multipartFormDataBlock {
    return nil;
}

- (NSTimeInterval)requestTimeoutInterval {
    return 30.0;
}

- (id)requestArgument {
    return nil;
}

- (id)systemArgument {
    return nil;
}

- (id)cacheFileNameFilterForRequestArgument:(id)argument {
    return nil;
}

- (ZGTResponseThreadType)responseThread {
    return ZGTResponseThreadTypeMainThread;
}

- (Class)responseClass {
    return nil;
}

- (id)jsonValidator {
    return nil;
}

//正常结束
- (void)requestCompleteFilter {
    
}

//失败结束
- (void)requestFailedFilter {
    
}

//交给ZGTRequest处理
- (id)responseModelObject {
    return nil;
}

- (struct ZGTRequestCompletDelegateFlag)requestCompletFlag {
    return _requestCompletDelegateFlag;
}

- (id)responseJSON {
    if (_responseObject && ([self responseSerialzerType] == ZGTResponseSerializerTypeJSON)) {
        return _responseObject;
    }
    return nil;
}

- (NSHTTPURLResponse *)response {
    if ([_task.response isKindOfClass:[NSHTTPURLResponse class]]) {
        return (NSHTTPURLResponse *)_task.response;
    }
    return nil;
}

- (NSDictionary *)responseHeaders {
    NSHTTPURLResponse *response = [self response];
    if (response) {
        return response.allHeaderFields;
    }
    return nil;
}

- (NSInteger)responseStatusCode {
    NSHTTPURLResponse *response = [self response];
    if (response) {
        return response.statusCode;
    }
    return NSURLErrorUnknown;
}

- (BOOL)statusCodeValidator {
    NSInteger statusCode = [self responseStatusCode];
    if (statusCode >= 200 && statusCode <=299) {
        return YES;
    } else {
        return NO;
    }
}

- (NSError *)responseError {
    return _task.error;
}

- (void)startWithDelegate:(id<ZGTRequestCompletDelegate>)delegate {
    _requestDelegate = delegate;
    if (_requestDelegate) {
        if ([_requestDelegate respondsToSelector:@selector(requestSuccessed:)]) {
            _requestCompletDelegateFlag.requestSuccessed = YES;
        }
        if ([_requestDelegate respondsToSelector:@selector(requestFailed:)]) {
            _requestCompletDelegateFlag.requestFailed = YES;
        }
    }
   
    [self start];
}

- (void)startWithSuccessComplet:(RequestSuccessBlcok)success
                    failComplet:(RequestFailBlcok)fail {
    _successBlock = [success copy];
    _failBlock = [fail copy];
    
    [self start];
}

- (BOOL)isExecuting {
    return _task.state == NSURLSessionTaskStateRunning;
}

- (BOOL)isCancelled {
    return _task.state == NSURLSessionTaskStateCompleted;
}

- (void)clearCompletionBlocks {
    // 接触当前Request对象的blcok对象 1)对自己的强引用 2)对传入的其他对象的强引用
    _successBlock = nil;
    _failBlock = nil;
}

- (void)addAccessory:(id<ZGTRequestAccessory>)accessory {
    if (!accessory) {
        return;
    }
    
    pthread_mutex_lock(&mutex_t);
    [self.mutableAccessorys addObject:accessory];
    pthread_mutex_unlock(&mutex_t);
}

- (NSArray *)accessorys {
    pthread_mutex_lock(&mutex_t);
    NSArray *accessorysCopy = nil;
    accessorysCopy = [self.mutableAccessorys copy];
    pthread_mutex_unlock(&mutex_t);
    return accessorysCopy;
}

- (NSMutableArray *)mutableAccessorys {
    if (_mutableAccessorys) {
        _mutableAccessorys = [[NSMutableArray alloc] initWithCapacity:16];
    }
    return _mutableAccessorys;
}

- (void)start {
    NSArray *accessorys = [self accessorys];
    for (id<ZGTRequestAccessory> accessory in accessorys) {
        if ([accessory respondsToSelector:@selector(requestWillStart:)]) {
            [accessory requestWillStart:self];
        }
    }
    [[ZGTRequestDispatcher sharedInstance] enqueRequest:self];
}

- (void)stop {
    NSArray *accessorys = [self accessorys];
    for (id<ZGTRequestAccessory> accessory in accessorys) {
        if ([accessory respondsToSelector:@selector(requestWillStop:)]) {
            [accessory requestWillStart:self];
        }
    }
    
    // 释放 delegate
    _requestDelegate = nil;
    
    // 释放block持有的对象（等价[self clearCompletionBlocks]）
    _successBlock = nil;
    _failBlock = nil;
    
    [[ZGTRequestDispatcher sharedInstance] cancelRequest:self];
    
    for (id<ZGTRequestAccessory> accessory in accessorys) {
        if ([accessory respondsToSelector:@selector(requestDidStop:)]) {
            [accessory requestWillStart:self];
        }
    }
}

#pragma mark - debug description

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@: %p, %@>",
            [self class],
            self,
            @{
              @"method" : @([self requestMethod]),
              @"host" : [self host],
              @"url" : [self requestURL],
              @"action" : [self requestAction],
              @"controller" : [self requestController],
              @"requestVersion" : [self requestVersion],
              }];
}

- (NSString *)debugDescription {
    return [self description];
}

@end
