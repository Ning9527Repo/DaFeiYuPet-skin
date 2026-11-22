#import <Foundation/Foundation.h>
#import <dispatch/dispatch.h>
#import <dlfcn.h>
#include <stdio.h>
#include <math.h>
int main(void) { @autoreleasepool {
    void *handle=dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote",RTLD_NOW|RTLD_LOCAL);
    void (*query)(dispatch_queue_t,void (^)(CFDictionaryRef))=handle?dlsym(handle,"MRMediaRemoteGetNowPlayingInfo"):NULL;
    if(!query) return 2;
    dispatch_semaphore_t done=dispatch_semaphore_create(0);
    query(dispatch_get_global_queue(QOS_CLASS_UTILITY,0),^(CFDictionaryRef raw){
        NSDictionary *info=raw && CFGetTypeID(raw)==CFDictionaryGetTypeID()?(__bridge NSDictionary *)raw:nil;
        NSDate *stamp=info[@"kMRMediaRemoteNowPlayingInfoTimestamp"];
        NSNumber *elapsed=info[@"kMRMediaRemoteNowPlayingInfoElapsedTime"], *rate=info[@"kMRMediaRemoteNowPlayingInfoPlaybackRate"];
        if([stamp isKindOfClass:NSDate.class] && [elapsed isKindOfClass:NSNumber.class] && [rate isKindOfClass:NSNumber.class])
            printf("timestamp age %.2f seconds, rate %.2f, elapsed present=%d\n",[NSDate.date timeIntervalSinceDate:stamp],rate.doubleValue,isfinite(elapsed.doubleValue));
        else puts("required playback fields absent");
        fflush(stdout); dispatch_semaphore_signal(done);
    });
    if(dispatch_semaphore_wait(done,dispatch_time(DISPATCH_TIME_NOW,5*NSEC_PER_SEC))) return 3;
    return 0;
} }
