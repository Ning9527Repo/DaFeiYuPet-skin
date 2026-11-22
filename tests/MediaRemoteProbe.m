#import <Foundation/Foundation.h>
#import <dlfcn.h>
#import <dispatch/dispatch.h>
#include <stdio.h>

typedef void (*MRGetPlaying)(dispatch_queue_t, void (^)(BOOL));

int main(void) {
    @autoreleasepool {
        void *handle=dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote", RTLD_NOW | RTLD_LOCAL);
        if(!handle) { fprintf(stderr,"framework unavailable\n"); return 2; }
        MRGetPlaying getPlaying=(MRGetPlaying)dlsym(handle,"MRMediaRemoteGetNowPlayingApplicationIsPlaying");
        if(!getPlaying) { fprintf(stderr,"symbol unavailable\n"); return 3; }
        // Query-only mode never registers private notifications in SpringBoard.
        dispatch_queue_t queue=dispatch_queue_create("com.mowang.dafeiyupet.media-probe",DISPATCH_QUEUE_SERIAL);
        dispatch_semaphore_t done=dispatch_semaphore_create(0);
        getPlaying(queue,^(BOOL playing){
            fprintf(stdout,"playback callback received: %d\n",playing?1:0); fflush(stdout);
            dispatch_semaphore_signal(done);
        });
        if(dispatch_semaphore_wait(done,dispatch_time(DISPATCH_TIME_NOW,4*NSEC_PER_SEC))) {
            fprintf(stderr,"playback callback timed out\n"); return 4;
        }
        return 0;
    }
}
