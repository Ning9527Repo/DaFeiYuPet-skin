#include <stdio.h>
#include <stdlib.h>
#include <ctype.h>
#include <string.h>

int main(int argc,char **argv) {
    if(argc!=2) return 2;
    FILE *f=fopen(argv[1],"rb"); if(!f) return 3;
    if(fseek(f,0,SEEK_END)) { fclose(f); return 4; }
    long n=ftell(f); if(n<0 || n>1048576 || fseek(f,0,SEEK_SET)) { fclose(f); return 5; }
    unsigned char *p=calloc((size_t)n+1,1); if(!p) { fclose(f); return 6; }
    if(fread(p,1,(size_t)n,f)!=(size_t)n) { free(p); fclose(f); return 7; }
    fclose(f);
    int lrc=0, enhanced=0, lines=0, printable=0, angles=0;
    for(long i=0;i<n;i++) {
        printable+=isprint(p[i]) || p[i]=='\r' || p[i]=='\n' || p[i]=='\t';
        lines+=p[i]=='\n'; angles+=p[i]=='<';
        if(i+6<n && p[i]=='[' && isdigit(p[i+1]) && isdigit(p[i+2]) && p[i+3]==':' && isdigit(p[i+4]) && isdigit(p[i+5]) && (p[i+6]=='.' || p[i+6]==']')) lrc++;
        if(i+6<n && p[i]=='<' && isdigit(p[i+1]) && isdigit(p[i+2]) && p[i+3]==':' && isdigit(p[i+4]) && isdigit(p[i+5]) && (p[i+6]=='.' || p[i+6]=='>')) enhanced++;
    }
    int base64=0;
    for(long i=0;i<n;i++) base64+=(isalnum(p[i]) || p[i]=='+' || p[i]=='/' || p[i]=='=' || p[i]=='\r' || p[i]=='\n');
    printf("bytes=%ld printable=%d%% base64-alphabet=%d%% newline=%d LRC-time-tags=%d enhanced-time-tags=%d angle-brackets=%d\n",n,n?(int)(100L*printable/n):0,n?(int)(100L*base64/n):0,lines,lrc,enhanced,angles);
    fputs("first-byte categories: ",stdout);
    for(long i=0;i<n && i<64;i++) putchar(isalpha(p[i])?'A':isdigit(p[i])?'0':p[i]=='\r'||p[i]=='\n'?'_':p[i]=='+'||p[i]=='/'||p[i]=='='?p[i]:'?');
    putchar('\n');
    free(p); return 0;
}
