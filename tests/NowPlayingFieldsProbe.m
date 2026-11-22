#import <Foundation/Foundation.h>
#import <dispatch/dispatch.h>
#import <dlfcn.h>
#import <objc/runtime.h>
#include <stdio.h>

typedef void (*MRGetNowPlayingInfo)(dispatch_queue_t, void (^)(CFDictionaryRef));

int main(void) {
    @autoreleasepool {
        void *handle=dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote",RTLD_NOW|RTLD_LOCAL);
        if(!handle) { fputs("framework unavailable\n",stderr); return 2; }
        MRGetNowPlayingInfo query=(MRGetNowPlayingInfo)dlsym(handle,"MRMediaRemoteGetNowPlayingInfo");
        if(!query) { fputs("query symbol unavailable\n",stderr); return 3; }
        dispatch_semaphore_t done=dispatch_semaphore_create(0);
        dispatch_queue_t queue=dispatch_queue_create("com.mowang.dafeiyupet.now-playing-probe",DISPATCH_QUEUE_SERIAL);
        query(queue,^(CFDictionaryRef info) {
            if(!info || CFGetTypeID(info)!=CFDictionaryGetTypeID()) {
                puts("no now-playing dictionary");
            } else {
                NSDictionary *fields=(__bridge NSDictionary *)info;
                printf("field count: %lu\n",(unsigned long)fields.count);
                for(id key in [[fields allKeys] sortedArrayUsingComparator:^NSComparisonResult(id a,id b) {
                    return [[a description] compare:[b description]];
                }]) {
                    id value=fields[key];
                    // Only field names and data types; never print song metadata, lyrics, or artwork.
                    printf("%s : %s\n",[[key description] UTF8String],class_getName([value class]));
                }
            }
            fflush(stdout);
            dispatch_semaphore_signal(done);
        });
        if(dispatch_semaphore_wait(done,dispatch_time(DISPATCH_TIME_NOW,5*NSEC_PER_SEC))) {
            fputs("now-playing callback timed out\n",stderr); return 4;
        }
        return 0;
    }
}
