//
//  IPReqyesr.m
//  ZGTNtetwork
//
//  Created by kidzss on 05/09/2020.
//  Copyright (c) 2020 kidzss. All rights reserved.
//  https://www.36ip.cn/?type=json&ip=218.4.255.255

#import "IPReqyest.h"

@implementation IPReqyest {
    NSString *_ip;
}

- (instancetype)initWithIp:(NSString *)ip {
    if (self = [super init]) {
        _ip = [ip copy];
    }
    return self;
}

- (ZGTRequestMethod)requestMethod {
    return ZGTRequestMethodGET;
}

- (NSString *)host {
    return @"https://www.36ip.cn";
}

- (NSString *)requestURL {
    return @"/";
}

- (ZGTRequestAPIType)requestApiType {
    return ZGTRequestAPITypeRestfull;
}

- (id)requestArgument {
    return @{
        @"ip":_ip,
        @"type":@"json"
    };
}

- (NSTimeInterval)cacheDurationTime {
    return 30;
}

- (long long)cacheVersion {
    return 1;
}

- (ZGTResponseSerializerType)responseSerialzerType {
    return ZGTResponseSerializerTypeJSON;
}

@end
