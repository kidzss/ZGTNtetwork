//
//  ZGTRequest.m
//  ZGTNtetwork
//
//  Created by kidzss on 05/09/2020.
//  Copyright (c) 2020 kidzss. All rights reserved.
//

#import "ZGTRequest.h"
#import <YYModel/YYModel.h>
#import "ZGTGlobalDef.h"
#import "ZGTRequestConfig.h"
#import "ZGTRequestDispatcher.h"
#import <CommonCrypto/CommonDigest.h>

void ZGTLog(NSString *format, ...) {
#ifdef DEBUG
    va_list argptr;
    va_start(argptr, format);
    NSLogv(format, argptr);
    va_end(argptr);
#endif
}

NSString * MD5StringFromString(NSString *string) {
    if(string == nil || [string length] == 0)
        return nil;
    
    const char *value = [string UTF8String];
    
    unsigned char outputBuffer[CC_MD5_DIGEST_LENGTH];
    CC_MD5(value, (CC_LONG)strlen(value), outputBuffer);
    
    NSMutableString *outputString = [[NSMutableString alloc] initWithCapacity:CC_MD5_DIGEST_LENGTH * 2];
    for(NSInteger count = 0; count < CC_MD5_DIGEST_LENGTH; count++){
        [outputString appendFormat:@"%02x",outputBuffer[count]];
    }
    
    return outputString;
}

NSString *BaseDirectory() {
    static NSString *path = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSArray *pathcaches=NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
        NSString* cacheDirectory  = [pathcaches objectAtIndex:0];
        path = [cacheDirectory stringByAppendingPathComponent:kCachedDataFolderName];
        
        NSError *error = nil;
        [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:&error];
        
        if (error) {
            NSString *errMsg = [error localizedDescription];
            ZGTLog(@"BaseDirectory(): create BaseDirectory faild %@", errMsg);
        } else {
            NSURL *url = [NSURL fileURLWithPath:path];
            NSError *error = nil;
            [url setResourceValue:[NSNumber numberWithBool:YES] forKey:NSURLIsExcludedFromBackupKey error:&error];
        }
    });
    return path;
}

// 缓存response data文件的路径
NSString *CacheFileAbsolutePathWithCacheFileName(NSString *cacheFileName) {
    if (!cacheFileName) return nil;
    NSString *baseDir = BaseDirectory();
    NSString *absolutePath = [baseDir stringByAppendingPathComponent:cacheFileName];
    return absolutePath;
}

// 缓存response data版本文件的路径
NSString *CacheVersionFileAbsolutePathWithCacheFileName(NSString *cacheFileName) {
    if (!cacheFileName) return nil;
    NSString *baseDir = BaseDirectory();
    NSString *absolutePath = [baseDir stringByAppendingPathComponent:cacheFileName];
    absolutePath = [NSString stringWithFormat:@"%@.version", absolutePath];
    return absolutePath;
}

dispatch_queue_t FileOpertionQueue() {
    static dispatch_queue_t _queue = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _queue = dispatch_queue_create("com.ZGTRequest.serialQueue", DISPATCH_QUEUE_SERIAL);
    });
    return _queue;
}

typedef NS_ENUM(NSInteger, KCachedJSONFrom) {
    KCachedJSONFromMemory           = 1,
    KCachedJSONFromDiskFile,
};

@implementation ZGTRequest {
    BOOL                _isDataFromCache;       // 标记 `当前Request对象` 的response数据是来自缓存
    id                  _cachedJSON;            //只有当[self cachedJSON]消息发送，才会被设置数据
    KCachedJSONFrom     _cacheFrom;
}

- (id)cachedJSON {
//    if (_cachedJSON) {
//        return _cachedJSON;
//    } else {
    
        // 内存缓存
//        id json = [[ZGTRequestDispatcher sharedInstance] cacheMemoryJSONWithRequest:self];
//        if (json) {
//            _cachedJSON = json;
//            _cacheFrom = KCachedJSONFromMemory;
//            return _cachedJSON;
//        }
//        
//        // 磁盘文件缓存
//        __block id _jsonFromCache = nil;
//        NSString *cacheFileName = [self cacheFileName];
//        NSString *cacheFilePath = CacheFileAbsolutePathWithCacheFileName(cacheFileName);
//        dispatch_sync(FileOpertionQueue(), ^{
//            _jsonFromCache = [NSKeyedUnarchiver unarchiveObjectWithFile:cacheFilePath];
//        });
//        if (_jsonFromCache) {
//            _cachedJSON = _jsonFromCache;
//            _cacheFrom = KCachedJSONFromDiskFile;
//            return _cachedJSON;
//        }
//        
//        return nil;
//    }
    return _cachedJSON;
}

- (BOOL)isDataFromCache {
    return _isDataFromCache;
}

// 缓存版本过期
- (BOOL)isCacheVersionExpired {
    long long cacheVersion = [self cacheVersionFileContent];
    long long requestVersion = [self cacheVersion];
//    return (requestVersion > cacheVersion);
    if (cacheVersion != requestVersion) return YES;
    else return NO;
}

- (void)startWithoutCache {
    [super start];
}

#pragma mark - overrides

- (NSTimeInterval)cacheDurationTime {
    return -1;
}

- (long long)cacheVersion { return 0.0;}

- (void)start {
    
    // 是否忽略缓存数据
    if (_ignoreCache) {
        [super start];
        return;
    }
    
    // Request对象没有启用缓存
    NSTimeInterval cacheDurationTime = [self cacheDurationTime];
    if (cacheDurationTime < 0) {
        [super start];
        return;
    }
    
    NSString *cacheFileName = [self cacheFileName];
    __ZGTDispatcherLRUNode *node = [[ZGTRequestDispatcher sharedInstance] cacheNodeWithCacheFileName:cacheFileName];
    // 先找内存缓存
    if (node) {
        // 内存缓存已经超时
        NSTimeInterval last = node->_lastTime;
        NSTimeInterval durate = CACurrentMediaTime() - last;
        if (durate > cacheDurationTime) {
            [super start];
            return;
        }
        
        //TODO: 需要判断内存缓存的版本
        
        // 调整命中的缓存项到LRU表头作为最新的缓存
        [[ZGTRequestDispatcher sharedInstance] setRecentUseCacheNode:node];
        
        // 将缓存数据设置给当前新的Request对象
        _cachedJSON = node->_value;
        
    } else {
        // 再找磁盘文件缓存
        NSString *cacheFilePath = CacheFileAbsolutePathWithCacheFileName(cacheFileName);
        
        // 缓存文件不存在
        if (![[NSFileManager defaultManager] fileExistsAtPath:cacheFilePath]) {
            [super start];
            return;
        }
        
        // 缓存文件版本不一致
        long long cacheVersion = [self cacheVersionFileContent];
        long long requestVersion = [self cacheVersion];
        if (cacheVersion != requestVersion) {
            [super start];
            return;
        }
        
        // 文件缓存已经超时
        NSTimeInterval curDurate = [self cachefileLastModifyDurationForCacheFilePath:cacheFilePath];
        NSTimeInterval reqDurate = [self cacheDurationTime];
        if (reqDurate < 0 || (curDurate > reqDurate)) {
            [super start];
            return;
        }
        
        // 读取磁盘文件缓存
        __block id _jsonFromCache = nil;
        dispatch_sync(FileOpertionQueue(), ^{
            _jsonFromCache = [NSKeyedUnarchiver unarchiveObjectWithFile:cacheFilePath];
        });
        
        if (!_jsonFromCache) {
            [super start];
            return;
        }
            
        // 将缓存数据设置给当前新的Request对象
        _cachedJSON = _jsonFromCache;
        
        // 将文件缓存data重新调入到内存
        [[ZGTRequestDispatcher sharedInstance] createNewCacheNodeWithRequest:self json:_cachedJSON];
    }
    
    // 手动将当前新的Request对象标记为response数据来自缓存
    _isDataFromCache = YES;
    
    // 被标记response数据来自缓存，所以不再执行写入cache文件
    [self requestCompleteFilter];
    
    // 回传来自缓存的数据结束此次请求
    struct ZGTRequestCompletDelegateFlag flag = [self requestCompletFlag];
    if (flag.requestSuccessed) {
        [self.requestDelegate requestSuccessed:self];
    }
    if (self.successBlock) {
        self.successBlock(self);
    }
    
    //【一定要写这句代码】 解除req.block对外部对象的strong引用
    [self clearCompletionBlocks];
}

- (id)responseModelObject {
    id json = [self responseJSON];
    if (json) {
        Class modelCls = [self responseClass];
        if (modelCls) {
            return [modelCls yy_modelWithJSON:json];
        }
    }
    return nil;
}

// 重写父类实现，添加缓存json读取逻辑
- (id)responseJSON {
    if (_cachedJSON) return _cachedJSON;
    return [super responseJSON];
}

- (void)requestCompleteFilter {
    [super requestCompleteFilter];
}

- (void)dealloc {
    ZGTLog(@"ZGTRequest dealloc: %p", self);
}

#pragma mark - tools

- (NSString *)cacheFileName {
    NSString *requestUrl = [self requestURL];
    NSString *baseUrl = [ZGTRequestConfig sharedInstance].baseURL;
    id argument = [self cacheFileNameFilterForRequestArgument:[self requestArgument]];
    
    NSString *requestInfo = nil;
    if ([self requestApiType] == ZGTRequestAPITypeRestfull) {
        requestInfo = [NSString stringWithFormat:@"Method:%ld Host:%@ Path:%@ Argument:%@ AppVersion:%@",(long)[self requestMethod], baseUrl, requestUrl,argument, ZGT_AppVersion];
    } else {
        requestInfo = [NSString stringWithFormat:@"Method:%ld Host:%@ Action:%@ Controller:%@ Argument:%@ AppVersion:%@",(long)[self requestMethod], baseUrl, [self requestAction], [self requestController], argument, ZGT_AppVersion];
    }
    
    // MD5之后作为文件名或缓存key
    NSString *cacheFileName = MD5StringFromString(requestInfo);
//    ZGTLog(@"cacheFileName: %@", cacheFileName);
    
    return cacheFileName;
}

// 读取缓存数据版本文件中的版本号
- (long long)cacheVersionFileContent {
    NSString *cacheFileName = [self cacheFileName];
    NSString *cacheVersionFilepath = CacheVersionFileAbsolutePathWithCacheFileName(cacheFileName);
    if (!cacheVersionFilepath) return 0.0;
    if (![[NSFileManager defaultManager] fileExistsAtPath:cacheVersionFilepath]) return 0.0;
    
    __block NSNumber *num = nil;
    dispatch_sync(FileOpertionQueue(), ^{
        num = [NSKeyedUnarchiver unarchiveObjectWithFile:cacheVersionFilepath];
    });
    if (!num || ![num isKindOfClass:[NSNumber class]]) return 0.0;
    return num.longLongValue;
}

- (NSTimeInterval)cachefileLastModifyDuration {
    NSString *cacheFileName = [self cacheFileName];
    NSString *cacheFilepath = CacheFileAbsolutePathWithCacheFileName(cacheFileName);
    return [self cachefileLastModifyDurationForCacheFilePath:cacheFilepath];
}

// 文件最后一次被修改时间与当前时间间隔，返回-1表示没有时间间隔
- (NSTimeInterval)cachefileLastModifyDurationForCacheFilePath:(NSString *)filepath {
    if (!filepath) return -1;
    
    NSError *error = nil;
    NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:filepath error:&error];
    
    if (error) {
        NSString *errMsg = [error localizedDescription];
        ZGTLog(@"cachefileLastModifyDurationForCacheFile: read cachefile attributes faild %@", errMsg);
        return -1;
    }
    
    NSTimeInterval seconds = -[[attributes fileModificationDate] timeIntervalSinceNow];
    return seconds;
}

//- (void)saveJsonResponseToCacheFile:(id)responseJSON {
//    
//    // 没有设置大于0的缓存超时时间，即不使用缓存
//    BOOL isDisableCache = [self cacheDurationTime] <= 0;
//    
//    // 必须开启缓存，并且不能来自缓存的response data
//    if (!isDisableCache && !_isDataFromCache) {
//        
//        if (!responseJSON) {
//            ZGTLog(@"saveJsonResponseToCacheFile: no exist responseJSON");
//            return;
//        }
//        
//        NSNumber *version = @([self cacheVersion]);
//        NSString *cacheFileName = [self cacheFileName];
//        NSString *cacheDataFilePath = CacheFileAbsolutePathWithCacheFileName(cacheFileName);
//        NSString *cacheVersionFilePath = CacheVersionFileAbsolutePathWithCacheFileName(cacheFileName);
//        
//        dispatch_async(FileOpertionQueue(), ^{
//            [NSKeyedArchiver archiveRootObject:responseJSON toFile:cacheDataFilePath];//写入response data
//            [NSKeyedArchiver archiveRootObject:version toFile:cacheVersionFilePath];//写入version number
//        });
//    }
//}
//
//- (void)removeJsonResponseCacheFile {
//    NSString *cacheFileName = [self cacheFileName];
//    NSString *cacheDataFilePath = CacheFileAbsolutePathWithCacheFileName(cacheFileName);
//    NSString *cacheVersionFilePath = CacheVersionFileAbsolutePathWithCacheFileName(cacheFileName);
//    dispatch_async(FileOpertionQueue(), ^{
//        [[NSFileManager defaultManager] removeItemAtPath:cacheDataFilePath error:nil];
//        [[NSFileManager defaultManager] removeItemAtPath:cacheVersionFilePath error:nil];
//    });
//}

@end
