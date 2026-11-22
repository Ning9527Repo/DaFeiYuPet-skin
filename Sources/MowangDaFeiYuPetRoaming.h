#pragma once
#include <math.h>
// Native adaptation: distances in pet widths, not desktop pixels.
// Progress comes from displayed GIF frames, so decoding stalls cannot outrun artwork.
typedef struct { double startX, endX, progress; int active; } MowangDaFeiYuPetRoaming;
static inline MowangDaFeiYuPetRoaming mowang_dafeiyupet_roamBegin(double x,double available,double petWidth,int profile,int preferRight) {
    if(!isfinite(x)||!isfinite(available)||!isfinite(petWidth)||available<=0||petWidth<=0||profile<0||profile>2)
        return (MowangDaFeiYuPetRoaming){0};
    x=fmin(fmax(x,0),available);
    double distance=petWidth*(profile==0?.7:profile==1?.45:1.2);
    double left=x,right=available-x;
    int direction=preferRight?1:-1;
    // Turn inward before starting instead of reflecting/sliding at the screen edge.
    if((direction>0?right:left)<fmin(distance,petWidth*.25)) direction=-direction;
    double target=fmin(fmax(x+direction*distance,0),available);
    return (MowangDaFeiYuPetRoaming){x,target,0,fabs(target-x)>.5};
}
static inline double mowang_dafeiyupet_roamAdvance(MowangDaFeiYuPetRoaming *r,double progress,double available) {
    if(!r->active) progress=r->progress;
    if(!isfinite(progress)) progress=r->progress;
    progress=fmin(fmax(progress,r->progress),1); r->progress=progress;
    // Gentle acceleration and braking without additional hops or throw physics.
    double eased=progress*progress*(3-2*progress);
    double x=r->startX+(r->endX-r->startX)*eased;
    if(progress>=1) r->active=0;
    return fmin(fmax(x,0),isfinite(available)?fmax(available,0):0);
}
