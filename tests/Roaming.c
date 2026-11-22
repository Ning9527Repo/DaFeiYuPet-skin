#include "../Sources/MowangDaFeiYuPetRoaming.h"
#include <assert.h>
#include <stdio.h>
int main(void) {
    for(int profile=0;profile<3;profile++) for(int direction=0;direction<2;direction++) {
        for(int start=0;start<=250;start++) {
            MowangDaFeiYuPetRoaming r=mowang_dafeiyupet_roamBegin(start,250,180,profile,direction);
            double previous=start;
            for(int frame=0;frame<=200;frame++) {
                double x=mowang_dafeiyupet_roamAdvance(&r,frame/200.,250);
                assert(isfinite(x)&&x>=0&&x<=250);
                assert(fabs(x-previous)<3); previous=x;
            }
            assert(!r.active && fabs(previous-r.endX)<1e-8);
        }
    }
    MowangDaFeiYuPetRoaming r=mowang_dafeiyupet_roamBegin(240,250,180,0,1);
    assert(r.endX<r.startX);
    double x=mowang_dafeiyupet_roamAdvance(&r,.5,250);
    assert(mowang_dafeiyupet_roamAdvance(&r,.2,250)==x);
    assert(mowang_dafeiyupet_roamAdvance(&r,NAN,250)==x);
    r.active=0; assert(mowang_dafeiyupet_roamAdvance(&r,1,250)==x);
    assert(!mowang_dafeiyupet_roamBegin(0,0,180,0,0).active);
    assert(!mowang_dafeiyupet_roamBegin(NAN,250,180,0,0).active);
    assert(!mowang_dafeiyupet_roamBegin(0,250,180,8,0).active);
    r=mowang_dafeiyupet_roamBegin(0,250,180,2,1);
    assert(mowang_dafeiyupet_roamAdvance(&r,.9,20)<=20);
    puts("PASS roaming: three profiles, 302706 bounded samples, inward edges, monotonic progress, stalls, cancellation and invalid input");
}
