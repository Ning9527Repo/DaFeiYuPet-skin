#import <Foundation/Foundation.h>
#import <zlib.h>
#include <stdio.h>
#include <ctype.h>
static void inspect(NSData *data,const char *kind) {
 const unsigned char *p=data.bytes; NSUInteger n=data.length; int tags=0,enhanced=0;
 for(NSUInteger i=0;i+6<n;i++) {
   if(p[i]=='[' && isdigit(p[i+1])&&isdigit(p[i+2])&&p[i+3]==':'&&isdigit(p[i+4])&&isdigit(p[i+5])&&(p[i+6]=='.'||p[i+6]==']')) tags++;
   if(p[i]=='<' && isdigit(p[i+1])&&isdigit(p[i+2])&&p[i+3]==':'&&isdigit(p[i+4])&&isdigit(p[i+5])&&(p[i+6]=='.'||p[i+6]=='>')) enhanced++;
 }
 printf("%s bytes=%lu LRC-tags=%d enhanced-tags=%d first-magic=",kind,(unsigned long)n,tags,enhanced);
 for(NSUInteger i=0;i<MIN(n,8);i++) printf("%02x",p[i]); puts("");
}
int main(int argc,char **argv) { @autoreleasepool {
 if(argc!=2) return 2;
 NSData *raw=[NSData dataWithContentsOfFile:[NSString stringWithUTF8String:argv[1]] options:0 error:nil]; if(!raw||raw.length>1048576) return 3;
 NSData *decoded=[[NSData alloc] initWithBase64EncodedData:raw options:NSDataBase64DecodingIgnoreUnknownCharacters]; if(!decoded) return 4;
 inspect(decoded,"base64");
 const unsigned char *p=decoded.bytes;
 for(NSUInteger offset=0;offset<MIN(decoded.length,64);offset++) {
   if(p[offset]!=0x78) continue;
   uLongf outSize=1048576; NSMutableData *out=[NSMutableData dataWithLength:outSize];
   int result=uncompress(out.mutableBytes,&outSize,p+offset,(uLong)(decoded.length-offset));
   if(result==Z_OK) { out.length=outSize; inspect(out,"zlib"); printf("zlib-offset=%lu\n",(unsigned long)offset); }
 }
 return 0;
} }
