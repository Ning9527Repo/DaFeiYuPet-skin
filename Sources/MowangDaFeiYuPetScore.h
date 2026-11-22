#pragma once
#include <math.h>
// C2006L/dafeiyu shared/score.ts, point-space native adaptation.
// Eligibility is separate from the formula; invalid values never score.
static inline unsigned mowang_dafeiyupet_clickScore(double speed,double size) {
    if(!isfinite(speed)||!isfinite(size)||speed<=0||size<=0) return 0;
    double value=round((speed/100.)*(462./size));
    // Native safety cap bounds labels and cumulative arithmetic.
    return (unsigned)fmax(1,fmin(1000000,value));
}
static inline unsigned mowang_dafeiyupet_flyingScore(int flying,double vx,double vy,double size) {
    if(!flying||!isfinite(vx)||!isfinite(vy)) return 0;
    double speed=hypot(vx,vy);
    return speed>=400 ? mowang_dafeiyupet_clickScore(speed,size) : 0;
}
