#pragma once
#import <Foundation/Foundation.h>
#import <float.h>
#import "MowangDaFeiYuPetLyrics.h"

// Pure, offline-testable selection from lrclib JSON search results.
// Returns a parsed LRC timeline or nil. Prefers a non-instrumental track with synced
// lyrics whose duration is closest to the now-playing duration.
static __attribute__((unused)) NSArray *mowang_dafeiyupet_pickLyricTimeline(id json, NSString *title, NSString *artist, double duration) {
    if(![json isKindOfClass:NSArray.class]) return nil;
    double bestPenalty=DBL_MAX; NSArray *best=nil;
    for(id row in json) {
        if(![row isKindOfClass:NSDictionary.class]) continue;
        if([row[@"instrumental"] boolValue]) continue;
        id synced=row[@"syncedLyrics"];
        if(![synced isKindOfClass:NSString.class] || ![(NSString *)synced length]) continue;
        id dur=row[@"duration"];
        if(![dur isKindOfClass:NSNumber.class] || !isfinite([dur doubleValue])) continue;
        double penalty=fabs([dur doubleValue]-duration);
        if(penalty<bestPenalty) {
            NSArray *timeline=mowang_dafeiyupet_parseLRC(synced);
            if(timeline.count) { bestPenalty=penalty; best=timeline; }
        }
    }
    return best;
}

static __attribute__((unused)) NSURL *mowang_dafeiyupet_lyricSearchURL(NSString *title, NSString *artist) {
    if(![title isKindOfClass:NSString.class] || ![(NSString *)title length] || [(NSString *)title length]>200) return nil;
    NSURLComponents *components=[NSURLComponents componentsWithString:@"https://lrclib.net/api/search"];
    NSMutableArray *items=[NSMutableArray array];
    [items addObject:[NSURLQueryItem queryItemWithName:@"track_name" value:title]];
    if([artist isKindOfClass:NSString.class] && artist.length) [items addObject:[NSURLQueryItem queryItemWithName:@"artist_name" value:artist]];
    components.queryItems=items;
    return components.URL;
}

// Bounded online lyric fetcher: identity-keyed memory cache, one in-flight request,
// backoff on failure, ephemeral session. Never persists lyrics.
@interface MowangDaFeiYuPetLyricFetcher : NSObject
@property(nonatomic,copy) void (^onReady)(void);
@property(nonatomic,copy) void (^onStatus)(NSString *status);
- (NSString *)lineForInfo:(NSDictionary *)info playing:(BOOL)playing wallNow:(NSTimeInterval)wallNow;
- (void)clear;
@end
