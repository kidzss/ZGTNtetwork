//
//  WeatherResponse.h
//  ZGTNtetwork
//
//  Created by kidzss on 05/09/2020.
//  Copyright (c) 2020 kidzss. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface WeatherModel : NSObject
@property (nonatomic, copy) NSString *address;
@property (nonatomic, assign) NSInteger alevel;
@property (nonatomic, assign) NSInteger level;
@property (nonatomic, copy) NSString *cityName;
@property (nonatomic, copy) NSString *lat;
@property (nonatomic, copy) NSString *lon;
@end
