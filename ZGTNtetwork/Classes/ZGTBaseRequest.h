//
//  ZGTBaseRequest.h
//  ZGTNtetwork
//
//  Created by kidzss on 05/09/2020.
//  Copyright (c) 2020 kidzss. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AFNetworking/AFNetworking.h>
#import "ZGTGlobalDef.h"

#define kZGTRequestEnableDownload    NO
#define kZGTRequestEnableUpload      NO

@class ZGTBaseRequest;

NS_ASSUME_NONNULL_BEGIN

typedef void (^RequestSuccessBlcok) (ZGTBaseRequest *request);
typedef void (^RequestFailBlcok) (ZGTBaseRequest *request);
typedef void (^AFMultipartFormDataBlock)(id<AFMultipartFormData> formData);

/**
 *  请求的优先级
 */
typedef NS_ENUM(NSInteger , ZGTRequestPriority) {
    /**
     *  NSURLSessionTaskPriorityLow
     */
    ZGTRequestPriorityLow = -4L,
    /**
     *  NSURLSessionTaskPriorityDefault
     */
    ZGTRequestPriorityDefault = 0,
    /**
     *  NSURLSessionTaskPriorityHigh
     */
    ZGTRequestPriorityHigh = 4,
};

typedef NS_ENUM(NSInteger , ZGTRequestSerializerType) {
    ZGTRequestSerializerTypeHTTP                     = 0,
    ZGTRequestSerializerTypeJSON,
};

typedef NS_ENUM(NSInteger , ZGTResponseSerializerType) {
    ZGTResponseSerializerTypeHTTP                    = 0,
    ZGTResponseSerializerTypeJSON,
    ZGTResponseSerializerTypeXML,
};

typedef NS_ENUM(NSInteger, ZGTRequestMethod) {
    ZGTRequestMethodGET                              = 1,
    ZGTRequestMethodPOST,
};

typedef NS_ENUM(NSInteger, ZGTRequestAPIType) {
    ZGTRequestAPITypeMVC                             = 1,
    ZGTRequestAPITypeRestfull,
};

typedef NS_ENUM(NSInteger, ZGTRequestType) {
    ZGTRequestTypeDataTask                           = 1,
    ZGTRequestTypeDownload,
    ZGTRequestTypeUpload,
};

typedef NS_ENUM(NSInteger, ZGTResponseThreadType) {
    ZGTResponseThreadTypeMainThread                  = 1,//主线程回调
    ZGTResponseThreadTypeBackgroudThread,                //子线程
};

// 参照NSURLError.h
typedef NS_ENUM(NSInteger, ZGTRequestErrorType) {
    ZGTRequestErrorTypeSystem                        = 1,
    ZGTRequestErrorTypeBusiness,
};

@protocol ZGTRequestAccessory  <NSObject>

@optional
- (void)requestWillStart:(id)request;
- (void)requestWillStop:(id)request;
- (void)requestDidStop:(id)request;

@end

struct ZGTRequestCompletDelegateFlag {
    unsigned int requestSuccessed   : 1;
    unsigned int requestFailed      : 1;
};

@protocol ZGTRequestCompletDelegate <NSObject>

@optional
- (void)requestSuccessed:(ZGTBaseRequest *)request;
- (void)requestFailed:(ZGTBaseRequest *)request;

@end

/**
 *  封装一个单独简单的网络请求需要的全部数据
 */
@interface ZGTBaseRequest : NSObject

//只读属性
// 请求之前相关
@property (nonatomic, copy) RequestSuccessBlcok                  successBlock;
@property (nonatomic, copy) RequestFailBlcok                     failBlock;
@property (nonatomic, strong) NSArray                            *accessorys;
@property (nonatomic, weak) id<ZGTRequestCompletDelegate>        requestDelegate;
// 响应数据相关
@property (nonatomic, strong, readonly) NSURLSessionTask         *task;
//json、data、xml...等等任意类型数据
@property (nonatomic, strong, readonly) id                       responseObject;

//子类重写的方法
// 请求之前相关
- (BOOL)isUseHttps;
- (BOOL)isUseCDN;
- (NSString *)host;
- (NSString *)cdnURL;
- (ZGTRequestPriority)requestPriority;
- (ZGTRequestAPIType)requestApiType;
- (ZGTRequestType)requestType;
- (ZGTLogOutputLevel)requestLogLevel;
- (NSString *)requestController;
- (NSString *)requestAction;
- (NSString *)requestVersion;
- (NSString *)requestURL;
- (NSString *)requestAbsoluteURL;
- (NSString *)downloadURL;
- (NSString *)uploadURL;
- (ZGTRequestMethod)requestMethod;
- (NSDictionary *)requestHeaderFieldValueDictionary;
- (NSArray *)requestAuthorizationHeaderFieldArray;
//请求参数打包形式
- (ZGTRequestSerializerType)requestSerialzerType;
//响应数据解析方式
- (ZGTResponseSerializerType)responseSerialzerType;
- (NSURLRequest *)buildDownloadUrlRequest;
- (NSURL *)saveDownloadDataUrl;
- (AFMultipartFormDataBlock)multipartFormDataBlock;
- (NSTimeInterval)requestTimeoutInterval;
//body字典
- (id)requestArgument;
//system字典
- (id)systemArgument;

//用于计算cache文件名时，使用某些特定参数加入到计算cache文件逻辑，默认不加入参数计算cache文件名
- (id)cacheFileNameFilterForRequestArgument:(id)argument;

// 请求结束
- (void)requestCompleteFilter;
- (void)requestFailedFilter;

// 响应数据
- (ZGTResponseThreadType)responseThread;
- (Class)responseClass;
- (id)jsonValidator;

//工具方法（不要重写）
- (BOOL)statusCodeValidator;
//返回解析成实体类的对象
- (id)responseModelObject;
- (id)responseJSON;
- (NSHTTPURLResponse *)response;
- (NSInteger)responseStatusCode;
- (NSDictionary *)responseHeaders;
- (NSError *)responseError;

- (struct ZGTRequestCompletDelegateFlag)requestCompletFlag;
- (void)startWithDelegate:(id<ZGTRequestCompletDelegate>)delegate;
- (void)startWithSuccessComplet:(RequestSuccessBlcok)success
                    failComplet:(RequestFailBlcok)fail;

- (void)start;
- (void)stop;

- (BOOL)isExecuting;
- (BOOL)isCancelled;

- (void)addAccessory:(id<ZGTRequestAccessory>)accessory;
- (NSArray *)accessorys;

/**
 *  取消Request对象对外部持有对象的循环强引用
 *  在Request执行完之后，一定要调用
 */
- (void)clearCompletionBlocks;

@end

NS_ASSUME_NONNULL_END
