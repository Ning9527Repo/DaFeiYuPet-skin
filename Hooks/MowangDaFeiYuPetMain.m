#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <substrate.h>
#import <os/log.h>
#import <dlfcn.h>
#import <QuartzCore/QuartzCore.h>
#import "MowangDaFeiYuPetConfig.h"
#import "MowangDaFeiYuPetController.h"
#import "../Sources/MowangDaFeiYuPetLyricSource.h"
#import "../Sources/MowangDaFeiYuPetLyricNet.h"
#import "../Sources/MowangDaFeiYuPetPaths.h"

static void (*mowang_dafeiyupet_originalLaunch)(id,SEL,id);
static void (*mowang_dafeiyupet_originalNotification)(id,SEL,id);
static void (*mowang_dafeiyupet_getPlaying)(dispatch_queue_t,void (^)(BOOL));
static dispatch_source_t mowang_dafeiyupet_mediaTimer;
static BOOL mowang_dafeiyupet_mediaInFlight, mowang_dafeiyupet_mediaHasState, mowang_dafeiyupet_mediaPlaying;
static CFTimeInterval mowang_dafeiyupet_mediaRequestedAt;
static NSUInteger mowang_dafeiyupet_mediaGeneration;
static void (*mowang_dafeiyupet_getInfo)(dispatch_queue_t,void (^)(CFDictionaryRef));
static NSDictionary *mowang_dafeiyupet_localSong;
static MowangDaFeiYuPetLyricFetcher *mowang_dafeiyupet_lyricNet;
static BOOL mowang_dafeiyupet_infoInFlight;
static CFTimeInterval mowang_dafeiyupet_infoRequestedAt;
static NSUInteger mowang_dafeiyupet_infoGeneration;
// Import is read once at launch on a background queue. A changed local file takes a respring.
static void mowang_dafeiyupet_loadLocalSong(void) {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY,0),^{
        NSString *path=mowang_dafeiyupet_resourcePath(@"/Library/Application Support/MowangDaFeiYuPet/lyrics.plist");
        NSDictionary *song=mowang_dafeiyupet_localLyric(path);
        dispatch_async(dispatch_get_main_queue(),^{
            mowang_dafeiyupet_localSong=song;
            os_log(os_log_create("com.mowang.dafeiyupet","lyrics"),"Local timeline %{public}s",song?"ready":"unavailable");
        });
    });
}

// Accept only a one-object parameter. Unknown private APIs fail closed.
static BOOL mowang_dafeiyupet_objectMethod(Class cls, SEL sel, BOOL voidResult) {
    Method method=class_getInstanceMethod(cls,sel);
    if(!method || method_getNumberOfArguments(method)!=3) return NO;
    char *argument=method_copyArgumentType(method,2), *result=method_copyReturnType(method);
    BOOL valid=argument && argument[0]=='@' && result && result[0]==(voidResult?'v':'@');
    free(argument); free(result);
    return valid;
}
static id mowang_dafeiyupet_object(id obj, SEL sel) {
    if(!obj || ![obj respondsToSelector:sel]) return nil;
    Method method=class_getInstanceMethod(object_getClass(obj),sel);
    if(!method || method_getNumberOfArguments(method)!=2) return nil;
    char *result=method_copyReturnType(method);
    BOOL valid=result && result[0]=='@'; free(result);
    return valid?((id(*)(id,SEL))objc_msgSend)(obj,sel):nil;
}
static BOOL mowang_dafeiyupet_messagingSection(NSString *identifier) {
    if(![identifier isKindOfClass:NSString.class]) return NO;
    static NSSet *sections; static dispatch_once_t once;
    dispatch_once(&once,^{ sections=[NSSet setWithArray:@[@"com.apple.MobileSMS",@"com.tencent.xin",@"com.tencent.mqq",@"net.whatsapp.WhatsApp",@"ph.telegra.Telegraph",@"org.whispersystems.signal",@"com.hammerandchisel.discord",@"jp.naver.line",@"com.facebook.Messenger"]]; });
    return [sections containsObject:identifier];
}
static void mowang_dafeiyupet_notification(id self,SEL cmd,id request) {
    mowang_dafeiyupet_originalNotification(self,cmd,request);
    // Section metadata only. Never inspect or log the notification payload.
    id section=mowang_dafeiyupet_object(request,@selector(sectionIdentifier));
    if(mowang_dafeiyupet_messagingSection(section))
        [[MowangDaFeiYuPetController mowang_dafeiyupet_shared] mowang_dafeiyupet_receivedEvent:@"message"];
}
static void mowang_dafeiyupet_installNotificationHook(void) {
    Class cls=objc_getClass("SBNCNotificationDispatcher");
    const char *names[]={"postNotificationRequest:","dispatchNotificationRequest:","deliverNotificationRequest:"};
    for(NSUInteger i=0;i<sizeof(names)/sizeof(names[0]);i++) {
        SEL sel=sel_registerName(names[i]);
        if(cls && mowang_dafeiyupet_objectMethod(cls,sel,YES)) {
            MSHookMessageEx(cls,sel,(IMP)mowang_dafeiyupet_notification,(IMP *)&mowang_dafeiyupet_originalNotification);
            os_log(os_log_create("com.mowang.dafeiyupet","events"),"Message hook installed %{public}s",names[i]);
            return;
        }
    }
    os_log(os_log_create("com.mowang.dafeiyupet","events"),"Message hook unavailable; no notification interception");
}
// Only the query ABI was exercised in a separate signed process on this iOS 17 device.
// Do not call the private notification-registration function from SpringBoard.
static void mowang_dafeiyupet_pollMedia(void) {
    if(!mowang_dafeiyupet_getPlaying) return;
    MowangDaFeiYuPetController *controller=[MowangDaFeiYuPetController mowang_dafeiyupet_shared];
    if(![[MowangDaFeiYuPetConfig mowang_dafeiyupet_shared] mowang_dafeiyupet_isEnabled]) {
        mowang_dafeiyupet_mediaHasState=NO;
        [controller mowang_dafeiyupet_lyricLine:nil];
        return;
    }
    CFTimeInterval now=CACurrentMediaTime();
    if(mowang_dafeiyupet_getInfo) {
        if(mowang_dafeiyupet_infoInFlight && now-mowang_dafeiyupet_infoRequestedAt>=5) {
            mowang_dafeiyupet_infoInFlight=NO;
            [controller mowang_dafeiyupet_lyricLine:nil];
        }
        if(!mowang_dafeiyupet_infoInFlight) {
            mowang_dafeiyupet_infoInFlight=YES;
            mowang_dafeiyupet_infoRequestedAt=now;
            NSUInteger serial=++mowang_dafeiyupet_infoGeneration;
            mowang_dafeiyupet_getInfo(dispatch_get_main_queue(),^(CFDictionaryRef raw) {
                if(serial!=mowang_dafeiyupet_infoGeneration) return;
                mowang_dafeiyupet_infoInFlight=NO;
                NSDictionary *info=raw && CFGetTypeID(raw)==CFDictionaryGetTypeID()?(__bridge NSDictionary *)raw:nil;
                if(![[MowangDaFeiYuPetConfig mowang_dafeiyupet_shared] mowang_dafeiyupet_isEnabled]) {
                    [controller mowang_dafeiyupet_lyricLine:nil];
                    return;
                }
                NSDictionary *localSong=mowang_dafeiyupet_localSong;
                NSString *line=localSong
                    ? mowang_dafeiyupet_matchedLine(localSong,info,NSDate.date.timeIntervalSince1970,mowang_dafeiyupet_mediaHasState && mowang_dafeiyupet_mediaPlaying)
                    : [mowang_dafeiyupet_lyricNet lineForInfo:info playing:(mowang_dafeiyupet_mediaHasState && mowang_dafeiyupet_mediaPlaying) wallNow:NSDate.date.timeIntervalSince1970];
                [controller mowang_dafeiyupet_lyricLine:line];
            });
        }
    } else [controller mowang_dafeiyupet_lyricLine:nil];
    if(mowang_dafeiyupet_mediaInFlight) {
        if(now-mowang_dafeiyupet_mediaRequestedAt<10) return;
        // A lost callback must not accumulate requests or deliver a stale event.
        mowang_dafeiyupet_mediaInFlight=NO;
        mowang_dafeiyupet_mediaHasState=NO;
    }
    mowang_dafeiyupet_mediaInFlight=YES;
    mowang_dafeiyupet_mediaRequestedAt=now;
    NSUInteger generation=++mowang_dafeiyupet_mediaGeneration;
    mowang_dafeiyupet_getPlaying(dispatch_get_main_queue(),^(BOOL playing) {
        if(generation!=mowang_dafeiyupet_mediaGeneration) return;
        mowang_dafeiyupet_mediaInFlight=NO;
        if(![[MowangDaFeiYuPetConfig mowang_dafeiyupet_shared] mowang_dafeiyupet_isEnabled]) {
            mowang_dafeiyupet_mediaHasState=NO;
            return;
        }
        BOOL changed=mowang_dafeiyupet_mediaHasState && mowang_dafeiyupet_mediaPlaying!=playing;
        mowang_dafeiyupet_mediaHasState=YES;
        mowang_dafeiyupet_mediaPlaying=playing;
        if(!playing) [controller mowang_dafeiyupet_lyricLine:nil];
        if(changed) {
            os_log(os_log_create("com.mowang.dafeiyupet","events"),"Music state changed playing=%d",playing);
            [[MowangDaFeiYuPetController mowang_dafeiyupet_shared] mowang_dafeiyupet_receivedEvent:playing?@"musicStart":@"musicStop"];
        }
    });
}
static void mowang_dafeiyupet_installMedia(void) {
    void *handle=dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote",RTLD_NOW|RTLD_LOCAL);
    if(!handle) {
        os_log(os_log_create("com.mowang.dafeiyupet","events"),"Media query unavailable");
        return;
    }
    mowang_dafeiyupet_getPlaying=(void (*)(dispatch_queue_t,void (^)(BOOL)))dlsym(handle,"MRMediaRemoteGetNowPlayingApplicationIsPlaying");
    if(!mowang_dafeiyupet_getPlaying) {
        os_log(os_log_create("com.mowang.dafeiyupet","events"),"Media query symbol unavailable");
        return;
    }
    mowang_dafeiyupet_getInfo=(void (*)(dispatch_queue_t,void (^)(CFDictionaryRef)))dlsym(handle,"MRMediaRemoteGetNowPlayingInfo");
    if(mowang_dafeiyupet_getInfo) {
        mowang_dafeiyupet_loadLocalSong();
        mowang_dafeiyupet_lyricNet=[MowangDaFeiYuPetLyricFetcher new];
        __weak MowangDaFeiYuPetController *controller=[MowangDaFeiYuPetController mowang_dafeiyupet_shared];
        mowang_dafeiyupet_lyricNet.onReady=^{ [controller mowang_dafeiyupet_lyricLine:nil]; };
    }
    mowang_dafeiyupet_mediaTimer=dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER,0,0,dispatch_get_main_queue());
    dispatch_source_set_timer(mowang_dafeiyupet_mediaTimer,DISPATCH_TIME_NOW,3*NSEC_PER_SEC,NSEC_PER_SEC/4);
    dispatch_source_set_event_handler(mowang_dafeiyupet_mediaTimer,^{ mowang_dafeiyupet_pollMedia(); });
    dispatch_resume(mowang_dafeiyupet_mediaTimer);
    os_log(os_log_create("com.mowang.dafeiyupet","events"),"Media query polling enabled");
}
static void mowang_dafeiyupet_launch(id self,SEL cmd,id app) {
    mowang_dafeiyupet_originalLaunch(self,cmd,app);
    [[MowangDaFeiYuPetConfig mowang_dafeiyupet_shared] mowang_dafeiyupet_reload];
    [[MowangDaFeiYuPetController mowang_dafeiyupet_shared] mowang_dafeiyupet_start];
    mowang_dafeiyupet_installNotificationHook();
    mowang_dafeiyupet_installMedia();
}
__attribute__((constructor)) static void mowang_dafeiyupet_initialize(void) {
    @autoreleasepool {
        os_log(os_log_create("com.mowang.dafeiyupet","load"),"ApelinLoaded %{public}s",APELIN_BUILD_ID);
        Class cls=objc_getClass("SpringBoard");
        if(cls) MSHookMessageEx(cls,@selector(applicationDidFinishLaunching:),(IMP)mowang_dafeiyupet_launch,(IMP *)&mowang_dafeiyupet_originalLaunch);
    }
}
