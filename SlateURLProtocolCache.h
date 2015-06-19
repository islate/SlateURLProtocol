//
//  SlateURLProtocolCache.h
//  SlateCore
//
//  Created by yize lin on 12-7-19.
//  Copyright (c) 2015年 Modern Mobile Digital Media Company Limited. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 *  自定义HTTP缓存类
 */
@interface SlateURLProtocolCache : NSObject

+ (instancetype)defaultCache;

- (NSString *)cachePathWithURL:(NSURL *)url;

- (BOOL)hasCacheWithURL:(NSURL *)url;
- (NSData *)readCacheWithURL:(NSURL *)url;

- (BOOL)hasCacheWithPath:(NSString *)cachePath;
- (NSData *)readCacheWithPath:(NSString *)cachePath;
- (BOOL)writeCacheWithPath:(NSString *)cachePath data:(NSData *)data responseHeaders:(NSDictionary *)responseHeaders requestURL:(NSURL *)requestURL redirectRequestURL:(NSURL *)redirectRequestURL;
- (void)writeCacheHeader:(NSDictionary *)responseHeaders cachePath:(NSString *)cachePath requestURL:(NSURL *)requestURL redirectRequestURL:(NSURL *)redirectRequestURL;

- (void)clearCache;

+ (BOOL)isResponseCompressed:(NSDictionary *)responseHeaders;

@end
