// SPDX-License-Identifier: MIT
#pragma once
#import <Foundation/Foundation.h>
#import <Security/Security.h>
#import <errno.h>
#import <unistd.h>
#import "ApelinBootstrap.h"

// No secret, preference value, or Keychain item is logged by this module.
static inline NSString *mowang_dafeiyupet_prefPath(NSString *domain) {
    NSString *relative=[NSString stringWithFormat:@"/var/mobile/Library/Preferences/%@.plist",domain];
#ifdef APELIN_BOOTSTRAP_ROOTHIDE
    return ApelinBootstrapPath(relative);
#else
    return relative;
#endif
}

// Copy only when the destination does not exist. Never merge or overwrite a new user's choices.
// Refuse malformed source data rather than treating it as an empty settings dictionary.
static inline BOOL mowang_dafeiyupet_copyPreferences(NSString *old, NSString *next, NSError **error) {
    if (!old.length || !next.length) return NO;
    NSFileManager *fm=NSFileManager.defaultManager;
    if ([fm fileExistsAtPath:next]) return YES;
    NSData *data=[NSData dataWithContentsOfFile:old options:0 error:error];
    if (!data) return NO;
    id plist=[NSPropertyListSerialization propertyListWithData:data options:NSPropertyListImmutable format:NULL error:error];
    if (![plist isKindOfClass:NSDictionary.class]) return NO;
    // A unique same-directory temporary file contains the full validated snapshot.
    // Hard-linking it into place publishes atomically and refuses to replace an existing destination.
    NSString *temporary=[next stringByAppendingFormat:@".migration-%@",NSUUID.UUID.UUIDString];
    if (![data writeToFile:temporary options:NSDataWritingAtomic error:error]) return NO;
    int result=link(temporary.fileSystemRepresentation,next.fileSystemRepresentation);
    int saved=errno;
    unlink(temporary.fileSystemRepresentation);
    if (result==0 || saved==EEXIST) return YES;
    if (error) *error=[NSError errorWithDomain:NSPOSIXErrorDomain code:saved userInfo:nil];
    return NO;
}

static inline BOOL mowang_dafeiyupet_migratePreferences(NSError **error) {
    return mowang_dafeiyupet_copyPreferences(mowang_dafeiyupet_prefPath(@"com.axs.dafeiyupet"),
        mowang_dafeiyupet_prefPath(@"com.mowang.dafeiyupet"),error);
}

static inline NSDictionary *mowang_dafeiyupet_migrationKeyQuery(NSString *service) {
    return @{(__bridge id)kSecClass:(__bridge id)kSecClassGenericPassword,
             (__bridge id)kSecAttrService:service,
             (__bridge id)kSecAttrAccount:@"provider"};
}

// Do not call at load time: only after the host is running and Keychain is available.
// Returns errSecItemNotFound for an absent old key; returns the exact access error otherwise.
// Never replaces an existing destination and never deletes the original item.
static inline OSStatus mowang_dafeiyupet_migrateKey(void) {
    NSDictionary *target=mowang_dafeiyupet_migrationKeyQuery(@"com.mowang.dafeiyupet.ai");
    NSMutableDictionary *probe=[target mutableCopy];
    probe[(__bridge id)kSecMatchLimit]=(__bridge id)kSecMatchLimitOne;
    OSStatus result=SecItemCopyMatching((__bridge CFDictionaryRef)probe,NULL);
    if (result==errSecSuccess) return errSecSuccess;
    if (result!=errSecItemNotFound) return result;
    NSMutableDictionary *source=[mowang_dafeiyupet_migrationKeyQuery(@"com.axs.dafeiyupet.ai") mutableCopy];
    source[(__bridge id)kSecReturnData]=@YES;
    source[(__bridge id)kSecMatchLimit]=(__bridge id)kSecMatchLimitOne;
    CFTypeRef raw=NULL;
    result=SecItemCopyMatching((__bridge CFDictionaryRef)source,&raw);
    if (result!=errSecSuccess) { if (raw) CFRelease(raw); return result; }
    NSData *secret=CFBridgingRelease(raw);
    if (![secret isKindOfClass:NSData.class] || secret.length==0) return errSecParam;
    NSMutableDictionary *addition=[target mutableCopy];
    addition[(__bridge id)kSecValueData]=secret;
    addition[(__bridge id)kSecAttrAccessible]=(__bridge id)kSecAttrAccessibleWhenUnlockedThisDeviceOnly;
    result=SecItemAdd((__bridge CFDictionaryRef)addition,NULL);
    // Race with a user's own save: an existing destination wins without being overwritten.
    return result==errSecDuplicateItem ? errSecSuccess : result;
}
