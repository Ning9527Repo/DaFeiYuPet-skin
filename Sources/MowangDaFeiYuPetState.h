#pragma once
#import <Foundation/Foundation.h>

// The legacy single pet always migrates to this stable logical identity.
static NSString * const MowangDaFeiYuPetPrimaryID = @"dafeiyu.primary";
static inline NSArray *mowang_dafeiyupet_boundedHistory(id raw) {
    if(![raw isKindOfClass:NSArray.class]) return @[];
    NSMutableArray *result=[NSMutableArray new];
    // Only complete valid user/assistant pairs can become provider context.
    for(NSUInteger i=0;i+1<[raw count];i+=2) {
        id u=raw[i], a=raw[i+1];
        if(![u isKindOfClass:NSDictionary.class] || ![a isKindOfClass:NSDictionary.class]) continue;
        id ut=u[@"content"], at=a[@"content"];
        if(![u[@"role"] isEqual:@"user"] || ![a[@"role"] isEqual:@"assistant"] ||
           ![ut isKindOfClass:NSString.class] || ![at isKindOfClass:NSString.class] ||
           ![ut length] || [ut length]>2048 || ![at length] || [at length]>8194) continue;
        [result addObject:@{@"role":@"user",@"content":ut}];
        [result addObject:@{@"role":@"assistant",@"content":at}];
        if(result.count>12) [result removeObjectsInRange:NSMakeRange(0,2)];
    }
    return result;
}
static inline NSDictionary *mowang_dafeiyupet_petState(NSDictionary *preferences) {
    id raw=preferences[@"petState"];
    NSMutableDictionary *state=[raw isKindOfClass:NSDictionary.class]?[raw mutableCopy]:[NSMutableDictionary new];
    // Do not reinterpret an unknown future schema.
    if(state[@"version"] && ![state[@"version"] isEqual:@1]) return @{};
    id rawPets=state[@"pets"];
    NSMutableDictionary *pets=[rawPets isKindOfClass:NSDictionary.class]?[rawPets mutableCopy]:[NSMutableDictionary new];
    id primary=pets[MowangDaFeiYuPetPrimaryID];
    if(![primary isKindOfClass:NSDictionary.class]) pets[MowangDaFeiYuPetPrimaryID]=@{@"name":@"大肥鱼",@"overrides":@{},@"memoryEnabled":@NO};
    NSString *active=state[@"activeID"];
    if(![active isKindOfClass:NSString.class] || ![pets[active] isKindOfClass:NSDictionary.class]) active=MowangDaFeiYuPetPrimaryID;
    state[@"version"]=@1; state[@"pets"]=pets; state[@"activeID"]=active;
    return state;
}
static inline NSDictionary *mowang_dafeiyupet_activePet(NSDictionary *state) {
    id pets=state[@"pets"], active=state[@"activeID"];
    if(![pets isKindOfClass:NSDictionary.class] || ![active isKindOfClass:NSString.class]) return @{};
    id pet=pets[active]; return [pet isKindOfClass:NSDictionary.class]?pet:@{};
}
static inline NSDictionary *mowang_dafeiyupet_effectivePreferences(NSDictionary *preferences) {
    NSMutableDictionary *result=[preferences mutableCopy];
    id overrides=mowang_dafeiyupet_activePet(mowang_dafeiyupet_petState(preferences))[@"overrides"];
    if([overrides isKindOfClass:NSDictionary.class]) {
        // Credentials, endpoints, global visibility and timer state are never overridden.
        for(NSString *key in @[@"size",@"opacity",@"gravity",@"restitution",@"groundFriction",@"throwPower",@"roam",@"actionInterval",@"mood"])
            if([overrides[key] isKindOfClass:NSNumber.class] || [overrides[key] isKindOfClass:NSString.class]) result[key]=overrides[key];
    }
    return result;
}
static inline NSDictionary *mowang_dafeiyupet_updatingPet(NSDictionary *state, NSString *identifier, NSDictionary *changes) {
    if(![state[@"version"] isEqual:@1] || !identifier.length || ![state[@"pets"] isKindOfClass:NSDictionary.class]) return nil;
    id current=state[@"pets"][identifier];
    if(![current isKindOfClass:NSDictionary.class]) return nil;
    NSMutableDictionary *pet=[current mutableCopy]; [pet addEntriesFromDictionary:changes];
    id enabled=pet[@"memoryEnabled"];
    BOOL keep=[enabled isKindOfClass:NSNumber.class] && [enabled boolValue];
    pet[@"memoryEnabled"]=@(keep);
    if(keep) pet[@"history"]=mowang_dafeiyupet_boundedHistory(pet[@"history"]);
    else { [pet removeObjectForKey:@"history"]; [pet removeObjectForKey:@"providerIdentity"]; }
    NSMutableDictionary *pets=[state[@"pets"] mutableCopy]; pets[identifier]=pet;
    NSMutableDictionary *updated=[state mutableCopy]; updated[@"pets"]=pets; return updated;
}
