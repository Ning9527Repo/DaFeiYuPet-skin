#import <Foundation/Foundation.h>
#import "../Sources/MowangDaFeiYuPetLyricSource.h"
#include <stdio.h>
static void check(BOOL ok,const char *reason) { if(!ok) { fprintf(stderr,"failed: %s\n",reason); exit(1); } }
int main(void) { @autoreleasepool {
    NSDictionary *song=@{@"title":@"示例",@"artist":@"歌手",@"duration":@60,@"timeline":mowang_dafeiyupet_parseLRC(@"[00:01.00]甲\n[00:04.00]乙")};
    NSDate *stamp=[NSDate dateWithTimeIntervalSince1970:100];
    NSDictionary *fields=@{@"kMRMediaRemoteNowPlayingInfoTitle":@"示例",@"kMRMediaRemoteNowPlayingInfoArtist":@"歌手",@"kMRMediaRemoteNowPlayingInfoDuration":@60,@"kMRMediaRemoteNowPlayingInfoElapsedTime":@2,@"kMRMediaRemoteNowPlayingInfoTimestamp":stamp,@"kMRMediaRemoteNowPlayingInfoPlaybackRate":@1};
    check([mowang_dafeiyupet_matchedLine(song,fields,101,YES) isEqual:@"甲"],"matching line");
    check([mowang_dafeiyupet_matchedLine(song,fields,103,YES) isEqual:@"乙"],"seeked timeline");
    check(mowang_dafeiyupet_matchedLine(song,fields,103,NO)==nil,"paused");
    check(mowang_dafeiyupet_matchedLine(song,fields,110,YES)==nil,"stale timestamp");
    NSMutableDictionary *different=[fields mutableCopy]; different[@"kMRMediaRemoteNowPlayingInfoTitle"]=@"另一首";
    check(mowang_dafeiyupet_matchedLine(song,different,101,YES)==nil,"track change");
    different=[fields mutableCopy]; different[@"kMRMediaRemoteNowPlayingInfoTimestamp"]=@100;
    check(mowang_dafeiyupet_matchedLine(song,different,101,YES)==nil,"unknown timestamp type");
    NSString *path=@"build/lyric-source-fixture.plist";
    NSDictionary *imported=@{@"title":@"示例",@"artist":@"歌手",@"duration":@60,@"lrc":@"[00:01.00]甲\n[00:04.00]乙"};
    check([imported writeToFile:path atomically:YES],"write fixture");
    check([mowang_dafeiyupet_matchedLine(mowang_dafeiyupet_localLyric(path),fields,101,YES) isEqual:@"甲"],"imported timeline");
    [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
    puts("Local lyric source tests passed");
} return 0; }
