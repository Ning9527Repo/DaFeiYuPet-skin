#import <Foundation/Foundation.h>
#import "../Sources/MowangDaFeiYuPetAIProtocol.h"
#include <assert.h>
int main(void) { @autoreleasepool {
    NSArray *bases=@[@"https://example.com",@"https://example.com/v1/",@"https://example.com/v1/chat/completions",@"https://example.com/proxy",@"https://example.com/v1beta"];
    NSArray *paths=@[@"/v1/chat/completions",@"/v1/chat/completions",@"/v1/chat/completions",@"/proxy/v1/chat/completions",@"/v1beta/chat/completions"];
    for(NSUInteger i=0;i<bases.count;i++) assert([mowang_dafeiyupet_aiEndpoint(bases[i],NO,NO).path isEqual:paths[i]]);
    assert(!mowang_dafeiyupet_aiEndpoint(@"http://localhost:11434",YES,NO));
    assert([mowang_dafeiyupet_aiEndpoint(@"http://localhost:11434",YES,YES).path isEqual:@"/api/chat"]);
    assert([mowang_dafeiyupet_aiEndpoint(@"https://example.com/api/chat/",YES,NO).path isEqual:@"/api/chat"]);
    for(NSString *bad in @[@"https://user:secret@example.com",@"https://example.com?key=x",@"https://example.com#x",@"file:///tmp/x",@"invalid"]) assert(!mowang_dafeiyupet_aiEndpoint(bad,NO,YES));
    assert([mowang_dafeiyupet_aiAnswer(@{@"choices":@[@{@"message":@{@"content":@"hello"}}]},NO) isEqual:@"hello"]);
    assert([mowang_dafeiyupet_aiAnswer(@{@"message":@{@"content":@"ollama"}},YES) isEqual:@"ollama"]);
    for(id bad in @[@[],@{},@{@"choices":@1},@{@"choices":@[@1]},@{@"message":@{@"content":@" "}}]) assert(!mowang_dafeiyupet_aiAnswer(bad,NO));
    assert([mowang_dafeiyupet_modelsEndpoint(@"https://example.com/v1/chat/completions",NO,NO).path isEqual:@"/v1/models"]);
    assert([mowang_dafeiyupet_modelsEndpoint(@"http://localhost:11434/api/chat",YES,YES).path isEqual:@"/api/tags"]);
    assert(!mowang_dafeiyupet_modelsEndpoint(@"https://user:secret@example.com/v1",NO,NO));
    assert(!mowang_dafeiyupet_modelsEndpoint(@"http://localhost:11434",YES,NO));
    NSArray *models=mowang_dafeiyupet_modelNames(@{@"data":@[@{@"id":@" zeta "},@{@"id":@"alpha"},@{@"id":@"alpha"},@{@"id":@"bad\nname"},@{@"id":@7}]},NO);
    assert(([models isEqual:@[@"alpha",@"zeta"]]));
    assert([mowang_dafeiyupet_modelNames(@{@"models":@[@{@"name":@"llama:latest"}]},YES) isEqual:@[@"llama:latest"]]);
    assert(!mowang_dafeiyupet_modelNames(@{@"data":@"invalid"},NO).count);
    NSData *data=[NSData dataWithContentsOfFile:@"MowangDaFeiYuPetPrefs/Resources/MowangDaFeiYuPetRoot.plist"];
    assert([NSPropertyListSerialization propertyListWithData:data options:0 format:NULL error:nil]);
    puts("PASS AI protocol: endpoint normalization, HTTP opt-in, credential URL rejection, both response schemas, malformed data, settings plist");
} return 0; }
