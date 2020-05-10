//
//  ZGTGlobalDef.h
//  ZGTNtetwork
//
//  Created by kidzss on 05/09/2020.
//  Copyright (c) 2020 kidzss. All rights reserved.
//

#ifndef ZGTGlobalDef_h
#define ZGTGlobalDef_h

#define ZGT_AppVersion (NSString *)[[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"]

/**
 *  日志输出级别，与DDLogLevel对应
 */
typedef NS_ENUM(NSInteger, ZGTLogOutputLevel) {
    ZGTLogOutputLevelNone            = 1,
    ZGTLogOutputLevelVerbose,
    ZGTLogOutputLevelDebug,
    ZGTLogOutputLevelInfo,
    ZGTLogOutputLevelWarn,
    ZGTLogOutputLevelError,
};

#endif /* ZGTGlobalDef_h */
