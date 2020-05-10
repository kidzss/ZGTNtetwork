//
//  ZViewController.m
//  ZGTNtetwork
//
//  Created by kidzss on 05/09/2020.
//  Copyright (c) 2020 kidzss. All rights reserved.
//

#import "ZViewController.h"
#import <ZGTNtetwork/ZGTNtetwork.h>
#import "WeatherRequest.h"
#import "IPReqyest.h"
#import "WeatherResponse.h"
#import "Wearther2Request.h"

@interface ZViewController ()<ZGTRequestCompletDelegate>

@end

@implementation ZViewController {
    
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    NSLog(@"path = %@", NSHomeDirectory());

//    [self test1];
//    [self test2];
//    [self test3];
    [self test4];
}

- (void)viewDidLoad {
    self.title = @"ZViewController";
    [super viewDidLoad];
}

// 测试多线程下创建同一个Request类对象的线程安全
- (void)test1 {
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        [self test2];
    });
    
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        [self test2];
    });
    
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        [self test2];
    });
    
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        [self test2];
    });
    
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        [self test2];
    });
    
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        [self test2];
    });
    
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        [self test2];
    });
    
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        [self test2];
    });
    
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        [self test2];
    });
    
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        [self test2];
    });
    
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        [self test2];
    });
    
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        [self test2];
    });
}

// 测试缓存、YYModel json 解析
- (void)test2 {
    
    WeatherRequest *req1 = [[WeatherRequest alloc] initWithkeyWord:@"苏州市"];
    [req1 startWithSuccessComplet:^(ZGTBaseRequest *request) {
        
        // 缓存
        //        ZGTRequest *req = (ZGTRequest *)request;
        //        id cacheJSON = [req cachedJSON];
        //        if (cacheJSON) {
        //            NSLog(@"cached response object = %@", cacheJSON);
        //        } else {
        //            NSLog(@"response object = %@", request.responseObject);
        //        }
        
        // json 解析
        WeatherModel *model = req1.responseModelObject;
        NSLog(@"model.address = %@", model.address);
        NSLog(@"model.alevel = %ld", model.alevel);
        NSLog(@"model.level = %ld", model.level);
        NSLog(@"model.cityName = %@", model.cityName);
        NSLog(@"model.lat = %@", model.lat);
        NSLog(@"model.lon = %@", model.lon);
        
    } failComplet:^(ZGTBaseRequest *request) {
        
        NSLog(@"error = %@", request.responseError);
    }];
    
    Wearther2Request *req2 = [[Wearther2Request alloc] initWithkeyWord:@"苏州市"];
    [req2 startWithSuccessComplet:^(ZGTBaseRequest *request) {
        
    } failComplet:^(ZGTBaseRequest *request) {
        
        NSLog(@"error = %@", request.responseError);
    }];
    
    IPReqyest *req3 = [[IPReqyest alloc] initWithIp:@"218.4.255.255"];
    [req3 startWithSuccessComplet:^(ZGTBaseRequest *request) {
        
    } failComplet:^(ZGTBaseRequest *request) {
        NSLog(@"error = %@", request.responseError);
    }];
}

- (void)test3 {
    
    //1. 创建一个链式请求
    ZGTChainRequest *chainReq = [[ZGTChainRequest alloc] init];
    
    //2. 创建一个基本请求
    WeatherRequest *req1 = [[WeatherRequest alloc] initWithkeyWord:@"苏州市"];
    
    // 3. 向链式中添加一个基本请求
    [chainReq addBasicRequest:req1 didBasicRequestFinished:^(ZGTChainRequest * _Nonnull chainReq, ZGTRequest * _Nonnull basicReq)
     {
         //4. 创建二个基本请求
         Wearther2Request *req2 = [[Wearther2Request alloc] initWithkeyWord:@"上海市"];
         
         //5. 向链式中添加二个基本请求
         [chainReq addBasicRequest:req2 didBasicRequestFinished:^(ZGTChainRequest * _Nonnull chainReq, ZGTRequest * _Nonnull basicReq)
          {
              //6. 创建三个基本请求
              IPReqyest *req3 = [[IPReqyest alloc] initWithIp:@"218.4.255.255"];
              
              //7. 向链式中添加二个基本请求
              [chainReq addBasicRequest:req3 didBasicRequestFinished:^(ZGTChainRequest * _Nonnull chainReq, ZGTRequest * _Nonnull basicReq)
               {
                   NSLog(@"");
               }];
          }];
     }];
    
    [chainReq startWithDelegate:self];
}

- (void)ZGTChainRequestDidSuccessFinish:(ZGTChainRequest *__nullable)chainReq {
    NSLog(@"链式请求全部执行完毕");
}

- (void)ZGTChainRequest:(ZGTChainRequest *__nullable)chainReq didBasicRequestFailed:(ZGTRequest *__nullable)request
{
    NSLog(@"其中有一个错误执行结束: %@", request);
}

- (void)test4 {
    
//    WeatherRequest *req1 = [[WeatherRequest alloc] initWithkeyWord:@"苏州市"];
//    Wearther2Request *req2 = [[Wearther2Request alloc] initWithkeyWord:@"上海市"];
    IPReqyest *req3 = [[IPReqyest alloc] initWithIp:@"218.4.255.255"];
    NSArray *requests = @[req3];
    
    [req3 startWithSuccessComplet:^(ZGTBaseRequest * _Nonnull request) {
        NSLog(@"request %@",request.responseObject);
    } failComplet:^(ZGTBaseRequest * _Nonnull request) {
        NSLog(@"request %@",request);
    }];
    
    ZGTBatchRequest *batchReq = [[ZGTBatchRequest alloc] initWithBasicRequestArray:requests];
    [batchReq startWithDelegate:self];
}

- (void)batchRequestDidSuccessFinish:(ZGTBatchRequest *)batchRequest {
    NSLog(@"批量请求全部执行完毕");
}

- (void)batchRequest:(ZGTBatchRequest *)batchReq didBasicRequestFailed:(ZGTRequest *)request {
    NSLog(@"其中有一个错误执行结束: %@", request);
}

- (void)test5 {
    [ZGTInterfaceAdapter sharedInstance].delegate = self;
}

/**
 *  ZGTInterfaceAdapter日志信息回调
 *
 *  @param level   日志级别
 *  @param module  模块名称
 *  @param content 日志正文
 */
- (void)ZGTInterfaceLogAdapterWithLevel:(ZGTLogOutputLevel)level
                                    module:(NSString *__nonnull)module
                                   content:(NSString *__nullable)content
{
    //do your things about log infos.....
}

@end
