#import <UIKit/UIKit.h>
@interface MowangDaFeiYuPetChatController : UIViewController <NSURLSessionDataDelegate,UITextViewDelegate>
@property(nonatomic,copy) void (^mowang_dafeiyupet_closeHandler)(void);
@property(nonatomic) BOOL mowang_dafeiyupet_compact;
@property(nonatomic) CGFloat mowang_dafeiyupet_tailX;
@property(nonatomic) BOOL mowang_dafeiyupet_tailOnTop;
@property(nonatomic,copy) void (^mowang_dafeiyupet_contentChanged)(void);
- (CGFloat)mowang_dafeiyupet_bubbleHeightForWidth:(CGFloat)width;
- (void)mowang_dafeiyupet_cancel;
@end
