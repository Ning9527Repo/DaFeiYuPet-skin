#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>
int main(int argc,char **argv){ @autoreleasepool {
 if(argc!=3)return 2;
 NSURL *url=[NSURL fileURLWithPath:[NSString stringWithUTF8String:argv[1]]];
 AVURLAsset *asset=[AVURLAsset URLAssetWithURL:url options:nil];
 double duration=CMTimeGetSeconds(asset.duration);
 if(!isfinite(duration)||duration<=0){fprintf(stderr,"Invalid duration\n");return 3;}
 AVAssetImageGenerator *gen=[[AVAssetImageGenerator alloc]initWithAsset:asset];
 gen.appliesPreferredTrackTransform=YES;gen.maximumSize=CGSizeMake(640,640);
 fprintf(stdout,"duration %.3fs\n",duration);
 UIGraphicsBeginImageContextWithOptions(CGSizeMake(1280,960),YES,1);
 [[UIColor whiteColor]setFill];UIRectFill(CGRectMake(0,0,1280,960));
 int count=0;
 for(int i=0;i<16;i++){@autoreleasepool{
 double t=duration*i/16.0; NSError *err=nil;
 CGImageRef cg=[gen copyCGImageAtTime:CMTimeMakeWithSeconds(t,600) actualTime:NULL error:&err];
 if(!cg){fprintf(stderr,"frame %.2f: %s\n",t,err.description.UTF8String);continue;}
 UIImage *im=[UIImage imageWithCGImage:cg];CGImageRelease(cg);
 CGFloat x=(i%4)*320,y=(i/4)*240;
 CGFloat scale=MIN(316/im.size.width,214/im.size.height);
 [im drawInRect:CGRectMake(x+(320-im.size.width*scale)/2,y,im.size.width*scale,im.size.height*scale)];
 [[NSString stringWithFormat:@"%.2fs",t]drawAtPoint:CGPointMake(x+6,y+218) withAttributes:@{NSFontAttributeName:[UIFont systemFontOfSize:15],NSForegroundColorAttributeName:UIColor.blackColor}];count++;
 }}
 UIImage *sheet=UIGraphicsGetImageFromCurrentImageContext();UIGraphicsEndImageContext();
 BOOL ok=[UIImageJPEGRepresentation(sheet,.9) writeToFile:[NSString stringWithUTF8String:argv[2]] atomically:YES];
 fprintf(stdout,"frames %d, output %s\n",count,ok?"ok":"failed");return (ok&&count)?0:4;
}}
