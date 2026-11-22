#pragma once
#import <Foundation/Foundation.h>
#import <math.h>

static inline NSNumber *mowang_dafeiyupet_balanceNumber(id value) {
    if(![value isKindOfClass:NSNumber.class] && ![value isKindOfClass:NSString.class]) return nil;
    if([value isKindOfClass:NSNumber.class] && CFGetTypeID((__bridge CFTypeRef)value)==CFBooleanGetTypeID()) return nil;
    NSScanner *scanner=[NSScanner scannerWithString:[value description]];
    double number=0;
    if(![scanner scanDouble:&number] || !scanner.isAtEnd || !isfinite(number)) return nil;
    return @(number);
}
static inline NSString *mowang_dafeiyupet_balanceText(id json, BOOL zn, NSString *name) {
    if(![json isKindOfClass:NSDictionary.class]) return nil;
    NSDictionary *root=json;
    for(NSString *flag in @[@"success",@"code"]) {
        id v=root[flag];
        if([v isKindOfClass:NSNumber.class] && ![v boolValue]) return nil;
    }
    if(zn) {
        NSDictionary *data=[root[@"data"] isKindOfClass:NSDictionary.class]?root[@"data"]:nil;
        NSDictionary *quota=[data[@"user_quota"] isKindOfClass:NSDictionary.class]?data[@"user_quota"]:nil;
        NSNumber *amount=mowang_dafeiyupet_balanceNumber(quota[@"total_available"]);
        if(![root[@"code"] isEqual:@YES] || ![data[@"object"] isEqual:@"token_usage"] || !amount) return nil;
        return [NSString stringWithFormat:@"%@：账户剩余额度 %@（原始 quota，未换算金额）",name,amount];
    }
    if([root[@"mode"] isEqual:@"quota_limited"]) {
        NSDictionary *quota=[root[@"quota"] isKindOfClass:NSDictionary.class]?root[@"quota"]:nil;
        NSNumber *amount=mowang_dafeiyupet_balanceNumber(quota[@"remaining"]);
        return amount?[NSString stringWithFormat:@"%@：Key 剩余配额 %@（非账户钱包）",name,amount]:nil;
    }
    NSDictionary *data=[root[@"data"] isKindOfClass:NSDictionary.class]?root[@"data"]:root;
    NSNumber *amount=mowang_dafeiyupet_balanceNumber(data[@"balance"]);
    if(!amount) return nil;
    NSString *currency=[data[@"currency"] isKindOfClass:NSString.class]?data[@"currency"]:@"";
    if(currency.length!=3 || [currency rangeOfCharacterFromSet:[[NSCharacterSet characterSetWithCharactersInString:@"ABCDEFGHIJKLMNOPQRSTUVWXYZ"] invertedSet]].location!=NSNotFound) currency=@"单位未声明";
    return [NSString stringWithFormat:@"%@：账户余额 %@ %@（接口返回）",name,amount,currency];
}
NSString *mowang_dafeiyupet_balanceSourceID(void);
@interface MowangDaFeiYuPetBalanceClient : NSObject <NSURLSessionDataDelegate>
@property(nonatomic,readonly) BOOL busy;
- (void)query:(void (^)(NSString *text, BOOL success))completion;
- (void)cancel;
@end
