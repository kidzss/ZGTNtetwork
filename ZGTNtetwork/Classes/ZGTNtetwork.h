//
//  ZGTNtetwork.h
//  ZGTNtetwork
//
//  Created by kidzss on 05/09/2020.
//  Copyright (c) 2020 kidzss. All rights reserved.
//

#import <Foundation/Foundation.h>

#if __has_include(<ZGTNtetwork/ZGTNtetwork.h>)
FOUNDATION_EXPORT double ZGTVersionNumber;
FOUNDATION_EXPORT const unsigned char ZGTVersionString[];
#import <ZGTNtetwork/ZGTInterfaceAdapter.h>
#import <ZGTNtetwork/ZGTRequest.h>
#import <ZGTNtetwork/ZGTBaseRequest.h>
#import <ZGTNtetwork/ZGTChainRequest.h>
#import <ZGTNtetwork/ZGTBatchRequest.h>
#import <ZGTNtetwork/ZGTRequestConfig.h>
#import <ZGTNtetwork/ZGTRequestDispatcher.h>
#else
#import "ZGTInterfaceAdapter.h"
#import "ZGTRequest.h"
#import "ZGTBaseRequest.h"
#import "ZGTChainRequest.h"
#import "ZGTBatchRequest.h"
#import "ZGTRequestConfig.h"
#import "ZGTRequestDispatcher.h"
#endif
