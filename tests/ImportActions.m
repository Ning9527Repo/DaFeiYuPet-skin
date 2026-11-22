#import <Foundation/Foundation.h>
#import <ImageIO/ImageIO.h>
#import <CommonCrypto/CommonDigest.h>
int main(void) { @autoreleasepool {
 NSString *root=NSProcessInfo.processInfo.environment[@"APELIN_PROJECT_ROOT"]; if(!root.length) return 2;
 NSString *base=[root stringByAppendingPathComponent:@"layout/Library/Application Support/MowangDaFeiYuPet"];
 NSString *folder=[base stringByAppendingPathComponent:@"animations"];
 [NSFileManager.defaultManager createDirectoryAtPath:folder withIntermediateDirectories:YES attributes:nil error:nil];
 NSString *tsv=[NSString stringWithContentsOfFile:[root stringByAppendingPathComponent:@"Assets/actions.tsv"] encoding:NSUTF8StringEncoding error:nil];
 NSMutableArray *catalog=[NSMutableArray array];
 for(NSString *line in [tsv componentsSeparatedByCharactersInSet:NSCharacterSet.newlineCharacterSet]) { @autoreleasepool {
 NSArray *c=[line componentsSeparatedByString:@"\t"]; if(c.count!=3) continue;
 NSString *key=c[2], *path=[folder stringByAppendingPathComponent:[key stringByAppendingString:@".gif"]];
 NSData *data=[NSData dataWithContentsOfFile:path];
 if(!data) { NSString *url=[NSString stringWithFormat:@"https://raw.githubusercontent.com/C2006L/dafeiyu/7ca2bb30f977e01c52198e27cff1e9264c92c755/dsh-pet-ref/dsh-pet/assets/preview/%@.gif",key];
 data=[NSData dataWithContentsOfURL:[NSURL URLWithString:url]];
 if(!data || ![data writeToFile:path atomically:YES]) { fprintf(stderr,"download failed %s\n",key.UTF8String); return 3; } }
 CGImageSourceRef src=CGImageSourceCreateWithData((__bridge CFDataRef)data,NULL);
 size_t count=src?CGImageSourceGetCount(src):0; if(!count || count>1000) return 4;
 NSMutableArray *times=[NSMutableArray array];
 for(size_t i=0;i<count;i++) { @autoreleasepool {
 CGImageRef image=CGImageSourceCreateImageAtIndex(src,i,NULL); if(!image) return 5;
 if(CGImageGetWidth(image)>1024 || CGImageGetHeight(image)>1024) return 6;
 CGImageRelease(image);
 NSDictionary *props=CFBridgingRelease(CGImageSourceCopyPropertiesAtIndex(src,i,NULL));
 NSDictionary *gif=props[(NSString *)kCGImagePropertyGIFDictionary];
 double delay=[gif[(NSString *)kCGImagePropertyGIFUnclampedDelayTime] doubleValue]; if(delay<=0) delay=[gif[(NSString *)kCGImagePropertyGIFDelayTime] doubleValue];
 [times addObject:@(MAX(.02,delay))];
 } }
 CFRelease(src); unsigned char digest[CC_SHA256_DIGEST_LENGTH]; CC_SHA256(data.bytes,(CC_LONG)data.length,digest); NSMutableString *hash=[NSMutableString string]; for(int i=0;i<CC_SHA256_DIGEST_LENGTH;i++) [hash appendFormat:@"%02x",digest[i]];
 [catalog addObject:@{@"id":key,@"category":c[0],@"title":c[1],@"durations":times,@"sha256":hash}];
 printf("%lu %s %zu frames\n",(unsigned long)catalog.count,key.UTF8String,count); fflush(stdout);
 } }
 if(catalog.count!=106) return 7;
 if(![catalog writeToFile:[base stringByAppendingPathComponent:@"catalog.plist"] atomically:YES]) return 8;
 puts("PASS: 106 animations, every frame decoded"); return 0;
} }
