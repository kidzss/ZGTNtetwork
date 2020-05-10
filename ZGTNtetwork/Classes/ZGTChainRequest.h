//
//  ZGTChainRequest.h
//  ZGTNtetwork
//
//  Created by kidzss on 05/09/2020.
//  Copyright (c) 2020 kidzss. All rights reserved.
//

#import <Foundation/Foundation.h>

@class ZGTRequest;
@class ZGTChainRequest;

NS_ASSUME_NONNULL_BEGIN

typedef void (^ChainRequestCallbackBlock)(ZGTChainRequest * chainReq, ZGTRequest * basicReq);

@protocol ZGTChainRequestDelegate <NSObject>
@optional

/**
 *  Chain链中的所有Request全部正常执行完毕回调
 *  - RequestA 执行完毕之后并且没有错误，才会开始执行RequestB
 *  - 过程是顺序步骤执行，所以不涉及线程安全问题
 */
- (void)chainRequestDidSuccessFinish:(ZGTChainRequest *)chainReq;

/**
 *  Chain链中某一个Request执行失败
 *
 *  @param chainReq 链式Request
 *  @param request  某一个基本的Reuqest
 */
- (void)chainRequest:(ZGTChainRequest *)chainReq didBasicRequestFailed:(ZGTRequest *)request;

@end

/**
 *  提供链式的Request
 */
@interface ZGTChainRequest : NSObject

@property (nonatomic, weak, nullable, readonly) id<ZGTChainRequestDelegate> chainRequestDelegate;

/**
 *  向链中添加基本Request对象
 */
- (void)addBasicRequest:(ZGTRequest *)req didBasicRequestFinished:(ChainRequestCallbackBlock)didFinish;

- (void)startWithDelegate:(id<ZGTChainRequestDelegate>)delegate;
- (void)stop;

/**
 *  返回链中所有的基本Request
 */
- (NSArray *)basicRequests;

@end

NS_ASSUME_NONNULL_END
