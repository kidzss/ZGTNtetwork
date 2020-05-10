//
//  ZGTRequestConfig.h
//  ZGTNtetwork
//
//  Created by kidzss on 05/09/2020.
//  Copyright (c) 2020 kidzss. All rights reserved.
//

#import <Foundation/Foundation.h>

@class ZGTBaseRequest;
@class AFSecurityPolicy;

/**
 *  对指定URL进行过滤重定向
 */
@protocol ZGTReuqestURLFilter <NSObject>
@optional
- (NSString *)filterForOriginURL:(NSString *)originPath withRequest:(ZGTBaseRequest *)req;
@end

/**
 *  对指定某些Request的缓存文件存放路径进行自定义
 */
//@protocol ZGTReuqestCacheJSONSavedPathFilter <NSObject>
//@optional
//- (NSString *)filterForOriginCacheFilePath:(NSString *)originPath withRequest:(ZGTBaseRequest *)req;
//@end

@interface ZGTRequestConfig : NSObject

@property (nonatomic, copy) NSString *baseURL;
@property (nonatomic, copy) NSString *cdnURL;
@property (strong, nonatomic) AFSecurityPolicy *securityPolicy;

- (void)addReuqestURLPathFilter:(id<ZGTReuqestURLFilter>)filter;
//- (void)addReuqestCacheJSONSavedPathFilter:(id<ZGTReuqestCacheJSONSavedPathFilter>)filter;

- (NSArray *)reuqestURLPathFilters;
//- (NSArray *)reuqestCacheJSONSavedPathFilters;

+ (instancetype)sharedInstance;

@end
