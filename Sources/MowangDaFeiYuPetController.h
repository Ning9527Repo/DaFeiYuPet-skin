#import <UIKit/UIKit.h>
@interface MowangDaFeiYuPetController : NSObject
+ (instancetype)mowang_dafeiyupet_shared;
- (void)mowang_dafeiyupet_start;
// Event metadata only: never pass notification bodies or media titles.
- (void)mowang_dafeiyupet_receivedEvent:(NSString *)kind;
// Only the matched local lyric line; nil immediately withdraws the display.
- (void)mowang_dafeiyupet_lyricLine:(NSString *)line;
// Short visible diagnostic for lyric fetch states (searching/failed/not-found).
- (void)mowang_dafeiyupet_lyricStatus:(NSString *)status;
@end
