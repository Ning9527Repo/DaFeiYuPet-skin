#pragma once
#import <Foundation/Foundation.h>

static inline NSURL *mowang_dafeiyupet_aiEndpoint(NSString *base, BOOL ollama, BOOL allowHTTP) {
    if (![base isKindOfClass:NSString.class] || base.length>2048) return nil;
    NSURLComponents *c=[NSURLComponents componentsWithString:[base stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]];
    BOOL https=[c.scheme.lowercaseString isEqual:@"https"];
    if ((!https && !(allowHTTP && [c.scheme.lowercaseString isEqual:@"http"])) || !c.host.length || c.user || c.password || c.query || c.fragment) return nil;
    NSString *path=c.path ?: @"";
    while ([path hasSuffix:@"/"]) path=[path substringToIndex:path.length-1];
    if (ollama) {
        if (![path hasSuffix:@"/api/chat"]) path=[path stringByAppendingString:@"/api/chat"];
    } else if (![path hasSuffix:@"/chat/completions"]) {
        NSRegularExpression *version=[NSRegularExpression regularExpressionWithPattern:@"/v[0-9]+(?:beta)?$" options:NSRegularExpressionCaseInsensitive error:nil];
        if (![version firstMatchInString:path options:0 range:NSMakeRange(0,path.length)]) path=[path stringByAppendingString:@"/v1"];
        path=[path stringByAppendingString:@"/chat/completions"];
    }
    c.path=path;
    return c.URL;
}
static inline NSURL *mowang_dafeiyupet_modelsEndpoint(NSString *base, BOOL ollama, BOOL allowHTTP) {
    NSURL *chat=mowang_dafeiyupet_aiEndpoint(base,ollama,allowHTTP);
    if(!chat) return nil;
    NSURLComponents *c=[NSURLComponents componentsWithURL:chat resolvingAgainstBaseURL:NO];
    NSString *suffix=ollama?@"/api/chat":@"/chat/completions";
    if(![c.path hasSuffix:suffix]) return nil;
    c.path=[[c.path substringToIndex:c.path.length-suffix.length] stringByAppendingString:ollama?@"/api/tags":@"/models"];
    return c.URL;
}
static inline NSArray<NSString *> *mowang_dafeiyupet_modelNames(id json, BOOL ollama) {
    if(![json isKindOfClass:NSDictionary.class]) return @[];
    id entries=json[ollama?@"models":@"data"];
    if(![entries isKindOfClass:NSArray.class]) return @[];
    NSMutableSet<NSString *> *names=[NSMutableSet set];
    for(id entry in entries) {
        if(![entry isKindOfClass:NSDictionary.class]) continue;
        id raw=entry[ollama?@"name":@"id"];
        if(![raw isKindOfClass:NSString.class]) continue;
        NSString *name=[raw stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if(name.length && name.length<=128 && [name rangeOfCharacterFromSet:NSCharacterSet.controlCharacterSet].location==NSNotFound) [names addObject:name];
        if(names.count>=200) break;
    }
    return [[names allObjects] sortedArrayUsingSelector:@selector(localizedStandardCompare:)];
}
static inline NSString *mowang_dafeiyupet_aiAnswer(id json, BOOL ollama) {
    if (![json isKindOfClass:NSDictionary.class]) return nil;
    id message=nil;
    if (ollama) message=json[@"message"];
    else {
        id choices=json[@"choices"];
        id first=[choices isKindOfClass:NSArray.class]?[choices firstObject]:nil;
        if ([first isKindOfClass:NSDictionary.class]) message=first[@"message"];
    }
    id content=[message isKindOfClass:NSDictionary.class]?message[@"content"]:nil;
    if (![content isKindOfClass:NSString.class]) return nil;
    NSString *text=[content stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    return text.length?text:nil;
}
