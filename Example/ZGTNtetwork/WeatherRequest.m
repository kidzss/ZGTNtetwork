//
//  WeatherRequest.m
//  ZGTNtetwork
//
//  Created by kidzss on 05/09/2020.
//  Copyright (c) 2020 kidzss. All rights reserved.
//

#import "WeatherRequest.h"
#import "WeatherResponse.h"

/**
 *  http://gc.ditu.aliyun.com/geocoding?a=苏州市
 */
@implementation WeatherRequest {
    NSString *_keyWord;
}

- (instancetype)initWithkeyWord:(NSString *)keyWord {
    if (self = [super init]) {
        _keyWord = [keyWord copy];
    }
    return self;
}

- (ZGTRequestMethod)requestMethod {
    return ZGTRequestMethodGET;
}

- (NSString *)host {
    return @"http://gc.ditu.aliyun.com";
}

- (NSString *)requestURL {
    return @"/geocoding";
}

- (id)requestArgument {
    return @{
             @"a" : _keyWord,
             };
}

- (ZGTRequestAPIType)requestApiType {
    return ZGTRequestAPITypeRestfull;
}

- (NSTimeInterval)cacheDurationTime {
    return 30;
}

- (long long)cacheVersion {
    return 1;
}

- (Class)responseClass {
    return [WeatherModel class];
}

- (ZGTResponseThreadType)responseThread {
    return ZGTResponseThreadTypeBackgroudThread;
}

@end
