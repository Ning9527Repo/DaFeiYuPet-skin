#import <Foundation/Foundation.h>
#import "../Sources/MowangDaFeiYuPetState.h"
#include <assert.h>
int main(void) { @autoreleasepool {
    NSDictionary *legacy=@{@"size":@180,@"aiURL":@"https://example.com",@"unknown":@7};
    NSDictionary *state=mowang_dafeiyupet_petState(legacy);
    assert([state[@"activeID"] isEqual:MowangDaFeiYuPetPrimaryID]);
    assert(![mowang_dafeiyupet_activePet(state)[@"memoryEnabled"] boolValue]);
    assert([mowang_dafeiyupet_effectivePreferences(legacy) isEqual:legacy]);
    NSMutableArray *history=[NSMutableArray new];
    for(int i=0;i<10;i++) { [history addObject:@{@"role":@"user",@"content":[NSString stringWithFormat:@"q%d",i]}]; [history addObject:@{@"role":@"assistant",@"content":@"a"}]; }
    NSArray *bounded=mowang_dafeiyupet_boundedHistory(history);
    assert(bounded.count==12 && [bounded[0][@"content"] isEqual:@"q4"]);
    assert(!mowang_dafeiyupet_boundedHistory(@[@1,@2]).count);
    assert(!mowang_dafeiyupet_boundedHistory(@[@{@"role":@"system",@"content":@"bad"},@{@"role":@"assistant",@"content":@"a"}]).count);
    state=mowang_dafeiyupet_updatingPet(state,MowangDaFeiYuPetPrimaryID,@{@"memoryEnabled":@YES,@"history":history,@"providerIdentity":@"provider-A",@"overrides":@{@"size":@220,@"aiURL":@"evil",@"enabled":@YES},@"futureField":@9});
    assert([mowang_dafeiyupet_activePet(state)[@"history"] count]==12);
    NSMutableDictionary *config=[legacy mutableCopy]; config[@"petState"]=state;
    NSDictionary *effective=mowang_dafeiyupet_effectivePreferences(config);
    assert([effective[@"size"] isEqual:@220] && [effective[@"aiURL"] isEqual:legacy[@"aiURL"]] && !effective[@"enabled"]);
    NSMutableDictionary *pets=[state[@"pets"] mutableCopy]; pets[@"other"]=@{@"memoryEnabled":@YES,@"history":bounded};
    NSMutableDictionary *multi=[state mutableCopy]; multi[@"pets"]=pets;
    NSDictionary *off=mowang_dafeiyupet_updatingPet(multi,MowangDaFeiYuPetPrimaryID,@{@"memoryEnabled":@NO});
    assert(!mowang_dafeiyupet_activePet(off)[@"history"] && !mowang_dafeiyupet_activePet(off)[@"providerIdentity"]);
    assert([off[@"pets"][@"other"] isEqual:pets[@"other"]]);
    assert([mowang_dafeiyupet_activePet(off)[@"futureField"] isEqual:@9]);
    assert(!mowang_dafeiyupet_updatingPet(state,@"missing",@{}));
    assert(!mowang_dafeiyupet_petState(@{@"petState":@{@"version":@99}}).count);
    assert(!mowang_dafeiyupet_activePet(@{}).count);
    assert([mowang_dafeiyupet_effectivePreferences(@{@"petState":@{@"version":@99},@"size":@180})[@"size"] isEqual:@180]);
    for(id bad in @[@1,@[],@{@"pets":@1,@"activeID":@4},@{@"pets":@{@"dafeiyu.primary":@2}}]) assert(mowang_dafeiyupet_petState(@{@"petState":bad})[@"activeID"]);
    NSData *data=[NSPropertyListSerialization dataWithPropertyList:state format:NSPropertyListBinaryFormat_v1_0 options:0 error:nil];
    assert([data writeToFile:@"build/pet-state-test.plist" atomically:YES]);
    NSDictionary *readback=[NSDictionary dictionaryWithContentsOfFile:@"build/pet-state-test.plist"];
    assert([readback isEqual:state]);
    puts("PASS pet state: stable migration, default privacy, 6-turn bounds, malformed data, safe overrides, per-pet isolation, opt-out deletion, future schema, binary plist roundtrip");
} return 0; }
