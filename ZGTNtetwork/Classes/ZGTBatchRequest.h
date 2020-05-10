//
//  ZGTBatchRequest.h
//  ZGTNtetwork
//
//  Created by kidzss on 05/09/2020.
//  Copyright (c) 2020 kidzss. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class ZGTRequest;
@class ZGTBatchRequest;

@protocol ZGTBatchRequestDelegate <NSObject>
@optional

/**
 *  全部的请求都正确执行结束
 */
- (void)batchRequestDidSuccessFinish:(ZGTBatchRequest *)batchRequest;

/**
 *  其中某一个请求错误执行结束
 *
 *  @param batchReq 所有的批量请求
 *  @param request  发生错误的请求
 */
- (void)batchRequest:(ZGTBatchRequest *)batchReq didBasicRequestFailed:(ZGTRequest *)request;

@end

/**
 *  提供批量的Request
 */
@interface ZGTBatchRequest : NSObject

/**
 *  发生错误的请求
 */
@property (nonatomic, strong, readonly) ZGTRequest *failedRequest;
@property (nonatomic, assign) NSInteger tag;

- (instancetype)initWithBasicRequestArray:(NSArray *)requestArray;
- (void)startWithDelegate:(id<ZGTBatchRequestDelegate>)delegate;
- (void)stop;

@end

NS_ASSUME_NONNULL_END
