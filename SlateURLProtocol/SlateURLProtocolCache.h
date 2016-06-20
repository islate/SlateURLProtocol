//
//  SlateURLProtocolCache.h
//  SlateCore
//
//  Created by yize lin on 12-7-19.
//  Copyright (c) 2012年 islate. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 *  自定义HTTP缓存类
 */
@interface SlateURLProtocolCache : NSObject

/*
 *  全局单例
 */
+ (instancetype)defaultCache;

/*
 *  添加自定义缓存规则
 *  @param folderName      缓存文件夹名称
 *  @param filter          过滤器block
 *  @param saveTo          生成缓存路径block
 *  @param isPermanent     是否没有过期时间（永不过期）
 */
- (void)addCacheRuleWithFolderName:(NSString *)folderName filter:(BOOL (^)(NSURL *url))filter saveTo:(NSString * (^)(NSURL *url, NSString *parentPath))saveTo isPermanent:(BOOL)isPermanent;

/*
 *  是否永不过期的缓存路径
 *  @param path            文件路径
 */
- (BOOL)isPermanentCachePath:(NSString *)path;

/*
 *  返回网址的缓存路径
 *  @param url            网址
 */
- (NSString *)cachePathWithURL:(NSURL *)url;

/*
 *  是否有缓存文件
 *  @param url            网址
 */
- (BOOL)hasCacheWithURL:(NSURL *)url;

/*
 *  返回缓存数据
 *  @param url            网址
 */
- (NSData *)readCacheWithURL:(NSURL *)url;

/*
 *  缓存路径是否有文件
 *  @param cachePath            缓存路径
 */
- (BOOL)hasCacheWithPath:(NSString *)cachePath;

/*
 *  返回缓存数据
 *  @param cachePath            缓存路径
 */
- (NSData *)readCacheWithPath:(NSString *)cachePath;

/*
 *  写入缓存数据
 *  @param cachePath            缓存路径
 *  @param data                 要写入的数据
 *  @param responseHeaders      http回复头部
 *  @param requestURL           请求的网址
 *  @param redirectRequestURL   重定向的网址
 */
- (BOOL)writeCacheWithPath:(NSString *)cachePath data:(NSData *)data responseHeaders:(NSDictionary *)responseHeaders requestURL:(NSURL *)requestURL redirectRequestURL:(NSURL *)redirectRequestURL;

/*
 *  写入缓存的回复头部信息
 *  @param responseHeaders      http回复头部
 *  @param cachePath            缓存路径
 *  @param requestURL           请求的网址
 *  @param redirectRequestURL   重定向的网址
 */
- (void)writeCacheHeader:(NSDictionary *)responseHeaders cachePath:(NSString *)cachePath requestURL:(NSURL *)requestURL redirectRequestURL:(NSURL *)redirectRequestURL;

/*
 *  清空缓存
 */
- (void)clearCache;

/*
 *  是否压缩
 *  @param responseHeaders            http回复的头部信息
 */
+ (BOOL)isResponseCompressed:(NSDictionary *)responseHeaders;

@end
