#pragma once
#include <math.h>
// Native adaptation of shared/pickers.ts rollKind. Preview maps turn to look,
// action to tap; move is excluded and remaining weights renormalized when disabled.
typedef enum { MowangPetIdle, MowangPetLook, MowangPetMove, MowangPetAction } MowangPetChoice;
static inline MowangPetChoice mowang_dafeiyupet_chooseAction(double roll,int mode,int allowMove) {
    static const double weights[3][4]={{60,15,15,10},{85,10,3,2},{30,20,30,20}};
    if(mode<0||mode>2) mode=0;
    if(!isfinite(roll)) roll=0;
    roll=fmax(0,fmin(nextafter(1.,0.),roll));
    double total=0;
    for(int i=0;i<4;i++) if(i!=MowangPetMove||allowMove) total+=weights[mode][i];
    double target=roll*total;
    for(int i=0;i<4;i++) {
        if(i==MowangPetMove&&!allowMove) continue;
        if(target<weights[mode][i]) return (MowangPetChoice)i;
        target-=weights[mode][i];
    }
    return MowangPetAction;
}
static inline int mowang_dafeiyupet_scheduleDue(double now,double last,double interval,int busy) {
    if(busy||!isfinite(now)||!isfinite(last)||!isfinite(interval)||interval<=0) return 0;
    return now>=last && now-last>=interval;
}
