#ifdef __OBJC__
#import <UIKit/UIKit.h>
#else
#ifndef FOUNDATION_EXPORT
#if defined(__cplusplus)
#define FOUNDATION_EXPORT extern "C"
#else
#define FOUNDATION_EXPORT extern
#endif
#endif
#endif

#import "ZGTBaseRequest.h"
#import "ZGTBatchRequest.h"
#import "ZGTChainRequest.h"
#import "ZGTGlobalDef.h"
#import "ZGTInterfaceAdapter.h"
#import "ZGTRequest.h"
#import "ZGTRequestConfig.h"
#import "ZGTRequestDispatcher.h"
#import "ZGTNtetwork.h"

FOUNDATION_EXPORT double ZGTNtetworkVersionNumber;
FOUNDATION_EXPORT const unsigned char ZGTNtetworkVersionString[];

