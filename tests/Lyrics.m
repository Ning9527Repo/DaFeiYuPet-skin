#import <Foundation/Foundation.h>
#import "../Sources/MowangDaFeiYuPetLyrics.h"
#include <stdio.h>

static void check(BOOL condition,NSString *reason) {
    if(!condition) { fprintf(stderr,"failed: %s\n",reason.UTF8String); exit(1); }
}
int main(void) {
    @autoreleasepool {
        NSArray *lines=mowang_dafeiyupet_parseLRC(@"[ar:demo]\n[offset:500]\n[00:01.50][00:05.00]首句\n[00:03.250]第二句\n[00:08]末句\n[99:99]无效\n[00:11.00]\n");
        check(lines.count==4,@"parsed timestamps");
        check(mowang_dafeiyupet_LRCLineAt(lines,1.99)==nil,@"before first line");
        check([mowang_dafeiyupet_LRCLineAt(lines,2.0) isEqual:@"首句"],@"offset and first line");
        check([mowang_dafeiyupet_LRCLineAt(lines,3.75) isEqual:@"第二句"],@"fractional timestamp");
        check([mowang_dafeiyupet_LRCLineAt(lines,5.5) isEqual:@"首句"],@"multiple timestamps");
        check([mowang_dafeiyupet_LRCLineAt(lines,8.5) isEqual:@"末句"],@"integer seconds");
        check(mowang_dafeiyupet_LRCLineAt(lines,-1)==nil,@"invalid position");
        check(mowang_dafeiyupet_parseLRC(@"[00:01.00]   ").count==0,@"empty line");
        puts("LRC timeline tests passed");
    }
    return 0;
}
