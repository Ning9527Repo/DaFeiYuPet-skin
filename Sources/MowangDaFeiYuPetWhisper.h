#pragma once
#import <Foundation/Foundation.h>
#include <math.h>
typedef struct { double elapsed; } MowangDaFeiYuPetWhisperClock;
// Accumulate visible time only. Busy interactions defer a due event without a burst.
static inline BOOL mowang_dafeiyupet_whisperTick(MowangDaFeiYuPetWhisperClock *clock, double dt, double interval, BOOL enabled, BOOL busy) {
    if(!enabled) { clock->elapsed=0; return NO; }
    if(!isfinite(interval) || interval<30 || interval>1800) interval=300;
    if(isfinite(dt) && dt>0) clock->elapsed=fmin(interval,clock->elapsed+fmin(dt,1));
    if(clock->elapsed<interval || busy) return NO;
    clock->elapsed=0; return YES;
}
static inline NSArray<NSString *> *mowang_dafeiyupet_whisperLines(void) {
    return @[@"陪你发会儿呆，也挺好。",@"今天也要记得喝水哦。",@"小鲸鱼正在认真摸鱼～",@"累了就歇一小会儿吧。",@"我就在这里，慢慢来。",@"肚子说，它想吃点好吃的。",@"伸个懒腰，再继续吧。",@"今天也有一点点小期待。",@"你忙你的，我乖乖待着。",@"偷偷给你加一点元气。",@"窗外的风，会是什么味道？",@"摸鱼也是要讲究节奏的。"];
}
// Uniform over every entry except the previous one, when possible.
static inline NSUInteger mowang_dafeiyupet_whisperIndex(NSUInteger count, NSUInteger previous, uint32_t random) {
    if(count<2) return 0;
    if(previous>=count) return random%count;
    NSUInteger index=random%(count-1); return index>=previous?index+1:index;
}
