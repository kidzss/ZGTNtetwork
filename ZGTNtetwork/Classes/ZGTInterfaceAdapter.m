//
//  ZGTInterfaceAdapter.m
//  ZGTNtetwork
//
//  Created by kidzss on 05/09/2020.
//  Copyright (c) 2020 kidzss. All rights reserved.
//

#import "ZGTInterfaceAdapter.h"

@implementation ZGTInterfaceAdapter

+ (instancetype)sharedInstance {
    static ZGTInterfaceAdapter *adapter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        adapter = [[ZGTInterfaceAdapter alloc] init];
    });
    return adapter;
}

- (void)removeDelegate {
    _delegate = nil;
}

@end
