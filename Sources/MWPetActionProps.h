#pragma once
#import <UIKit/UIKit.h>
#import "MWPetMotionMath.h"
@interface MWPetActionProps : NSObject
@property(nonatomic,readonly,copy) NSString *failure;
- (instancetype)initWithRoot:(NSString *)root required:(NSSet<NSString *> *)required;
// anchorSpace: near/far props inherit the exact arm transform used for the character.
- (void)drawProps:(NSArray<NSString *> *)names kind:(NSString *)kind variant:(NSInteger)variant phase:(double)phase elapsed:(double)elapsed space:(NSString *)space;
@end
