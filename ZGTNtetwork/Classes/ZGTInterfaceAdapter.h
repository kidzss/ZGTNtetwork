//
//  ZGTInterfaceAdapter.h
//  ZGTNtetwork
//
//  Created by kidzss on 05/09/2020.
//  Copyright (c) 2020 kidzss. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ZGTGlobalDef.h"

/**
 *  暴露给主工程的网络层适配器
 */
@protocol ZGTInterfaceAdapter <NSObject>
@optional

/**
 *  通过主工程调用Commom层打印log
 *
 *  @param level   log级别
 *  @param module  log模块
 *  @param content log内容
 */
- (void)ZGTInterfaceLogAdapterWithLevel:(ZGTLogOutputLevel)level
                                    module:(NSString *__nonnull)module
                                   content:(NSString *__nullable)content;

@end

/**
 *  管理协议实现类对象
 */
@interface ZGTInterfaceAdapter : NSObject

@property (nonatomic, weak, nullable) id<ZGTInterfaceAdapter> delegate;

+ (instancetype __nonnull)sharedInstance;

@end
