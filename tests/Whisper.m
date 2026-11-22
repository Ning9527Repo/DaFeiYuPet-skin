#import "../Sources/MowangDaFeiYuPetWhisper.h"
#include <assert.h>
#include <stdio.h>
int main(void) { @autoreleasepool {
    MowangDaFeiYuPetWhisperClock c={0};
    for(int i=0;i<299;i++) assert(!mowang_dafeiyupet_whisperTick(&c,1,300,YES,NO));
    assert(mowang_dafeiyupet_whisperTick(&c,1,300,YES,NO));
    c.elapsed=299; assert(!mowang_dafeiyupet_whisperTick(&c,1,300,YES,YES));
    for(int i=0;i<100;i++) assert(!mowang_dafeiyupet_whisperTick(&c,1,300,YES,YES));
    assert(mowang_dafeiyupet_whisperTick(&c,0,300,YES,NO));
    assert(!mowang_dafeiyupet_whisperTick(&c,0,300,YES,NO));
    c.elapsed=299; assert(!mowang_dafeiyupet_whisperTick(&c,1,300,NO,NO)); assert(c.elapsed==0);
    assert(!mowang_dafeiyupet_whisperTick(&c,NAN,NAN,YES,NO)); assert(c.elapsed==0);
    assert(!mowang_dafeiyupet_whisperTick(&c,-1,300,YES,NO));
    assert(!mowang_dafeiyupet_whisperTick(&c,10000,300,YES,NO)); assert(c.elapsed==1);
    NSArray *lines=mowang_dafeiyupet_whisperLines(); assert(lines.count==12);
    for(NSString *line in lines) assert(line.length>0 && line.length<=20);
    for(NSUInteger previous=0;previous<lines.count;previous++)
        for(uint32_t r=0;r<10000;r++) { NSUInteger n=mowang_dafeiyupet_whisperIndex(lines.count,previous,r); assert(n<lines.count && n!=previous); }
    assert(mowang_dafeiyupet_whisperIndex(1,0,99)==0);
    puts("PASS whisper: timing, busy deferral, opt-out reset, invalid time, no-repeat selection (120000 samples), bounded local lines");
} }
