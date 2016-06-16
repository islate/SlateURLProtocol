//
//  SlateURLProtocolCache.m
//  SlateCore
//
//  Created by yize lin on 12-7-19.
//  Copyright (c) 2012年 Modern Mobile Digital Media Company Limited. All rights reserved.
//

#import "SlateURLProtocolCache.h"

//#import "SlateOfflineVideoManager.h"
#import "SlateAppInfo.h"
#import "SlateURLProtocol.h"
#import "SlateUtils.h"

@interface SlateURLProtocolCache ()

@property (nonatomic, strong) NSString *urlCacheFolderName;
@property (nonatomic, strong) NSString *urlCachePath;
@property (nonatomic, strong) NSString *packageCacheFolderName;
@property (nonatomic, strong) NSString *packageCachePath;
@property (nonatomic, strong) NSString *pdfCacheFolderName;
@property (nonatomic, strong) NSString *pdfCachePath;

- (BOOL)isImageUrl:(NSString *)urlString;
- (BOOL)isPdfUrl:(NSString *)urlString;

@end

@implementation SlateURLProtocolCache

+ (instancetype)defaultCache
{
    static id               _sharedInstance = nil;
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
        _urlCacheFolderName = @"URLCache";
        _packageCacheFolderName = @"PackageCache";
        _pdfCacheFolderName = @"PDFCache";
        _urlCachePath = [kCachesDirectory stringByAppendingPathComponent:_urlCacheFolderName];
        _packageCachePath = [kCachesDirectory stringByAppendingPathComponent:_packageCacheFolderName];
        _pdfCachePath = [kCachesDirectory stringByAppendingPathComponent:_pdfCacheFolderName];
    }
    return self;
}

- (void)setPackageCacheFolderName:(NSString *)folderName
{
    _packageCacheFolderName = folderName;
    _packageCachePath = [kCachesDirectory stringByAppendingPathComponent:folderName];
}

- (BOOL)isVideoUrl:(NSString *)urlString
{
    NSString *pathExtension = [[urlString pathExtension] lowercaseString];
    if (!pathExtension)
    {
        return NO;
    }
    return ([@"m3u8|m4v|mov|mp4|avi|mpg|mpeg|3gp|ts" rangeOfString:pathExtension].location != NSNotFound);
}

- (BOOL)isImageUrl:(NSString *)urlString
{
    NSString *pathExtension = [[urlString pathExtension] lowercaseString];
    if (!pathExtension)
    {
        return NO;
    }
    return ([@"png|jpg|gif|jpeg|webp" rangeOfString:pathExtension].location != NSNotFound);
}

- (BOOL)isPdfUrl:(NSString *)urlString
{
    NSString *pathExtension = [[urlString pathExtension] lowercaseString];
    if (!pathExtension)
    {
        return NO;
    }
    return [pathExtension isEqualToString:@"pdf"];
}

- (NSString *)cachePathWithURL:(NSURL *)url
{
    if (url == nil)
    {
        return @"";
    }
    
    BOOL isImage = NO;
    NSString *relativePath = nil;
    NSString *urlString = url.absoluteString;
    
//    if ([SlateOfflineVideoManager isVideoURL:[NSURL URLWithString:urlString]])
//    {
//        return [SlateOfflineVideoManager cachePathWithURL:[NSURL URLWithString:urlString]];
//    }

    if ([self isPdfUrl:urlString])
    {
        NSString *cachePath = [_pdfCachePath stringByAppendingPathComponent:url.host];
        NSString *fileName = [NSString stringWithFormat:@"%@.pdf", [url.absoluteString md5]];
        return [cachePath stringByAppendingPathComponent:fileName];
    }
    
    NSRange range1 = [urlString rangeOfString:@"/statics/"];
    NSRange range2 = [urlString rangeOfString:@"/slateInterface/"];
    NSRange range3 = [urlString rangeOfString:@"/uploadfile/"];
    NSRange range4 = [urlString rangeOfString:@"/issue_"];

    BOOL packageCache = NO;
    if (range1.length > 0)
    {
        packageCache = YES;
        relativePath = [urlString substringFromIndex:range1.location];
    }
    else if (range2.length > 0)
    {
        relativePath = [urlString substringFromIndex:range2.location];
        
        if ([self isImageUrl:urlString])
        {
            isImage = YES;
            packageCache = YES;
        }
        else
        {
            if ([urlString rangeOfString:@"updatetime"].location != NSNotFound)
            {
                packageCache = YES;
            }
        }
    }
    else if (range3.length > 0)
    {
        packageCache = YES;
        relativePath = [urlString substringFromIndex:range3.location];
    }
    else if (range4.length > 0)
    {
        if ([self isImageUrl:urlString])
        {
            isImage = YES;
            packageCache = YES;
            relativePath = [urlString substringFromIndex:range4.location];
        }
    }

    if (packageCache)
    {
        // 与解压包相同的存储路径，为了支持打包下载
        NSString *cachePath = _packageCachePath;
        if (isImage)
        {
            cachePath = [cachePath stringByAppendingPathComponent:@"pictures"];
        }
        return [cachePath stringByAppendingPathComponent:relativePath];
    }

    // 通用存储路径
    NSString *cachePath = [_urlCachePath stringByAppendingPathComponent:url.host];
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
    [[NSFileManager defaultManager] removeItemAtPath:_pdfCachePath error:nil];
    [[NSFileManager defaultManager] removeItemAtPath:_packageCachePath error:nil];
    [[NSFileManager defaultManager] removeItemAtPath:_urlCachePath error:nil];
}

- (void)clearOldCaches
{
    NSArray *array = @[@"SlateURLProtocolCache",@"SlateCache"];
    for (NSString *name in array)
    {
        NSString *path = [kCachesDirectory stringByAppendingPathComponent:name];
        BOOL isDirectory = NO;
        if ([[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDirectory])
        {
            if (isDirectory)
            {
                [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
            }
        }
    }
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
