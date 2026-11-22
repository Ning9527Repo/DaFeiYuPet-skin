#import <UIKit/UIKit.h>
#import "MowangDaFeiYuPetConfig.h"
#import "MowangDaFeiYuPetController.h"

%hook SpringBoard
- (void)applicationDidFinishLaunching:(id)application {
    %orig;
    [[MowangDaFeiYuPetController mowang_dafeiyupet_shared] mowang_dafeiyupet_start];
}
%end

%ctor {
    @autoreleasepool {
        [MowangDaFeiYuPetConfig mowang_dafeiyupet_shared];
    }
}
