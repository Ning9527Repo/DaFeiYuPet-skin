#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
NS_ASSUME_NONNULL_BEGIN
@interface MWPetDoubaoVoice : NSObject <AVAudioPlayerDelegate>
@property(nonatomic,copy,nullable) void (^status)(NSString *message);
+ (NSArray<NSDictionary<NSString *,NSString *> *> *)voices;
+ (BOOL)saveKey:(NSString *)key;
- (void)speak:(NSString *)text speaker:(NSString *)speaker volume:(float)volume;
- (void)stop;
@end
NS_ASSUME_NONNULL_END
