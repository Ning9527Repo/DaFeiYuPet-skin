#import "../Sources/MowangDaFeiYuPetPlayback.h"
#include <assert.h>
#include <stdio.h>
int main(void) { @autoreleasepool {
    assert(mowang_dafeiyupet_frameDelay(@(NAN))==.1);
    assert(mowang_dafeiyupet_frameDelay(@(-1))==.1);
    assert(mowang_dafeiyupet_frameDelay(@"bad")==.1);
    assert(mowang_dafeiyupet_frameDelay(@(.001))==.01);
    assert(mowang_dafeiyupet_frameDelay(@100)==10);
    NSArray *times=@[@.1,@.2,@.3];
    assert(mowang_dafeiyupet_frameProgress(times,0,100)==0);
    double stalled=mowang_dafeiyupet_frameProgress(times,1,100);
    assert(fabs(stalled-1./6)<1e-9);
    assert(stalled==mowang_dafeiyupet_frameProgress(times,1,1000));
    assert(fabs(mowang_dafeiyupet_frameProgress(times,2,.1)-1./3)<1e-9);
    assert(mowang_dafeiyupet_frameProgress(times,3,100)==1);
    assert(mowang_dafeiyupet_frameProgress(@[],3,100)==0);
    assert(mowang_dafeiyupet_frameProgress(times,1,NAN)==0);
    NSString *root=NSProcessInfo.processInfo.environment[@"APELIN_PROJECT_ROOT"];
    assert(root.length);
    NSArray *catalog=[NSArray arrayWithContentsOfFile:[root stringByAppendingPathComponent:@"layout/Library/Application Support/MowangDaFeiYuPet/catalog.plist"]];
    assert(catalog.count==106);
    NSUInteger frames=0;
    for(NSDictionary *entry in catalog) {
        NSArray *delays=entry[@"durations"]; double previous=0;
        for(NSUInteger i=0;i<delays.count;i++) {
            double delay=mowang_dafeiyupet_frameDelay(delays[i]);
            assert(delay==[delays[i] doubleValue]);
            double p=mowang_dafeiyupet_frameProgress(delays,i+1,delay);
            assert(p>=previous && p<=1); previous=p; frames++;
        }
        assert(fabs(previous-1)<1e-9);
    }
    printf("PASS playback: invalid delays, first frame, decode stalls, monotonic progress, 106 actions / %lu frames\n",(unsigned long)frames);
} }
