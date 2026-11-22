#import "MowangDaFeiYuPetController.h"
#import "MowangDaFeiYuPetConfig.h"
#import "MowangDaFeiYuPetTextureView.h"
#import "MowangDaFeiYuPetPreferences.h"
#import "MowangDaFeiYuPetPhysics.h"
#import "MowangDaFeiYuPetPomodoro.h"
#import "MowangDaFeiYuPetScore.h"
#import "MowangDaFeiYuPetScheduler.h"
#import "MowangDaFeiYuPetRoaming.h"
#import "MowangDaFeiYuPetPlayback.h"
#import "MowangDaFeiYuPetWhisper.h"
#import "MowangDaFeiYuPetEnvironment.h"

#import "MowangDaFeiYuPetBubble.h"
#import "../MowangDaFeiYuPetPrefs/MowangDaFeiYuPetChatController.h"
#import <objc/message.h>
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>
#import <notify.h>
#import <ImageIO/ImageIO.h>
#import <os/log.h>

// Checked object-returning zero-argument selectors only; unknown state fails closed.
static id mowang_dafeiyupet_object(id obj, NSString *name) {
    SEL s=NSSelectorFromString(name); if(!obj || ![obj respondsToSelector:s]) return nil;
    Method m=class_getInstanceMethod(object_getClass(obj),s);
    if(!m || method_getNumberOfArguments(m)!=2) return nil;
    char *t=method_copyReturnType(m); BOOL ok=t && t[0]=='@'; free(t);
    return ok ? ((id(*)(id,SEL))objc_msgSend)(obj,s) : nil;
}
static BOOL mowang_dafeiyupet_locked(void) {
    id m=mowang_dafeiyupet_object(NSClassFromString(@"SBLockScreenManager"),@"sharedInstance");
    SEL s=NSSelectorFromString(@"isUILocked");
    if(!m || ![m respondsToSelector:s]) return YES;
    Method method=class_getInstanceMethod([m class],s);
    char *type=method_copyReturnType(method);
    BOOL valid=method_getNumberOfArguments(method)==2 && type && (type[0]=='B'||type[0]=='c'); free(type);
    return !valid || ((BOOL(*)(id,SEL))objc_msgSend)(m,s);
}
static BOOL mowang_dafeiyupet_homeVisible(void) {
    id app=UIApplication.sharedApplication; SEL selector=NSSelectorFromString(@"_accessibilityFrontMostApplication");
    Method method=class_getInstanceMethod(object_getClass(app),selector);
    if(!method || method_getNumberOfArguments(method)!=2) return NO;
    char *type=method_copyReturnType(method); BOOL valid=type && type[0]=='@'; free(type);
    if(!valid || ![app respondsToSelector:selector]) return NO;
    id front=mowang_dafeiyupet_object(app,@"_accessibilityFrontMostApplication");
    return !front || [mowang_dafeiyupet_object(front,@"bundleIdentifier") isEqual:@"com.apple.springboard"];
}
static BOOL mowang_dafeiyupet_homeOnly(void) {
    id scope=[[MowangDaFeiYuPetConfig mowang_dafeiyupet_shared] mowang_dafeiyupet_valueForKey:@"scope" defaultValue:@1];
    return ![scope isKindOfClass:NSNumber.class] || [scope integerValue]!=0;
}
static NSString *mowang_dafeiyupet_balanceSourceID(void) {
    NSUserDefaults *settings=NSUserDefaults.standardUserDefaults;
    NSString *pinned=[settings stringForKey:@"MWAIHubThirdPartyPinnedID"];
    return pinned.length?[@"thirdparty-" stringByAppendingString:pinned]:([settings integerForKey:@"MWAIHubProvider"]==1?@"wanwanzhou":@"zn");
}
@interface MowangDaFeiYuPetWindow : UIWindow
@property(nonatomic,weak) UIView *mowang_dafeiyupet_pet, *mowang_dafeiyupet_menu;
@property(nonatomic) BOOL mowang_dafeiyupet_chatOpen;
@property(nonatomic,weak) UIView *mowang_dafeiyupet_chatView;
@end
@implementation MowangDaFeiYuPetWindow
- (BOOL)canBecomeKeyWindow { return self.mowang_dafeiyupet_chatOpen; }
- (BOOL)_canBecomeKeyWindow { return self.mowang_dafeiyupet_chatOpen; }
- (BOOL)canBecomeFirstResponder { return self.mowang_dafeiyupet_chatOpen; }
// SpringBoard can suppress automatic keyboard UI independently of responder
// acceptance. Limit the opt-in to this window, never the system's other windows.
- (BOOL)_disableAutomaticKeyboardUI { return !self.mowang_dafeiyupet_chatOpen; }
- (BOOL)_disableAutomaticKeyboardBehavior { return !self.mowang_dafeiyupet_chatOpen; }
- (UIView *)hitTest:(CGPoint)p withEvent:(UIEvent *)event {
    if(self.mowang_dafeiyupet_chatOpen) {
        if(mowang_dafeiyupet_locked()) return nil;
        if(self.rootViewController.presentedViewController || self.rootViewController.childViewControllers.lastObject.presentedViewController) return [super hitTest:p withEvent:event];
        UIView *chat=self.mowang_dafeiyupet_chatView;
        if(chat) {
            CGPoint c=[chat convertPoint:p fromView:self];
            if(CGRectContainsPoint(chat.bounds,c)) return [chat hitTest:c withEvent:event];
        }
        return nil;
    }
    UIView *pet=self.mowang_dafeiyupet_pet;
    if(self.hidden || !pet || pet.hidden || mowang_dafeiyupet_locked() ||
       (mowang_dafeiyupet_homeOnly() && !mowang_dafeiyupet_homeVisible())) return nil;
    UIView *menu=self.mowang_dafeiyupet_menu;
    if(menu && !menu.hidden) {
        CGPoint m=[menu convertPoint:p fromView:self];
        if(CGRectContainsPoint(menu.bounds,m)) return [menu hitTest:m withEvent:event];
    }
    // Only the character body catches touches; transparent margins pass through.
    CGPoint q=[pet convertPoint:p fromView:self];
    CGRect body=CGRectInset(pet.bounds,pet.bounds.size.width*.30,pet.bounds.size.height*.05);
    return CGRectContainsPoint(body,q) ? [pet hitTest:q withEvent:event] : nil;
}
@end
@interface MowangDaFeiYuPetTouchView : UIImageView
@property(nonatomic,copy) void (^mowang_dafeiyupet_touchDown)(void);
@end
@implementation MowangDaFeiYuPetTouchView
- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if(self.mowang_dafeiyupet_touchDown) self.mowang_dafeiyupet_touchDown();
    [super touchesBegan:touches withEvent:event];
}
@end
@interface MowangDaFeiYuPetController () {
    MowangPetBattery _environmentBattery;
    MowangDaFeiYuPetBody _mowang_dafeiyupet_body;
    MowangDaFeiYuPetTrail _mowang_dafeiyupet_trail;
    MowangDaFeiYuPetRoaming _mowang_dafeiyupet_roaming;
    MowangDaFeiYuPetWhisperClock _mowang_dafeiyupet_whisperClock;
    CGPoint _mowang_dafeiyupet_dragTarget;
    CFTimeInterval _mowang_dafeiyupet_squashStart;
    double _mowang_dafeiyupet_squashDepth;
    int _mowang_dafeiyupet_lockToken;
    // Accessed only on the serial decode queue; one compressed source, no frame cache.
    CGImageSourceRef _mowang_dafeiyupet_source;
    NSString *_mowang_dafeiyupet_sourcePath;
}
@property(nonatomic,strong) MowangDaFeiYuPetWindow *mowang_dafeiyupet_window;
@property(nonatomic) CGFloat mowang_dafeiyupet_chatKeyboardTop;
@property(nonatomic,strong) MowangDaFeiYuPetChatController *mowang_dafeiyupet_chat;
@property(nonatomic,weak) UIWindow *mowang_dafeiyupet_previousKeyWindow;
@property(nonatomic,strong) UIImageView *mowang_dafeiyupet_pet;
@property(nonatomic,strong) MowangDaFeiYuPetTextureView *textureView;
@property(nonatomic,copy) NSString *textureSelection;
@property(nonatomic) CFTimeInterval textureActionStart;
@property(nonatomic,strong) UIImage *mowang_dafeiyupet_idleImage;
@property(nonatomic,strong) NSMutableSet<NSString *> *mowang_dafeiyupet_failedActions;
@property(nonatomic) CFTimeInterval mowang_dafeiyupet_retryAfter;
@property(nonatomic,strong) UILabel *mowang_dafeiyupet_bubble, *mowang_dafeiyupet_badge;
@property(nonatomic,strong) UIScrollView *mowang_dafeiyupet_menu;
@property(nonatomic,strong) UIPanGestureRecognizer *mowang_dafeiyupet_panGesture;
@property(nonatomic) BOOL mowang_dafeiyupet_positionLocked;
@property(nonatomic) BOOL mowang_dafeiyupet_hasPosition;
@property(nonatomic) BOOL mowang_dafeiyupet_roamPaused;
@property(nonatomic) unsigned mowang_dafeiyupet_pendingScore;
@property(nonatomic) NSUInteger mowang_dafeiyupet_sessionScore;
@property(nonatomic,strong) UIView *mowang_dafeiyupet_scoreEffect;
@property(nonatomic) CFTimeInterval mowang_dafeiyupet_menuUntil;
@property(nonatomic,strong) CADisplayLink *mowang_dafeiyupet_link;
@property(nonatomic,strong) dispatch_source_t mowang_dafeiyupet_watch;
@property(nonatomic,strong) dispatch_queue_t mowang_dafeiyupet_decodeQueue;
@property(nonatomic,copy) NSDictionary *mowang_dafeiyupet_manifest;
@property(nonatomic,copy) NSArray<NSDictionary *> *mowang_dafeiyupet_catalog;
@property(nonatomic) NSUInteger mowang_dafeiyupet_menuPage;
@property(nonatomic,copy) NSArray<NSDictionary *> *mowang_dafeiyupet_menuEntries;
@property(nonatomic,copy) NSString *mowang_dafeiyupet_action;
@property(nonatomic) NSUInteger mowang_dafeiyupet_frame, mowang_dafeiyupet_generation;
@property(nonatomic) BOOL mowang_dafeiyupet_loading, mowang_dafeiyupet_dragging, mowang_dafeiyupet_flying, mowang_dafeiyupet_keyboardVisible;
@property(nonatomic) CFTimeInterval mowang_dafeiyupet_last, mowang_dafeiyupet_frameTime, mowang_dafeiyupet_idleTime, mowang_dafeiyupet_bubbleUntil;
@property(nonatomic) double mowang_dafeiyupet_reset, mowang_dafeiyupet_whisperPreview;
@property(nonatomic) NSUInteger mowang_dafeiyupet_lastWhisper;
@property(nonatomic) BOOL mowang_dafeiyupet_whisperBubble;
@property(nonatomic,copy) NSString *mowang_dafeiyupet_pendingBalance;
@property(nonatomic,copy) NSString *mowang_dafeiyupet_pendingBalanceSource;
@property(nonatomic) CFTimeInterval mowang_dafeiyupet_pendingBalanceUntil;
@property(nonatomic,copy) NSString *mowang_dafeiyupet_pendingEvent;
@property(nonatomic) CFTimeInterval mowang_dafeiyupet_pendingEventUntil, mowang_dafeiyupet_lastMessageEvent;
@property(nonatomic,strong) NSMutableArray<NSDictionary *> *environmentQueue;
@property(nonatomic,strong) MowangPetWeatherRequest *environmentRequest;
@property(nonatomic,copy) NSDictionary *environmentCity;
@property(nonatomic,copy) NSString *environmentWeather;
@property(nonatomic) NSTimeInterval environmentFetched, environmentNext;
@property(nonatomic) double environmentWeatherPreview, environmentBatteryPreview;
@property(nonatomic) BOOL environmentWeatherEnabled, environmentMonitoring;
@property(nonatomic) BOOL mowang_dafeiyupet_lyricBubble;
@end
@implementation MowangDaFeiYuPetController
+ (instancetype)mowang_dafeiyupet_shared { static id instance; static dispatch_once_t once; dispatch_once(&once,^{instance=[self new];}); return instance; }
- (void)mowang_dafeiyupet_start {
    self.environmentQueue=[NSMutableArray new];
    self.environmentWeatherPreview=[self mowang_dafeiyupet_number:@"weatherPreviewToken" fallback:0 low:0 high:1e12];
    self.environmentBatteryPreview=[self mowang_dafeiyupet_number:@"batteryPreviewToken" fallback:0 low:0 high:1e12];
    for(NSString *note in @[UIDeviceBatteryLevelDidChangeNotification,UIDeviceBatteryStateDidChangeNotification]) [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(environmentBatterySample) name:note object:nil];
    self.mowang_dafeiyupet_lastWhisper=NSNotFound;
    self.mowang_dafeiyupet_whisperPreview=[self mowang_dafeiyupet_number:@"whisperPreviewToken" fallback:0 low:0 high:1e12];
    self.mowang_dafeiyupet_failedActions=[NSMutableSet set];
    self.mowang_dafeiyupet_decodeQueue=dispatch_queue_create("com.mowang.dafeiyupet.frames",DISPATCH_QUEUE_SERIAL);
    self.mowang_dafeiyupet_catalog=[NSArray arrayWithContentsOfFile:mowang_dafeiyupet_resourcePath(@"/Library/Application Support/MowangDaFeiYuPet/catalog.plist")] ?: @[];
    NSMutableDictionary *manifest=[NSMutableDictionary dictionary];
    for(NSDictionary *entry in self.mowang_dafeiyupet_catalog) manifest[entry[@"id"]]=entry[@"durations"];
    self.mowang_dafeiyupet_manifest=manifest;
    // MWAIHub's installed producer still uses the legacy name; both tweaks
    // share SpringBoard and exchange only formatted display strings.
    for(NSString *name in @[@"com.mowang.dafeiyupet.balance-update", @"com.axs.dafeiyupet.balance-update"]) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(mowang_dafeiyupet_balanceUpdate:) name:name object:nil];
    }
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(mowang_dafeiyupet_refresh) name:MowangDaFeiYuPetPreferencesChanged object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(mowang_dafeiyupet_refresh) name:UIApplicationDidBecomeActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(mowang_dafeiyupet_keyboardShow:) name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(mowang_dafeiyupet_keyboardHide:) name:UIKeyboardDidHideNotification object:nil];
    __weak typeof(self) weakSelf=self;
    notify_register_dispatch("com.apple.springboard.lockstate",&_mowang_dafeiyupet_lockToken,dispatch_get_main_queue(),^(int token){
        [weakSelf mowang_dafeiyupet_destroy];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC/5),dispatch_get_main_queue(),^{ [weakSelf mowang_dafeiyupet_refresh]; });
    });
    [self mowang_dafeiyupet_refresh];
}
- (double)mowang_dafeiyupet_number:(NSString *)key fallback:(double)fallback low:(double)low high:(double)high {
    id v=[[MowangDaFeiYuPetConfig mowang_dafeiyupet_shared] mowang_dafeiyupet_valueForKey:key defaultValue:@(fallback)];
    return mowang_dafeiyupet_clamp([v isKindOfClass:NSNumber.class]?[v doubleValue]:fallback,low,high);
}
- (MowangDaFeiYuPetPhysics)mowang_dafeiyupet_physics {
    return mowang_dafeiyupet_physics(
        [self mowang_dafeiyupet_number:@"gravity" fallback:1400 low:0 high:3000],
        [self mowang_dafeiyupet_number:@"restitution" fallback:.78 low:0 high:1],
        [self mowang_dafeiyupet_number:@"groundFriction" fallback:2.5 low:0 high:10],
        [self mowang_dafeiyupet_number:@"throwPower" fallback:1 low:.25 high:2]);
}
- (void)environmentEnqueue:(NSString *)text kind:(NSString *)kind {
    if(!text.length) return;
    NSIndexSet *same=[self.environmentQueue indexesOfObjectsPassingTest:^BOOL(NSDictionary *row, NSUInteger i, BOOL *stop) { return [row[@"kind"] isEqual:kind]; }];
    [self.environmentQueue removeObjectsAtIndexes:same];
    if(self.environmentQueue.count>=3) [self.environmentQueue removeObjectAtIndex:0];
    [self.environmentQueue addObject:@{@"text":text,@"kind":kind,@"until":@(CACurrentMediaTime()+120)}];
}
- (void)environmentBatterySample {
    if(!NSThread.isMainThread) { dispatch_async(dispatch_get_main_queue(),^{ [self environmentBatterySample]; }); return; }
    if(!self.environmentMonitoring) return;
    NSString *line=mowang_pet_battery(&_environmentBattery,UIDevice.currentDevice.batteryLevel,UIDevice.currentDevice.batteryState);
    if(line) [self environmentEnqueue:line kind:@"电量提醒"];
}
- (void)environmentRefresh {
    BOOL enabled=[[MowangDaFeiYuPetConfig mowang_dafeiyupet_shared] mowang_dafeiyupet_isEnabled];
    BOOL battery=enabled && [self mowang_dafeiyupet_number:@"batteryAlertsEnabled" fallback:1 low:0 high:1]>0;
    if(battery!=self.environmentMonitoring) {
        self.environmentMonitoring=battery; _environmentBattery=(MowangPetBattery){0};
        // Monitoring is process-local; never disable monitoring another SpringBoard client needs.
        if(battery) { UIDevice.currentDevice.batteryMonitoringEnabled=YES; [self environmentBatterySample]; }
    }
    NSDictionary *prefs=mowang_dafeiyupet_readPreferences();
    id city=prefs[@"weatherCity"];
    BOOL weather=enabled && [prefs[@"weatherEnabled"] boolValue] && mowang_pet_city(city);
    if(weather!=self.environmentWeatherEnabled || !(self.environmentCity==city || [self.environmentCity isEqual:city])) {
        [self.environmentRequest cancel]; self.environmentRequest=nil;
        self.environmentCity=mowang_pet_city(city)?city:nil;
        self.environmentWeatherEnabled=weather; self.environmentWeather=nil; self.environmentNext=0; self.environmentFetched=0;
        [self.environmentQueue removeAllObjects];
    }
    if(!enabled) { [self.environmentQueue removeAllObjects]; return; }
    NSIndexSet *disabled=[self.environmentQueue indexesOfObjectsPassingTest:^BOOL(NSDictionary *row, NSUInteger i, BOOL *stop) { return (!battery && [row[@"kind"] isEqual:@"电量提醒"]) || (!weather && [row[@"kind"] isEqual:@"天气碎碎念"]); }];
    [self.environmentQueue removeObjectsAtIndexes:disabled];
    double preview=[self mowang_dafeiyupet_number:@"batteryPreviewToken" fallback:0 low:0 high:1e12];
    if(preview!=self.environmentBatteryPreview) { self.environmentBatteryPreview=preview; [self environmentEnqueue:@"电量提醒预览：电量不多时，我会提醒你充电哦～" kind:@"电量预览"]; }
    preview=[self mowang_dafeiyupet_number:@"weatherPreviewToken" fallback:0 low:0 high:1e12];
    if(preview!=self.environmentWeatherPreview) {
        self.environmentWeatherPreview=preview;
        if(weather && mowang_pet_weatherFresh(self.environmentFetched,NSDate.date.timeIntervalSince1970) && self.environmentWeather) [self environmentEnqueue:self.environmentWeather kind:@"天气碎碎念"];
        else if(!weather) [self environmentEnqueue:@"请先选择城市并开启天气碎碎念。" kind:@"天气预览"];
        else if(!self.environmentRequest && NSDate.date.timeIntervalSince1970<self.environmentNext) [self environmentEnqueue:@"天气暂不可用，请稍后再试。" kind:@"天气预览"];
    }
}
- (void)environmentTick {
    NSTimeInterval now=NSDate.date.timeIntervalSince1970;
    if(self.environmentWeatherEnabled && !self.environmentRequest && now>=self.environmentNext && !mowang_dafeiyupet_locked() && self.mowang_dafeiyupet_window) {
        self.environmentNext=now+1800;
        NSDictionary *city=self.environmentCity;
        self.environmentRequest=[MowangPetWeatherRequest new];
        __weak typeof(self) weakSelf=self;
        [self.environmentRequest start:mowang_pet_forecastURL(city) completion:^(id json, NSString *failure) {
            typeof(self) owner=weakSelf; if(!owner || !owner.environmentWeatherEnabled || ![owner.environmentCity isEqual:city]) return;
            owner.environmentRequest=nil;
            NSString *line=failure?nil:mowang_pet_weather(json,city,NSDate.date.timeIntervalSince1970);
            owner.environmentWeather=line; owner.environmentFetched=line?NSDate.date.timeIntervalSince1970:0;
            [owner environmentEnqueue:line ?: (failure ?: @"天气数据缺失或已过期，暂时无法播报。") kind:@"天气碎碎念"];
            os_log(os_log_create("com.mowang.dafeiyupet","environment"),"Weather request completed valid=%d",line!=nil);
        }];
    }
    CFTimeInterval tick=CACurrentMediaTime();
    NSIndexSet *expired=[self.environmentQueue indexesOfObjectsPassingTest:^BOOL(NSDictionary *row, NSUInteger i, BOOL *stop) { return tick>[row[@"until"] doubleValue]; }];
    [self.environmentQueue removeObjectsAtIndexes:expired];
    if(!self.environmentQueue.count || mowang_dafeiyupet_locked() || !self.mowang_dafeiyupet_window || self.mowang_dafeiyupet_chat || self.mowang_dafeiyupet_menu || self.mowang_dafeiyupet_dragging || self.mowang_dafeiyupet_flying || self.mowang_dafeiyupet_loading || self.mowang_dafeiyupet_pendingBalance || self.mowang_dafeiyupet_pendingEvent || ![self.mowang_dafeiyupet_action isEqual:@"daiji-huxi-xiuxian"] || (!self.mowang_dafeiyupet_bubble.hidden && tick<=self.mowang_dafeiyupet_bubbleUntil)) return;
    NSDictionary *row=self.environmentQueue.firstObject; [self.environmentQueue removeObjectAtIndex:0];
    self.mowang_dafeiyupet_lyricBubble=NO; self.mowang_dafeiyupet_whisperBubble=NO;
    self.mowang_dafeiyupet_bubble.text=row[@"text"];
    self.mowang_dafeiyupet_bubble.accessibilityLabel=[NSString stringWithFormat:@"%@：%@",row[@"kind"],row[@"text"]];
    self.mowang_dafeiyupet_bubble.hidden=NO; self.mowang_dafeiyupet_bubbleUntil=tick+8;
    [self mowang_dafeiyupet_place];
    os_log(os_log_create("com.mowang.dafeiyupet","environment"),"Environment bubble displayed %{public}@",row[@"kind"]);
}
- (void)mowang_dafeiyupet_refresh {
    [self environmentRefresh];
    if(![[MowangDaFeiYuPetConfig mowang_dafeiyupet_shared] mowang_dafeiyupet_isEnabled]) {
        if(self.mowang_dafeiyupet_watch) { dispatch_source_cancel(self.mowang_dafeiyupet_watch); self.mowang_dafeiyupet_watch=nil; }
        self.mowang_dafeiyupet_pendingBalance=nil;
        self.mowang_dafeiyupet_pendingBalanceSource=nil;
        self.mowang_dafeiyupet_pendingEvent=nil;
        [self mowang_dafeiyupet_destroy]; return;
    }
    if(!self.mowang_dafeiyupet_watch) {
        self.mowang_dafeiyupet_watch=dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER,0,0,dispatch_get_main_queue());
        dispatch_source_set_timer(self.mowang_dafeiyupet_watch,DISPATCH_TIME_NOW,NSEC_PER_SEC/2,NSEC_PER_SEC/10);
        __weak typeof(self) weakSelf=self;
        dispatch_source_set_event_handler(self.mowang_dafeiyupet_watch,^{[weakSelf mowang_dafeiyupet_visibility];});
        dispatch_resume(self.mowang_dafeiyupet_watch);
    }
    BOOL balanceEnabled=[self mowang_dafeiyupet_number:@"balanceWhisperEnabled" fallback:0 low:0 high:1]>0;
    if(!balanceEnabled) {
        self.mowang_dafeiyupet_pendingBalance=nil;
        self.mowang_dafeiyupet_pendingBalanceSource=nil;
    }
    if(!balanceEnabled && self.mowang_dafeiyupet_whisperBubble && [self.mowang_dafeiyupet_bubble.accessibilityLabel hasPrefix:@"余额碎碎念："]) {
        self.mowang_dafeiyupet_bubble.hidden=YES;
        self.mowang_dafeiyupet_whisperBubble=NO;
    }
    if([self mowang_dafeiyupet_number:@"whisperEnabled" fallback:0 low:0 high:1]==0 && [self mowang_dafeiyupet_number:@"balanceWhisperEnabled" fallback:0 low:0 high:1]==0) {
        _mowang_dafeiyupet_whisperClock.elapsed=0;
        if(self.mowang_dafeiyupet_whisperBubble) self.mowang_dafeiyupet_bubble.hidden=YES;
        self.mowang_dafeiyupet_whisperBubble=NO;
    }
    self.mowang_dafeiyupet_positionLocked=[self mowang_dafeiyupet_number:@"positionLocked" fallback:0 low:0 high:1]>0;
    self.mowang_dafeiyupet_panGesture.enabled=!self.mowang_dafeiyupet_positionLocked;
    [self mowang_dafeiyupet_visibility];
}
- (void)mowang_dafeiyupet_keyboardShow:(NSNotification *)note {
    self.mowang_dafeiyupet_keyboardVisible=YES;
    if(!self.mowang_dafeiyupet_chat) { [self mowang_dafeiyupet_destroy]; return; }
    CGRect frame=[note.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    os_log(os_log_create("com.mowang.dafeiyupet","chat"),"ChatKeyboard willShow height=%.0f",frame.size.height);
    self.mowang_dafeiyupet_chatKeyboardTop=CGRectGetMinY([self.mowang_dafeiyupet_window convertRect:frame fromWindow:nil]);
    [self mowang_dafeiyupet_placeChat];
}
- (void)mowang_dafeiyupet_keyboardHide:(NSNotification *)note { self.mowang_dafeiyupet_keyboardVisible=NO; self.mowang_dafeiyupet_chatKeyboardTop=0; [self mowang_dafeiyupet_placeChat]; [self mowang_dafeiyupet_refresh]; }
- (void)refreshTexture {
    id value=[[MowangDaFeiYuPetConfig mowang_dafeiyupet_shared] mowang_dafeiyupet_valueForKey:@"skin" defaultValue:@"original"];
    NSString *selection=[value isKindOfClass:NSString.class]?value:@"original";
    if(![@[@"original",@"deepseek",@"harness",@"chatgpt",@"claude",@"gemini",@"qwen",@"kimi",@"minimax"] containsObject:selection]) selection=@"original";
    if(!self.mowang_dafeiyupet_pet || [selection isEqual:self.textureSelection]) return;
    [self.textureView removeFromSuperview]; self.textureView=nil; self.textureSelection=selection;
    self.mowang_dafeiyupet_generation++; // Reject old asynchronous GIF completions.
    if(![selection isEqual:@"original"]) {
        NSString *root=mowang_dafeiyupet_resourcePath(@"/Library/Application Support/MowangDaFeiYuPet/LiveTextures");
        MowangDaFeiYuPetTextureView *view=[[MowangDaFeiYuPetTextureView alloc] initWithAssetRoot:root scheme:selection];
        if(view.failure) {
            os_log_error(os_log_create("com.mowang.dafeiyupet","textures"),"Live renderer unavailable: %{public}@",view.failure);
            self.mowang_dafeiyupet_pet.accessibilityHint=[@"纹理加载失败，使用原动作：" stringByAppendingString:view.failure];
        } else {
            self.textureView=view; view.frame=self.mowang_dafeiyupet_pet.bounds;
            view.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
            self.mowang_dafeiyupet_pet.image=nil;
            [self.mowang_dafeiyupet_pet addSubview:view];
            [view advanceToTime:CACurrentMediaTime() action:self.mowang_dafeiyupet_action dragging:self.mowang_dafeiyupet_dragging flying:self.mowang_dafeiyupet_flying];
        }
    }
    if(!self.textureView) self.mowang_dafeiyupet_pet.image=self.mowang_dafeiyupet_idleImage;
    [self mowang_dafeiyupet_action:@"idle"];
}
- (void)mowang_dafeiyupet_visibility {
    BOOL locked=mowang_dafeiyupet_locked();
    BOOL allow=!locked && (!self.mowang_dafeiyupet_keyboardVisible || self.mowang_dafeiyupet_chat!=nil);
    if(mowang_dafeiyupet_homeOnly()) allow=allow && mowang_dafeiyupet_homeVisible();
    if(!allow) { [self mowang_dafeiyupet_destroy]; return; }
    if(!self.mowang_dafeiyupet_window) [self mowang_dafeiyupet_create];
    UIWindow *w=self.mowang_dafeiyupet_window;
    CGRect bounds=w.windowScene?w.windowScene.coordinateSpace.bounds:UIScreen.mainScreen.bounds;
    if(!CGRectEqualToRect(w.frame,bounds)) { w.frame=bounds; [self mowang_dafeiyupet_place]; }
    [self refreshTexture];
    CGFloat size=[self mowang_dafeiyupet_number:@"size" fallback:180 low:100 high:300];
    self.mowang_dafeiyupet_pet.bounds=CGRectMake(0,0,size,size*124/220);
    self.mowang_dafeiyupet_pet.alpha=[self mowang_dafeiyupet_number:@"opacity" fallback:1 low:.2 high:1];
    double reset=[self mowang_dafeiyupet_number:@"resetToken" fallback:0 low:0 high:1e12];
    if(reset!=self.mowang_dafeiyupet_reset) { self.mowang_dafeiyupet_reset=reset; [self mowang_dafeiyupet_home]; }
    [self mowang_dafeiyupet_place];
    [self environmentTick];
    id state=[[MowangDaFeiYuPetConfig mowang_dafeiyupet_shared] mowang_dafeiyupet_valueForKey:@"pomoState" defaultValue:@{}];
    if(![state isKindOfClass:NSDictionary.class]) state=@{};
    id started=state[@"startedAt"], work=state[@"workMin"], rest=state[@"restMin"];
    MowangDaFeiYuPetPomoSnapshot snap={0};
    if([started isKindOfClass:NSNumber.class] && [work isKindOfClass:NSNumber.class] && [rest isKindOfClass:NSNumber.class]) snap=mowang_dafeiyupet_pomo_snapshot([started doubleValue],[work intValue],[rest intValue],NSDate.date.timeIntervalSince1970);
    self.mowang_dafeiyupet_badge.hidden=snap.phase==MowangDaFeiYuPetPomoIdle;
    if(snap.phase!=MowangDaFeiYuPetPomoIdle) {
        self.mowang_dafeiyupet_badge.text=[NSString stringWithFormat:@"%@ %02u:%02u",snap.phase==MowangDaFeiYuPetPomoWork?@"专注":@"休息",snap.remainingSeconds/60,snap.remainingSeconds%60];
        self.mowang_dafeiyupet_badge.backgroundColor=snap.phase==MowangDaFeiYuPetPomoWork?[UIColor colorWithRed:.72 green:.30 blue:.22 alpha:.95]:[UIColor colorWithRed:.25 green:.53 blue:.35 alpha:.95];
    }
}
- (void)mowang_dafeiyupet_create {
    UIWindowScene *scene=nil;
    for(UIScene *candidate in UIApplication.sharedApplication.connectedScenes) {
        if([candidate isKindOfClass:UIWindowScene.class] && candidate.activationState==UISceneActivationStateForegroundActive) { scene=(UIWindowScene *)candidate; break; }
    }
    MowangDaFeiYuPetWindow *w=scene?[[MowangDaFeiYuPetWindow alloc] initWithWindowScene:scene]:[[MowangDaFeiYuPetWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    w.frame=scene?scene.coordinateSpace.bounds:UIScreen.mainScreen.bounds;
    w.windowLevel=UIWindowLevelAlert+1; w.backgroundColor=UIColor.clearColor;
    UIViewController *vc=[UIViewController new]; vc.view.backgroundColor=UIColor.clearColor; w.rootViewController=vc;
    MowangDaFeiYuPetTouchView *pet=[[MowangDaFeiYuPetTouchView alloc] initWithFrame:CGRectMake(0,0,180,180.*124/220)];
    __weak typeof(self) weakSelf=self;
    pet.mowang_dafeiyupet_touchDown=^{
        typeof(self) owner=weakSelf;
        if(!owner) return;
        owner.mowang_dafeiyupet_pendingScore=mowang_dafeiyupet_flyingScore(owner.mowang_dafeiyupet_flying,owner->_mowang_dafeiyupet_body.vx,owner->_mowang_dafeiyupet_body.vy,owner.mowang_dafeiyupet_pet.bounds.size.width);
    };
    pet.userInteractionEnabled=YES; pet.contentMode=UIViewContentModeScaleAspectFit;
    [vc.view addSubview:pet]; w.mowang_dafeiyupet_pet=pet;
    MowangDaFeiYuPetBubble *bubble=[MowangDaFeiYuPetBubble new]; bubble.numberOfLines=3; bubble.font=[UIFont systemFontOfSize:14];
    bubble.textAlignment=NSTextAlignmentCenter; bubble.backgroundColor=UIColor.clearColor;
    bubble.textColor=UIColor.blackColor; bubble.hidden=YES; bubble.userInteractionEnabled=NO;
    [vc.view addSubview:bubble];
    UILabel *badge=[UILabel new]; badge.font=[UIFont monospacedDigitSystemFontOfSize:12 weight:UIFontWeightSemibold];
    badge.textAlignment=NSTextAlignmentCenter; badge.textColor=UIColor.whiteColor; badge.layer.cornerRadius=8; badge.clipsToBounds=YES; badge.userInteractionEnabled=NO; badge.hidden=YES;
    [vc.view addSubview:badge]; self.mowang_dafeiyupet_badge=badge;
    self.mowang_dafeiyupet_window=w; self.mowang_dafeiyupet_pet=pet; self.mowang_dafeiyupet_bubble=bubble;
    pet.isAccessibilityElement=YES; pet.accessibilityLabel=@"大肥鱼桌宠";
    pet.accessibilityHint=@"单击聊天，长按或双击打开动作菜单";
    UITapGestureRecognizer *tap=[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(mowang_dafeiyupet_tap:)];
    UITapGestureRecognizer *doubleTap=[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(mowang_dafeiyupet_openMenu:)]; doubleTap.numberOfTapsRequired=2;
    UILongPressGestureRecognizer *hold=[[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(mowang_dafeiyupet_openMenu:)]; hold.minimumPressDuration=.5;
    UIPanGestureRecognizer *pan=[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(mowang_dafeiyupet_pan:)];
    [tap requireGestureRecognizerToFail:doubleTap]; [tap requireGestureRecognizerToFail:hold];
    [pet addGestureRecognizer:tap]; [pet addGestureRecognizer:doubleTap]; [pet addGestureRecognizer:hold]; [pet addGestureRecognizer:pan];
    self.mowang_dafeiyupet_panGesture=pan;
    pan.enabled=!self.mowang_dafeiyupet_positionLocked;
    if(!self.mowang_dafeiyupet_hasPosition) [self mowang_dafeiyupet_home];
    else [self mowang_dafeiyupet_place];
    [self mowang_dafeiyupet_action:@"idle"];
    self.mowang_dafeiyupet_idleTime=CACurrentMediaTime();
    // Passive pet never takes focus; only explicit chat temporarily becomes key.
    w.hidden=NO;
    self.mowang_dafeiyupet_link=[CADisplayLink displayLinkWithTarget:self selector:@selector(mowang_dafeiyupet_tick:)];
    self.mowang_dafeiyupet_link.preferredFramesPerSecond=30;
    [self.mowang_dafeiyupet_link addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];
}
- (void)mowang_dafeiyupet_closeMenu {
    [self.mowang_dafeiyupet_menu removeFromSuperview]; self.mowang_dafeiyupet_menu=nil;
    self.mowang_dafeiyupet_window.mowang_dafeiyupet_menu=nil;
    self.mowang_dafeiyupet_idleTime=CACurrentMediaTime();
}
- (void)mowang_dafeiyupet_openMenu:(UIGestureRecognizer *)g {
    if(g.state!=UIGestureRecognizerStateBegan && g.state!=UIGestureRecognizerStateEnded) return;
    if([g isKindOfClass:UILongPressGestureRecognizer.class] && g.state!=UIGestureRecognizerStateBegan) return;
    if(self.mowang_dafeiyupet_menu) { [self mowang_dafeiyupet_closeMenu]; return; }
    _mowang_dafeiyupet_roaming.active=0;
    self.mowang_dafeiyupet_flying=NO; _mowang_dafeiyupet_body.vx=0; _mowang_dafeiyupet_body.vy=0;
    self.mowang_dafeiyupet_bubble.hidden=YES;
    self.mowang_dafeiyupet_lyricBubble=NO;
    [self mowang_dafeiyupet_showMenu];
}
- (void)mowang_dafeiyupet_menuHeading:(NSString *)title inStack:(UIStackView *)stack {
    UILabel *label=[UILabel new]; label.text=title;
    label.font=[UIFont systemFontOfSize:11 weight:UIFontWeightBold];
    label.textColor=[UIColor colorWithRed:.44 green:.47 blue:.55 alpha:1];
    [stack addArrangedSubview:label]; [label.heightAnchor constraintEqualToConstant:23].active=YES;
}
- (void)mowang_dafeiyupet_menuButton:(NSString *)title tag:(NSInteger)tag inStack:(UIStackView *)stack {
    UIButton *button=[UIButton buttonWithType:UIButtonTypeSystem]; button.tag=tag;
    [button setTitle:title forState:UIControlStateNormal];
    button.titleLabel.font=[UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    button.contentHorizontalAlignment=UIControlContentHorizontalAlignmentLeft;
    UIButtonConfiguration *configuration=[UIButtonConfiguration plainButtonConfiguration];
    configuration.contentInsets=NSDirectionalEdgeInsetsMake(0,12,0,8);
    button.configuration=configuration;
    button.backgroundColor=[UIColor colorWithRed:.96 green:.97 blue:.99 alpha:1];
    button.layer.cornerRadius=11; button.clipsToBounds=YES;
    [button addTarget:self action:@selector(mowang_dafeiyupet_menuChoice:) forControlEvents:UIControlEventTouchUpInside];
    [stack addArrangedSubview:button]; [button.heightAnchor constraintEqualToConstant:39].active=YES;
}
- (void)mowang_dafeiyupet_showMenu {
    NSUInteger count=self.mowang_dafeiyupet_catalog.count, pages=MAX(1,(count+5)/6);
    self.mowang_dafeiyupet_menuPage%=pages;
    NSUInteger start=self.mowang_dafeiyupet_menuPage*6;
    self.mowang_dafeiyupet_menuEntries=[self.mowang_dafeiyupet_catalog subarrayWithRange:NSMakeRange(start,MIN(6,count-start))];
    UIScrollView *menu=[UIScrollView new];
    menu.backgroundColor=[UIColor colorWithRed:1 green:.995 blue:.98 alpha:.98];
    menu.layer.cornerRadius=18; menu.layer.borderWidth=1; menu.clipsToBounds=YES;
    menu.layer.borderColor=[UIColor colorWithWhite:.8 alpha:.6].CGColor;
    menu.showsVerticalScrollIndicator=YES;
    UIStackView *stack=[UIStackView new]; stack.axis=UILayoutConstraintAxisVertical; stack.spacing=5;
    CGFloat width=MIN(284,self.mowang_dafeiyupet_window.bounds.size.width-16);
    stack.frame=CGRectMake(12,10,width-24,0);
    [menu addSubview:stack];
    [self mowang_dafeiyupet_menuHeading:[NSString stringWithFormat:@"动作 · %lu / %lu 页",(unsigned long)self.mowang_dafeiyupet_menuPage+1,(unsigned long)pages] inStack:stack];
    for(NSUInteger i=0;i<self.mowang_dafeiyupet_menuEntries.count;i++) {
        NSDictionary *entry=self.mowang_dafeiyupet_menuEntries[i];
        [self mowang_dafeiyupet_menuButton:[NSString stringWithFormat:@"%@  ·  %@",entry[@"category"],entry[@"title"]] tag:(NSInteger)i inStack:stack];
    }
    NSInteger base=(NSInteger)self.mowang_dafeiyupet_menuEntries.count;
    [self mowang_dafeiyupet_menuButton:@"下一页动作  ›" tag:base inStack:stack];
    [self mowang_dafeiyupet_menuHeading:@"人物与位置" inStack:stack];
    [self mowang_dafeiyupet_menuButton:self.mowang_dafeiyupet_positionLocked?@"🔒 人物已锁定 · 点击解锁":@"解锁状态 · 点击锁定拖动" tag:base+1 inStack:stack];
    [self mowang_dafeiyupet_menuButton:self.mowang_dafeiyupet_roamPaused?@"恢复自动漫游（本次）":@"暂停自动漫游（本次）" tag:base+2 inStack:stack];
    [self mowang_dafeiyupet_menuButton:@"回初始位置" tag:base+3 inStack:stack];
    [self mowang_dafeiyupet_menuHeading:@"碎碎念" inStack:stack];
    NSDictionary *stored=mowang_dafeiyupet_readPreferences();
    BOOL balance=[stored[@"balanceWhisperEnabled"] isKindOfClass:NSNumber.class]?[stored[@"balanceWhisperEnabled"] boolValue]:NO;
    [self mowang_dafeiyupet_menuButton:balance?@"桌宠显示监控余额  ·  开":@"桌宠显示监控余额  ·  关" tag:base+4 inStack:stack];
    NSInteger interval=[stored[@"whisperInterval"] isKindOfClass:NSNumber.class]?[stored[@"whisperInterval"] integerValue]:300;
    [self mowang_dafeiyupet_menuButton:[NSString stringWithFormat:@"碎碎念间隔  ·  %@  ›",@{@30:@"30 秒",@60:@"1 分钟",@300:@"5 分钟",@900:@"15 分钟",@1800:@"30 分钟"}[@(interval)] ?: @"5 分钟"] tag:base+5 inStack:stack];
    [self mowang_dafeiyupet_menuButton:@"关闭浮窗" tag:base+6 inStack:stack];
    [stack layoutIfNeeded];
    CGFloat height=23*3+39*(self.mowang_dafeiyupet_menuEntries.count+7)+5*(self.mowang_dafeiyupet_menuEntries.count+9)+20;
    stack.frame=CGRectMake(12,10,width-24,height-20);
    menu.contentSize=CGSizeMake(width,height);
    self.mowang_dafeiyupet_menu=menu; self.mowang_dafeiyupet_window.mowang_dafeiyupet_menu=menu;
    [self.mowang_dafeiyupet_window.rootViewController.view addSubview:menu];
    self.mowang_dafeiyupet_menuUntil=CACurrentMediaTime()+60;
    [self mowang_dafeiyupet_place];
}
- (void)mowang_dafeiyupet_menuChoice:(UIButton *)sender {
    NSInteger choice=sender.tag, count=(NSInteger)self.mowang_dafeiyupet_menuEntries.count;
    if(choice<count) {
        NSString *key=self.mowang_dafeiyupet_menuEntries[(NSUInteger)choice][@"id"];
        [self mowang_dafeiyupet_closeMenu]; [self mowang_dafeiyupet_action:key]; return;
    }
    if(choice==count+5) {
        [self mowang_dafeiyupet_showIntervalChoices]; return;
    }
    [self mowang_dafeiyupet_closeMenu];
    if(choice==count) { self.mowang_dafeiyupet_menuPage++; [self mowang_dafeiyupet_showMenu]; }
    else if(choice==count+1 || choice==count+4) {
        NSString *key=choice==count+1?@"positionLocked":@"balanceWhisperEnabled";
        id storedValue=mowang_dafeiyupet_readPreferences()[key];
        BOOL current=[storedValue isKindOfClass:NSNumber.class]?[storedValue boolValue]:NO;
        NSError *error=nil;
        if(mowang_dafeiyupet_writePreference(key,@(!current),&error)) {
            if(choice==count+1) {
                self.mowang_dafeiyupet_positionLocked=!current;
                self.mowang_dafeiyupet_panGesture.enabled=current;
                if(!current) { self.mowang_dafeiyupet_dragging=NO; self.mowang_dafeiyupet_flying=NO; _mowang_dafeiyupet_trail.count=0; _mowang_dafeiyupet_body.vx=0; _mowang_dafeiyupet_body.vy=0; }
            }
            [self mowang_dafeiyupet_showMenu];
        } else os_log_error(os_log_create("com.mowang.dafeiyupet","menu"),"Preference write failed for %{public}@",key);
    }
    else if(choice==count+2) { self.mowang_dafeiyupet_roamPaused=!self.mowang_dafeiyupet_roamPaused; [self mowang_dafeiyupet_showMenu]; }
    else if(choice==count+3) { [self mowang_dafeiyupet_home]; [self mowang_dafeiyupet_action:@"idle"]; }
}
- (void)mowang_dafeiyupet_showIntervalChoices {
    [self mowang_dafeiyupet_closeMenu];
    UIScrollView *menu=[UIScrollView new];
    menu.backgroundColor=[UIColor colorWithRed:1 green:.995 blue:.98 alpha:.98];
    menu.layer.cornerRadius=18; menu.layer.borderWidth=1;
    menu.layer.borderColor=[UIColor colorWithWhite:.8 alpha:.6].CGColor;
    UIStackView *stack=[UIStackView new]; stack.axis=UILayoutConstraintAxisVertical; stack.spacing=5;
    CGFloat width=MIN(284,self.mowang_dafeiyupet_window.bounds.size.width-16);
    stack.frame=CGRectMake(12,10,width-24,0); [menu addSubview:stack];
    [self mowang_dafeiyupet_menuHeading:@"碎碎念间隔" inStack:stack];
    NSArray *titles=@[@"30 秒",@"1 分钟",@"5 分钟",@"15 分钟",@"30 分钟"];
    for(NSInteger i=0;i<5;i++) [self mowang_dafeiyupet_menuButton:titles[(NSUInteger)i] tag:i inStack:stack];
    [self mowang_dafeiyupet_menuButton:@"返回动作菜单" tag:5 inStack:stack];
    [stack layoutIfNeeded]; stack.frame=CGRectMake(12,10,width-24,23+39*6+5*6);
    menu.contentSize=CGSizeMake(width,CGRectGetMaxY(stack.frame)+10);
    for(UIButton *button in stack.arrangedSubviews) if([button isKindOfClass:UIButton.class]) {
        [button removeTarget:self action:@selector(mowang_dafeiyupet_menuChoice:) forControlEvents:UIControlEventTouchUpInside];
        [button addTarget:self action:@selector(mowang_dafeiyupet_intervalChoice:) forControlEvents:UIControlEventTouchUpInside];
    }
    self.mowang_dafeiyupet_menu=menu; self.mowang_dafeiyupet_window.mowang_dafeiyupet_menu=menu;
    [self.mowang_dafeiyupet_window.rootViewController.view addSubview:menu];
    self.mowang_dafeiyupet_menuUntil=CACurrentMediaTime()+60;
    [self mowang_dafeiyupet_place];
}
- (void)mowang_dafeiyupet_intervalChoice:(UIButton *)sender {
    if(sender.tag<5) {
        NSArray *values=@[@30,@60,@300,@900,@1800];
        NSError *error=nil;
        if(!mowang_dafeiyupet_writePreference(@"whisperInterval",values[(NSUInteger)sender.tag],&error)) {
            os_log_error(os_log_create("com.mowang.dafeiyupet","menu"),"Whisper interval write failed");
            return;
        }
    }
    [self mowang_dafeiyupet_closeMenu]; [self mowang_dafeiyupet_showMenu];
}
- (void)mowang_dafeiyupet_closeChat {
    if(!self.mowang_dafeiyupet_chat) return;
    MowangDaFeiYuPetChatController *chat=self.mowang_dafeiyupet_chat;
    chat.mowang_dafeiyupet_closeHandler=nil;
    [chat mowang_dafeiyupet_cancel];
    [chat.view endEditing:YES];
    [chat willMoveToParentViewController:nil]; [chat.view removeFromSuperview]; [chat removeFromParentViewController];
    self.mowang_dafeiyupet_window.mowang_dafeiyupet_chatView=nil;
    self.mowang_dafeiyupet_chat=nil;
    self.mowang_dafeiyupet_window.mowang_dafeiyupet_chatOpen=NO;
    [self.mowang_dafeiyupet_window resignKeyWindow];
    if(!mowang_dafeiyupet_locked()) [self.mowang_dafeiyupet_previousKeyWindow makeKeyWindow];
    self.mowang_dafeiyupet_previousKeyWindow=nil;
    self.mowang_dafeiyupet_keyboardVisible=NO;
    self.mowang_dafeiyupet_link.paused=NO; self.mowang_dafeiyupet_last=0;
    self.mowang_dafeiyupet_idleTime=CACurrentMediaTime();
    self.mowang_dafeiyupet_chatKeyboardTop=0;
    self.mowang_dafeiyupet_window.windowLevel=UIWindowLevelAlert+1;
    [self mowang_dafeiyupet_place];
}
- (void)mowang_dafeiyupet_placeChat {
    MowangDaFeiYuPetChatController *chat=self.mowang_dafeiyupet_chat;
    if(!chat) return;
    CGSize s=self.mowang_dafeiyupet_window.bounds.size,p=self.mowang_dafeiyupet_pet.bounds.size;
    CGFloat bottom=self.mowang_dafeiyupet_chatKeyboardTop>0?MIN(s.height-34,self.mowang_dafeiyupet_chatKeyboardTop-8):s.height-34;
    CGFloat w=MIN(272,s.width-24),maxHeight=MAX(176,bottom-64-p.height),h=MIN(maxHeight,chat.mowang_dafeiyupet_compact?[chat mowang_dafeiyupet_bubbleHeightForWidth:w]:222);
    CGFloat petY=MIN(_mowang_dafeiyupet_body.y,MAX(52,bottom-p.height));
    self.mowang_dafeiyupet_pet.center=CGPointMake(_mowang_dafeiyupet_body.x+p.width/2,petY+p.height/2);
    CGFloat x=mowang_dafeiyupet_clamp(self.mowang_dafeiyupet_pet.center.x-w/2,8,s.width-w-8);
    CGFloat y=petY-h-3;
    BOOL top=y<52 && petY+p.height+h+3<=bottom;
    if(top) y=petY+p.height+3;
    y=MAX(52,MIN(y,bottom-h));
    chat.mowang_dafeiyupet_tailOnTop=top;
    chat.mowang_dafeiyupet_tailX=self.mowang_dafeiyupet_pet.center.x-x;
    chat.view.frame=CGRectMake(x,y,w,h);
    [chat.view setNeedsLayout];
}
- (void)mowang_dafeiyupet_openChat {
    MowangDaFeiYuPetWindow *w=self.mowang_dafeiyupet_window;
    if(!w || self.mowang_dafeiyupet_chat || mowang_dafeiyupet_locked()) return;
    for(UIWindow *candidate in w.windowScene.windows) if(candidate.isKeyWindow && candidate!=w) self.mowang_dafeiyupet_previousKeyWindow=candidate;
    MowangDaFeiYuPetChatController *chat=[MowangDaFeiYuPetChatController new];
    self.mowang_dafeiyupet_chat=chat;
    __weak typeof(self) weakSelf=self;
    chat.mowang_dafeiyupet_closeHandler=^{ [weakSelf mowang_dafeiyupet_closeChat]; };
    chat.mowang_dafeiyupet_compact=YES;
    UIViewController *root=w.rootViewController;
    [root addChildViewController:chat];
    [root.view addSubview:chat.view]; [chat didMoveToParentViewController:root];
    w.mowang_dafeiyupet_chatView=chat.view;
    chat.mowang_dafeiyupet_contentChanged=^{ [weakSelf mowang_dafeiyupet_placeChat]; };
    [self mowang_dafeiyupet_placeChat];
    self.mowang_dafeiyupet_bubble.hidden=YES;
    self.mowang_dafeiyupet_lyricBubble=NO;
    self.mowang_dafeiyupet_link.paused=YES;
    _mowang_dafeiyupet_roaming.active=0;
    w.mowang_dafeiyupet_chatOpen=YES;
    w.windowLevel=UIWindowLevelNormal+1;
    [w makeKeyWindow];
}
- (void)mowang_dafeiyupet_destroy {
    [self mowang_dafeiyupet_closeChat];
    [self mowang_dafeiyupet_closeMenu];
    self.mowang_dafeiyupet_pendingScore=0;
    [self.mowang_dafeiyupet_scoreEffect removeFromSuperview]; self.mowang_dafeiyupet_scoreEffect=nil;
    [self.mowang_dafeiyupet_link invalidate]; self.mowang_dafeiyupet_link=nil;
    self.mowang_dafeiyupet_window.hidden=YES; self.mowang_dafeiyupet_window=nil;
    [self.textureView removeFromSuperview]; self.textureView=nil; self.textureSelection=nil;
    self.mowang_dafeiyupet_pet.image=nil; self.mowang_dafeiyupet_pet=nil; self.mowang_dafeiyupet_bubble=nil;
    self.mowang_dafeiyupet_badge=nil;
    self.mowang_dafeiyupet_lyricBubble=NO;
    self.mowang_dafeiyupet_generation++; self.mowang_dafeiyupet_last=0;
    dispatch_async(self.mowang_dafeiyupet_decodeQueue,^{
        if(self->_mowang_dafeiyupet_source) { CFRelease(self->_mowang_dafeiyupet_source); self->_mowang_dafeiyupet_source=NULL; }
        self->_mowang_dafeiyupet_sourcePath=nil;
    });
    self.mowang_dafeiyupet_dragging=NO; self.mowang_dafeiyupet_flying=NO;
    self.mowang_dafeiyupet_panGesture=nil;
    _mowang_dafeiyupet_trail.count=0; _mowang_dafeiyupet_squashStart=0;
    _mowang_dafeiyupet_roaming.active=0;
}
- (void)mowang_dafeiyupet_home {
    CGSize s=self.mowang_dafeiyupet_window.bounds.size, p=self.mowang_dafeiyupet_pet.bounds.size;
    _mowang_dafeiyupet_body=(MowangDaFeiYuPetBody){fmax(0,s.width-p.width-12),fmax(0,s.height-p.height-48),0,0};
    self.mowang_dafeiyupet_hasPosition=YES;
    self.mowang_dafeiyupet_dragging=NO; self.mowang_dafeiyupet_flying=NO;
    _mowang_dafeiyupet_trail.count=0; _mowang_dafeiyupet_squashStart=0;
    _mowang_dafeiyupet_roaming.active=0;
    self.mowang_dafeiyupet_pet.transform=CGAffineTransformIdentity;
    [self mowang_dafeiyupet_place];
}
- (void)mowang_dafeiyupet_place {
    CGSize s=self.mowang_dafeiyupet_window.bounds.size, p=self.mowang_dafeiyupet_pet.bounds.size;
    _mowang_dafeiyupet_body.x=mowang_dafeiyupet_clamp(_mowang_dafeiyupet_body.x,0,fmax(0,s.width-p.width));
    _mowang_dafeiyupet_body.y=mowang_dafeiyupet_clamp(_mowang_dafeiyupet_body.y,44,fmax(44,s.height-p.height-34));
    // Bounds/center remain valid while the presentation is squashed; setting frame
    // with a nonidentity transform would corrupt the next physics placement.
    self.mowang_dafeiyupet_pet.center=CGPointMake(_mowang_dafeiyupet_body.x+p.width/2,_mowang_dafeiyupet_body.y+p.height/2);
    CGFloat x=mowang_dafeiyupet_clamp(_mowang_dafeiyupet_body.x,8,fmax(8,s.width-188));
    self.mowang_dafeiyupet_badge.frame=CGRectMake(x,fmax(44,_mowang_dafeiyupet_body.y-28),112,24);
    MowangDaFeiYuPetBubble *bubble=(id)self.mowang_dafeiyupet_bubble;
    CGFloat bw=MIN(210,s.width-16);
    CGSize textSize=[bubble.text boundingRectWithSize:CGSizeMake(bw-24,80) options:NSStringDrawingUsesLineFragmentOrigin attributes:@{NSFontAttributeName:bubble.font} context:nil].size;
    CGFloat bh=MIN(84,MAX(43,ceil(textSize.height)+23));
    CGFloat bx=mowang_dafeiyupet_clamp(self.mowang_dafeiyupet_pet.center.x-bw/2,8,s.width-bw-8);
    CGFloat by=_mowang_dafeiyupet_body.y-bh-3;
    bubble.mowang_dafeiyupet_tailOnTop=by<50;
    if(bubble.mowang_dafeiyupet_tailOnTop) by=_mowang_dafeiyupet_body.y+p.height+3;
    bubble.frame=CGRectMake(bx,mowang_dafeiyupet_clamp(by,50,s.height-bh-34),bw,bh);
    bubble.mowang_dafeiyupet_tailX=self.mowang_dafeiyupet_pet.center.x-bx;
    [bubble setNeedsDisplay];
    self.mowang_dafeiyupet_badge.frame=CGRectMake(x,MAX(44,CGRectGetMinY(bubble.frame)-28),112,24);
    CGFloat menuWidth=fmin(284,s.width-16), menuHeight=fmin(self.mowang_dafeiyupet_menu.contentSize.height,s.height-100);
    CGFloat menuY=_mowang_dafeiyupet_body.y-menuHeight-12;
    if(menuY<50) menuY=_mowang_dafeiyupet_body.y+p.height+12;
    self.mowang_dafeiyupet_menu.frame=CGRectMake(mowang_dafeiyupet_clamp(_mowang_dafeiyupet_body.x,8,s.width-menuWidth-8),mowang_dafeiyupet_clamp(menuY,50,s.height-menuHeight-40),menuWidth,menuHeight);
}
- (NSString *)mowang_dafeiyupet_randomCategory:(NSArray<NSString *> *)categories {
    NSMutableArray *keys=[NSMutableArray array];
    for(NSDictionary *entry in self.mowang_dafeiyupet_catalog) if([categories containsObject:entry[@"category"]] && ![self.mowang_dafeiyupet_failedActions containsObject:entry[@"id"]]) [keys addObject:entry[@"id"]];
    if(keys.count>1) [keys removeObject:self.mowang_dafeiyupet_action];
    return keys.count?keys[arc4random_uniform((uint32_t)keys.count)]:@"daiji-huxi-xiuxian";
}
- (void)mowang_dafeiyupet_action:(NSString *)name {
    NSDictionary *aliases=@{@"idle":@"daiji-huxi-xiuxian",@"look":@"dongzhangxiwang",@"drag":@"beishubiao-tuozhuai-xuankong-fankui"};
    if([name isEqual:@"tap"]) name=[self mowang_dafeiyupet_randomCategory:@[@"click"]];
    name=aliases[name] ?: name;
    if(!self.mowang_dafeiyupet_manifest[name] || [self.mowang_dafeiyupet_failedActions containsObject:name]) name=@"daiji-huxi-xiuxian";
    BOOL wasIdle=[self.mowang_dafeiyupet_action isEqual:@"daiji-huxi-xiuxian"];
    BOOL isIdle=[name isEqual:@"daiji-huxi-xiuxian"];
    if(isIdle && !wasIdle) self.mowang_dafeiyupet_idleTime=CACurrentMediaTime();
    if(!self.textureView && ![self.mowang_dafeiyupet_action isEqual:name]) self.mowang_dafeiyupet_pet.image=self.mowang_dafeiyupet_idleImage;
    self.textureActionStart=CACurrentMediaTime();
    _mowang_dafeiyupet_roaming.active=0;
    self.mowang_dafeiyupet_action=name; self.mowang_dafeiyupet_frame=0;
    NSArray *moves=@[@"pangxie-zoulu",@"yuandi-piaofu-tabu",@"yuandi-zuozhuan-benpao"];
    NSUInteger profile=[moves indexOfObject:name];
    if(profile!=NSNotFound && !self.mowang_dafeiyupet_roamPaused &&
       [self mowang_dafeiyupet_number:@"roam" fallback:0 low:0 high:1]>0 &&
       !UIAccessibilityIsReduceMotionEnabled() && !self.mowang_dafeiyupet_dragging && !self.mowang_dafeiyupet_flying) {
        CGSize s=self.mowang_dafeiyupet_window.bounds.size,p=self.mowang_dafeiyupet_pet.bounds.size;
        _mowang_dafeiyupet_roaming=mowang_dafeiyupet_roamBegin(_mowang_dafeiyupet_body.x,s.width-p.width,p.width,(int)profile,arc4random_uniform(2));
        _mowang_dafeiyupet_body.vx=0; _mowang_dafeiyupet_body.vy=0;
    }
    for(NSDictionary *entry in self.mowang_dafeiyupet_catalog) if([entry[@"id"] isEqual:name]) self.mowang_dafeiyupet_pet.accessibilityValue=entry[@"title"];
    self.mowang_dafeiyupet_frameTime=0; self.mowang_dafeiyupet_generation++;
}
- (void)mowang_dafeiyupet_squash:(double)depth {
    if(UIAccessibilityIsReduceMotionEnabled()) return;
    _mowang_dafeiyupet_squashStart=CACurrentMediaTime();
    _mowang_dafeiyupet_squashDepth=depth;
}
- (void)mowang_dafeiyupet_scoreBurst:(unsigned)score {
    self.mowang_dafeiyupet_sessionScore=MIN((NSUInteger)1000000000,self.mowang_dafeiyupet_sessionScore+score);
    self.mowang_dafeiyupet_lyricBubble=NO;
    self.mowang_dafeiyupet_whisperBubble=NO;
    self.mowang_dafeiyupet_bubble.accessibilityLabel=nil;
    self.mowang_dafeiyupet_bubble.text=[NSString stringWithFormat:@"+%u 分 · 本次 %lu 分",score,(unsigned long)self.mowang_dafeiyupet_sessionScore];
    self.mowang_dafeiyupet_bubble.hidden=NO; self.mowang_dafeiyupet_bubbleUntil=CACurrentMediaTime()+3;
    UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification,self.mowang_dafeiyupet_bubble.text);
    [self.mowang_dafeiyupet_scoreEffect removeFromSuperview]; self.mowang_dafeiyupet_scoreEffect=nil;
    if(UIAccessibilityIsReduceMotionEnabled()) return;
    UIView *effect=[[UIView alloc] initWithFrame:self.mowang_dafeiyupet_window.bounds];
    effect.userInteractionEnabled=NO; effect.accessibilityElementsHidden=YES;
    [self.mowang_dafeiyupet_window.rootViewController.view addSubview:effect]; self.mowang_dafeiyupet_scoreEffect=effect;
    CGPoint center=self.mowang_dafeiyupet_pet.center;
    // Fixed twelve particles and at most one effect container; no repeating emitter.
    for(NSUInteger i=0;i<12;i++) {
        UIView *dot=[[UIView alloc] initWithFrame:CGRectMake(0,0,6,6)]; dot.center=center;
        dot.layer.cornerRadius=3; dot.backgroundColor=[UIColor colorWithHue:i/12. saturation:.75 brightness:1 alpha:1];
        [effect addSubview:dot];
        double angle=2*M_PI*i/12.;
        [UIView animateWithDuration:.55 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
            dot.center=CGPointMake(center.x+cos(angle)*48,center.y+sin(angle)*48); dot.alpha=0;
        } completion:nil];
    }
    __weak typeof(self) weakSelf=self;
    [UIView animateWithDuration:.65 animations:^{ effect.alpha=0; } completion:^(BOOL finished){
        [effect removeFromSuperview];
        if(weakSelf.mowang_dafeiyupet_scoreEffect==effect) weakSelf.mowang_dafeiyupet_scoreEffect=nil;
    }];
}
- (void)mowang_dafeiyupet_tap:(UITapGestureRecognizer *)g {
    if(g.state!=UIGestureRecognizerStateEnded) return;
    [self mowang_dafeiyupet_closeMenu];
    self.mowang_dafeiyupet_flying=NO; _mowang_dafeiyupet_body.vx=0; _mowang_dafeiyupet_body.vy=0;
    [self mowang_dafeiyupet_squash:.55];
    [self mowang_dafeiyupet_action:@"tap"];
    [self mowang_dafeiyupet_openChat];
    unsigned score=self.mowang_dafeiyupet_pendingScore; self.mowang_dafeiyupet_pendingScore=0;
    if(score) [self mowang_dafeiyupet_scoreBurst:score];
}
- (void)mowang_dafeiyupet_pan:(UIPanGestureRecognizer *)g {
    CFTimeInterval now=CACurrentMediaTime();
    CGPoint pointer=[g locationInView:self.mowang_dafeiyupet_window];
    if(g.state==UIGestureRecognizerStateBegan) {
        [self mowang_dafeiyupet_closeMenu];
        self.mowang_dafeiyupet_dragging=YES; self.mowang_dafeiyupet_flying=NO;
        _mowang_dafeiyupet_body.vx=0; _mowang_dafeiyupet_body.vy=0;
        _mowang_dafeiyupet_trail.count=0; _mowang_dafeiyupet_squashStart=0;
        _mowang_dafeiyupet_roaming.active=0;
        self.mowang_dafeiyupet_pet.transform=CGAffineTransformIdentity;
        CGPoint translation=[g translationInView:self.mowang_dafeiyupet_window];
        _mowang_dafeiyupet_dragTarget=CGPointMake(_mowang_dafeiyupet_body.x+translation.x,_mowang_dafeiyupet_body.y+translation.y);
        [g setTranslation:CGPointZero inView:self.mowang_dafeiyupet_window];
        [self mowang_dafeiyupet_action:@"drag"];
    }
    if(g.state==UIGestureRecognizerStateChanged || g.state==UIGestureRecognizerStateBegan) {
        CGPoint t=[g translationInView:self.mowang_dafeiyupet_window];
        _mowang_dafeiyupet_dragTarget.x+=t.x; _mowang_dafeiyupet_dragTarget.y+=t.y;
        [g setTranslation:CGPointZero inView:self.mowang_dafeiyupet_window];
        mowang_dafeiyupet_sample(&_mowang_dafeiyupet_trail,now,pointer.x,pointer.y);
    }
    if(g.state==UIGestureRecognizerStateEnded || g.state==UIGestureRecognizerStateCancelled || g.state==UIGestureRecognizerStateFailed) {
        self.mowang_dafeiyupet_dragging=NO;
        _mowang_dafeiyupet_body.vx=0; _mowang_dafeiyupet_body.vy=0;
        // Do not append an up event: holding still must expire the last movement.
        if(g.state==UIGestureRecognizerStateEnded)
            mowang_dafeiyupet_estimateRelease(&_mowang_dafeiyupet_trail,now,[self mowang_dafeiyupet_physics].power,&_mowang_dafeiyupet_body.vx,&_mowang_dafeiyupet_body.vy);
        _mowang_dafeiyupet_trail.count=0;
        self.mowang_dafeiyupet_flying=hypot(_mowang_dafeiyupet_body.vx,_mowang_dafeiyupet_body.vy)>0;
        self.mowang_dafeiyupet_idleTime=now;
        [self mowang_dafeiyupet_action:@"idle"];
    }
}
- (void)mowang_dafeiyupet_lyricLine:(NSString *)line {
    if(!NSThread.isMainThread) {
        dispatch_async(dispatch_get_main_queue(),^{ [self mowang_dafeiyupet_lyricLine:line]; });
        return;
    }
    BOOL valid=[line isKindOfClass:NSString.class] && line.length && line.length<=240 &&
               [[MowangDaFeiYuPetConfig mowang_dafeiyupet_shared] mowang_dafeiyupet_isEnabled];
    if(!valid && self.mowang_dafeiyupet_lyricBubble) {
        self.mowang_dafeiyupet_bubble.hidden=YES;
        self.mowang_dafeiyupet_lyricBubble=NO;
    }
    // Lyrics yield to chat, menus, scores, action feedback, messages and whispers.
    if(!valid || !self.mowang_dafeiyupet_window || self.mowang_dafeiyupet_chat || self.mowang_dafeiyupet_menu ||
       mowang_dafeiyupet_locked() || (mowang_dafeiyupet_homeOnly() && !mowang_dafeiyupet_homeVisible()) ||
       (!self.mowang_dafeiyupet_bubble.hidden && !self.mowang_dafeiyupet_lyricBubble && CACurrentMediaTime()<=self.mowang_dafeiyupet_bubbleUntil)) return;
    if(self.mowang_dafeiyupet_lyricBubble && !self.mowang_dafeiyupet_bubble.hidden && [self.mowang_dafeiyupet_bubble.text isEqualToString:line]) {
        self.mowang_dafeiyupet_bubbleUntil=CACurrentMediaTime()+5;
        return;
    }
    self.mowang_dafeiyupet_bubble.text=line;
    self.mowang_dafeiyupet_bubble.accessibilityLabel=[@"歌词：" stringByAppendingString:line];
    self.mowang_dafeiyupet_bubble.hidden=NO;
    self.mowang_dafeiyupet_whisperBubble=NO;
    self.mowang_dafeiyupet_lyricBubble=YES;
    self.mowang_dafeiyupet_bubbleUntil=CACurrentMediaTime()+5;
    [self mowang_dafeiyupet_place];
}
- (void)mowang_dafeiyupet_receivedEvent:(NSString *)kind {
    if(!NSThread.isMainThread) {
        dispatch_async(dispatch_get_main_queue(),^{ [self mowang_dafeiyupet_receivedEvent:kind]; });
        return;
    }
    if(![[MowangDaFeiYuPetConfig mowang_dafeiyupet_shared] mowang_dafeiyupet_isEnabled] || mowang_dafeiyupet_locked()) return;
    CFTimeInterval now=CACurrentMediaTime();
    if([kind isEqualToString:@"message"]) {
        if(now-self.mowang_dafeiyupet_lastMessageEvent<4) return;
        self.mowang_dafeiyupet_lastMessageEvent=now;
    } else if(![kind isEqualToString:@"musicStart"] && ![kind isEqualToString:@"musicStop"]) return;
    self.mowang_dafeiyupet_pendingEvent=kind;
    self.mowang_dafeiyupet_pendingEventUntil=now+15;
    if(self.mowang_dafeiyupet_lyricBubble) {
        self.mowang_dafeiyupet_bubble.hidden=YES;
        self.mowang_dafeiyupet_lyricBubble=NO;
    }
    [self mowang_dafeiyupet_showPendingEvent];
    os_log(os_log_create("com.mowang.dafeiyupet","events"),"Event queued %{public}@",kind);
}
- (void)mowang_dafeiyupet_showPendingEvent {
    NSString *event=self.mowang_dafeiyupet_pendingEvent;
    if(!event) return;
    CFTimeInterval now=CACurrentMediaTime();
    if(now>self.mowang_dafeiyupet_pendingEventUntil || mowang_dafeiyupet_locked()) { self.mowang_dafeiyupet_pendingEvent=nil; return; }
    if(!self.mowang_dafeiyupet_window || self.mowang_dafeiyupet_chat || self.mowang_dafeiyupet_menu ||
       self.mowang_dafeiyupet_dragging || self.mowang_dafeiyupet_flying || self.mowang_dafeiyupet_loading ||
       ![self.mowang_dafeiyupet_action isEqual:@"daiji-huxi-xiuxian"] ||
       (!self.mowang_dafeiyupet_bubble.hidden && now<=self.mowang_dafeiyupet_bubbleUntil)) return;
    self.mowang_dafeiyupet_pendingEvent=nil;
    self.mowang_dafeiyupet_lyricBubble=NO;
    NSString *action=[event isEqualToString:@"message"]?@"gongzuozhuangtai-sikao-maopao":
                     [event isEqualToString:@"musicStart"]?@"gongzuozhuangtai-queyue-qingzhu":@"gongzuozhuangtai-yuandi-duobu-zhangwang";
    NSString *text=[event isEqualToString:@"message"]?@"有新消息啦！":
                   [event isEqualToString:@"musicStart"]?@"音乐响起来啦 ♪":@"音乐暂停了。";
    [self mowang_dafeiyupet_action:action];
    self.mowang_dafeiyupet_bubble.text=text;
    self.mowang_dafeiyupet_bubble.accessibilityLabel=[@"事件联动：" stringByAppendingString:text];
    self.mowang_dafeiyupet_bubble.hidden=NO;
    self.mowang_dafeiyupet_whisperBubble=NO;
    self.mowang_dafeiyupet_bubbleUntil=now+5;
    [self mowang_dafeiyupet_place];
    os_log(os_log_create("com.mowang.dafeiyupet","events"),"Event displayed %{public}@",event);
}
- (void)mowang_dafeiyupet_balanceUpdate:(NSNotification *)note {
    if(!NSThread.isMainThread) {
        dispatch_async(dispatch_get_main_queue(),^{ [self mowang_dafeiyupet_balanceUpdate:note]; });
        return;
    }
    if([self mowang_dafeiyupet_number:@"balanceWhisperEnabled" fallback:0 low:0 high:1]==0 ||
       ![[MowangDaFeiYuPetConfig mowang_dafeiyupet_shared] mowang_dafeiyupet_isEnabled]) return;
    NSDictionary *info=note.userInfo;
    NSString *source=info[@"source"], *name=info[@"name"], *balance=info[@"balance"], *today=info[@"today"];
    if(![source isKindOfClass:NSString.class] || ![name isKindOfClass:NSString.class] ||
       ![balance isKindOfClass:NSString.class] || ![today isKindOfClass:NSString.class] ||
       ![@[@"zn",@"wanwanzhou",@"thirdparty"] containsObject:source] ||
       !( [source isEqualToString:@"thirdparty"] ? [mowang_dafeiyupet_balanceSourceID() hasPrefix:@"thirdparty-"] : [source isEqualToString:mowang_dafeiyupet_balanceSourceID()] ) ||
       name.length>32 || balance.length>64 || today.length>64 ||
       [name rangeOfCharacterFromSet:NSCharacterSet.newlineCharacterSet].location!=NSNotFound ||
       [balance rangeOfCharacterFromSet:NSCharacterSet.newlineCharacterSet].location!=NSNotFound ||
       [today rangeOfCharacterFromSet:NSCharacterSet.newlineCharacterSet].location!=NSNotFound) return;
    self.mowang_dafeiyupet_pendingBalance=[NSString stringWithFormat:@"%@\n余额：%@\n今日消耗：%@",name.length?name:@"监控余额",balance.length?balance:@"未知",today.length?today:@"未知"];
    self.mowang_dafeiyupet_pendingBalanceSource=mowang_dafeiyupet_balanceSourceID();
    self.mowang_dafeiyupet_pendingBalanceUntil=CACurrentMediaTime()+300;
    [self mowang_dafeiyupet_showPendingBalance];
    os_log(os_log_create("com.mowang.dafeiyupet","balance"),"BalanceUpdate received source=%{public}@",source);
}
- (void)mowang_dafeiyupet_showPendingBalance {
    if(!self.mowang_dafeiyupet_pendingBalance.length) return;
    if(CACurrentMediaTime()>self.mowang_dafeiyupet_pendingBalanceUntil || ![self.mowang_dafeiyupet_pendingBalanceSource isEqualToString:mowang_dafeiyupet_balanceSourceID()] || [self mowang_dafeiyupet_number:@"balanceWhisperEnabled" fallback:0 low:0 high:1]==0) {
        self.mowang_dafeiyupet_pendingBalance=nil;
        self.mowang_dafeiyupet_pendingBalanceSource=nil;
        return;
    }
    BOOL mayShow=self.mowang_dafeiyupet_window && !mowang_dafeiyupet_locked() && !self.mowang_dafeiyupet_chat && !self.mowang_dafeiyupet_dragging && !self.mowang_dafeiyupet_flying && !self.mowang_dafeiyupet_menu && [self.mowang_dafeiyupet_action isEqual:@"daiji-huxi-xiuxian"] && (self.mowang_dafeiyupet_bubble.hidden || CACurrentMediaTime()>self.mowang_dafeiyupet_bubbleUntil);
    if(!mayShow) return;
    NSString *text=self.mowang_dafeiyupet_pendingBalance;
    self.mowang_dafeiyupet_lyricBubble=NO;
    self.mowang_dafeiyupet_pendingBalance=nil;
    self.mowang_dafeiyupet_pendingBalanceSource=nil;
    self.mowang_dafeiyupet_bubble.text=text;
    self.mowang_dafeiyupet_bubble.accessibilityLabel=[@"余额碎碎念：" stringByAppendingString:text];
    self.mowang_dafeiyupet_bubble.hidden=NO;
    self.mowang_dafeiyupet_whisperBubble=YES;
    self.mowang_dafeiyupet_bubbleUntil=CACurrentMediaTime()+12;
    [self mowang_dafeiyupet_place];
    os_log(os_log_create("com.mowang.dafeiyupet","balance"),"BalancePoll displayed");
}
- (void)mowang_dafeiyupet_whisper {
    NSArray *lines=mowang_dafeiyupet_whisperLines();
    NSUInteger index=mowang_dafeiyupet_whisperIndex(lines.count,self.mowang_dafeiyupet_lastWhisper,arc4random());
    self.mowang_dafeiyupet_lastWhisper=index;
    self.mowang_dafeiyupet_lyricBubble=NO;
    [self mowang_dafeiyupet_action:[self mowang_dafeiyupet_randomCategory:@[@"碎碎念事件"]]];
    self.mowang_dafeiyupet_whisperBubble=NO;
    self.mowang_dafeiyupet_bubble.accessibilityLabel=nil;
    self.mowang_dafeiyupet_bubble.text=lines[index];
    self.mowang_dafeiyupet_bubble.accessibilityLabel=[@"离线碎碎念：" stringByAppendingString:lines[index]];
    self.mowang_dafeiyupet_bubble.hidden=NO;
    self.mowang_dafeiyupet_whisperBubble=YES;
    self.mowang_dafeiyupet_bubbleUntil=CACurrentMediaTime()+7;
}
- (void)mowang_dafeiyupet_tick:(CADisplayLink *)link {
    CFTimeInterval now=link.timestamp, dt=self.mowang_dafeiyupet_last?fmin(.05,now-self.mowang_dafeiyupet_last):0;
    self.mowang_dafeiyupet_last=now;
    CGSize s=self.mowang_dafeiyupet_window.bounds.size,p=self.mowang_dafeiyupet_pet.bounds.size;
    if(self.mowang_dafeiyupet_dragging) {
        double tx=mowang_dafeiyupet_clamp(_mowang_dafeiyupet_dragTarget.x,0,fmax(0,s.width-p.width));
        double ty=mowang_dafeiyupet_clamp(_mowang_dafeiyupet_dragTarget.y,44,fmax(44,s.height-p.height-34));
        mowang_dafeiyupet_spring(&_mowang_dafeiyupet_body,tx,ty,dt,[self mowang_dafeiyupet_physics].power);
        [self mowang_dafeiyupet_place];
    }
    if(self.mowang_dafeiyupet_flying && !self.mowang_dafeiyupet_dragging) {
        MowangDaFeiYuPetPhysics physics=[self mowang_dafeiyupet_physics];
        double ground=fmax(44,s.height-p.height-34);
        double impact=_mowang_dafeiyupet_body.vy+physics.gravity*dt;
        BOOL landing=_mowang_dafeiyupet_body.y<ground && impact>0 && _mowang_dafeiyupet_body.y+impact*dt>=ground;
        // Physics uses a y=0 origin inside the top safe margin.
        _mowang_dafeiyupet_body.y-=44;
        mowang_dafeiyupet_stepWithPhysics(&_mowang_dafeiyupet_body,dt,s.width-p.width,ground-44,physics);
        _mowang_dafeiyupet_body.y+=44;
        if(landing) [self mowang_dafeiyupet_squash:mowang_dafeiyupet_landingSquash(impact)];
        if(_mowang_dafeiyupet_body.vx==0 && _mowang_dafeiyupet_body.vy==0) self.mowang_dafeiyupet_flying=NO;
        [self mowang_dafeiyupet_place];
    }
    if(_mowang_dafeiyupet_roaming.active) {
        if(self.mowang_dafeiyupet_menu || self.mowang_dafeiyupet_dragging || self.mowang_dafeiyupet_flying ||
           self.mowang_dafeiyupet_roamPaused || UIAccessibilityIsReduceMotionEnabled() ||
           [self mowang_dafeiyupet_number:@"roam" fallback:0 low:0 high:1]==0) {
            _mowang_dafeiyupet_roaming.active=0;
        } else {
            NSArray *times=self.mowang_dafeiyupet_manifest[self.mowang_dafeiyupet_action];
            double progress=mowang_dafeiyupet_frameProgress(times,self.mowang_dafeiyupet_frame,now-self.mowang_dafeiyupet_frameTime);
            _mowang_dafeiyupet_body.x=mowang_dafeiyupet_roamAdvance(&_mowang_dafeiyupet_roaming,progress,s.width-p.width);
            [self mowang_dafeiyupet_place];
        }
    }
    if(_mowang_dafeiyupet_squashStart) {
        double u=mowang_dafeiyupet_clamp((now-_mowang_dafeiyupet_squashStart)/.220,0,1);
        if(u>=1 || UIAccessibilityIsReduceMotionEnabled()) {
            self.mowang_dafeiyupet_pet.transform=CGAffineTransformIdentity;
            _mowang_dafeiyupet_squashStart=0;
        } else {
            double scale=mowang_dafeiyupet_squashScale(u,_mowang_dafeiyupet_squashDepth);
            // Translate down half the lost height: the feet stay fixed.
            self.mowang_dafeiyupet_pet.transform=CGAffineTransformMake(1,0,0,scale,0,p.height*(1-scale)/2);
        }
    }
    if(self.mowang_dafeiyupet_menu && now>self.mowang_dafeiyupet_menuUntil) [self mowang_dafeiyupet_closeMenu];
    double interval=[self mowang_dafeiyupet_number:@"actionInterval" fallback:12 low:6 high:60];
    BOOL busy=self.mowang_dafeiyupet_menu || self.mowang_dafeiyupet_dragging || self.mowang_dafeiyupet_flying || ![self.mowang_dafeiyupet_action isEqual:@"daiji-huxi-xiuxian"];
    BOOL whisperBusy=busy || self.mowang_dafeiyupet_loading || now<self.mowang_dafeiyupet_retryAfter || (!self.mowang_dafeiyupet_bubble.hidden && now<=self.mowang_dafeiyupet_bubbleUntil);
    double preview=[self mowang_dafeiyupet_number:@"whisperPreviewToken" fallback:0 low:0 high:1e12];
    BOOL previewDue=preview!=self.mowang_dafeiyupet_whisperPreview;
    BOOL whisperEnabled=[self mowang_dafeiyupet_number:@"whisperEnabled" fallback:0 low:0 high:1]>0;
    if(whisperEnabled && (mowang_dafeiyupet_whisperTick(&_mowang_dafeiyupet_whisperClock,dt,[self mowang_dafeiyupet_number:@"whisperInterval" fallback:300 low:30 high:1800],whisperEnabled,whisperBusy) || (previewDue && !whisperBusy))) {
            self.mowang_dafeiyupet_whisperPreview=preview;
            [self mowang_dafeiyupet_whisper];
            busy=YES;
        }
    if(mowang_dafeiyupet_scheduleDue(now,self.mowang_dafeiyupet_idleTime,interval,busy)) {
        self.mowang_dafeiyupet_idleTime=now;
        BOOL move=!self.mowang_dafeiyupet_roamPaused && [self mowang_dafeiyupet_number:@"roam" fallback:0 low:0 high:1]>0;
        int mode=(int)[self mowang_dafeiyupet_number:@"actionMood" fallback:0 low:0 high:2];
        MowangPetChoice choice=mowang_dafeiyupet_chooseAction(arc4random_uniform(1000000)/1000000.,mode,move);
        NSString *action=choice==MowangPetMove?[self mowang_dafeiyupet_randomCategory:@[@"move"]]:choice==MowangPetAction?[self mowang_dafeiyupet_randomCategory:@[@"小动作",@"玩耍",@"吃什么",@"时节"]]:choice==MowangPetLook?@"look":@"idle";
        [self mowang_dafeiyupet_action:action];
    }
    if(now>self.mowang_dafeiyupet_bubbleUntil) self.mowang_dafeiyupet_bubble.hidden=YES;
    [self mowang_dafeiyupet_showPendingEvent];
    [self mowang_dafeiyupet_showPendingBalance];
    if(!self.mowang_dafeiyupet_bubble.hidden) [self mowang_dafeiyupet_place];
    if(self.textureView) {
        // Share physics, gestures, scope, bubble arbitration and the 30Hz clock; never decode GIFs in live mode.
        [self.textureView advanceToTime:now action:self.mowang_dafeiyupet_action dragging:self.mowang_dafeiyupet_dragging flying:self.mowang_dafeiyupet_flying];
        if(!self.mowang_dafeiyupet_dragging && ![self.mowang_dafeiyupet_action isEqual:@"daiji-huxi-xiuxian"] && now-self.textureActionStart>2.4) [self mowang_dafeiyupet_action:@"idle"];
        return;
    }
    if(self.mowang_dafeiyupet_loading || now<self.mowang_dafeiyupet_retryAfter) return;
    NSArray *durations=self.mowang_dafeiyupet_manifest[self.mowang_dafeiyupet_action];
    if(![durations isKindOfClass:NSArray.class] || durations.count==0) return;
    NSUInteger index=self.mowang_dafeiyupet_frame;
    if(index>0 && now-self.mowang_dafeiyupet_frameTime<mowang_dafeiyupet_frameDelay(durations[MIN(index-1,durations.count-1)])) return;
    if(index>=durations.count) { [self mowang_dafeiyupet_action:self.mowang_dafeiyupet_dragging?@"drag":@"idle"]; return; }
    NSString *relative=[NSString stringWithFormat:@"/Library/Application Support/MowangDaFeiYuPet/animations/%@.gif",self.mowang_dafeiyupet_action];
    NSString *path=mowang_dafeiyupet_resourcePath(relative);
    NSUInteger generation=self.mowang_dafeiyupet_generation;
    self.mowang_dafeiyupet_loading=YES;
    // At most one decode in flight + one displayed image, never UIImageView.animationImages.
    dispatch_async(self.mowang_dafeiyupet_decodeQueue,^{ @autoreleasepool {
        if(![self->_mowang_dafeiyupet_sourcePath isEqual:path]) {
            if(self->_mowang_dafeiyupet_source) CFRelease(self->_mowang_dafeiyupet_source);
            self->_mowang_dafeiyupet_source=CGImageSourceCreateWithURL((__bridge CFURLRef)[NSURL fileURLWithPath:path],(__bridge CFDictionaryRef)@{(NSString *)kCGImageSourceShouldCache:@NO});
            self->_mowang_dafeiyupet_sourcePath=path;
        }
        CGImageRef frame=self->_mowang_dafeiyupet_source?CGImageSourceCreateImageAtIndex(self->_mowang_dafeiyupet_source,index,(__bridge CFDictionaryRef)@{(NSString *)kCGImageSourceShouldCache:@NO}):NULL;
        UIImage *image=frame?[UIImage imageWithCGImage:frame]:nil;
        if(frame) CGImageRelease(frame);
        if(image) { UIGraphicsBeginImageContextWithOptions(image.size,NO,1); [image drawAtPoint:CGPointZero]; image=UIGraphicsGetImageFromCurrentImageContext(); UIGraphicsEndImageContext(); }
        if(!image) {
            if(self->_mowang_dafeiyupet_source) { CFRelease(self->_mowang_dafeiyupet_source); self->_mowang_dafeiyupet_source=NULL; }
            self->_mowang_dafeiyupet_sourcePath=nil;
        }
        dispatch_async(dispatch_get_main_queue(),^{
            self.mowang_dafeiyupet_loading=NO;
            if(generation!=self.mowang_dafeiyupet_generation || !self.mowang_dafeiyupet_pet) return;
            if(!image) {
                NSString *failed=self.mowang_dafeiyupet_action;
                BOOL idle=[failed isEqual:@"daiji-huxi-xiuxian"];
                if(!idle) [self.mowang_dafeiyupet_failedActions addObject:failed];
                [self mowang_dafeiyupet_action:@"idle"];
                self.mowang_dafeiyupet_retryAfter=CACurrentMediaTime()+(idle?5:.25);
                self.mowang_dafeiyupet_pet.image=self.mowang_dafeiyupet_idleImage;
                self.mowang_dafeiyupet_lyricBubble=NO;
                self.mowang_dafeiyupet_whisperBubble=NO;
                self.mowang_dafeiyupet_bubble.accessibilityLabel=nil;
                self.mowang_dafeiyupet_bubble.text=@"动作素材暂不可用，已返回待机。";
                self.mowang_dafeiyupet_bubble.hidden=NO;
                self.mowang_dafeiyupet_bubbleUntil=CACurrentMediaTime()+4;
                return;
            }
            if(index==0 && [self.mowang_dafeiyupet_action isEqual:@"daiji-huxi-xiuxian"]) self.mowang_dafeiyupet_idleImage=image;
            self.mowang_dafeiyupet_pet.image=image;
            self.mowang_dafeiyupet_frame++; self.mowang_dafeiyupet_frameTime=CACurrentMediaTime();
        });
    }});
}
@end
