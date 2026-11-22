#import "MowangDaFeiYuPetConfig.h"
#import "MowangDaFeiYuPetPreferences.h"
#import "MowangDaFeiYuPetState.h"

@interface MowangDaFeiYuPetConfig ()
@property (atomic, copy) NSDictionary *snapshot;
@property (nonatomic, strong) dispatch_queue_t reloadQueue;
@end

static void mowang_dafeiyupet_preferencesDidChange(CFNotificationCenterRef center, void *observer,
                                          CFStringRef name, const void *object, CFDictionaryRef info) {
    MowangDaFeiYuPetConfig *config = (__bridge MowangDaFeiYuPetConfig *)observer;
    dispatch_async(config.reloadQueue, ^{
        [config mowang_dafeiyupet_reload];
    });
}

@implementation MowangDaFeiYuPetConfig

+ (instancetype)mowang_dafeiyupet_shared {
    static MowangDaFeiYuPetConfig *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _reloadQueue = dispatch_queue_create("com.mowang.dafeiyupet.preferences", DISPATCH_QUEUE_SERIAL);
        [self mowang_dafeiyupet_reload];
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
            (__bridge const void *)self, mowang_dafeiyupet_preferencesDidChange,
            (__bridge CFStringRef)MowangDaFeiYuPetPreferencesChanged, NULL,
            CFNotificationSuspensionBehaviorDeliverImmediately);
        // Close the window between the first read and observer registration.
        dispatch_async(_reloadQueue, ^{ [self mowang_dafeiyupet_reload]; });
    }
    return self;
}

- (void)mowang_dafeiyupet_reload {
    self.snapshot = mowang_dafeiyupet_effectivePreferences(mowang_dafeiyupet_readPreferences());
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:MowangDaFeiYuPetPreferencesChanged object:self];
    });
}

- (id)mowang_dafeiyupet_valueForKey:(NSString *)key defaultValue:(id)defaultValue {
    return self.snapshot[key] ?: defaultValue;
}

- (BOOL)mowang_dafeiyupet_isEnabled {
    id value = [self mowang_dafeiyupet_valueForKey:@"enabled" defaultValue:@(NO)];
    return [value isKindOfClass:[NSNumber class]] ? [value boolValue] : NO;
}

- (void)dealloc {
    CFNotificationCenterRemoveEveryObserver(CFNotificationCenterGetDarwinNotifyCenter(),
                                            (__bridge const void *)self);
}

@end
