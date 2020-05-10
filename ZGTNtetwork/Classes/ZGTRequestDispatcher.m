//
//  ZGTRequestDispatcher.m
//  ZGTNtetwork
//
//  Created by kidzss on 05/09/2020.
//  Copyright (c) 2020 kidzss. All rights reserved.
//

#import "ZGTRequestDispatcher.h"
#import <pthread.h>
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>

#import <AFNetworking/AFNetworking.h>
#import "ZGTRequestConfig.h"
#import "ZGTRequest.h"
#import "ZGTInterfaceAdapter.h"


static pthread_mutex_t mutex_t;

/**
 *  最大的缓存项个数
 */
static const NSInteger kMaxCacheNodeCount = 20;

/**
 *  最大缓存开销，20M
 */
//static const NSUInteger kMaxCacheMemoryCost = 1024 * 1024 * 20;

@implementation __ZGTDispatcherLRUNode

-(NSString *)description {
    
#pragma clang diagnostic push
#pragma clang diagnostic ignored"-Wformat"
    return [NSString stringWithFormat:@"<%@ - %p> _prev = %p, _next = %p, _cost = %lu, _key = %@", [self class], self, _prev, _next, _cost, _key];
#pragma clang diagnostic pop
}

- (NSString *)debugDescription {
    return [self description];
}

@end

/**
 *  LRU结构实例，淘汰对象策略:
 *  - 最新使用的对象，使用头插法查到表头
 *  - 表末尾的节点是每次被淘汰的缓存对象
 *  - 中间的节点被使用后，调到表头
 */
@interface __ZGTDispatcherLRUNodeMap : NSObject {
    @package
  
    /**
     *  所有的Node对象都只由这个Dic持有，即所有node.retainCoutn == 1，除tail和head
     *  - key: __ZGTDispatcherLRUNode对象->_key
     *  - value: __ZGTDispatcherLRUNode对象
     */
    CFMutableDictionaryRef _cacheDic;
    __ZGTDispatcherLRUNode __strong *_head;//retain节点，在最后release
    __ZGTDispatcherLRUNode __strong *_tail;//retain节点，在最后release

    NSUInteger _totalCost;
    NSUInteger _totalCount;
    BOOL _releaseNodeOnMainThread;//是否在主线程执行释放对象
    BOOL _releaseAsynchronously;//是否异步释放容器对象
}

- (void)insertNodeAtHead:(__ZGTDispatcherLRUNode *)node;
- (void)bringNodeToHead:(__ZGTDispatcherLRUNode *)node;
- (void)removeNode:(__ZGTDispatcherLRUNode *)node;
- (__ZGTDispatcherLRUNode *)removeTailNode;
- (void)removeAll;

- (void)_debugAllNodes;

@end
@implementation __ZGTDispatcherLRUNodeMap

- (void)dealloc {
    _cacheDic = nil;
}

- (instancetype)init {
    if (self = [super init]) {
        _cacheDic = CFDictionaryCreateMutable(CFAllocatorGetDefault(), 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
        _totalCost = 0;
        _totalCount = 0;
        _head = nil;
        _tail = nil;
        _releaseNodeOnMainThread = NO;
        _releaseAsynchronously = YES;//异步释放node对象
    }
    return self;
}

- (void)insertNodeAtHead:(__ZGTDispatcherLRUNode *)node {
    if (!node) return;
    NSString *key = node->_key ? node->_key : @"";
    CFDictionarySetValue(_cacheDic, (__bridge const void *)key, (__bridge const void *)(node));
    _totalCost += node->_cost;
    _totalCount++;
    if (_head) {
        node->_next = _head;
        _head->_prev = node;
        _head = node;
    } else {
        _head = _tail = node;
    }
}

- (void)bringNodeToHead:(__ZGTDispatcherLRUNode *)node {
    if (!node) return;
    if (node == _head) return;
    if (_tail == node) {
        _tail = node->_prev;
        _tail->_next = nil;
    } else {
        node->_next->_prev = node->_prev;
        node->_prev->_next = node->_next;
    }
    node->_next = _head;
    node->_prev = nil;
    _head->_prev = node;
    _head = node;
}

- (void)removeNode:(__ZGTDispatcherLRUNode *)node {//传入的指针引用这node对象，retainCount==2
    if (!node) return;
    NSString *key = node->_key ? node->_key : @"";
    CFDictionaryRemoveValue(_cacheDic, (__bridge const void *)(key));//retainCount==1
    
    _totalCost -= node->_cost;
    _totalCount--;
    if (node->_next) node->_next->_prev = node->_prev;
    if (node->_prev) node->_prev->_next = node->_next;
    if (_head == node) _head = node->_next;
    if (_tail == node) _tail = node->_prev;
}//retainCount==0

- (__ZGTDispatcherLRUNode *)removeTailNode {
    if (!_tail) return nil;
    __ZGTDispatcherLRUNode *tail = _tail;//retainCount==2
    
    // 从缓存中移除
    NSString *key = tail->_key ? tail->_key : @"";
    CFDictionaryRemoveValue(_cacheDic, (__bridge const void *)(key));//retainCount==1
    
    _totalCost -= _tail->_cost;
    _totalCount--;
    if (_head == _tail) {
        _head = _tail = nil;
    } else {
        _tail = _tail->_prev;
        _tail->_next = nil;
    }
    return tail;
}//retainCount==0

- (void)removeAll {
    _totalCost = 0;
    _totalCount = 0;
    
    //执行[_head release]与[_tail release]，此时所有的node.retainCount == 1
    _head = nil;
    _tail = nil;
    
    // 异步子线程释放所有的缓存项
    if (CFDictionaryGetCount(_cacheDic) > 0) {
        CFMutableDictionaryRef _releaseDic = _cacheDic;//retainCount==2
        
        _cacheDic = CFDictionaryCreateMutable(CFAllocatorGetDefault(), 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);//retainCount==1，并使用新的缓存字典，因为内部对象是异步释放
        
        if (_releaseAsynchronously) {
            dispatch_async(dispatch_get_global_queue(0, 0), ^{
                CFRelease(_releaseDic);//retainCount==0
            });
        } else if (_releaseNodeOnMainThread && !pthread_main_np()) {
            dispatch_async(dispatch_get_main_queue(), ^{
                CFRelease(_releaseDic);//retainCount==0
            });
        } else {
            CFRelease(_releaseDic);//retainCount==0
        }
    }
}

- (void)_debugAllNodes {
    __ZGTDispatcherLRUNode *node = _head;
    while (node) {
        ZGTLog(@"node.key = %@", node->_key);
        node = node->_next;
    }
}

@end

/**
 *  负责持有临时创建的ZGTBaseRequest对象，避免在执行期间被废弃
 *  - 一是记录Request对应的Task对象，二是为了防止局部创建的Reqiest对象被废弃
 *  - key: NSURLSessionTask对象.taskIdentifier（每一个Task对象的identifier肯定是不一样的）
 *  - value: ZGTBaseRequest对象
 */
@interface __ZGTRequestDispatcherContext : NSObject

// 持有ZGTBaseRequest对象
- (void)saveRequest:(ZGTBaseRequest *)req;
// 释放ZGTBaseRequest对象
- (void)removeRequestForTask:(NSURLSessionTask *)task;
- (id)requestForKey:(NSString *)key;
- (id)requestForTask:(NSURLSessionTask *)task;
- (NSArray *)allKeys;

@end

@implementation __ZGTRequestDispatcherContext {
    NSMutableDictionary *_cacheDic;
    // 使用队列记录依次入队的Request的key值
    NSMutableArray *_enqueKeys;
}

- (void)saveRequest:(ZGTBaseRequest *)req {
    if (!_cacheDic) {
        _cacheDic = [[NSMutableDictionary alloc] initWithCapacity:32];
    }
#pragma clang diagnostic push
#pragma clang diagnostic ignored"-Wformat"
    NSString *key = [NSString stringWithFormat:@"%lu", req.task.taskIdentifier];
#pragma clang diagnostic pop
    _cacheDic[key] = req;
    
    if (!_enqueKeys) {
        _enqueKeys = [[NSMutableArray alloc] initWithCapacity:32];
    }
    
    [_enqueKeys addObject:key];
}

- (void)removeRequestForTask:(NSURLSessionTask *)task {
#pragma clang diagnostic push
#pragma clang diagnostic ignored"-Wformat"
    if (!_cacheDic) {
        _cacheDic = [[NSMutableDictionary alloc] initWithCapacity:32];
    }
    NSString *key = [NSString stringWithFormat:@"%lu", task.taskIdentifier];
#pragma clang diagnostic pop
    
    id obj = [_cacheDic objectForKey:key];
    [_cacheDic removeObjectForKey:key];
    
    if (!_enqueKeys) {
        _enqueKeys = [[NSMutableArray alloc] initWithCapacity:32];
    }
    
    [_enqueKeys addObject:key];

    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        [obj hash];
    });
}

- (id)requestForKey:(NSString *)key {
    if (!key) {
        return nil;
    }
    
    ZGTBaseRequest *req = [_cacheDic objectForKey:key];
    return req;
}

- (ZGTBaseRequest *)requestForTask:(NSURLSessionTask *)task  {
    if (!task) {
        return nil;
    }
    
#pragma clang diagnostic push
#pragma clang diagnostic ignored"-Wformat"
    NSString *key = [NSString stringWithFormat:@"%lu", task.taskIdentifier];
#pragma clang diagnostic pop
    ZGTBaseRequest *req = [_cacheDic objectForKey:key];
    return req;
}

- (NSArray *)allKeys {
    NSArray *allKeys = [_enqueKeys copy];
    return allKeys;
}

@end

@interface ZGTBaseRequest ()

@property (nonatomic, strong, readwrite) NSURLSessionTask  *task;
@property (nonatomic, strong, readwrite) id                responseObject;

@end

@implementation ZGTRequestDispatcher {
    AFHTTPSessionManager *_sessionManager;
    ZGTRequestConfig *_netConfig;
    __ZGTRequestDispatcherContext *_ctx;
    __ZGTDispatcherLRUNodeMap *_lruMap;
    dispatch_queue_t _serialQueue;
    UIBackgroundTaskIdentifier _writeCacheFilesTaskIdentifier;
    NSMutableArray *_allKeys;
}

+ (instancetype)sharedInstance {
    static ZGTRequestDispatcher *_dispatcher = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _dispatcher = [[ZGTRequestDispatcher alloc] init];
    });
    return _dispatcher;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidEnterBackgroundNotification object:nil];
    [_lruMap removeAll];
    pthread_mutex_destroy(&mutex_t);
}

- (instancetype)init {
    if (self = [super init]) {
        _netConfig = [ZGTRequestConfig sharedInstance];
        _sessionManager = [AFHTTPSessionManager manager];
        _sessionManager.securityPolicy = _netConfig.securityPolicy;
        _ctx = [[__ZGTRequestDispatcherContext alloc] init];
        _lruMap = [[__ZGTDispatcherLRUNodeMap alloc] init];
        pthread_mutex_init(&mutex_t, NULL);
        _serialQueue = dispatch_queue_create("com.ZGTRequestDispatcher.serial.queueu", DISPATCH_QUEUE_SERIAL);
        _allKeys = [[NSMutableArray alloc] initWithCapacity:64];
        
        // 收到系统内存警告
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_appDidUnActiveNotification) name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
        // App即将退出
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_appDidUnActiveNotification) name:UIApplicationWillTerminateNotification object:nil];
        // App后台挂起
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_appDidUnActiveNotification) name:UIApplicationDidEnterBackgroundNotification object:nil];
    }
    return self;
}

- (void)_appDidUnActiveNotification {
    
    _writeCacheFilesTaskIdentifier = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        // 最多完成10分钟的任务
        [[UIApplication sharedApplication] endBackgroundTask:_writeCacheFilesTaskIdentifier];
        _writeCacheFilesTaskIdentifier = UIBackgroundTaskInvalid;
    }];
    
    
    CFIndex count = CFDictionaryGetCount(_lruMap->_cacheDic);
    CFTypeRef *keys = (CFTypeRef *)malloc(count * sizeof(CFTypeRef));
    CFTypeRef *values = (CFTypeRef *)malloc(count * sizeof(CFTypeRef));
    CFDictionaryGetKeysAndValues(_lruMap->_cacheDic, (const void **)keys, (const void **)values);
    
    for (NSInteger i = 0; i < count; i++) {
        NSString *cacheFileName = (__bridge NSString *)(keys[i]);
        __ZGTDispatcherLRUNode *node = (__bridge __ZGTDispatcherLRUNode *)(values[i]);
        
        id json = node->_value;
        NSNumber *version = node->_version;
        
        if (cacheFileName && json && version) {
            NSString *cacheDataFilePath = CacheFileAbsolutePathWithCacheFileName(cacheFileName);
            NSString *cacheVersionFilePath = CacheVersionFileAbsolutePathWithCacheFileName(cacheFileName);
            
            [NSKeyedArchiver archiveRootObject:json toFile:cacheDataFilePath];//写入response data
            [NSKeyedArchiver archiveRootObject:version toFile:cacheVersionFilePath];//写入version number
        }

    }
    
    free(keys);
    free(values);
    [_lruMap removeTailNode];
    
    [[UIApplication sharedApplication] endBackgroundTask:_writeCacheFilesTaskIdentifier];
    _writeCacheFilesTaskIdentifier = UIBackgroundTaskInvalid;
}

- (void)enqueRequest:(ZGTBaseRequest *)req {
    // 日志级别
    ZGTLogOutputLevel logLevel = [req requestLogLevel];
    
    // 组装参数字典
    ZGTRequestAPIType apiType = [req requestApiType];
    NSMutableDictionary *argumentDic = nil;//最终的参数字典
    id dataArgument = [req requestArgument];//普通参数
    id systemArgument = [req systemArgument];//系统参数
    
    if (apiType == ZGTRequestAPITypeMVC) {
        
        NSString *action = [[req requestAction] copy];
        NSString *controller = [[req requestController] copy];
        
        if (!action || !controller) {
            NSString *logInfo = [NSString stringWithFormat:@"[%@]Not config Request: %@",@"network",NSStringFromClass(req.class)];
            id<ZGTInterfaceAdapter> adapterDelegtae = [ZGTInterfaceAdapter sharedInstance].delegate;
            if ([adapterDelegtae respondsToSelector:@selector(ZGTInterfaceLogAdapterWithLevel:module:content:)]) {
                [adapterDelegtae ZGTInterfaceLogAdapterWithLevel:logLevel module:@"network" content:logInfo];
            }
            return;
        }
        
        NSMutableDictionary *tempArgument = [[NSMutableDictionary alloc] initWithCapacity:32];
        
        if (dataArgument && [dataArgument isKindOfClass:[NSDictionary class]]) {
            NSMutableDictionary *dataDic = [[NSMutableDictionary alloc] initWithDictionary:dataArgument];
            [dataDic setObject:action forKey:@"action"];
            [tempArgument setObject:dataDic forKey:@"data"];
        }
        
        if (systemArgument && [systemArgument isKindOfClass:[NSDictionary class]]) {
            NSMutableDictionary *systemDic = [[NSMutableDictionary alloc] initWithDictionary:systemArgument];
            [systemDic setObject:controller forKey:@"controller"];
            [tempArgument setObject:systemDic forKey:@"system"];
        }
        
        argumentDic = tempArgument;
    } else {
        argumentDic = dataArgument;
    }
    
    // 请求参数组装类型
    ZGTRequestSerializerType requestSerialType = [req requestSerialzerType];
    AFHTTPRequestSerializer *requestSerializer = nil;
    if (requestSerialType == ZGTRequestSerializerTypeHTTP) {
        requestSerializer = [AFHTTPRequestSerializer serializer];
    } else if (requestSerialType == ZGTRequestSerializerTypeJSON) {
        requestSerializer = [AFJSONRequestSerializer serializer];
    }
    _sessionManager.requestSerializer = requestSerializer;
    
    // 请求超时时间
    requestSerializer.timeoutInterval = [req requestTimeoutInterval];
    
    // 响应数据解析类型
    ZGTResponseSerializerType responseSerialType = [req responseSerialzerType];
    AFHTTPResponseSerializer *responseSerializer = nil;
    if (responseSerialType == ZGTResponseSerializerTypeHTTP) {
        responseSerializer = [AFHTTPResponseSerializer serializer];
    } else if (responseSerialType == ZGTResponseSerializerTypeJSON) {
        responseSerializer = [AFJSONResponseSerializer serializer];
    } else if (responseSerialType == ZGTResponseSerializerTypeXML) {
        responseSerializer = [AFXMLParserResponseSerializer serializer];
    }
    responseSerializer.acceptableContentTypes = [NSSet setWithObjects:@"application/json", @"text/plain", @"text/html",@"text/json",@"text/javascript", nil];
    _sessionManager.responseSerializer = responseSerializer;
    
    // 需要账号密码访问的api
    NSArray *authorizationHeaderFieldArray = [req requestAuthorizationHeaderFieldArray];
    if (authorizationHeaderFieldArray != nil && (authorizationHeaderFieldArray.count == 2)) {
        NSString *username = (NSString *)authorizationHeaderFieldArray.firstObject;
        NSString *password = (NSString *)authorizationHeaderFieldArray.lastObject;
        [requestSerializer setAuthorizationHeaderFieldWithUsername:username password:password];
    }
    
    // 请求头参数字典
    NSDictionary *headerFieldValueDictionary = [req requestHeaderFieldValueDictionary];
    if (headerFieldValueDictionary != nil) {
        for (id httpHeaderField in headerFieldValueDictionary.allKeys) {
            id value = headerFieldValueDictionary[httpHeaderField];
            if ([httpHeaderField isKindOfClass:[NSString class]] && [value isKindOfClass:[NSString class]]) {
                [requestSerializer setValue:(NSString *)value forHTTPHeaderField:(NSString *)httpHeaderField];
            } else {
                ZGTLog(@"Error, class of key/value in headerFieldValueDictionary should be NSString.");
            }
        }
    }
    
    // NSURLRequest构建、NSURLSessionTask构建
    NSURLSessionTask *task = nil;
//    NSURLRequest *urlRequest = [req buildCustomUrlRequest];
    ZGTRequestMethod httpMethod = [req requestMethod];
    ZGTRequestType requestType = [req requestType];
    NSString *host = [req host];
    NSString *logInfo = nil;
    
    // 响应回调线程
    if ([req responseThread] == ZGTResponseThreadTypeMainThread) {
        _sessionManager.completionQueue = nil;
    } else {
        _sessionManager.completionQueue = dispatch_get_global_queue(0, 0);
    }
    
    NSString *absoluteURL = [self buildRequestURL:req];
    __weak __typeof(self)weakSelf = self;
    if (ZGTRequestTypeDataTask == requestType) {
        switch (httpMethod) {
            case ZGTRequestMethodGET: {
                
                logInfo = [NSString stringWithFormat:@"[%@]get network request-->action:%@,controller:%@;machine_code:%@;session_id:%@;version:%@", @"network" ,[req requestAction], [req requestController], [systemArgument objectForKey:@"machine_code"],[systemArgument objectForKey:@"session_id"],[systemArgument objectForKey:@"new_version"]];
                
                task = [_sessionManager GET:absoluteURL parameters:argumentDic progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
                    __strong __typeof(weakSelf)strongSelf = weakSelf;
                    [strongSelf _handleRequestCompletWithDataTask:task responseObject:responseObject error:nil];
                } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
                    __strong __typeof(weakSelf)strongSelf = weakSelf;
                    [strongSelf _handleRequestCompletWithDataTask:task responseObject:nil error:nil];
                }];
                break;
            }
            case ZGTRequestMethodPOST: {
                
               logInfo = [NSString stringWithFormat:@"[%@]post network request-->action:%@,controller:%@;machine_code:%@;session_id:%@;version:%@", @"network" ,[req requestAction], [req requestController], [systemArgument objectForKey:@"machine_code"],[systemArgument objectForKey:@"session_id"],[systemArgument objectForKey:@"new_version"]];
                
                task = [_sessionManager POST:absoluteURL parameters:argumentDic progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
                    __strong __typeof(weakSelf)strongSelf = weakSelf;
                    [strongSelf _handleRequestCompletWithDataTask:task responseObject:responseObject error:nil];
                } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
                    __strong __typeof(weakSelf)strongSelf = weakSelf;
                    [strongSelf _handleRequestCompletWithDataTask:task responseObject:nil error:nil];
                }];
                break;
            }
        }
    } else if (ZGTRequestTypeDownload == requestType) {//TODO: 待完善
        if (kZGTRequestEnableDownload) {
            NSURLRequest *request = [req buildDownloadUrlRequest];
            NSURL *saveDataURL = [req saveDownloadDataUrl];
            if (request) {
                task = [_sessionManager downloadTaskWithRequest:request progress:^(NSProgress * _Nonnull downloadProgress) {
                    
                } destination:^NSURL * _Nonnull(NSURL * _Nonnull targetPath, NSURLResponse * _Nonnull response) {
                    return saveDataURL;
                } completionHandler:^(NSURLResponse * _Nonnull response, NSURL * _Nullable filePath, NSError * _Nullable error) {
                    
                
                }];
            }
        }
    } else if (ZGTRequestTypeUpload == requestType) {//TODO: 待完善
        if (kZGTRequestEnableUpload) {
            AFMultipartFormDataBlock block = [req multipartFormDataBlock];
            NSMutableURLRequest *request = [[AFHTTPRequestSerializer serializer] multipartFormRequestWithMethod:        @"POST" URLString:host parameters:argumentDic constructingBodyWithBlock:^(id<AFMultipartFormData> formData)
                                            {
                                                if (block) block(formData);
                                            } error:nil];
            
            task = [_sessionManager uploadTaskWithStreamedRequest:request progress:^(NSProgress * _Nonnull uploadProgress) {
                
            } completionHandler:^(NSURLResponse * _Nonnull response, id  _Nullable responseObject, NSError * _Nullable error) {
                
            }];
        }
    }
    
    req.task = task;
    
    // NSURLSessionTask的优先级设置
    ZGTRequestPriority priority = [req requestPriority];
    switch (priority) {
        case ZGTRequestPriorityLow: {
            task.priority = NSURLSessionTaskPriorityLow;
            break;
        }
        case ZGTRequestPriorityDefault: {
            task.priority = NSURLSessionTaskPriorityDefault;
            break;
        }
        case ZGTRequestPriorityHigh: {
            task.priority = NSURLSessionTaskPriorityHigh;
            break;
        }
    }
    
    // 启动Task
    [task resume];

    // 缓存Request对象
    pthread_mutex_lock(&mutex_t);
    [_ctx saveRequest:req];
    pthread_mutex_unlock(&mutex_t);
}

- (void)cancelRequest:(ZGTBaseRequest *)req {
    if (req.task.state == NSURLSessionTaskStateRunning || req.task.state == NSURLSessionTaskStateSuspended) {
        [req.task cancel];
    }
    
    pthread_mutex_lock(&mutex_t);
    [_ctx removeRequestForTask:req.task];
    pthread_mutex_unlock(&mutex_t);
}

- (void)cancelAllRequests {
    pthread_mutex_lock(&mutex_t);
    NSArray *allKeys = [_ctx allKeys];
    pthread_mutex_unlock(&mutex_t);
    
    for (NSString * key in allKeys) {
        ZGTRequest *req = [_ctx requestForKey:key];
        [[ZGTRequestDispatcher sharedInstance] cancelRequest:req];
    }
}

- (NSString *)buildRequestURL:(ZGTBaseRequest *)req {
    
    NSString *detailUrl = [req requestURL];
    if ([detailUrl hasPrefix:@"http://"] || [detailUrl hasPrefix:@"https://"]) {
        return detailUrl;
    }
    
    NSString *absoluteURL;

    NSString *cdnUrl_cfg = [_netConfig cdnURL];
    NSString *cdnUrl_req = [req cdnURL];
    BOOL isUseCDN = [req isUseCDN];
    NSString *host = [req host];
    
    if (isUseCDN) {
        if (cdnUrl_cfg.length > 0) {
            absoluteURL = cdnUrl_cfg;
        } else {
            absoluteURL = cdnUrl_req;
        }
    } else {
        if (host.length > 0) {
            absoluteURL = host;
        } else {
            absoluteURL = [req requestAbsoluteURL];
        }
    }
    
    absoluteURL = [NSString stringWithFormat:@"%@%@", absoluteURL, detailUrl];
    
    if ([req isUseHttps]) {
        absoluteURL = [absoluteURL lowercaseString];
        absoluteURL = [absoluteURL stringByReplacingOccurrencesOfString:@"http" withString:@"https"];
    }

    NSArray *urlFilters = [_netConfig reuqestURLPathFilters];
    for (id<ZGTReuqestURLFilter> filter in urlFilters) {
        absoluteURL = [filter filterForOriginURL:absoluteURL withRequest:req];
    }

    return absoluteURL;
}

#pragma mark - tools

- (BOOL)checkJson:(id)json withValidator:(id)validatorJson {
    // 二者不存在其一，json检查失败
    if (!json || !validatorJson) return NO;
    
    if ([json isKindOfClass:[NSDictionary class]] &&
        [validatorJson isKindOfClass:[NSDictionary class]]) {
        NSDictionary * dict = json;
        NSDictionary * validator = validatorJson;
        BOOL result = YES;
        NSEnumerator * enumerator = [validator keyEnumerator];
        NSString * key;
        while ((key = [enumerator nextObject]) != nil) {
            id value = dict[key];
            id format = validator[key];
            if ([value isKindOfClass:[NSDictionary class]]
                || [value isKindOfClass:[NSArray class]]) {
                result = [self checkJson:value withValidator:format];
                if (!result) {
                    break;
                }
            } else {
                if ([value isKindOfClass:format] == NO &&
                    [value isKindOfClass:[NSNull class]] == NO) {
                    result = NO;
                    break;
                }
            }
        }
        return result;
    } else if ([json isKindOfClass:[NSArray class]] &&
               [validatorJson isKindOfClass:[NSArray class]]) {
        NSArray * validatorArray = (NSArray *)validatorJson;
        if (validatorArray.count > 0) {
            NSArray * array = json;
            NSDictionary * validator = validatorJson[0];
            for (id item in array) {
                BOOL result = [self checkJson:item withValidator:validator];
                if (!result) {
                    return NO;
                }
            }
        }
        return YES;
    } else if ([json isKindOfClass:validatorJson]) {
        return YES;
    } else {
        return NO;
    }
}

/**
 *  检查网络请求响应结果是否合法
 *  - response status code
 *  - 如果是json响应结构，检测json结构是否返回合法
 */
- (BOOL)checkResultWithRequest:(ZGTBaseRequest *)req {
    // 响应code是否合法
    BOOL statusCodeValidator = [req statusCodeValidator];
    if (!statusCodeValidator) {
        return NO;
    }
    
    // 检测json结构是否正确
    if ([req responseSerialzerType] == ZGTResponseSerializerTypeJSON) {
        // json 响应结构
        id responseJSON = [req responseJSON];
        id jsonValidator = [req jsonValidator];
        
        if (responseJSON && jsonValidator) {
            return [self checkJson:responseJSON withValidator:jsonValidator];
        }
        return YES;
    }
    
    // 非json结构不检测
    return YES;
}

- (void)_removeCacheWithFileName:(NSString *)filename {
    if (!filename) return;
    NSString *dataFile = CacheFileAbsolutePathWithCacheFileName(filename);
    NSString *versionFile = CacheVersionFileAbsolutePathWithCacheFileName(filename);
    dispatch_async(FileOpertionQueue(), ^(){
        [[NSFileManager defaultManager] removeItemAtPath:dataFile error:nil];
        [[NSFileManager defaultManager] removeItemAtPath:versionFile error:nil];
    });
}

#pragma mark - handle network callback

// 处理DataTask
- (void)_handleRequestCompletWithDataTask:(NSURLSessionDataTask * __nullable)task
                           responseObject:(id  __nullable)responseObject
                                    error:(NSError * __nullable)error {
#pragma clang diagnostic push
#pragma clang diagnostic ignored"-Wformat"
    NSString *key = [NSString stringWithFormat:@"%lu", task.taskIdentifier];
#pragma clang diagnostic pop
    pthread_mutex_lock(&mutex_t);
    ZGTRequest *req = [_ctx requestForKey:key];
    pthread_mutex_unlock(&mutex_t);
    ZGTLog(@"Request <%@ - %p> is finished", req, req);
    
    // 日志打印
    if (!error) {
        ZGTLogOutputLevel logLevel = [req requestLogLevel];
        NSString *logInfo = [NSString stringWithFormat:@"[%@]network request post success-->action:%@,controller:%@",@"network",req.requestAction,req.requestController];
        id<ZGTInterfaceAdapter> adapterDelegtae = [ZGTInterfaceAdapter sharedInstance].delegate;
        if ([adapterDelegtae respondsToSelector:@selector(ZGTInterfaceLogAdapterWithLevel:module:content:)]) {
            [adapterDelegtae ZGTInterfaceLogAdapterWithLevel:logLevel module:@"network" content:logInfo];
        }
    } else {
        
        ZGTLogOutputLevel logLevel = [req requestLogLevel];
        NSString *logInfo = [NSString stringWithFormat:@"[%@]network request post fail-->action:%@,controller:%@",@"network",req.requestAction,req.requestController];
        id<ZGTInterfaceAdapter> adapterDelegtae = [ZGTInterfaceAdapter sharedInstance].delegate;
        if ([adapterDelegtae respondsToSelector:@selector(ZGTInterfaceLogAdapterWithLevel:module:content:)]) {
            [adapterDelegtae ZGTInterfaceLogAdapterWithLevel:logLevel module:@"network" content:logInfo];
        }
    }
    
    // will stop
    NSArray *accessorys = [req accessorys];
    for (id<ZGTRequestAccessory> accecory in accessorys) {
        if ([accecory respondsToSelector:@selector(requestWillStop:)]) {
            [accecory requestWillStop:req];
        }
    }
    
    struct ZGTRequestCompletDelegateFlag __flag = [req requestCompletFlag];
    if (req) {
        
        // Request对象正常结束
        //根据response serializer type变化，可能是data、json、xml...
        req.responseObject = responseObject;
        
        BOOL isSuccess = [self checkResultWithRequest:req];
        if (isSuccess) {
            ZGTLog(@"Request <%@ - @p> success finished, status code = %ld", req, req, req.responseStatusCode);
            
            // Request是否开启缓存
            BOOL isEnableCache = [req cacheDurationTime] > 0;
            if (isEnableCache) {
                
                // 将reponse json 使用内存缓存起来
                NSString *cacheFileName = [req cacheFileName];
                NSTimeInterval now = CACurrentMediaTime();
                
                if (cacheFileName) {
                    pthread_mutex_lock(&mutex_t);
                    
                    // 查询请求对应的内存缓存
                    __ZGTDispatcherLRUNode *node = CFDictionaryGetValue(_lruMap->_cacheDic, (__bridge const void *)(cacheFileName));
                    
                    if (node) {
                        
                        /**
                         *  已存在节点，先修改数据，再调整为头结点
                         */
                        _lruMap->_totalCost -= node->_cost;
                        node->_cost = class_getInstanceSize([req class]);
                        _lruMap->_totalCost += node->_cost;
                        node->_lastTime = now;
                        node->_value = [req responseJSON];//保存最新的json
                        node->_aliveTime = [req cacheDurationTime];
                        [_lruMap bringNodeToHead:node];
                        
                    } else {
                        /**
                         * 不存在节点，先创建新节点，然后作为头结点插入
                         */
                        node = [[__ZGTDispatcherLRUNode alloc] init];
                        node->_version = @([req cacheVersion]);
                        node->_key = [cacheFileName copy];
                        node->_cost = class_getInstanceSize([req class]);
                        node->_lastTime = now;
                        node->_value = [req responseJSON];//保存最新的json
                        node->_aliveTime = [req cacheDurationTime];
                        node->_version = @([req cacheVersion]);
                        [_lruMap insertNodeAtHead:node];
                    }
                    
                    /**
                     *  按照长度清理，只需废弃一个缓存项，就不在子线程执行，即在当前所在线程执行废弃
                     */
                    if (CFDictionaryGetCount(_lruMap->_cacheDic) > kMaxCacheNodeCount) {
                        __ZGTDispatcherLRUNode *tail = [_lruMap removeTailNode];//retainCount == 1
                        if (tail) {
                            /**
                             *  缓存文件删除
                             */
                            BOOL isCacheTimeout = [req cachefileLastModifyDuration] >= [req cacheDurationTime];
                            BOOL isCacheVersionExpira = [req cacheVersionFileContent] != [req cacheVersion];
                            if (isCacheTimeout || isCacheVersionExpira) {
                                dispatch_async(FileOpertionQueue(), ^{
                                    [self _removeCacheWithFileName:cacheFileName];
                                });
                            }
                            
                            /**
                             *  内存缓存清理
                             */
                            if (_lruMap->_releaseAsynchronously) {
                                dispatch_async(dispatch_get_global_queue(0, 0), ^{
                                    [tail class];//retainCount == 0
                                });
                            } else if (_lruMap->_releaseNodeOnMainThread && !pthread_main_np()) {
                                dispatch_async(dispatch_get_main_queue(), ^{
                                    [tail class];//retainCount == 0
                                });
                            } else {
                                tail = nil;//retainCount == 0
                            }
                        }
                    }
                    pthread_mutex_unlock(&mutex_t);
                }
            }
            
            if (__flag.requestSuccessed) {
                [req.requestDelegate requestSuccessed:req];
            }
            
            if (req.successBlock) {
                req.successBlock(req);//必须在最后使用[req clearCompletionBlocks]打破循环引用
            }
            
        } else {
            ZGTLog(@"Request <%@ - @p> failed finished, status code = %ld", req, req, req.responseStatusCode);
            [req requestFailedFilter];
            
            if (__flag.requestFailed) {
                [req.requestDelegate requestFailed:req];
            }
            
            if (req.failBlock) {
                req.failBlock(req);//必须在最后使用[req clearCompletionBlocks]打破循环引用
            }
        }
    } else {
        //do nothing request 已经被取消掉了
    }
    
    // did stop
    for (id<ZGTRequestAccessory> accecory in accessorys) {
        if ([accecory respondsToSelector:@selector(requestDidStop:)]) {
            [accecory requestDidStop:req];
        }
    }
    
    // 移除Request对象的缓存
    pthread_mutex_lock(&mutex_t);
    [_ctx removeRequestForTask:task];
    pthread_mutex_unlock(&mutex_t);
    
    // 清除Request对象.Block对象，对外部对象的引用
    [req clearCompletionBlocks];
}

// 处理UploadTask，暂时不使用
- (void)_handleRequestCompletWithUploadTask:(NSURLSessionDataTask * _Nonnull)task responseObject:(id  _Nullable )responseObject error:(NSError * _Nonnull)error {
}

// 处理DownloadTask，暂时不使用
- (void)_handleRequestCompletWithDownloadTask:(NSURLSessionDataTask * _Nonnull)task responseObject:(id  _Nullable )responseObject error:(NSError * _Nonnull)error {

}

- (__ZGTDispatcherLRUNode *)cacheNodeWithCacheFileName:(NSString *)cacheFileName {
    __ZGTDispatcherLRUNode *node = nil;
    pthread_mutex_lock(&mutex_t);
    if (!cacheFileName) return nil;
    node = CFDictionaryGetValue(_lruMap->_cacheDic, (__bridge const void *)(cacheFileName));
    pthread_mutex_unlock(&mutex_t);
    return node;
}

- (void)setRecentUseCacheNode:(__ZGTDispatcherLRUNode *)node {
    if (!node) return;
    pthread_mutex_lock(&mutex_t);
    [_lruMap bringNodeToHead:node];
    pthread_mutex_unlock(&mutex_t);
}

- (void)createNewCacheNodeWithRequest:(ZGTBaseRequest *)req json:(id)json {
    if (!req || !json) return;
    if (![req isMemberOfClass:[ZGTRequest class]]) return;
    ZGTRequest *req_c = (ZGTRequest *)req;
    pthread_mutex_lock(&mutex_t);
    __ZGTDispatcherLRUNode *node = nil;
    NSTimeInterval now = CACurrentMediaTime();
    node = [[__ZGTDispatcherLRUNode alloc] init];
    node->_version = @([req_c cacheVersion]);
    node->_key = [[req_c cacheFileName] copy];
    node->_cost = class_getInstanceSize([req class]);
    node->_lastTime = now;
    node->_value = [req responseJSON];//保存最新的json
    node->_aliveTime = [req_c cacheDurationTime];
    if (node) [_lruMap insertNodeAtHead:node];
    pthread_mutex_unlock(&mutex_t);
}

@end
