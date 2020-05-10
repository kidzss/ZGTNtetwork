//
//  ZGTBatchRequest.m
//  ZGTNtetwork
//
//  Created by kidzss on 05/09/2020.
//  Copyright (c) 2020 kidzss. All rights reserved.
//

#import "ZGTBatchRequest.h"
#import <pthread.h>
#import "ZGTRequest.h"

static pthread_mutex_t cache_mutex;

/**
 *  负责持有临时创建的BatchRequest对象，避免在执行期间被废弃
 */
@interface __ZGTBatchRequestCache : NSObject

+ (instancetype)sharedInstance;

- (void)addBatchRequest:(ZGTBatchRequest *)request;
- (void)removeBatchRequest:(ZGTBatchRequest *)request;

@end
@implementation __ZGTBatchRequestCache {
    NSMutableArray *_batchRequests;
}

+ (instancetype)sharedInstance {
    static __ZGTBatchRequestCache *_cache = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _cache = [[__ZGTBatchRequestCache alloc] init];
    });
    return _cache;
}

- (instancetype)init {
    if (self = [super init]) {
        pthread_mutex_init(&cache_mutex, NULL);
        _batchRequests = [[NSMutableArray alloc] initWithCapacity:16];
    }
    return self;
}

- (void)addBatchRequest:(ZGTBatchRequest *)request {
    pthread_mutex_lock(&cache_mutex);
    if (request) {
        [_batchRequests addObject:request];
    }
    pthread_mutex_unlock(&cache_mutex);
}

- (void)removeBatchRequest:(ZGTBatchRequest *)request {
    pthread_mutex_lock(&cache_mutex);
    if (request) {
        [_batchRequests removeObject:request];
    }
    pthread_mutex_unlock(&cache_mutex);
}

@end

@interface ZGTBatchRequest () <ZGTRequestCompletDelegate>
@end
@implementation ZGTBatchRequest {
    NSArray *_requests;
    NSInteger _curFinishedCount;
    id<ZGTBatchRequestDelegate> __weak _batchRequestDelegate;
}

- (instancetype)initWithBasicRequestArray:(NSArray *)requestArray {
    if (self = [super init]) {
        _requests = [[NSArray alloc] initWithArray:requestArray copyItems:NO];
        _curFinishedCount = 0;
    }
    return self;
}

- (void)dealloc {
    _requests = nil;
#ifdef DEBUG
    NSLog(@"BatchRequest %@ is dealloc", self);
#endif
}

- (void)startWithDelegate:(id<ZGTBatchRequestDelegate>)delegate {
    @synchronized (self) {
        if (_curFinishedCount > 0) {
#ifdef DEBUG
            NSLog(@"批量请求已经开始执行");
#endif
            return;
        }
    }
    
    _batchRequestDelegate = delegate;
    BOOL isAllZGTRequestCls = YES;
    for (ZGTRequest *req in _requests) {
        if (![req isKindOfClass:[ZGTRequest class]]) {
            isAllZGTRequestCls = NO;
            break;
        }
    }
    
    if (!isAllZGTRequestCls) {
#ifdef DEBUG
        NSLog(@"批量请求必须都是ZGTRequest子类的对象");
#endif
        return;
    }
    
    [[__ZGTBatchRequestCache sharedInstance] addBatchRequest:self];
    for (ZGTRequest *req in _requests) {
        [req startWithDelegate:self];
    }
}

- (void)stop {
    _batchRequestDelegate = nil;
    for (ZGTRequest *req in _requests) {
        [req stop];
    }
    [[__ZGTBatchRequestCache sharedInstance] removeBatchRequest:self];
}

#pragma mark - ZGTRequestCompletDelegate

/**
 *  链中的某一个Request正常执行结束，接着继续执行下一个依赖的Request，一直到所有的执行完毕或错误结束
 */
- (void)requestSuccessed:(ZGTBaseRequest *)request {
    @synchronized (self) {
        _curFinishedCount += 1;
    }
    
    if (_curFinishedCount == _requests.count) {
        // 回调请求全部结束
        if ([_batchRequestDelegate respondsToSelector:@selector(batchRequestDidSuccessFinish:)]) {
            [_batchRequestDelegate batchRequestDidSuccessFinish:self];
        }
        
        // 清除请求缓存
        [[__ZGTBatchRequestCache sharedInstance] removeBatchRequest:self];
    }
}

/**
 *  链中某一个Request错误执行结束，则停止后续所有的Request结束
 */
- (void)requestFailed:(ZGTBaseRequest *)request {
    // 保存发生错误的请求
    _failedRequest = (ZGTRequest *)request;
    
    // 结束执行所有的Request
    for (ZGTRequest *req in _requests) {
        [req stop];
    }
    
    // 回调请求全部结束
    if ([_batchRequestDelegate respondsToSelector:@selector(batchRequest:didBasicRequestFailed:)]) {
        [_batchRequestDelegate batchRequest:self didBasicRequestFailed:(ZGTRequest *)request];
    }

    // 清除缓存数据
    [[__ZGTBatchRequestCache sharedInstance] removeBatchRequest:self];
}

@end
