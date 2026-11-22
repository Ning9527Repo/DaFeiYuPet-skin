#pragma once
#import <Foundation/Foundation.h>
#import "MWPetMotionMath.h"
// Each clip is explicitly authored; unknown ids are rejected, never silently marked supported.
@interface MWPetLiveActions : NSObject
@property(nonatomic,readonly,copy) NSString *failure;
@property(nonatomic,readonly) NSDictionary<NSString *,NSDictionary *> *clips;
- (instancetype)initWithRoot:(NSString *)root;
- (BOOL)sampleAction:(NSString *)action elapsed:(double)elapsed values:(double *)values;
- (NSDictionary *)clip:(NSString *)action;
@end
