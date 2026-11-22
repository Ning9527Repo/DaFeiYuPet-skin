#pragma once
#import "ApelinBootstrap.h"
static inline NSString *mowang_dafeiyupet_resourcePath(NSString *rootfsPath) {
    return ApelinBootstrapPath(rootfsPath);
}
static inline NSString *mowang_dafeiyupet_preferencesPath(void) {
#ifdef APELIN_BOOTSTRAP_ROOTHIDE
    return ApelinBootstrapPath(@"/var/mobile/Library/Preferences/com.mowang.dafeiyupet.plist");
#else
    return @"/var/mobile/Library/Preferences/com.mowang.dafeiyupet.plist";
#endif
}
