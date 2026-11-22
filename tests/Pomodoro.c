#include "../Sources/MowangDaFeiYuPetPomodoro.h"
#include <assert.h>
#include <stdio.h>

int main(void) {
    double start = 1700000000;
    MowangDaFeiYuPetPomoSnapshot s = mowang_dafeiyupet_pomo_snapshot(start,25,5,start);
    assert(s.phase == MowangDaFeiYuPetPomoWork && s.remainingSeconds == 1500);
    s = mowang_dafeiyupet_pomo_snapshot(start,25,5,start+1499.2);
    assert(s.phase == MowangDaFeiYuPetPomoWork && s.remainingSeconds == 1);
    s = mowang_dafeiyupet_pomo_snapshot(start,25,5,start+1500);
    assert(s.phase == MowangDaFeiYuPetPomoRest && s.remainingSeconds == 300);
    assert(s.phaseStartedAt == start+1500 && s.endsAt == start+1800);
    s = mowang_dafeiyupet_pomo_snapshot(start,25,5,start+1800);
    assert(s.phase == MowangDaFeiYuPetPomoWork && s.remainingSeconds == 1500 && s.cycleIndex == 1);
    s = mowang_dafeiyupet_pomo_snapshot(start,25,5,start+1800*1000000.0+1600);
    assert(s.phase == MowangDaFeiYuPetPomoRest && s.remainingSeconds == 200 && s.cycleIndex == 1000000);
    s = mowang_dafeiyupet_pomo_snapshot(start,25,5,start-100);
    assert(s.phase == MowangDaFeiYuPetPomoWork && s.remainingSeconds == 1500 && s.endsAt == start+1500);
    for(int w=1; w<=600; ++w) {
        int r=601-w;
        s = mowang_dafeiyupet_pomo_snapshot(start,w,r,start+w*60);
        assert(s.phase == MowangDaFeiYuPetPomoRest && s.remainingSeconds == (unsigned)r*60);
        s = mowang_dafeiyupet_pomo_snapshot(start,w,r,start+(w+r)*60);
        assert(s.phase == MowangDaFeiYuPetPomoWork && s.cycleIndex == 1);
    }
    for (int i=0; i<200000; i++) {
        double now=start+i*3.17;
        s=mowang_dafeiyupet_pomo_snapshot(start,25,5,now);
        assert(s.remainingSeconds>=1 && s.remainingSeconds<=1500);
        assert(s.endsAt>now && s.phaseStartedAt<=now);
    }
    assert(mowang_dafeiyupet_pomo_snapshot(0,25,5,start).phase == MowangDaFeiYuPetPomoIdle);
    assert(mowang_dafeiyupet_pomo_snapshot(NAN,25,5,start).phase == MowangDaFeiYuPetPomoIdle);
    assert(mowang_dafeiyupet_pomo_snapshot(start,25,5,INFINITY).phase == MowangDaFeiYuPetPomoIdle);
    assert(mowang_dafeiyupet_pomo_snapshot(start,0,5,start).phase == MowangDaFeiYuPetPomoIdle);
    assert(mowang_dafeiyupet_pomo_snapshot(start,25,601,start).phase == MowangDaFeiYuPetPomoIdle);
    puts("Pomodoro: boundaries, 600 duration pairs, 200000 recovery samples and invalid states passed");
    return 0;
}
