#pragma once
#import <Foundation/Foundation.h>
#import <math.h>

typedef struct { BOOL baseline; NSInteger state; unsigned tiers; } MowangPetBattery;
// UIDeviceBatteryState: unknown=0, unplugged=1, charging=2, full=3.
static inline NSString *mowang_pet_battery(MowangPetBattery *s, double level, NSInteger state) {
    if(!isfinite(level) || level<0 || level>1 || state<1 || state>3) return nil;
    unsigned tier=level<=.10001?3:level<=.20001?1:0;
    if(!s->baseline) { s->baseline=YES; s->state=state; s->tiers=state==1?tier:0; return nil; }
    NSInteger old=s->state; s->state=state;
    if(state>=2 && old==1) { s->tiers=0; return state==3?@"电量满格啦，精神满满！":@"接上电源啦，补充一点能量～"; }
    if(state==3 && old!=3) return @"电量满格啦，精神满满！";
    if(state!=1) return nil;
    unsigned fresh=tier & ~s->tiers; s->tiers|=tier;
    if(fresh&2) return @"电量不多于 10% 啦，快给手机补充能量吧！";
    if(fresh&1) return @"电量不多于 20% 啦，记得准备充电哦～";
    return nil;
}
static inline BOOL mowang_pet_number(id value, double low, double high) {
    return [value isKindOfClass:NSNumber.class] && CFGetTypeID((__bridge CFTypeRef)value)!=CFBooleanGetTypeID() && isfinite([value doubleValue]) && [value doubleValue]>=low && [value doubleValue]<=high;
}
static inline BOOL mowang_pet_label(id value) {
    return [value isKindOfClass:NSString.class] && [value length]>0 && [value length]<=80 && [value rangeOfCharacterFromSet:NSCharacterSet.controlCharacterSet].location==NSNotFound;
}
static inline BOOL mowang_pet_city(id city) {
    return [city isKindOfClass:NSDictionary.class] && mowang_pet_label(city[@"name"]) && mowang_pet_number(city[@"latitude"],-90,90) && mowang_pet_number(city[@"longitude"],-180,180);
}
static inline NSArray *mowang_pet_cities(id json) {
    if(![json isKindOfClass:NSDictionary.class] || json[@"error"] || ![json[@"results"] isKindOfClass:NSArray.class]) return @[];
    NSMutableArray *cities=[NSMutableArray new];
    for(id row in json[@"results"]) {
        if(!mowang_pet_city(row)) continue;
        NSMutableArray *parts=[NSMutableArray arrayWithObject:row[@"name"]];
        for(NSString *key in @[@"admin1",@"country"]) if(mowang_pet_label(row[key]) && ![parts containsObject:row[key]]) [parts addObject:row[key]];
        [cities addObject:@{@"name":row[@"name"],@"label":[parts componentsJoinedByString:@" · "],@"latitude":row[@"latitude"],@"longitude":row[@"longitude"]}];
        if(cities.count==5) break;
    }
    return cities;
}
static inline NSString *mowang_pet_weather(id json, id city, NSTimeInterval now) {
    if(!mowang_pet_city(city) || ![json isKindOfClass:NSDictionary.class] || json[@"error"]) return nil;
    id current=json[@"current"], units=json[@"current_units"];
    if(![current isKindOfClass:NSDictionary.class] || ![units isKindOfClass:NSDictionary.class] || ![units[@"temperature_2m"] isEqual:@"°C"] || ![units[@"time"] isEqual:@"unixtime"] || !mowang_pet_number(current[@"time"],now-3600,now+300) || !mowang_pet_number(current[@"temperature_2m"],-100,70) || !mowang_pet_number(current[@"weather_code"],0,99)) return nil;
    double raw=[current[@"weather_code"] doubleValue]; if(floor(raw)!=raw) return nil;
    NSInteger code=(NSInteger)raw;
    NSString *condition=@{@0:@"晴朗",@1:@"大致晴朗",@2:@"多云",@3:@"阴天",@45:@"有雾",@48:@"有雾",@51:@"毛毛雨",@53:@"毛毛雨",@55:@"毛毛雨",@56:@"冻毛毛雨",@57:@"冻毛毛雨",@61:@"有雨",@63:@"有雨",@65:@"大雨",@66:@"冻雨",@67:@"冻雨",@71:@"有雪",@73:@"有雪",@75:@"大雪",@77:@"雪粒",@80:@"阵雨",@81:@"阵雨",@82:@"强阵雨",@85:@"阵雪",@86:@"阵雪",@95:@"雷雨",@96:@"雷雨伴冰雹",@99:@"雷雨伴冰雹"}[@(code)];
    if(!condition) return nil;
    double t=[current[@"temperature_2m"] doubleValue];
    NSString *tip=code>=95?@"注意雷雨，出门小心哦！":code>=51?@"出门留意雨雪哦～":t>=30?@"记得补水防晒～":t<=10?@"记得添件衣服～":@"愿你今天也有好心情～";
    return [NSString stringWithFormat:@"%@：%@，%.0f°C。%@",city[@"name"],condition,t,tip];
}
static inline BOOL mowang_pet_weatherFresh(NSTimeInterval fetched, NSTimeInterval now) { return isfinite(fetched) && now>=fetched && now-fetched<1800; }

// One bounded ephemeral request, no cookies, credentials, disk cache or redirects.
@interface MowangPetWeatherRequest : NSObject <NSURLSessionDataDelegate>
@property(nonatomic,strong) NSURLSession *session;
@property(nonatomic,strong) NSURLSessionDataTask *task;
@property(nonatomic,strong) NSMutableData *data;
@property(nonatomic,copy) void (^completion)(id, NSString *);
@property(nonatomic,copy) NSString *failure;
- (void)start:(NSURL *)url completion:(void (^)(id, NSString *))completion;
- (void)cancel;
@end
@implementation MowangPetWeatherRequest
- (void)cancel { self.completion=nil; [self.session invalidateAndCancel]; self.session=nil; self.task=nil; self.data=nil; }
- (void)start:(NSURL *)url completion:(void (^)(id, NSString *))completion {
    [self cancel];
    if(![url.scheme isEqual:@"https"] || ![@[@"api.open-meteo.com",@"geocoding-api.open-meteo.com"] containsObject:url.host] || url.user || url.password) { completion(nil,@"天气地址无效。"); return; }
    self.completion=completion; self.failure=nil; self.data=[NSMutableData new];
    NSURLSessionConfiguration *c=NSURLSessionConfiguration.ephemeralSessionConfiguration;
    c.timeoutIntervalForRequest=12; c.timeoutIntervalForResource=15; c.URLCache=nil; c.HTTPCookieStorage=nil; c.URLCredentialStorage=nil;
    self.session=[NSURLSession sessionWithConfiguration:c delegate:self delegateQueue:NSOperationQueue.mainQueue];
    self.task=[self.session dataTaskWithURL:url]; [self.task resume];
}
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task willPerformHTTPRedirection:(NSHTTPURLResponse *)response newRequest:(NSURLRequest *)request completionHandler:(void (^)(NSURLRequest *))completionHandler { self.failure=@"天气服务发生重定向，已拒绝。"; completionHandler(nil); }
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)task didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler {
    if(task!=self.task || ![response isKindOfClass:NSHTTPURLResponse.class] || ((NSHTTPURLResponse *)response).statusCode!=200 || response.expectedContentLength>65536) { self.failure=@"天气服务不可用或响应过大。"; completionHandler(NSURLSessionResponseCancel); } else completionHandler(NSURLSessionResponseAllow);
}
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)task didReceiveData:(NSData *)data {
    if(task!=self.task) return;
    if(self.data.length+data.length>65536) { self.failure=@"天气响应超过 64KB，已停止。"; [task cancel]; } else [self.data appendData:data];
}
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    if(task!=self.task) return;
    id json=(!error && !self.failure)?[NSJSONSerialization JSONObjectWithData:self.data options:0 error:NULL]:nil;
    NSString *failure=self.failure ?: (error?@"天气暂时查不到，请稍后再试。":(!json?@"天气数据格式无效。":nil));
    void (^done)(id,NSString *)=self.completion;
    [self cancel]; if(done) done(json,failure);
}
@end
static inline NSURL *mowang_pet_forecastURL(NSDictionary *city) {
    if(!mowang_pet_city(city)) return nil;
    return [NSURL URLWithString:[NSString stringWithFormat:@"https://api.open-meteo.com/v1/forecast?latitude=%.5f&longitude=%.5f&current=temperature_2m,weather_code&temperature_unit=celsius&timeformat=unixtime&forecast_days=1",[city[@"latitude"] doubleValue],[city[@"longitude"] doubleValue]]];
}
