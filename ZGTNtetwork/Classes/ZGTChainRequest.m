//
//  ZGTChainRequest.m
//  ZGTNtetwork
//
//  Created by kidzss on 05/09/2020.
//  Copyright (c) 2020 kidzss. All rights reserved.
//

#import "ZGTChainRequest.h"
#import <pthread.h>
#import "ZGTRequest.h"

static pthread_mutex_t mutex;

/**
 *  负责持有临时创建的ChainRequest对象，避免在执行期间被废弃
 */
@interface __ZGTChainRequestCache : NSObject

+ (instancetype)sharedInstance;
- (void)addChainRequest:(ZGTChainRequest *)request;
- (void)removeChainRequest:(ZGTChainRequest *)request;

@end

@implementation __ZGTChainRequestCache {
    NSMutableArray *_chainRequests;
}

+ (instancetype)sharedInstance {
    static __ZGTChainRequestCache *_cache = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _cache = [[__ZGTChainRequestCache alloc] init];
    });
    return _cache;
}

- (instancetype)init {
    if (self = [super init]) {
        pthread_mutex_init(&mutex, NULL);
        _chainRequests = [[NSMutableArray alloc] initWithCapacity:16];
    }
    return self;
}

- (void)addChainRequest:(ZGTChainRequest *)request {
    pthread_mutex_lock(&mutex);
    if (request) {
        [_chainRequests addObject:request];
    }
    pthread_mutex_unlock(&mutex);
}

- (void)removeChainRequest:(ZGTChainRequest *)request {
    pthread_mutex_lock(&mutex);
    if (request) {
        [_chainRequests removeObject:request];
    }
    pthread_mutex_unlock(&mutex);
}

@end

@interface ZGTChainRequest () <ZGTRequestCompletDelegate>

@property (nonatomic, weak, nullable, readwrite) id<ZGTChainRequestDelegate> chainRequestDelegate;

@end

@implementation ZGTChainRequest {
    NSInteger _curExecuteReqIndex;
    ChainRequestCallbackBlock _emptyBlock;
    NSMutableArray <ChainRequestCallbackBlock>*_callbackBlocks;
    NSMutableArray <ZGTRequest *>*_requests;
}

- (void)dealloc {
    _emptyBlock = nil;
    _callbackBlocks = nil;
    _requests = nil;
#ifdef DEBUG
    NSLog(@"ChainRequest %@ is dealloc", self);
#endif
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _curExecuteReqIndex = 0;
        _emptyBlock = ^(ZGTChainRequest *__nonnull chainReq, ZGTRequest *__nonnull basicReq){};
        _callbackBlocks = [[NSMutableArray alloc] initWithCapacity:16];
        _requests = [[NSMutableArray alloc] initWithCapacity:16];
    }
    return self;
}

- (void)addBasicRequest:(ZGTRequest *)req
didBasicRequestFinished:(ChainRequestCallbackBlock)didFinish {
    if (req) {
        [_requests addObject:req];
    }
    
    if (didFinish) {
        [_callbackBlocks addObject:[didFinish copy]];
    } else {
        [_callbackBlocks addObject:_emptyBlock];
    }
}

- (void)startWithDelegate:(id<ZGTChainRequestDelegate>)delegate {
    _chainRequestDelegate = delegate;
    
    if (_curExecuteReqIndex > 0) {// 已经正在开始请求
#ifdef DEBUG
        NSLog(@"链式请求已经开始执行");
#endif
        return;
    }

    if ((_requests.count > 0) && (_callbackBlocks.count > 0) && (_requests.count == _callbackBlocks.count)) {
        [self startNextRequest];
        [[__ZGTChainRequestCache sharedInstance] addChainRequest:self];
    } else {
        // Error! Chain request array is empty or count is not match
    }
}

- (void)stop {
    _chainRequestDelegate = nil;
    
    // 取出当链中前被执行的Request，停止继续执行，即后面的Request都不会再执行
    NSInteger curRunningRequestIndex = _curExecuteReqIndex - 1;
    if ((curRunningRequestIndex > -1) && (curRunningRequestIndex < _requests.count)) {
        ZGTRequest *req = [_requests objectAtIndex:curRunningRequestIndex];
        [req stop];
    }
    
    // 清除所有的缓存数据
    [_callbackBlocks removeAllObjects];
    [_requests removeAllObjects];
    
    [[__ZGTChainRequestCache sharedInstance] removeChainRequest:self];
}

- (NSArray *)basicRequests {
    return [_requests copy];
}

- (BOOL)startNextRequest {
    if ((_curExecuteReqIndex > -1) && (_curExecuteReqIndex < _requests.count)) {
        // 继续执行下一个链式Request
        ZGTRequest *req = [_requests objectAtIndex:_curExecuteReqIndex];
        _curExecuteReqIndex += 1;
        req.requestDelegate = self;
        [req startWithDelegate:self];
        return YES;
    }
    
    // 所有链式Request执行完毕
    return NO;
}

#pragma mark - ZGTRequestCompletDelegate

/**
 *  链中的某一个Request正常执行结束，接着继续执行下一个依赖的Request，一直到所有的执行完毕或错误结束
 */
- (void)requestSuccessed:(ZGTBaseRequest *)request {
    // 取出上一个正常结束的Request回调Block
    NSInteger curFinishedRequestIndex = _curExecuteReqIndex - 1;
    if ((curFinishedRequestIndex > -1) && (curFinishedRequestIndex < _requests.count)) {
        // 响应数据处理、添加下一个依赖的Request对象
        ChainRequestCallbackBlock block = [_callbackBlocks objectAtIndex:curFinishedRequestIndex];
        if (block != _emptyBlock) {
            block(self, (ZGTRequest *)request);
        }
        
        // 是否还有后续的依赖Request对象执行
        if (![self startNextRequest]) {
            // 回调请求全部结束
            if ([_chainRequestDelegate respondsToSelector:@selector(chainRequestDidSuccessFinish:)]) {
                [_chainRequestDelegate chainRequestDidSuccessFinish:self];
            }
            
            // 清除请求缓存
            [_callbackBlocks removeAllObjects];
            [_requests removeAllObjects];
            [[__ZGTChainRequestCache sharedInstance] removeChainRequest:self];
        }
    }
}

/**
 *  链中某一个Request错误执行结束，则停止后续所有的Request结束
 */
- (void)requestFailed:(ZGTBaseRequest *)request {
    // 回调请求全部结束
    if ([_chainRequestDelegate respondsToSelector:@selector(chainRequest:didBasicRequestFailed:)]) {
        [_chainRequestDelegate chainRequest:self didBasicRequestFailed:(ZGTRequest *)request];
    }
    
    // 清除请求缓存
    [_callbackBlocks removeAllObjects];
    [_requests removeAllObjects];
    [[__ZGTChainRequestCache sharedInstance] removeChainRequest:self];
}

@end

