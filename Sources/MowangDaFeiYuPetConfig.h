#pragma once

#import <Foundation/Foundation.h>

@interface MowangDaFeiYuPetConfig : NSObject
+ (instancetype)mowang_dafeiyupet_shared;
- (BOOL)mowang_dafeiyupet_isEnabled;
- (id)mowang_dafeiyupet_valueForKey:(NSString *)key defaultValue:(id)defaultValue;
- (void)mowang_dafeiyupet_reload;
@end
