// Native offline test: production frame codec and response state machine; no API calls.
#import "../Sources/MWPetDoubaoVoice.m"
#include <assert.h>
@interface MWVoiceProbe : MWPetDoubaoVoice
@property(nonatomic,strong) NSMutableArray *events;
@property(nonatomic,copy) NSString *lastStatus;
@end
@implementation MWVoiceProbe
- (void)report:(NSString *)text { self.lastStatus=text; }
- (void)send:(uint32_t)event session:(NSString *)sid body:(NSDictionary *)body then:(void (^)(void))next {
 (void)sid; (void)body; [self.events addObject:@(event)]; if(next)next();
}
@end
static NSData *response(unsigned type,unsigned event,NSString *identifier,NSData *payload) {
 uint8_t h[]={0x11,(uint8_t)((type<<4)|4),0,0};
 NSMutableData *d=[NSMutableData dataWithBytes:h length:4];MWVoiceU32(d,event);
 NSData *s=[identifier dataUsingEncoding:NSUTF8StringEncoding];MWVoiceU32(d,(uint32_t)s.length);[d appendData:s];MWVoiceU32(d,(uint32_t)payload.length);[d appendData:payload];return d;
}
int main(void) { @autoreleasepool {
 NSData *f=MWVoiceFrame(1,nil,@{}); const uint8_t *b=f.bytes;assert(f.length==14&&b[0]==0x11&&b[1]==0x14&&b[2]==0x10);
 NSUInteger offset=4;uint32_t v=0;assert(MWVoiceRead(f,&offset,&v)&&v==1);assert(MWVoiceRead(f,&offset,&v)&&v==2);offset=f.length;assert(!MWVoiceRead(f,&offset,&v));
 f=MWVoiceFrame(200,@"s",@{@"text":@"你好"});offset=4;assert(MWVoiceRead(f,&offset,&v)&&v==200);assert(MWVoiceRead(f,&offset,&v)&&v==1);offset++;assert(MWVoiceRead(f,&offset,&v));assert(offset+v==f.length);assert([NSJSONSerialization JSONObjectWithData:[f subdataWithRange:NSMakeRange(offset,v)] options:0 error:nil]);
 MWVoiceProbe *p=[MWVoiceProbe new];p.sid=@"s";p.speaker=@"zh_female_xiaohe_uranus_bigtts";p.text=@"测试";p.events=[NSMutableArray new];p.audio=[NSMutableData new];
 NSData *empty=[@"{}" dataUsingEncoding:NSUTF8StringEncoding];
 [p consume:response(9,50,@"connection",empty)];assert([p.events isEqual:@[@100]]);
 [p consume:response(9,150,@"s",empty)];assert(([p.events isEqual:@[@100,@200,@102]]));
 NSData *audio=[@"mock-mp3-frame" dataUsingEncoding:NSUTF8StringEncoding];[p consume:response(11,352,@"s",audio)];assert([p.audio isEqual:audio]);
 [p consume:response(9,153,@"s",empty)];assert(p.lastStatus.length&&!p.audio);
 p.audio=[NSMutableData new];[p consume:response(11,352,@"wrong",audio)];assert([p.lastStatus containsString:@"不匹配"]);
 for(NSUInteger n=0;n<14;n++){[p consume:[f subdataWithRange:NSMakeRange(0,n)]];assert(p.lastStatus.length);}
 assert(MWPetDoubaoVoice.voices.count==10);
 puts("PASS native Doubao production codec/state tests: frames, handshake, text+finish ordering, audio, failure, stale session, truncation; no network/key used");
 }return 0;}
