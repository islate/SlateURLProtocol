//
//  SlateURLProtocol.m
//  SlateCore
//
//  Created by yize lin on 12-7-10.
//  Copyright (c) 2012年 Modern Mobile Digital Media Company Limited. All rights reserved.
//

#import "SlateURLProtocol.h"

#import "SlateReachability.h"
#import "SlateUtils.h"

#ifdef DEBUG
#    define DLog(...) NSLog(__VA_ARGS__)
#else
#    define DLog(...) /* */
#endif
#define ALog(...) NSLog(__VA_ARGS__)

NSString* const SlateURLProtocolErrorDomain = @"SlateURLProtocolErrorDomain";
NSString* const SlateURLProtocolRequest = @"SlateURLProtocolRequest";
NSString* const SlateURLProtocolRedirectURLHeader = @"X-SlateURLProtocol-Redirect-url";
NSString* const SlateURLProtocolFetchURLHeader = @"X-SlateURLProtocol-Fetch-url";
NSString* const SlateURLProtocolFetchDateHeader = @"X-SlateURLProtocol-Fetch-date";
NSString* const SlateURLProtocolNoCacheHeader = @"X-Slate-No-Cache";
NSString* const SlateURLProtocolIgnoreCacheControlHeadersHeader = @"X-Slate-Ignore-Cache-Control-Headers";
NSString* const SlateURLProtocolCacheNoExpireHeader = @"X-Slate-Cache-No-Expire";
NSString* const SlateURLProtocolCustomizedHeader = @"X-Slate";

NSTimeInterval const SlateURLProtocolLocalMaxAge = 60 * 60 * 8;

@interface SlateURLProtocol ()

@property (nonatomic, strong) NSMutableURLRequest *mutableRequest;
@property (nonatomic, strong) NSHTTPURLResponse *response;
@property (nonatomic, strong) NSURLConnection *connection;
@property (nonatomic, strong) NSMutableData *receivedData;
@property (nonatomic, strong) NSDictionary *responseHTTPHeaders;
@property (nonatomic, strong) NSString *cachePath;
@property (nonatomic, strong) NSString *cacheHeaderPath;
@property (nonatomic, assign) BOOL didUseCache;
@property (nonatomic, assign) BOOL cacheable;

- (BOOL)cacheExpiredReturnAge:(NSTimeInterval *)age;
- (BOOL)hasCache;
- (void)readCache;
- (void)writeCache:(NSHTTPURLResponse *)response redirectRequest:(NSURLRequest *)redirectRequest;
- (NSDictionary *)cachedHeaders;
- (void)setConditionalGETHeaders;

+ (NSDate *)dateFromRFC1123String:(NSString *)string;
+ (BOOL)allowsCaching:(NSDictionary *)responseHeaders;
+ (BOOL)cacheExpires:(NSDictionary *)responseHeaders age:(NSTimeInterval *)age;

@end

static NSDictionary<NSString*, NSString*> *_customHeaders = nil;

@implementation SlateURLProtocol

+ (void)registerClass
{
    [NSURLProtocol registerClass:[SlateURLProtocol class]];
}

+ (void)setCustomHttpHeaders:(NSDictionary<NSString*, NSString*>*)HTTPHeaders
{
    _customHeaders = HTTPHeaders;
}

#pragma mark - NSURLProtocol methods

+ (BOOL)canInitWithRequest:(NSURLRequest *)request
{
    if (![request.URL.scheme.lowercaseString isEqualToString:@"http"])
    {
        // 只拦截http请求，不拦截https ftp等其他协议
        return NO;
    }

    if (request.URL.host.length == 0
        || [request.URL.host isEqualToString:@"localhost"]
        || [request.URL.host isEqualToString:@"127.0.0.1"])
    {
        // 没有host??    微博登录有这种情况，不能拦截
        // localhost和127.0.0.1不拦截
        return NO;
    }
    
    if ([request.URL isVideo])
    {
        // 不拦截视频请求
        return NO;
    }
    
    if ([NSURLProtocol propertyForKey:SlateURLProtocolRequest inRequest:request] != nil)
    {
        // 已经拦截过了，不能再次拦截
        return NO;
    }
    
    if ([request.allHTTPHeaderFields objectForKey:@"Range"])
    {
        // 不支持Range (流媒体)
        return NO;
    }
    
    if ([request.allHTTPHeaderFields objectForKey:SlateURLProtocolNoCacheHeader])
    {
        // 不缓存
        return NO;
    }
    
    BOOL isPOST = ([[request HTTPMethod] isEqualToString:@"POST"]);
    BOOL isXHR = ([[request.allHTTPHeaderFields objectForKey:@"X-Requested-With"] isEqualToString:@"XMLHttpRequest"]);
    BOOL hasCustomizedHeader = ([request.allHTTPHeaderFields objectForKey:SlateURLProtocolCustomizedHeader] != nil);
    if ((isPOST || isXHR) && hasCustomizedHeader)
    {
        // 不缓存已经自定义头部的POST、XHR请求
        return NO;
    }

    NSString *origin = [request.allHTTPHeaderFields objectForKey:@"Origin"];
    NSString *accept = [request.allHTTPHeaderFields objectForKey:@"Accept"];
    if (origin && [accept isEqualToString:@"application/json"])
    {
        // 不缓存跨域的ajax请求， NSURLConnection有超时bug   linyize 2016.5.9
        return NO;
    }
    
    // 拦截所有其他请求    linyize 2013.9.12
    return YES;
}

+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)theRequest
{
    return theRequest;
}

- (id)initWithRequest:(NSURLRequest *)request cachedResponse:(NSCachedURLResponse *)cachedResponse client:(id<NSURLProtocolClient>)client
{
    NSMutableURLRequest* newRequest = [request mutableCopy];
    [NSURLProtocol setProperty:@"1" forKey:SlateURLProtocolRequest inRequest:newRequest];
    
    // 自定义头部
    if (![newRequest.allHTTPHeaderFields objectForKey:SlateURLProtocolCustomizedHeader] && _customHeaders)
    {
        [[_customHeaders copy] enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
            if ([key isKindOfClass:[NSString class]] && [obj isKindOfClass:[NSString class]])
            {
                [newRequest setValue:obj forHTTPHeaderField:key];
            }
        }];
    }
    
    // Now continue the process with this "tagged" request
    self = [super initWithRequest:newRequest
                   cachedResponse:cachedResponse
                           client:client];
    if (self)
    {
        self.mutableRequest = newRequest;
        self.didUseCache = NO;
        
        BOOL isPOST = ([[newRequest HTTPMethod] isEqualToString:@"POST"]);
        BOOL isXHR = ([[newRequest.allHTTPHeaderFields objectForKey:@"X-Requested-With"] isEqualToString:@"XMLHttpRequest"]);
        self.cacheable = !(isPOST || isXHR);
        if (self.cacheable)
        {
            self.receivedData = [NSMutableData data];
        }
    }
    
    return self;
}

- (void)startLoading
{
    if (self.cacheable)
    {
        self.cachePath = [[SlateURLProtocolCache defaultCache] cachePathWithURL:self.request.URL];
        self.cacheHeaderPath = [self.cachePath stringByAppendingString:@".header"];
        
        if ([self hasCache])
        {
            NSTimeInterval currentAge = 0;
            
            if ([self cacheNoExpire])
            {
                // 不判断是否过期，直接读缓存
                [self readCache];
                return;
            }
            else if (![self cacheExpiredReturnAge:&currentAge])
            {
                // 缓存未过期，并在8小时之内，信任header，读取缓存
                if (currentAge < SlateURLProtocolLocalMaxAge)
                {
                    [self readCache];
                    return;
                }
            }
            
            // 如果缓存过期，或者超过8小时，使用conditional GET，问HTTP服务器是否需要更新
            [self setConditionalGETHeaders];
            
            DLog(@"SlateURLProtocol update ====== %@", self.request.URL.absoluteString);
        }
        else
        {
            DLog(@"SlateURLProtocol new ====== %@", self.request.URL.absoluteString);
        }
    }
    
    // 下载
    [self setConnection:[NSURLConnection connectionWithRequest:self.request delegate:self]];
}

- (void)stopLoading 
{
    [self.connection cancel];
}

#pragma mark - NSURLConnectionDelegate NSURLConnectionDataDelegate

- (NSURLRequest *)connection:(NSURLConnection *)connection willSendRequest:(NSURLRequest *)request redirectResponse:(NSURLResponse *)response
{
    if (response != nil)
    {
        // 跳转的url
        NSMutableURLRequest *redirectableRequest = [request mutableCopy];

        [NSURLProtocol removePropertyForKey:SlateURLProtocolRequest inRequest:redirectableRequest];
        
        if ([response isKindOfClass:[NSHTTPURLResponse class]]
            && self.cacheable)
        {
            self.response = (NSHTTPURLResponse *)response;
            [self writeCache:self.response redirectRequest:redirectableRequest];
        }
        
        [[self client] URLProtocol:self wasRedirectedToRequest:redirectableRequest redirectResponse:response];
        return redirectableRequest;
    }
    else
    {
        return request;
    }
}

- (void)connection:(NSURLConnection*)conn didReceiveResponse:(NSURLResponse*)response 
{
    if ([response isKindOfClass:[NSHTTPURLResponse class]]
        && self.cacheable)
    {
        self.response = (NSHTTPURLResponse *)response;
        if (self.response.statusCode == 304)
        {
            DLog(@"SlateURLProtocol HTTP 304 Not Modified =------------- %@", self.request.URL.absoluteString);
            
            if ([self hasCache])
            {
                [self readCache];
                return;
            }
        }
        
        self.responseHTTPHeaders = self.response.allHeaderFields;
    }
    
    [[self client] URLProtocol:self
            didReceiveResponse:response 
            cacheStoragePolicy:NSURLCacheStorageNotAllowed];
    
    if (self.cacheable)
    {
        [self.receivedData setLength:0];
    }
}

- (void)connection:(NSURLConnection*)connection didReceiveData:(NSData*)data
{
    if (self.didUseCache)
    {
        return;
    }
    
    [[self client] URLProtocol:self didLoadData:data];
    
    if (self.cacheable)
    {
        [self.receivedData appendData:data];
    }
}

- (void)connectionDidFinishLoading:(NSURLConnection*)conn
{
    [self setConnection:nil];
    
    if (self.didUseCache)
    {
        return;
    }
    
    [[self client] URLProtocolDidFinishLoading:self];
    
    if (self.cacheable)
    {
        if ([self.response statusCode] / 100 == 2)
        {
            // 接收到数据。 HTTP状态码 200/206
            
            BOOL isResponseCompressed = [SlateURLProtocolCache isResponseCompressed:self.responseHTTPHeaders];
//            BOOL allowsCaching = [[self class] allowsCaching:self.responseHTTPHeaders];
//            BOOL ignoreCacheControlHeaders = ([self.request.allHTTPHeaderFields objectForKey:SlateURLProtocolIgnoreCacheControlHeadersHeader] != nil);
//            BOOL cacheNoExpire = ([self.request.allHTTPHeaderFields objectForKey:SlateURLProtocolCacheNoExpireHeader] != nil);
            NSUInteger contentLength = [[self.responseHTTPHeaders objectForKey:@"Content-Length"] intValue];
            
            if (contentLength == 0
                || isResponseCompressed
                || (contentLength == self.receivedData.length && self.receivedData.length > 0) )
            {
                // 下载完整
                
                // 总是缓存
                //if (allowsCaching || ignoreCacheControlHeaders || cacheNoExpire)
                {
                    [self writeCache:self.response redirectRequest:nil];
                }
            }
            else
            {
                // 下载不完整?
                DLog(@"SlateURLProtocol HTTP %ld incomplete %lu/%lu =------------- %@", (long)self.response.statusCode, (unsigned long)self.receivedData.length, (unsigned long)contentLength, self.response.URL);
            }
        }
        else
        {
            // 没有接收到数据。 HTTP状态码 304/404/500/503
            DLog(@"SlateURLProtocol HTTP %ld =------------- %@", (long)self.response.statusCode, self.response.URL);
        }
    }
}

- (void)connection:(NSURLConnection*)conn didFailWithError:(NSError*)error 
{
    if (self.didUseCache)
    {
        return;
    }
    
    if (self.cacheable && [self hasCache])
    {
        [self readCache];
        return;
    }
    
    [[self client] URLProtocol:self didFailWithError:error];
    [self setConnection:nil];
}

#pragma mark - private

- (BOOL)cacheNoExpire
{
    if (![[NSUserDefaults standardUserDefaults] boolForKey:@"SlateUseCache"])
    {
        // 不使用缓存，每次都刷新数据
        return NO;
    }
    
    BOOL cacheNoExpire = ([self.request.allHTTPHeaderFields objectForKey:SlateURLProtocolCacheNoExpireHeader] != nil);
    return cacheNoExpire;
}

- (BOOL)cacheExpiredReturnAge:(NSTimeInterval *)age
{
    if (![[NSUserDefaults standardUserDefaults] boolForKey:@"SlateUseCache"])
    {
        // 不使用缓存，每次都刷新数据
        return YES;
    }
    
    if ([[SlateReachability sharedReachability] isNetworkBroken])
    {
        // 断网了，直接读取缓存
        return NO;
    }

    NSDictionary *cachedHeaders = [self cachedHeaders];
    
    if (cachedHeaders && [cachedHeaders isKindOfClass:[NSDictionary class]])
    {
        return [[self class] cacheExpires:cachedHeaders age:age];
    }
    
    if ([[SlateURLProtocolCache defaultCache] isPermanentCachePath:self.cachePath])
    {
        // 永久缓存的路径
        return NO;
    }

    return YES;
}

- (BOOL)hasCache
{
    return [[SlateURLProtocolCache defaultCache] hasCacheWithPath:self.cachePath];
}

- (void)readCache
{
    self.didUseCache = YES;
    
    NSDictionary *cachedHeaders = [self cachedHeaders];
    if (!(cachedHeaders && [cachedHeaders isKindOfClass:[NSDictionary class]]))
    {
        cachedHeaders = @{};
    }
    
    /* create the response */
	NSHTTPURLResponse *theResponse =
    [[NSHTTPURLResponse alloc] initWithURL:self.request.URL
                                statusCode:200
                               HTTPVersion:@"HTTP/1.1"
                              headerFields:cachedHeaders];
    
    NSString *redirectURLString = [cachedHeaders objectForKey:SlateURLProtocolRedirectURLHeader];
    if (redirectURLString)
    {
        NSMutableURLRequest *redirectableRequest = [self.request mutableCopy];
        
        [NSURLProtocol removePropertyForKey:SlateURLProtocolRequest inRequest:redirectableRequest];
        
        [redirectableRequest setURL:[NSURL URLWithString:redirectURLString]];
        
        [[self client] URLProtocol:self wasRedirectedToRequest:redirectableRequest redirectResponse:theResponse];
        return;
    }
    
    NSData *data = [[SlateURLProtocolCache defaultCache] readCacheWithPath:self.cachePath];
	
    /* get a reference to the client so we can hand off the data */
    id<NSURLProtocolClient> client = [self client];
    
    /* turn off caching for this response data */ 
	[client URLProtocol:self didReceiveResponse:theResponse cacheStoragePolicy:NSURLCacheStorageNotAllowed];
	
    /* set the data in the response to our jfif data */ 
	[client URLProtocol:self didLoadData:data];
	
    /* notify that we completed loading */
	[client URLProtocolDidFinishLoading:self];
	
    /* we can release our copy */
    
    //DLog(@"readCache =------------- %@", self.cachePath);
}

- (void)writeCache:(NSHTTPURLResponse *)response redirectRequest:(NSURLRequest *)redirectRequest
{
    [[SlateURLProtocolCache defaultCache] writeCacheWithPath:self.cachePath data:self.receivedData responseHeaders:self.responseHTTPHeaders requestURL:self.request.URL redirectRequestURL:redirectRequest.URL];
}

- (NSDictionary *)cachedHeaders
{
    return [NSDictionary dictionaryWithContentsOfFile:self.cacheHeaderPath];
}

- (void)setConditionalGETHeaders
{
    NSDictionary *cachedHeaders = [self cachedHeaders];
    
    if (cachedHeaders && [cachedHeaders isKindOfClass:[NSDictionary class]])
    {
        NSString *etag = [cachedHeaders objectForKey:@"Etag"];
        if (etag)
        {
            [self.mutableRequest setValue:etag forHTTPHeaderField:@"If-None-Match"];
        }
        
        NSString *lastModified = [cachedHeaders objectForKey:@"Last-Modified"];
        if (lastModified)
        {
            [self.mutableRequest setValue:lastModified forHTTPHeaderField:@"If-Modified-Since"];
        }
    }
}

#pragma mark - HTTP协议

// 将字符串转化为GMT rfc1123格式的时间
+ (NSDate *)dateFromRFC1123String:(NSString *)string
{
	NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
	[formatter setLocale:[[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"]];
	// Does the string include a week day?
	NSString *day = @"";
	if ([string rangeOfString:@","].location != NSNotFound) {
		day = @"EEE, ";
	}
	// Does the string include seconds?
	NSString *seconds = @"";
	if ([[string componentsSeparatedByString:@":"] count] == 3) {
		seconds = @":ss";
	}
	[formatter setDateFormat:[NSString stringWithFormat:@"%@dd MMM yyyy HH:mm%@ z",day,seconds]];
	return [formatter dateFromString:string];
}

// response是否允许缓存
+ (BOOL)allowsCaching:(NSDictionary *)responseHeaders
{
	NSString *cacheControl = [[responseHeaders objectForKey:@"Cache-Control"] lowercaseString];
	if (cacheControl)
    {
		if ([cacheControl isEqualToString:@"no-cache"] || [cacheControl isEqualToString:@"no-store"])
        {
			return NO;
		}
	}
    
	NSString *pragma = [[responseHeaders objectForKey:@"Pragma"] lowercaseString];
	if (pragma)
    {
		if ([pragma isEqualToString:@"no-cache"])
        {
			return NO;
		}
	}
    
	return YES;
}

// 缓存是否过期
+ (BOOL)cacheExpires:(NSDictionary *)responseHeaders age:(NSTimeInterval *)age
{
    // Look for a max-age header
    NSString *cacheControl = [[responseHeaders objectForKey:@"Cache-Control"] lowercaseString];
    if (cacheControl)
    {
        NSScanner *scanner = [NSScanner scannerWithString:cacheControl];
        [scanner scanUpToString:@"max-age" intoString:NULL];
        if ([scanner scanString:@"max-age" intoString:NULL])
        {
            [scanner scanString:@"=" intoString:NULL];
            NSTimeInterval maxAge = 0;
            [scanner scanDouble:&maxAge];
            
            NSDate *fetchDate = [self dateFromRFC1123String:[responseHeaders objectForKey:SlateURLProtocolFetchDateHeader]];
            NSDate *expiryDate = [[NSDate alloc] initWithTimeInterval:maxAge sinceDate:fetchDate];
            
            if ([expiryDate timeIntervalSinceNow] >= 0)
            {
                *age = [[NSDate date] timeIntervalSinceDate:fetchDate];
                return NO;
            }
            
            // RFC 2612 says max-age must override any Expires header
            return YES;
        }
    }
    
    // Look for an Expires header to see if the content is out of date
    NSString *expires = [responseHeaders objectForKey:@"Expires"];
    if (expires)
    {
        NSDate *expireDate = [self dateFromRFC1123String:expires];
        if (expireDate)
        {
            if ([expireDate timeIntervalSinceNow] >= 0)
            {
                NSDate *fetchDate = [self dateFromRFC1123String:[responseHeaders objectForKey:SlateURLProtocolFetchDateHeader]];
                *age = [[NSDate date] timeIntervalSinceDate:fetchDate];
                return NO;
            }
        }
    }
    
    // No explicit expiration time sent by the server
    return YES;
}

@end
