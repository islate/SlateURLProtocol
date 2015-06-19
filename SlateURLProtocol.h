//
//  SlateURLProtocol.h
//  SlateCore
//
//  Created by yize lin on 15-3-25.
//  Copyright (c) 2015年 Modern Mobile Digital Media Company Limited. All rights reserved.
//

#import <Foundation/Foundation.h>

NSString* const SlateURLProtocolRedirectURLHeader;
NSString* const SlateURLProtocolFetchURLHeader;
NSString* const SlateURLProtocolFetchDateHeader;
NSString* const SlateURLProtocolNoCacheHeader;
NSString* const SlateURLProtocolIgnoreCacheControlHeadersHeader;
NSString* const SlateURLProtocolCacheNoExpireHeader;

/**
 *  自定义NSURLProtocol
 *  1、拦截HTTP请求
 *  2、实现自己的http缓存逻辑
 */
@interface SlateURLProtocol : NSURLProtocol

+ (void) registerClass;

@end
