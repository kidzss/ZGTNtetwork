//  Wearther2Request.m
//  ZGTNtetwork
//
//  Created by kidzss on 05/09/2020.
//  Copyright (c) 2020 kidzss. All rights reserved.
//

#import "Wearther2Request.h"

@implementation Wearther2Request {
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
    return @"http://wthrcdn.etouch.cn";
}

- (NSString *)requestURL {
    return @"/weather_mini";
}

- (id)requestArgument {
    return @{
             @"city" : _keyWord,
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

@end
