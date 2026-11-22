#include "../Sources/MowangDaFeiYuPetScheduler.h"
#include <assert.h>
#include <stdio.h>
int main(void) {
    assert(mowang_dafeiyupet_chooseAction(0,0,1)==MowangPetIdle);
    assert(mowang_dafeiyupet_chooseAction(.6,0,1)==MowangPetLook);
    assert(mowang_dafeiyupet_chooseAction(.75,0,1)==MowangPetMove);
    assert(mowang_dafeiyupet_chooseAction(.9,0,1)==MowangPetAction);
    assert(mowang_dafeiyupet_chooseAction(NAN,0,1)==MowangPetIdle);
    assert(mowang_dafeiyupet_chooseAction(2,99,1)==MowangPetAction);
    int counts[4]={0};
    for(int i=0;i<10000;i++) counts[mowang_dafeiyupet_chooseAction((i+.5)/10000.,0,1)]++;
    assert(counts[0]==6000&&counts[1]==1500&&counts[2]==1500&&counts[3]==1000);
    for(int mode=0;mode<3;mode++) for(int i=0;i<10000;i++)
        assert(mowang_dafeiyupet_chooseAction((i+.5)/10000.,mode,0)!=MowangPetMove);
    assert(!mowang_dafeiyupet_scheduleDue(111.99,100,12,0));
    assert(mowang_dafeiyupet_scheduleDue(112,100,12,0));
    assert(!mowang_dafeiyupet_scheduleDue(200,100,12,1));
    assert(!mowang_dafeiyupet_scheduleDue(99,100,12,0));
    assert(!mowang_dafeiyupet_scheduleDue(NAN,100,12,0));
    puts("PASS scheduler: weighted boundaries, distribution, disabled movement, busy and timing guards");
    return 0;
}
