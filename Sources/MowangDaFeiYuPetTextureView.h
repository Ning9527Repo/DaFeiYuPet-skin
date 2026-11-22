#pragma once
#import <UIKit/UIKit.h>
// No timer, network, frame sequence or thumbnail. Driven by the controller's existing display link.
@interface MowangDaFeiYuPetTextureView : UIView
@property(nonatomic,readonly,copy) NSString *scheme;
@property(nonatomic,readonly,copy) NSString *failure;
- (instancetype)initWithAssetRoot:(NSString *)root scheme:(NSString *)scheme;
- (void)advanceToTime:(CFTimeInterval)time action:(NSString *)action dragging:(BOOL)dragging flying:(BOOL)flying;
@end
