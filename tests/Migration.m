#import <Foundation/Foundation.h>
#import "../Sources/MowangDaFeiYuPetMigration.h"
static void check(BOOL condition, NSString *message) { if (!condition) { NSLog(@"Migration test failed: %@",message); exit(1); } }
int main(void) { @autoreleasepool {
    NSString *dir=[@"build" stringByAppendingPathComponent:[@"migration-fixture-" stringByAppendingString:NSUUID.UUID.UUIDString]];
    NSFileManager *fm=NSFileManager.defaultManager;
    check([fm createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil],@"fixture folder");
    NSString *old=[dir stringByAppendingPathComponent:@"old.plist"],*next=[dir stringByAppendingPathComponent:@"new.plist"];
    NSDictionary *source=@{@"enabled":@YES,@"petState":@{@"history":@[@"synthetic-only"]}};
    check([source writeToFile:old atomically:YES],@"fixture source");
    NSError *error=nil;
    check(mowang_dafeiyupet_copyPreferences(old,next,&error),@"copy");
    check([source isEqual:[NSDictionary dictionaryWithContentsOfFile:next]],@"same values");
    check([@{ @"enabled":@NO } writeToFile:next atomically:YES],@"new values");
    check(mowang_dafeiyupet_copyPreferences(old,next,&error),@"repeat copy");
    check([[NSDictionary dictionaryWithContentsOfFile:next][@"enabled"] isEqual:@NO],@"does not overwrite");
    check([source isEqual:[NSDictionary dictionaryWithContentsOfFile:old]],@"old untouched");
    [fm removeItemAtPath:next error:nil];
    check([@[@"malformed"] writeToFile:old atomically:YES],@"malformed fixture");
    check(!mowang_dafeiyupet_copyPreferences(old,next,&error),@"reject non-dictionary");
    check(![fm fileExistsAtPath:next],@"no malformed output");
    check([[mowang_dafeiyupet_migrationKeyQuery(@"com.mowang.dafeiyupet.ai") objectForKey:(__bridge id)kSecAttrAccount] isEqual:@"provider"],@"query account");
    check([fm removeItemAtPath:dir error:nil],@"remove fixture");
    puts("migration fixture tests passed (Keychain access not exercised)");
    return 0;
} }
