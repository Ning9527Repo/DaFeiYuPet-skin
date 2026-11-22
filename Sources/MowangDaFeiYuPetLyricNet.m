#import "MowangDaFeiYuPetLyricNet.h"
#import "MowangDaFeiYuPetLyricSource.h"
#import <QuartzCore/QuartzCore.h>
#import <os/log.h>

// Online lyric fetcher. Bounded, ephemeral, one in-flight request, identity-keyed
// cache and backoff. Never stores lyrics to disk and never runs in the Settings process.
@implementation MowangDaFeiYuPetLyricFetcher {
    NSURLSession *_session;
    NSString *_cachedIdentity, *_fetchingIdentity, *_failureIdentity;
    NSArray *_timeline;
    NSTimeInterval _nextRetry;
    NSUInteger _generation;
}
- (instancetype)init {
    if(!(self=[super init])) return nil;
    NSURLSessionConfiguration *config=NSURLSessionConfiguration.ephemeralSessionConfiguration;
    config.timeoutIntervalForRequest=12; config.timeoutIntervalForResource=15;
    config.URLCache=nil; config.HTTPCookieStorage=nil; config.URLCredentialStorage=nil;
    config.requestCachePolicy=NSURLRequestReloadIgnoringLocalCacheData;
    _session=[NSURLSession sessionWithConfiguration:config];
    return self;
}
- (void)dealloc { [_session invalidateAndCancel]; }
- (void)clear { _timeline=nil; _cachedIdentity=nil; _failureIdentity=nil; _fetchingIdentity=nil; _nextRetry=0; }
- (NSString *)identityForInfo:(NSDictionary *)info {
    id title=info[@"kMRMediaRemoteNowPlayingInfoTitle"], artist=info[@"kMRMediaRemoteNowPlayingInfoArtist"], duration=info[@"kMRMediaRemoteNowPlayingInfoDuration"];
    if(![title isKindOfClass:NSString.class] || ![(NSString *)title length]) return nil;
    NSString *hash=[NSString stringWithFormat:@"%@|%@|%.1f",title,[artist isKindOfClass:NSString.class]?artist:@"",[duration isKindOfClass:NSNumber.class]?[duration doubleValue]:0];
    return hash.length>260?nil:hash;
}
- (void)startFetch:(NSString *)identity info:(NSDictionary *)info {
    if(!identity || [_fetchingIdentity isEqual:identity]) return;
    CFTimeInterval now=CACurrentMediaTime();
    if([_failureIdentity isEqual:identity] && now<_nextRetry) return;
    id title=info[@"kMRMediaRemoteNowPlayingInfoTitle"], artist=info[@"kMRMediaRemoteNowPlayingInfoArtist"], duration=info[@"kMRMediaRemoteNowPlayingInfoDuration"];
    double durationValue=[duration isKindOfClass:NSNumber.class]?[duration doubleValue]:0;
    NSURL *url=mowang_dafeiyupet_lyricSearchURL(title,artist);
    if(!url) { if(self.onStatus) self.onStatus(@"歌词：标题无效，无法搜索"); return; }
    if(self.onStatus) self.onStatus(@"歌词：正在搜索…");
    _fetchingIdentity=identity;
    NSUInteger generation=++_generation;
    __weak typeof(self) weak=self;
    NSMutableURLRequest *request=[NSMutableURLRequest requestWithURL:url];
    [request setValue:@"DaFeiYuPet-Minis/1.0" forHTTPHeaderField:@"User-Agent"];
    [[_session dataTaskWithRequest:request completionHandler:^(NSData *data,NSURLResponse *response,NSError *error) {
        dispatch_async(dispatch_get_main_queue(),^{
            typeof(self) self=weak; if(!self || generation!=self->_generation) return;
            self->_fetchingIdentity=nil;
            NSInteger status=[response isKindOfClass:NSHTTPURLResponse.class]?((NSHTTPURLResponse *)response).statusCode:0;
            if(error || status!=200 || !data || data.length>1<<20) {
                self->_failureIdentity=identity; self->_nextRetry=CACurrentMediaTime()+60;
                os_log(os_log_create("com.mowang.dafeiyupet","lyrics"),"Network lyric fetch failed status=%ld",(long)status);
                if(self.onStatus) self.onStatus(@"歌词：在线获取失败，请检查网络");
                return;
            }
            id json=[NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            NSArray *timeline=mowang_dafeiyupet_pickLyricTimeline(json,title,artist,durationValue);
            if(!timeline.count) {
                self->_failureIdentity=identity; self->_nextRetry=CACurrentMediaTime()+120;
                os_log(os_log_create("com.mowang.dafeiyupet","lyrics"),"No synced lyrics found");
                if(self.onStatus) self.onStatus(@"歌词：未找到该歌曲的同步歌词");
                return;
            }
            self->_cachedIdentity=identity; self->_timeline=timeline; self->_failureIdentity=nil;
            os_log(os_log_create("com.mowang.dafeiyupet","lyrics"),"Lyrics cached for %{public}@",identity);
            if(self.onReady) self.onReady();
        });
    }] resume];
}
- (NSString *)lineForInfo:(NSDictionary *)info playing:(BOOL)playing wallNow:(NSTimeInterval)wallNow {
    if(![info isKindOfClass:NSDictionary.class]) return nil;
    NSString *identity=[self identityForInfo:info];
    if(!identity) return nil;
    if([identity isEqual:_cachedIdentity] && _timeline.count) {
        NSDictionary *song=@{@"title":info[@"kMRMediaRemoteNowPlayingInfoTitle"],
                             @"artist":info[@"kMRMediaRemoteNowPlayingInfoArtist"],
                             @"duration":info[@"kMRMediaRemoteNowPlayingInfoDuration"],
                             @"timeline":_timeline};
        return mowang_dafeiyupet_matchedLine(song,info,wallNow,playing);
    }
    [self startFetch:identity info:info];
    return nil;
}
@end
