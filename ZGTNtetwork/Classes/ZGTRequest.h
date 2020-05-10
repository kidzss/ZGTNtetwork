//
//  ZGTRequest.h
//  ZGTNtetwork
//
//  Created by kidzss on 05/09/2020.
//  Copyright (c) 2020 kidzss. All rights reserved.
//

#import "ZGTBaseRequest.h"


#pragma clang diagnostic push
#pragma clang diagnostic ignored"-Wunused-function"

static NSString *const kCachedDataFolderName = @"ZGTRequestCaches";
void ZGTLog(NSString *format, ...);
NSString * MD5StringFromString(NSString *string);
NSString *CacheFileAbsolutePathWithCacheFileName(NSString *cacheFileName);
NSString *CacheVersionFileAbsolutePathWithCacheFileName(NSString *cacheFileName);
extern dispatch_queue_t FileOpertionQueue(void);

#pragma clang diagnostic pop

/**
 *  提供Request响应数据的缓存，所有的Request父类
 */
@interface ZGTRequest : ZGTBaseRequest

// 设置忽略缓存数据
@property (nonatomic, assign) BOOL ignoreCache;

////////////////////// 子类重写的方法 //////////////////////////

//返回时间 <= 0 即不使用缓存
- (NSTimeInterval)cacheDurationTime;

//重写此方法获取与该值相等的版本缓存数据，并使用这个值作为后续缓存response json的版本号
- (long long)cacheVersion;

////////////////////// 工具方法（不要重写） //////////////////////////

//查询缓存的response json
- (id)cachedJSON;

//response json是否来自缓存
- (BOOL)isDataFromCache;

//缓存是否版本过期
- (BOOL)isCacheVersionExpired;

// 不适用缓存进行网络请求
- (void)startWithoutCache;

//将此次请求得到的最新response json缓存到磁盘文件
//- (void)saveJsonResponseToCacheFile:(id)jsonResponse;
//- (void)removeJsonResponseCacheFile;

//- (id)cacheSensitiveData;

// 内存缓存的唯一标示 与 磁盘缓存文件的唯一文件名
- (NSString *)cacheFileName;

// 缓存版本
- (long long)cacheVersionFileContent;
// 缓存文件最后修改时间与当前时间的差值
- (NSTimeInterval)cachefileLastModifyDuration;
- (NSTimeInterval)cachefileLastModifyDurationForCacheFilePath:(NSString *)filepath;

@end
