#import "../Sources/MowangDaFeiYuPetEnvironment.h"
#include <assert.h>
int main(void) { @autoreleasepool {
    MowangPetBattery s={0};
    assert(!mowang_pet_battery(&s,-1,0)); assert(!s.baseline);
    assert(!mowang_pet_battery(&s,.5,1));
    assert(mowang_pet_battery(&s,.20,1)); assert(!mowang_pet_battery(&s,.19,1));
    assert(mowang_pet_battery(&s,.10,1)); assert(!mowang_pet_battery(&s,.09,1));
    assert(!mowang_pet_battery(&s,.21,1)); assert(!mowang_pet_battery(&s,.19,1));
    assert(mowang_pet_battery(&s,.19,2)); assert(!mowang_pet_battery(&s,.2,2));
    assert(mowang_pet_battery(&s,1,3)); assert(!mowang_pet_battery(&s,1,3));
    assert(!mowang_pet_battery(&s,.8,1)); assert(mowang_pet_battery(&s,.09,1)); assert(!mowang_pet_battery(&s,.08,1));
    MowangPetBattery low={0}; assert(!mowang_pet_battery(&low,.08,1)); assert(!mowang_pet_battery(&low,.07,1));
    assert(!mowang_pet_battery(&low,NAN,2)); assert(low.state==1);
    NSDictionary *city=@{@"name":@"测试城",@"latitude":@30,@"longitude":@120};
    assert(mowang_pet_city(city)); assert(!mowang_pet_city(@{@"name":@"x",@"latitude":@YES,@"longitude":@0}));
    NSArray *cities=mowang_pet_cities(@{@"results":@[NSNull.null,city,@{@"name":@"bad",@"latitude":@91,@"longitude":@0}]}); assert(cities.count==1);
    assert(!mowang_pet_cities(@[]).count); assert(!mowang_pet_cities(@{@"error":@YES}).count);
    NSMutableDictionary *current=[@{@"time":@10000,@"temperature_2m":@22,@"weather_code":@0} mutableCopy];
    NSMutableDictionary *weather=[@{@"current":current,@"current_units":@{@"time":@"unixtime",@"temperature_2m":@"°C"}} mutableCopy];
    assert(mowang_pet_weather(weather,city,10000));
    current[@"time"]=@1; assert(!mowang_pet_weather(weather,city,10000));
    current[@"time"]=@10400; assert(!mowang_pet_weather(weather,city,10000)); current[@"time"]=@10000;
    current[@"weather_code"]=@4; assert(!mowang_pet_weather(weather,city,10000));
    current[@"weather_code"]=@61; assert([mowang_pet_weather(weather,city,10000) containsString:@"雨"]);
    current[@"temperature_2m"]=NSNull.null; assert(!mowang_pet_weather(weather,city,10000));
    assert(!mowang_pet_weather(@[],city,10000));
    assert(mowang_pet_weatherFresh(10000,10001)); assert(!mowang_pet_weatherFresh(10000,11800)); assert(!mowang_pet_weatherFresh(10000,9999));
    assert([mowang_pet_forecastURL(city).scheme isEqual:@"https"]);
    __block BOOL refused=NO;
    MowangPetWeatherRequest *r=[MowangPetWeatherRequest new];
    [r start:[NSURL URLWithString:@"http://api.open-meteo.com/"] completion:^(id json,NSString *failure){ refused=!json && failure.length>0; }]; assert(refused);
    NSURLSession *session=NSURLSession.sharedSession;
    NSURLSessionDataTask *task=[session dataTaskWithURL:mowang_pet_forecastURL(city)]; // Never resumed.
    r.task=task;
    NSHTTPURLResponse *response=[[NSHTTPURLResponse alloc] initWithURL:mowang_pet_forecastURL(city) statusCode:302 HTTPVersion:@"HTTP/1.1" headerFields:@{}];
    __block NSURLRequest *redirect=(id)NSNull.null;
    [r URLSession:session task:task willPerformHTTPRedirection:response newRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:@"https://example.com/"]] completionHandler:^(NSURLRequest *request) { redirect=request; }]; assert(!redirect && r.failure.length);
    __block NSURLSessionResponseDisposition disposition=NSURLSessionResponseAllow;
    NSHTTPURLResponse *tooBig=[[NSHTTPURLResponse alloc] initWithURL:mowang_pet_forecastURL(city) statusCode:200 HTTPVersion:@"HTTP/1.1" headerFields:@{@"Content-Length":@"65537"}];
    [r URLSession:session dataTask:task didReceiveResponse:tooBig completionHandler:^(NSURLSessionResponseDisposition value) { disposition=value; }]; assert(disposition==NSURLSessionResponseCancel);
    r.data=[NSMutableData new]; r.failure=nil;
    [r URLSession:session dataTask:task didReceiveData:[NSMutableData dataWithLength:65537]]; assert(r.data.length==0 && r.failure.length);
    puts("PASS battery baseline/tiers/dedup/reset/charging/full/unknown; weather city/parser/expiry/failure/HTTPS/redirect/64KB");
} return 0; }
