//
//  ZGTRequestConfig.m
//  ZGTNtetwork
//
//  Created by kidzss on 05/09/2020.
//  Copyright (c) 2020 kidzss. All rights reserved.
//

#import "ZGTRequestConfig.h"
#import <pthread.h>
#import <AFNetworking/AFNetworking.h>

static pthread_mutex_t mutex_t;

@implementation ZGTRequestConfig {
    NSMutableArray *_urlPathFilters;
//    NSMutableArray *_cacheFilePathFilters;
}

+ (instancetype)sharedInstance {
    static ZGTRequestConfig *_config = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _config = [[ZGTRequestConfig alloc] init];
    });
    return _config;
}

- (void)dealloc {
    pthread_mutex_destroy(&mutex_t);
}

- (instancetype)init {
    if (self = [super init]) {
        pthread_mutex_init(&mutex_t, NULL);
        _urlPathFilters = [[NSMutableArray alloc] initWithCapacity:32];
//        _cacheFilePathFilters = [[NSMutableArray alloc] initWithCapacity:32];
    }
    return self;
}

- (void)addReuqestURLPathFilter:(id<ZGTReuqestURLFilter>)filter {
    pthread_mutex_lock(&mutex_t);
    if (filter) [_urlPathFilters addObject:filter];
    pthread_mutex_unlock(&mutex_t);
}

//- (void)addReuqestCacheJSONSavedPathFilter:(id<ZGTReuqestCacheJSONSavedPathFilter>)filter {
//    pthread_mutex_lock(&mutex_t);
//    if (filter) [_cacheFilePathFilters addObject:filter];
//    pthread_mutex_unlock(&mutex_t);
//}

- (NSArray *)reuqestURLPathFilters {
    pthread_mutex_lock(&mutex_t);
    NSArray *copyArr = [_urlPathFilters copy];
    pthread_mutex_unlock(&mutex_t);
    return copyArr;
}

//- (NSArray *)reuqestCacheJSONSavedPathFilters {
//    pthread_mutex_lock(&mutex_t);
//    NSArray *copyArr = [_cacheFilePathFilters copy];
//    pthread_mutex_unlock(&mutex_t);
//    return copyArr;
//}

@end
