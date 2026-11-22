#import "MWPetLiveActions.h"
@interface MWPetMotionTrack : NSObject
@property(nonatomic,strong) NSData *keys;
@end
@implementation MWPetMotionTrack
@end
@interface MWPetLiveActions ()
@property(nonatomic,readwrite,copy) NSString *failure;
@property(nonatomic,readwrite,strong) NSDictionary *clips;
@property(nonatomic,strong) NSDictionary<NSString *,MWPetMotionTrack *> *tracks;
@end
@implementation MWPetLiveActions
- (instancetype)initWithRoot:(NSString *)root {
 if(!(self=[super init]))return nil;
 NSData *data=[NSData dataWithContentsOfFile:[root stringByAppendingPathComponent:@"actions.json"]];
 NSDictionary *json=data?[NSJSONSerialization JSONObjectWithData:data options:0 error:nil]:nil;
 NSArray *names=@[@"x",@"y",@"angle",@"sx",@"sy",@"waist",@"head",@"armNear",@"armFar",@"legBack",@"legFront",@"tail",@"fin",@"ahoge",@"sit",@"yaw",@"lookX",@"lookY",@"mouth"];
 if(![json isKindOfClass:NSDictionary.class]||![json[@"channels"] isEqual:names]||![json[@"clips"] isKindOfClass:NSArray.class]||[json[@"clips"] count]!=106){self.failure=@"Invalid 106 action manifest";return self;}
 NSMutableDictionary *clips=[NSMutableDictionary new],*tracks=[NSMutableDictionary new];
 for(NSDictionary *clip in json[@"clips"]){
  NSString *key=clip[@"id"];NSArray *keys=clip[@"keys"];
  if(![key isKindOfClass:NSString.class]||!key.length||clips[key]||![keys isKindOfClass:NSArray.class]||keys.count<2||keys.count>64||![clip[@"duration"] isKindOfClass:NSNumber.class]||[clip[@"duration"] doubleValue]<=0||[clip[@"duration"] doubleValue]>60){self.failure=@"Invalid action identity or duration";return self;}
  NSMutableData *frames=[NSMutableData new];double previous=-1;
  for(NSDictionary *k in keys){
   MWKeyframe frame={0};frame.t=[k[@"t"] doubleValue];
   if(!isfinite(frame.t)||frame.t<0||frame.t>1||frame.t<=previous){self.failure=@"Invalid keyframe time";return self;}previous=frame.t;
   for(NSUInteger c=0;c<names.count;c++){id n=k[@"pose"][names[c]];if(![n isKindOfClass:NSNumber.class]||!isfinite([n doubleValue])||fabs([n doubleValue])>300){self.failure=@"Invalid motion channel";return self;}frame.v[c]=[n doubleValue];}
   [frames appendBytes:&frame length:sizeof(frame)];
  }
  if([keys.firstObject[@"t"] doubleValue]!=0||previous!=1){self.failure=@"Missing neutral endpoints";return self;}
  MWPetMotionTrack *track=[MWPetMotionTrack new];track.keys=frames;tracks[key]=track;clips[key]=clip;
 }
 self.clips=clips;self.tracks=tracks;return self;
}
- (NSDictionary *)clip:(NSString *)action {return self.clips[action];}
- (BOOL)sampleAction:(NSString *)action elapsed:(double)elapsed values:(double *)values {
 MWNeutral(values);MWPetMotionTrack *track=self.tracks[action];NSDictionary *clip=self.clips[action];
 if(!track||!isfinite(elapsed))return NO;
 MWSample(track.keys.bytes,track.keys.length/sizeof(MWKeyframe),elapsed/[clip[@"duration"] doubleValue],values);return YES;
}
@end
