#pragma once

#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#import "MowangDaFeiYuPetPaths.h"

static NSString * const MowangDaFeiYuPetPreferencesDomain = @"com.mowang.dafeiyupet";
static NSString * const MowangDaFeiYuPetPreferencesChanged = @"com.mowang.dafeiyupet.preferences-changed";

static inline NSDictionary *mowang_dafeiyupet_readPreferences(void) {
    // Read only the new identity. Legacy data is never imported implicitly.
    NSString *path = mowang_dafeiyupet_preferencesPath();
    NSDictionary *values = path.length > 0 ? [NSDictionary dictionaryWithContentsOfFile:path] : nil;
    if ([values isKindOfClass:[NSDictionary class]]) {
        return values;
    }
    // Compatibility fallback, not a second writable file location.
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:MowangDaFeiYuPetPreferencesDomain];
    [defaults synchronize];
    return [defaults persistentDomainForName:MowangDaFeiYuPetPreferencesDomain] ?: @{};
}

// Settings and the explicitly opened pet chat UI share this atomic writer.
static inline BOOL mowang_dafeiyupet_writePreference(NSString *key, id value, NSError **error) {
    NSString *path = mowang_dafeiyupet_preferencesPath();
    if (key.length == 0 || path.length == 0) {
        if (error) {
            *error = [NSError errorWithDomain:MowangDaFeiYuPetPreferencesDomain code:1
                                    userInfo:@{NSLocalizedDescriptionKey: @"Invalid preference path or key"}];
        }
        return NO;
    }
    NSFileManager *manager = [NSFileManager defaultManager];
    NSMutableDictionary *values;
    if ([manager fileExistsAtPath:path]) {
        NSData *existing = [NSData dataWithContentsOfFile:path options:0 error:error];
        id decoded = existing ? [NSPropertyListSerialization propertyListWithData:existing
                         options:NSPropertyListMutableContainers format:NULL error:error] : nil;
        if (![decoded isKindOfClass:[NSDictionary class]]) {
            if (error && !*error) {
                *error = [NSError errorWithDomain:MowangDaFeiYuPetPreferencesDomain code:2
                                        userInfo:@{NSLocalizedDescriptionKey: @"Preferences are not a dictionary"}];
            }
            return NO;
        }
        values = [decoded mutableCopy];
    } else {
        values = [mowang_dafeiyupet_readPreferences() mutableCopy];
    }
    if (value) values[key] = value;
    else [values removeObjectForKey:key];
    if (![manager createDirectoryAtPath:[path stringByDeletingLastPathComponent]
            withIntermediateDirectories:YES attributes:nil error:error]) {
        return NO;
    }
    NSData *data = [NSPropertyListSerialization dataWithPropertyList:values
                         format:NSPropertyListBinaryFormat_v1_0 options:0 error:error];
    if (!data || ![data writeToFile:path options:NSDataWritingAtomic error:error]) {
        return NO;
    }
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:MowangDaFeiYuPetPreferencesDomain];
    // Mirror the whole snapshot so cfprefsd cannot flush stale unrelated keys.
    [defaults setPersistentDomain:values forName:MowangDaFeiYuPetPreferencesDomain];
    [defaults synchronize];
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
        (__bridge CFStringRef)MowangDaFeiYuPetPreferencesChanged, NULL, NULL, true);
    return YES;
}
