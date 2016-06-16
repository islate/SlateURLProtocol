//
//  NSString+md5.m
//  SlateCore
//
//  Created by lin yize on 14-1-14.
//  Copyright (c) 2015年 Modern Mobile Digital Media Company Limited. All rights reserved.
//

#import "NSString+md5.h"

#import <CommonCrypto/CommonCryptor.h>
#import <CommonCrypto/CommonDigest.h>

@implementation NSString (MD5)

- (NSString *)md5
{
    const char      *cStr = [self UTF8String];
    unsigned char   result[CC_MD5_DIGEST_LENGTH];
    
    CC_MD5(cStr, (CC_LONG)strlen(cStr), result);
    
    NSMutableString *resultStr = [NSMutableString stringWithCapacity:CC_MD5_DIGEST_LENGTH * 2];
    
    for (int i = 0; i < CC_MD5_DIGEST_LENGTH; i++)
    {
        [resultStr appendFormat:@"%02x", result[i]];
    }
    
    return resultStr;
}

@end
