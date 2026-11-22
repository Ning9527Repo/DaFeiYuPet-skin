#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

int main(int argc, char *argv[]) {
    @autoreleasepool {
        if (argc != 3) return 2;
        UIImage *source = [UIImage imageWithContentsOfFile:[NSString stringWithUTF8String:argv[1]]];
        if (!source) return 3;
        CGSize size = CGSizeMake(30, 30);
        UIGraphicsBeginImageContextWithOptions(size, NO, 2.0);
        [source drawInRect:CGRectMake(0, 0, size.width, size.height)];
        UIImage *scaled = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        NSData *png = UIImagePNGRepresentation(scaled);
        if (!png || ![png writeToFile:[NSString stringWithUTF8String:argv[2]] atomically:YES]) return 4;
        return 0;
    }
}
