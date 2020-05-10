//
//  ZGTRequestDispatcher.h
//  ZGTNtetwork
//
//  Created by kidzss on 05/09/2020.
//  Copyright (c) 2020 kidzss. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 *  LRU结构中的一个节点，这个类是框架内部使用
 */
@interface __ZGTDispatcherLRUNode : NSObject {
    @package
    // 节点之间不进行强引用，由Map对象强引用所有节点
    __unsafe_unretained __ZGTDispatcherLRUNode *_prev;
    __unsafe_unretained __ZGTDispatcherLRUNode *_next;
    NSUInteger                                      _cost;
    NSTimeInterval                                  _lastTime;//最后使用时间
    NSTimeInterval                                  _aliveTime;//存活时间
    NSString                                        *_key;//缓存文件名
    id                                              _value;//json
    NSNumber                                        *_version;//缓存版本
}

@end

@class ZGTBaseRequest;

@interface ZGTRequestDispatcher : NSObject

+ (instancetype)sharedInstance;

/**
 *  入队调度单个基本请求
 */
- (void)enqueRequest:(ZGTBaseRequest *)req;

/**
 *  取消入队调度的单个基本请求
 */
- (void)cancelRequest:(ZGTBaseRequest *)req;

/**
 *  删除所有的入队请求
 */
- (void)cancelAllRequests;

//如下函数，框架调用者不需要去使用，是框架内部使用的
- (NSString *)buildRequestURL:(ZGTBaseRequest *)req;
- (__ZGTDispatcherLRUNode *)cacheNodeWithCacheFileName:(NSString *)cacheFileName;
- (void)setRecentUseCacheNode:(__ZGTDispatcherLRUNode *)node;
- (void)createNewCacheNodeWithRequest:(ZGTBaseRequest *)req json:(id)json;

@end
