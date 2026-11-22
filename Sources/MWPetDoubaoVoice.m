#import "MWPetDoubaoVoice.h"
#import <Security/Security.h>
static NSDictionary *MWVoiceKeyQuery(void) {
 return @{(__bridge id)kSecClass:(__bridge id)kSecClassGenericPassword,(__bridge id)kSecAttrService:@"com.mowang.dafeiyupet.doubao",(__bridge id)kSecAttrAccount:@"tts"};
}
static void MWVoiceU32(NSMutableData *data,uint32_t value) { value=CFSwapInt32HostToBig(value); [data appendBytes:&value length:4]; }
static NSData *MWVoiceFrame(uint32_t event,NSString *sid,NSDictionary *body) {
 uint8_t header[]={0x11,0x14,0x10,0}; NSMutableData *data=[NSMutableData dataWithBytes:header length:4]; MWVoiceU32(data,event);
 if(sid) { NSData *s=[sid dataUsingEncoding:NSUTF8StringEncoding]; MWVoiceU32(data,(uint32_t)s.length); [data appendData:s]; }
 NSData *json=[NSJSONSerialization dataWithJSONObject:body options:0 error:nil]; MWVoiceU32(data,(uint32_t)json.length); [data appendData:json]; return data;
}
static BOOL MWVoiceRead(NSData *d,NSUInteger *offset,uint32_t *v) {
 if(*offset>d.length || d.length-*offset<4) return NO; uint32_t x; [d getBytes:&x range:NSMakeRange(*offset,4)]; *offset+=4; *v=CFSwapInt32BigToHost(x); return YES;
}
@interface MWPetDoubaoVoice ()
@property(nonatomic,strong) NSURLSession *session;
@property(nonatomic,strong) NSURLSessionWebSocketTask *socket;
@property(nonatomic,strong) NSMutableData *audio;
@property(nonatomic,strong) AVAudioPlayer *player;
@property(nonatomic,copy) NSString *sid,*text,*speaker;
@property(nonatomic) NSUInteger generation;
@property(nonatomic) float volume;
@end
@implementation MWPetDoubaoVoice
+ (NSArray *)voices {
 return @[
 @{ @"name":@"较弱萝莉",@"id":@"ICL_uranus_zh_female_jiaoruoluoli_tob"},
 @{ @"name":@"邪魅女王",@"id":@"ICL_uranus_zh_female_xiemeinvwang_tob"},
 @{ @"name":@"病弱少女",@"id":@"ICL_uranus_zh_female_bingruoshaonv_tob"},
 @{ @"name":@"调皮公主",@"id":@"ICL_uranus_zh_female_tiaopigongzhu_tob"},
 @{ @"name":@"傲慢娇声",@"id":@"ICL_uranus_zh_female_aomanjiaosheng_tob"},
 @{ @"name":@"病娇萌妹",@"id":@"ICL_uranus_zh_female_bingjiaomengmei_tob"},
 @{ @"name":@"湾湾小何",@"id":@"zh_female_xiaohe_uranus_bigtts"},
 @{ @"name":@"魅力苏菲",@"id":@"zh_female_sophie_uranus_bigtts"},
 @{ @"name":@"柔美女友",@"id":@"zh_female_roumeinvyou_uranus_bigtts"},
 @{ @"name":@"玲玲姐姐",@"id":@"zh_female_lingling_uranus_bigtts"}];
}
+ (BOOL)saveKey:(NSString *)key {
 NSDictionary *q=MWVoiceKeyQuery();
 if(!key.length) { OSStatus s=SecItemDelete((__bridge CFDictionaryRef)q); return s==errSecSuccess||s==errSecItemNotFound; }
 if(key.length>4096 || [key rangeOfCharacterFromSet:NSCharacterSet.whitespaceAndNewlineCharacterSet].location!=NSNotFound) return NO;
 NSDictionary *a=@{(__bridge id)kSecValueData:[key dataUsingEncoding:NSUTF8StringEncoding],(__bridge id)kSecAttrAccessible:(__bridge id)kSecAttrAccessibleWhenUnlockedThisDeviceOnly};
 OSStatus s=SecItemUpdate((__bridge CFDictionaryRef)q,(__bridge CFDictionaryRef)a);
 if(s==errSecItemNotFound) { NSMutableDictionary *n=[q mutableCopy]; [n addEntriesFromDictionary:a]; s=SecItemAdd((__bridge CFDictionaryRef)n,NULL); } return s==errSecSuccess;
}
- (void)report:(NSString *)text { if(self.status) self.status(text); }
- (void)stop {
 self.generation++; [self.socket cancelWithCloseCode:NSURLSessionWebSocketCloseCodeNormalClosure reason:nil]; self.socket=nil;
 [self.session invalidateAndCancel]; self.session=nil; [self.player stop]; self.player=nil; self.audio=nil; self.text=nil;
}
- (void)fail:(NSString *)message { [self stop]; [self report:message]; }
- (void)send:(uint32_t)event session:(NSString *)sid body:(NSDictionary *)body then:(void (^)(void))next {
 NSUInteger g=self.generation; __weak typeof(self) weak=self;
 [self.socket sendMessage:[[NSURLSessionWebSocketMessage alloc] initWithData:MWVoiceFrame(event,sid,body)] completionHandler:^(NSError *error) {
 dispatch_async(dispatch_get_main_queue(),^{ typeof(self) owner=weak; if(!owner||g!=owner.generation)return; if(error) [owner fail:@"豆包语音发送失败，请检查网络或鉴权权限。"]; else if(next)next(); }); }];
}
- (NSDictionary *)body:(uint32_t)event text:(NSString *)text {
 NSMutableDictionary *params=[@{@"speaker":self.speaker,@"audio_params":@{@"format":@"mp3",@"sample_rate":@24000,@"bit_rate":@64000}} mutableCopy];
 if(text)params[@"text"]=text;
 return @{@"user":@{@"uid":@"dafeiyupet"},@"namespace":@"BidirectionalTTS",@"event":@(event),@"req_params":params};
}
- (void)speak:(NSString *)text speaker:(NSString *)speaker volume:(float)volume {
 [self stop]; if(!text.length)return;
 if(![[[self.class voices] valueForKey:@"id"] containsObject:speaker]) { [self report:@"请选择有效的豆包声线。"];return; }
 NSMutableDictionary *q=[MWVoiceKeyQuery() mutableCopy]; q[(__bridge id)kSecReturnData]=@YES; CFTypeRef result=NULL;
 OSStatus s=SecItemCopyMatching((__bridge CFDictionaryRef)q,&result); NSData *secret=CFBridgingRelease(result);
 NSString *key=s==errSecSuccess?[[NSString alloc] initWithData:secret encoding:NSUTF8StringEncoding]:nil;
 if(!key.length){[self report:@"请先设置豆包语音 API Key（与聊天 Key 分开）。"];return;}
 self.speaker=speaker; self.text=[text substringWithRange:[text rangeOfComposedCharacterSequencesForRange:NSMakeRange(0,MIN(text.length,600))]]; self.volume=fminf(1,fmaxf(0,volume)); self.sid=NSUUID.UUID.UUIDString; self.audio=[NSMutableData new];
 NSMutableURLRequest *r=[NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"wss://openspeech.bytedance.com/api/v3/tts/bidirection"]]; r.timeoutInterval=30;
 [r setValue:key forHTTPHeaderField:@"X-Api-Key"]; [r setValue:@"seed-tts-2.0" forHTTPHeaderField:@"X-Api-Resource-Id"]; [r setValue:NSUUID.UUID.UUIDString forHTTPHeaderField:@"X-Api-Connect-Id"];
 NSURLSessionConfiguration *c=NSURLSessionConfiguration.ephemeralSessionConfiguration; c.HTTPCookieStorage=nil; c.URLCache=nil;
 self.session=[NSURLSession sessionWithConfiguration:c]; self.socket=[self.session webSocketTaskWithRequest:r]; [self.socket resume];
 [self report:@"豆包语音合成中（文字将发送至火山引擎）"];
 [self receive]; [self send:1 session:nil body:@{} then:nil];
 NSUInteger g=self.generation; __weak typeof(self) weak=self;
 dispatch_after(dispatch_time(DISPATCH_TIME_NOW,60*NSEC_PER_SEC),dispatch_get_main_queue(),^{ typeof(self) o=weak; if(o && o.generation==g && o.socket)[o fail:@"豆包语音合成超时，已停止。"]; });
}
- (void)receive {
 NSUInteger g=self.generation; __weak typeof(self) weak=self;
 [self.socket receiveMessageWithCompletionHandler:^(NSURLSessionWebSocketMessage *message,NSError *error) {
 dispatch_async(dispatch_get_main_queue(),^{ typeof(self) o=weak; if(!o||o.generation!=g)return;
 if(error){[o fail:@"豆包连接失败：请检查网络、API Key、模型及声线权限。"];return;}
 if(message.type!=NSURLSessionWebSocketMessageTypeData){[o fail:@"豆包返回异常文本响应，未播放。"];return;}
 [o consume:message.data]; if(o.socket && o.generation==g)[o receive]; }); }];
}
- (void)consume:(NSData *)data {
 if(data.length<4){[self fail:@"豆包协议帧不完整。"];return;}
 const uint8_t *b=data.bytes; NSUInteger offset=(b[0]&15)*4; unsigned type=b[1]>>4,flags=b[1]&15;
 if((b[0]>>4)!=1 || offset<4 || offset>data.length || (b[2]&15)!=0){[self fail:@"豆包返回不支持的协议或压缩格式。"];return;}
 uint32_t event=0,n=0;
 if(type==15){[self fail:@"豆包拒绝合成，请检查额度、模型及声线授权。"];return;}
 if((type!=9&&type!=11)||!(flags&4)||!MWVoiceRead(data,&offset,&event)){[self fail:@"豆包协议事件缺失。"];return;}
 // Connection responses carry connection id; all remaining responses carry session id.
 if(!MWVoiceRead(data,&offset,&n)||n>data.length-offset){[self fail:@"豆包协议标识长度错误。"];return;}
 NSData *identifier=[data subdataWithRange:NSMakeRange(offset,n)]; offset+=n;
 if(event>=100 && ![[[NSString alloc] initWithData:identifier encoding:NSUTF8StringEncoding] isEqual:self.sid]){[self fail:@"豆包返回会话不匹配。"];return;}
 if(!MWVoiceRead(data,&offset,&n)||n>data.length-offset||offset+n!=data.length){[self fail:@"豆包协议负载长度错误。"];return;}
 NSData *payload=[data subdataWithRange:NSMakeRange(offset,n)];
 if(event==51||event==153||event==151){[self fail:@"豆包合成失败：请检查声线使用权限和账户额度。"];return;}
 if(event==50){[self send:100 session:self.sid body:[self body:100 text:nil] then:nil];return;}
 if(event==150){ __weak typeof(self) weak=self; [self send:200 session:self.sid body:[self body:200 text:self.text] then:^{ typeof(self) o=weak; [o send:102 session:o.sid body:@{} then:nil]; }];return; }
 if(event==352){if(type!=11||self.audio.length+payload.length>12*1024*1024){[self fail:@"豆包音频无效或超过12MB限制。"];return;}[self.audio appendData:payload];return;}
 if(event==152){
 NSDictionary *meta=[NSJSONSerialization JSONObjectWithData:payload options:0 error:nil]; id code=[meta isKindOfClass:NSDictionary.class]?meta[@"status_code"]:nil;
 if(code && [code integerValue]!=20000000){[self fail:@"豆包会话返回失败状态，未播放。"];return;}
 if(!self.audio.length){[self fail:@"豆包没有返回音频，请检查声线权限。"];return;}
 NSData *audio=[self.audio copy]; float volume=self.volume; [self stop]; NSError *error=nil;
 self.player=[[AVAudioPlayer alloc] initWithData:audio error:&error];
 if(!self.player){[self report:@"豆包音频解码失败。"];return;}
 self.player.delegate=self;self.player.volume=volume;
 if(![self.player play]){[self fail:@"豆包音频无法播放。"];return;}[self report:@"豆包语音播放中"];
 }
}
- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag { if(player==self.player){ self.player=nil;[self report:flag?@"豆包语音播放结束":@"豆包语音播放失败"]; } }
@end
