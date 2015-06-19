//
//  SlateReachability.h
//  SlateCore
//
//  Created by yize lin on 15-3-25.
//  Copyright (c) 2015年 Modern Mobile Digital Media Company Limited. All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSString * const SlateReachabilityDidChangeNotification;

/**
 *  网络状态检测
 */
@interface SlateReachability : NSObject

+ (instancetype)sharedReachability;

- (BOOL)isNetworkWiFi;
- (BOOL)isNetwork3Gor2G;
- (BOOL)isNetworkBroken;
- (BOOL)isNetworkOK;

@end
