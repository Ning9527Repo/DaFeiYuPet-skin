#pragma once
#import <Foundation/Foundation.h>
#import "MowangDaFeiYuPetLyrics.h"
#include <math.h>

// A single explicitly imported song; no scanning of another app's container.
// The caller supplies a readable local plist with title, artist, duration and lrc.
// A single explicitly imported song; no scanning of another app's container.
// The caller supplies a readable local plist with title, artist, duration and lrc.
static __attribute__((unused)) NSDictionary *mowang_dafeiyupet_localLyric(NSString *path) {
    NSDictionary *attributes=[[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil];
    if(![attributes[NSFileType] isEqual:NSFileTypeRegular] || [attributes[NSFileSize] unsignedLongLongValue]>600000) return nil;
    NSData *data=[NSData dataWithContentsOfFile:path options:NSDataReadingMappedIfSafe error:nil];
    if(!data || data.length>600000) return nil;
    id value=[NSPropertyListSerialization propertyListWithData:data options:NSPropertyListImmutable format:NULL error:nil];
    if(![value isKindOfClass:NSDictionary.class]) return nil;
    NSDictionary *song=value;
    NSString *title=song[@"title"], *artist=song[@"artist"], *lrc=song[@"lrc"];
    NSNumber *duration=song[@"duration"];
    if(![title isKindOfClass:NSString.class] || !title.length || title.length>200 ||
       ![artist isKindOfClass:NSString.class] || !artist.length || artist.length>200 ||
       ![duration isKindOfClass:NSNumber.class] || !isfinite(duration.doubleValue) || duration.doubleValue<=0 || duration.doubleValue>21600 ||
       ![lrc isKindOfClass:NSString.class] || lrc.length>524288) return nil;
    NSArray *timeline=mowang_dafeiyupet_parseLRC(lrc);
    return timeline.count?@{@"title":title,@"artist":artist,@"duration":duration,@"timeline":timeline}:nil;
}

// Fail closed on stale / unknown metadata. The timestamp is absolute wall-clock
// seconds as observed by the verified isolated query, NOT monotonic media time.
static NSString *mowang_dafeiyupet_matchedLine(NSDictionary *song,NSDictionary *info, NSTimeInterval wallNow, BOOL playing) {
    if(!playing || !song || ![info isKindOfClass:NSDictionary.class]) return nil;
    id title=info[@"kMRMediaRemoteNowPlayingInfoTitle"], artist=info[@"kMRMediaRemoteNowPlayingInfoArtist"], duration=info[@"kMRMediaRemoteNowPlayingInfoDuration"];
    id elapsed=info[@"kMRMediaRemoteNowPlayingInfoElapsedTime"], timestamp=info[@"kMRMediaRemoteNowPlayingInfoTimestamp"];
    id rate=info[@"kMRMediaRemoteNowPlayingInfoPlaybackRate"];
    if(![title isKindOfClass:NSString.class] || ![artist isKindOfClass:NSString.class] ||
       ![duration isKindOfClass:NSNumber.class] || ![elapsed isKindOfClass:NSNumber.class] ||
       ![timestamp isKindOfClass:NSDate.class] || ![rate isKindOfClass:NSNumber.class] ||
       ![title isEqual:song[@"title"]] || ![artist isEqual:song[@"artist"]] ||
       !isfinite([duration doubleValue]) || fabs([duration doubleValue]-[song[@"duration"] doubleValue])>2 ||
       !isfinite([elapsed doubleValue]) || !isfinite([timestamp timeIntervalSince1970]) || !isfinite([rate doubleValue]) ||
       [rate doubleValue]<0.5 || [rate doubleValue]>2 || !isfinite(wallNow) ||
       wallNow-[timestamp timeIntervalSince1970]<-2 || wallNow-[timestamp timeIntervalSince1970]>8) return nil;
    double position=[elapsed doubleValue]+MAX(0,wallNow-[timestamp timeIntervalSince1970])*[rate doubleValue];
    if(position<0 || position>[duration doubleValue]+2) return nil;
    return mowang_dafeiyupet_LRCLineAt(song[@"timeline"],position);
}
