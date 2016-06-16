//
//  SlateURLProtocolCache.m
//  SlateCore
//
//  Created by yize lin on 12-7-19.
//  Copyright (c) 2012年 Modern Mobile Digital Media Company Limited. All rights reserved.
//

#import "SlateURLProtocolCache.h"

#import "SlateURLProtocol.h"
#import "SlateUtils.h"

@interface SlateURLProtocolCache ()

@property (nonatomic, strong) NSMutableArray *cacheRules;
@property (nonatomic, strong) NSString *defaultCacheFolderName;
@property (nonatomic, strong) NSString *defaultCachePath;
@property (nonatomic, strong) NSString *cachesDirectory;

@end

@implementation SlateURLProtocolCache

+ (instancetype)defaultCache
{
    static id _sharedInstance = nil;
    static dispatch_once_t  once = 0;
    
    dispatch_once(&once, ^{
        _sharedInstance = [[self alloc] init];
    });
    return _sharedInstance;
}

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        _cachesDirectory = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex:0];
        _cacheRules = [NSMutableArray new];
        _defaultCacheFolderName = @"URLCache";
        _defaultCachePath = [_cachesDirectory stringByAppendingPathComponent:_defaultCacheFolderName];
    }
    return self;
}

- (void)addCacheRuleWithFolderName:(NSString *)folderName filter:(BOOL (^)(NSURL *url))filter saveTo:(NSString * (^)(NSURL *url, NSString *parentPath))saveTo isPermanent:(BOOL)isPermanent
{
    NSDictionary *cacheRule = @{@"folderName": folderName, @"filter":filter, @"saveTo":saveTo, @"isPermanent":@(isPermanent)};
    [_cacheRules addObject:cacheRule];
}

- (BOOL)isPermanentCachePath:(NSString *)path
{
    for (NSDictionary *cacheRule in _cacheRules)
    {
        NSString *folderName = [cacheRule objectForKey:@"folderName"];
        BOOL isPermanent = [[cacheRule objectForKey:@"isPermanent"] boolValue];
        if (!isPermanent || !folderName)
        {
            continue;
        }
        NSString *parentPath = [_cachesDirectory stringByAppendingPathComponent:folderName];
        if ([path hasPrefix:parentPath])
        {
            return YES;
        }
    }
    return NO;
}

- (NSString *)cachePathWithURL:(NSURL *)url
{
    if (url == nil)
    {
        return @"";
    }
    
    // 自定义缓存规则
    for (NSDictionary *cacheRule in _cacheRules)
    {
        NSString *folderName = [cacheRule objectForKey:@"folderName"];
        BOOL (^filter)(NSURL *url) = [cacheRule objectForKey:@"filter"];
        NSString *(^saveTo)(NSURL *url, NSString *parentPath) = [cacheRule objectForKey:@"saveTo"];
        if (!filter || !saveTo || !folderName)
        {
            continue;
        }
        if (!filter(url))
        {
            continue;
        }
        NSString *parentPath = [_cachesDirectory stringByAppendingPathComponent:folderName];
        NSString *cachePath = saveTo(url, parentPath);
        return cachePath;
    }

    // 默认存储路径
    NSString *cachePath = [_defaultCachePath stringByAppendingPathComponent:url.host];
    return [cachePath stringByAppendingPathComponent:[url.absoluteString md5]];
}

- (BOOL)hasCacheWithURL:(NSURL *)url
{
    NSString *cachePath = [self cachePathWithURL:url];
    return [self hasCacheWithPath:cachePath];
}

- (NSData *)readCacheWithURL:(NSURL *)url
{
    NSString *cachePath = [self cachePathWithURL:url];
    return [self readCacheWithPath:cachePath];
}

- (BOOL)hasCacheWithPath:(NSString *)cachePath
{
    return [[NSFileManager defaultManager] fileExistsAtPath:cachePath];
}

- (NSData *)readCacheWithPath:(NSString *)cachePath
{
    return [NSData dataWithContentsOfFile:cachePath];
}

- (BOOL)writeCacheWithPath:(NSString *)cachePath data:(NSData *)data responseHeaders:(NSDictionary *)responseHeaders requestURL:(NSURL *)requestURL redirectRequestURL:(NSURL *)redirectRequestURL
{
    if (cachePath && data && responseHeaders && requestURL)
    {
        [[NSFileManager defaultManager] createDirectoryAtPath:[cachePath stringByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:nil];
        
        if ([data writeToFile:cachePath atomically:YES])
        {
            [self writeCacheHeader:responseHeaders cachePath:cachePath requestURL:requestURL redirectRequestURL:redirectRequestURL];
            return YES;
        }
    }
    return NO;
}

- (void)writeCacheHeader:(NSDictionary *)responseHeaders cachePath:(NSString *)cachePath requestURL:(NSURL *)requestURL redirectRequestURL:(NSURL *)redirectRequestURL
{
    if (responseHeaders && cachePath && requestURL
        && [responseHeaders isKindOfClass:[NSDictionary class]]
        && [cachePath isKindOfClass:[NSString class]]
        && [requestURL isKindOfClass:[NSURL class]])
    {
        NSMutableDictionary *mutableResponseHeaders = [NSMutableDictionary dictionaryWithDictionary:responseHeaders];
        
        if ([[self class] isResponseCompressed:mutableResponseHeaders])
        {
            [mutableResponseHeaders removeObjectForKey:@"Content-Encoding"];
        }
        
        NSString *date = [[[self class] rfc1123DateFormatter] stringFromDate:[NSDate date]];
        if (date)
        {
            [mutableResponseHeaders setObject:date forKey:SlateURLProtocolFetchDateHeader];
        }
        if (requestURL.absoluteString)
        {
            [mutableResponseHeaders setObject:requestURL.absoluteString forKey:SlateURLProtocolFetchURLHeader];
        }
        if (redirectRequestURL.absoluteString)
        {
            [mutableResponseHeaders setObject:redirectRequestURL.absoluteString forKey:SlateURLProtocolRedirectURLHeader];
        }
        [mutableResponseHeaders writeToFile:[cachePath stringByAppendingString:@".header"] atomically:YES];
    }
}

- (void)clearCache
{
    for (NSDictionary *cacheRule in _cacheRules)
    {
        NSString *folderName = [cacheRule objectForKey:@"folderName"];
        if (!folderName)
        {
            continue;
        }
        NSString *parentPath = [_cachesDirectory stringByAppendingPathComponent:folderName];
        [[NSFileManager defaultManager] removeItemAtPath:parentPath error:nil];
    }
    [[NSFileManager defaultManager] removeItemAtPath:_defaultCachePath error:nil];
}

#pragma mark - HTTP协议

// response是否gzip
+ (BOOL)isResponseCompressed:(NSDictionary *)responseHeaders
{
	NSString *encoding = [responseHeaders objectForKey:@"Content-Encoding"];
	return encoding && [encoding rangeOfString:@"gzip"].location != NSNotFound;
}

// 将时间转化为GMT rfc1123格式的字符串
+ (NSDateFormatter *)rfc1123DateFormatter
{
	static NSDateFormatter *dateFormatter = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        dateFormatter = [[NSDateFormatter alloc] init];
		[dateFormatter setLocale:[[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"]];
		[dateFormatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
		[dateFormatter setDateFormat:@"EEE, dd MMM yyyy HH:mm:ss 'GMT'"];
    });
	return dateFormatter;
}

@end
