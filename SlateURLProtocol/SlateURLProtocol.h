//
//  SlateURLProtocol.h
//  SlateCore
//
//  Created by yize lin on 12-7-10.
//  Copyright (c) 2012年 islate. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "SlateURLProtocolCache.h"

extern NSString* const SlateURLProtocolRedirectURLHeader;
extern NSString* const SlateURLProtocolFetchURLHeader;
extern NSString* const SlateURLProtocolFetchDateHeader;
extern NSString* const SlateURLProtocolNoCacheHeader;
extern NSString* const SlateURLProtocolIgnoreCacheControlHeadersHeader;
extern NSString* const SlateURLProtocolCacheNoExpireHeader;
extern NSString* const SlateURLProtocolCustomizedHeader;

/**
 *  自定义NSURLProtocol
 *  1、拦截HTTP请求
 *  2、实现自己的http缓存逻辑
 */
@interface SlateURLProtocol : NSURLProtocol

/*
 *  注册类，开始拦截请求
 */
+ (void)registerClass;

/*
 *  自定义http请求头部信息。
 */
+ (void)setCustomHttpHeaders:(NSDictionary<NSString *, NSString *> *)HTTPHeaders;

@end
