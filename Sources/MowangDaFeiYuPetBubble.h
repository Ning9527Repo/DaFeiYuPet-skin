#import <UIKit/UIKit.h>

@interface MowangDaFeiYuPetBubble : UILabel
@property(nonatomic) CGFloat mowang_dafeiyupet_tailX;
@property(nonatomic) BOOL mowang_dafeiyupet_tailOnTop;
@end

@implementation MowangDaFeiYuPetBubble
- (void)drawRect:(CGRect)rect {
    CGFloat h=self.bounds.size.height, w=self.bounds.size.width;
    CGRect body=CGRectMake(0,self.mowang_dafeiyupet_tailOnTop?7:0,w,h-7);
    UIBezierPath *path=[UIBezierPath bezierPathWithRoundedRect:CGRectInset(body,.5,.5) cornerRadius:14];
    CGFloat x=MAX(20,MIN(w-20,self.mowang_dafeiyupet_tailX));
    CGFloat y=self.mowang_dafeiyupet_tailOnTop?7:h-7;
    [path moveToPoint:CGPointMake(x-6,y)];
    [path addLineToPoint:CGPointMake(x,self.mowang_dafeiyupet_tailOnTop?0:h)];
    [path addLineToPoint:CGPointMake(x+6,y)]; [path closePath];
    [[UIColor colorWithWhite:1 alpha:.97] setFill]; [path fill];
    [super drawRect:rect];
}
- (void)drawTextInRect:(CGRect)rect {
    rect=UIEdgeInsetsInsetRect(rect,UIEdgeInsetsMake(self.mowang_dafeiyupet_tailOnTop?15:8,12,self.mowang_dafeiyupet_tailOnTop?8:15,12));
    [super drawTextInRect:rect];
}
@end
