#import "MowangDaFeiYuPetBalance.h"
#import <Security/Security.h>
#import <LocalAuthentication/LocalAuthentication.h>
#import <os/log.h>

static os_log_t mowang_dafeiyupet_balanceLog(void) {
    static os_log_t log;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ log=os_log_create("com.mowang.dafeiyupet", "balance"); });
    return log;
}

NSString *mowang_dafeiyupet_balanceSourceID(void) {
    NSUserDefaults *settings=NSUserDefaults.standardUserDefaults;
    NSString *pinned=[settings stringForKey:@"MWAIHubThirdPartyPinnedID"];
    return pinned.length?[ @"thirdparty-" stringByAppendingString:pinned ]:([settings integerForKey:@"MWAIHubProvider"]==1?@"wanwanzhou":@"zn");
}

@interface MowangDaFeiYuPetBalanceClient ()
@property(nonatomic,strong) NSURLSession *session;
@property(nonatomic,strong) NSURLSessionDataTask *task;
@property(nonatomic,strong) NSMutableData *data;
@property(nonatomic,copy) void (^completion)(NSString *,BOOL);
@property(nonatomic,copy) NSString *name,*failure;
@property(nonatomic) BOOL zn;
@end
@implementation MowangDaFeiYuPetBalanceClient
- (BOOL)busy { return self.task!=nil; }
- (void)cancel {
    self.completion=nil;
    [self.task cancel]; self.task=nil;
    [self.session invalidateAndCancel]; self.session=nil; self.data=nil;
}
- (void)finish:(NSString *)text success:(BOOL)success {
    void (^callback)(NSString *,BOOL)=self.completion;
    [self cancel];
    if(callback) callback(text,success);
}
- (void)query:(void (^)(NSString *,BOOL))completion {
    if(self.busy) return;
    self.completion=completion; self.failure=nil;
    NSUserDefaults *settings=NSUserDefaults.standardUserDefaults;
    NSString *pinned=[settings stringForKey:@"MWAIHubThirdPartyPinnedID"];
    NSString *account=nil; NSURLComponents *url=nil;
    self.zn=NO;
    if(pinned.length) {
        id records=[settings objectForKey:@"MWAIHubThirdPartyRecordsV1"];
        if([records isKindOfClass:NSArray.class]) for(id record in records) {
            if(![record isKindOfClass:NSDictionary.class] || ![record[@"id"] isEqual:pinned]) continue;
            if([record[@"url"] isKindOfClass:NSString.class]) url=[NSURLComponents componentsWithString:record[@"url"]];
            self.name=[record[@"name"] isKindOfClass:NSString.class]?record[@"name"]:@"第三方";
            account=[@"thirdparty-" stringByAppendingString:pinned]; break;
        }
    } else {
        self.zn=[settings integerForKey:@"MWAIHubProvider"]!=1;
        account=self.zn?@"zn":@"wanwanzhou"; self.name=self.zn?@"智纽":@"晚晚舟";
        url=[NSURLComponents componentsWithString:self.zn?@"https://ai.apizn.com/api/usage/token/":@"https://wanwanzhou.top/v1/usage"];
    }
    NSArray *hosts=@[@"ai.apizn.com",@"wanwanzhou.top",@"xingchiapi.com",@"luluai.win"];
    BOOL valid=url && [url.scheme.lowercaseString isEqual:@"https"] && [hosts containsObject:url.host.lowercaseString] && (!url.port || url.port.integerValue==443) && !url.user && !url.password && !url.query && !url.fragment && ([url.path isEqual:@"/v1/usage"] || (self.zn && [url.path isEqual:@"/api/usage/token/"]));
    if(!valid || !account.length) {
        os_log(mowang_dafeiyupet_balanceLog(),"BalanceQuery invalid source pinned=%d url=%d",pinned.length>0,url!=nil);
        [self finish:@"余额来源无效；请在余额监控选择平台或有效的 /v1/usage 记录。" success:NO]; return;
    }
    LAContext *lac=[LAContext new]; lac.interactionNotAllowed=YES;
    NSDictionary *q=@{(__bridge id)kSecClass:(__bridge id)kSecClassGenericPassword,(__bridge id)kSecAttrService:@"com.mowang.aihubmanager",(__bridge id)kSecAttrAccount:account,(__bridge id)kSecReturnData:@YES,(__bridge id)kSecMatchLimit:(__bridge id)kSecMatchLimitOne,(__bridge id)kSecUseAuthenticationContext:lac};
    CFTypeRef result=NULL; OSStatus status=SecItemCopyMatching((__bridge CFDictionaryRef)q,&result);
    id bytes=CFBridgingRelease(result);
    NSString *key=status==errSecSuccess && [bytes isKindOfClass:NSData.class]?[[NSString alloc] initWithData:bytes encoding:NSUTF8StringEncoding]:nil;
    if(!key.length || key.length>4096 || [key rangeOfCharacterFromSet:NSCharacterSet.controlCharacterSet].location!=NSNotFound) {
        os_log(mowang_dafeiyupet_balanceLog(),"BalanceQuery key unavailable status=%d",(int)status);
        [self finish:@"无法读取余额监控的 Key；请解锁并在原插件保存 Key。" success:NO]; return;
    }
    if([url.host.lowercaseString isEqual:@"wanwanzhou.top"]) {
        NSDateFormatter *f=[NSDateFormatter new]; f.locale=[NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"]; f.timeZone=NSTimeZone.localTimeZone;
        NSDate *now=NSDate.date; f.dateFormat=@"yyyy-MM-dd"; NSString *end=[f stringFromDate:now]; f.dateFormat=@"yyyy-MM-01"; NSString *start=[f stringFromDate:now]; f.dateFormat=@"d";
        url.queryItems=@[[NSURLQueryItem queryItemWithName:@"start_date" value:start],[NSURLQueryItem queryItemWithName:@"end_date" value:end],[NSURLQueryItem queryItemWithName:@"days" value:[f stringFromDate:now]],[NSURLQueryItem queryItemWithName:@"timezone" value:f.timeZone.name]];
    }
    NSMutableURLRequest *r=[NSMutableURLRequest requestWithURL:url.URL]; r.HTTPMethod=@"GET"; r.timeoutInterval=20;
    [r setValue:@"application/json" forHTTPHeaderField:@"Accept"]; [r setValue:[@"Bearer " stringByAppendingString:key] forHTTPHeaderField:@"Authorization"];
    NSURLSessionConfiguration *c=NSURLSessionConfiguration.ephemeralSessionConfiguration;
    c.URLCache=nil; c.HTTPCookieStorage=nil; c.URLCredentialStorage=nil; c.HTTPShouldSetCookies=NO; c.timeoutIntervalForResource=25;
    self.data=[NSMutableData new]; self.session=[NSURLSession sessionWithConfiguration:c delegate:self delegateQueue:NSOperationQueue.mainQueue];
    os_log(mowang_dafeiyupet_balanceLog(),"BalanceQuery network start zn=%d pinned=%d",self.zn,pinned.length>0);
    self.task=[self.session dataTaskWithRequest:r]; [self.task resume];
}
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task willPerformHTTPRedirection:(NSHTTPURLResponse *)response newRequest:(NSURLRequest *)request completionHandler:(void (^)(NSURLRequest *))completionHandler {
    self.failure=@"余额接口要求重定向，已拒绝转发密钥。"; completionHandler(nil);
}
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)task didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler {
    NSInteger code=[response isKindOfClass:NSHTTPURLResponse.class]?((NSHTTPURLResponse *)response).statusCode:0;
    BOOL ok=task==self.task && code==200 && response.expectedContentLength<=65536;
    if(!ok) self.failure=code==401||code==403?@"余额查询未授权，请检查原插件的 Key。":@"余额接口错误或响应超过64KB。";
    completionHandler(ok?NSURLSessionResponseAllow:NSURLSessionResponseCancel);
}
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)task didReceiveData:(NSData *)data {
    if(task!=self.task) return;
    if(self.data.length+data.length>65536) { self.failure=@"余额响应超过64KB。"; [task cancel]; return; }
    [self.data appendData:data];
}
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    if(task!=self.task) return;
    NSString *text=(!error && !self.failure)?mowang_dafeiyupet_balanceText([NSJSONSerialization JSONObjectWithData:self.data options:0 error:nil],self.zn,self.name):nil;
    os_log(mowang_dafeiyupet_balanceLog(),"BalanceQuery network finish success=%d error=%d",text!=nil,error!=nil || self.failure!=nil);
    [self finish:text ?: self.failure ?: (error?@"余额查询连接失败或超时，请稍后重试。":@"接口未返回可验证的账户余额或配额。") success:text!=nil];
}
@end
