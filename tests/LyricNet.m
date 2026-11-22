// Offline tests for lyric network selection + existing LRC parser integration.
// No network request is made; fixtures are literal JSON.
#import "../Sources/MowangDaFeiYuPetLyricNet.h"
#import "../Sources/MowangDaFeiYuPetLyrics.h"
#include <assert.h>

static NSArray *searchResult(void) {
    return @[
        @{@"id":@1,@"trackName":@"半壶纱",@"artistName":@"刘珂矣",@"duration":@250.0,@"instrumental":@NO,
          @"syncedLyrics":@"[00:01.00]第一句\n[00:05.00]第二句"},
        @{@"id":@2,@"trackName":@"半壶纱",@"artistName":@"刘珂矣",@"duration":@302.0,@"instrumental":@NO,
          @"syncedLyrics":@"[00:02.00]第二首采样\n[00:09.00]更接近"},
        @{@"id":@3,@"trackName":@"半壶纱",@"artistName":@"刘珂矣",@"duration":@240.0,@"instrumental":@YES,
          @"syncedLyrics":@"[00:01.00]纯音乐"},
        @{@"id":@4,@"trackName":@"半壶纱",@"artistName":@"刘珂矣",@"duration":@180.0,@"instrumental":@NO,
          @"plainLyrics":@"没有时间轴"},
    ];
}
int main(void) { @autoreleasepool {
    NSURL *url=mowang_dafeiyupet_lyricSearchURL(@"半壶纱",@"刘珂矣");
    assert(url);
    NSString *queried=url.query;
    assert([queried containsString:@"track_name=%E5%8D%8A%E5%A3%B6%E7%BA%B1"]);
    assert([queried containsString:@"artist_name=%E5%88%98%E7%8F%82%E7%9F%A3"]);
    assert(!mowang_dafeiyupet_lyricSearchURL(@"",@"x"));
    assert(!mowang_dafeiyupet_lyricSearchURL((id)@1,@"x"));
    // Instrumental and plain-only rows are rejected; nearest non-instrumental synced row wins.
    NSArray *timeline=mowang_dafeiyupet_pickLyricTimeline(searchResult(),@"半壶纱",@"刘珂矣",251.0);
    assert(timeline.count==2);
    assert([timeline[0][@"text"] isEqual:@"第一句"]);   // 250 is nearest to 251
    // Binary search boundaries: before first line -> nil; inside first line -> first line; after -> last.
    assert(!mowang_dafeiyupet_LRCLineAt(timeline,0.5));
    assert([mowang_dafeiyupet_LRCLineAt(timeline,1.0) isEqual:@"第一句"]);
    assert([mowang_dafeiyupet_LRCLineAt(timeline,5.0) isEqual:@"第二句"]);
    assert([mowang_dafeiyupet_LRCLineAt(timeline,99.0) isEqual:@"第二句"]);
    assert(!mowang_dafeiyupet_LRCLineAt(timeline,-1));
    // Garbage / empty inputs fail closed.
    assert(!mowang_dafeiyupet_pickLyricTimeline(@[],@"a",@"b",100));
    assert(!mowang_dafeiyupet_pickLyricTimeline(@"",@"a",@"b",100));
    // All-instrumental list yields nil.
    NSArray *onlyInstrumental=@[@{@"id":@9,@"duration":@200.0,@"instrumental":@YES,@"syncedLyrics":@"[00:01.00]x"}];
    assert(!mowang_dafeiyupet_pickLyricTimeline(onlyInstrumental,@"a",@"b",200));
    puts("PASS lyric selection: URL encoding, instrumental/plain rejection, nearest-duration synced timeline, LRC boundaries");
    return 0;
} }
