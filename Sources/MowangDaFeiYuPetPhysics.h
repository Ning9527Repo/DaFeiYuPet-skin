#pragma once
#include <math.h>
#include <stddef.h>
// Native point-space adaptation of C2006L/dafeiyu shared/physics.ts.
// See apelin/REFERENCE.md for provenance and iOS-specific limits.
typedef struct { double x,y,vx,vy; } MowangDaFeiYuPetBody;
typedef struct { double gravity,restitution,friction,power; } MowangDaFeiYuPetPhysics;
static inline double mowang_dafeiyupet_clamp(double v,double lo,double hi) {
    return isfinite(v) ? fmin(fmax(v,lo),hi) : lo;
}
static inline MowangDaFeiYuPetPhysics mowang_dafeiyupet_physics(double gravity,double restitution,double friction,double power) {
    return (MowangDaFeiYuPetPhysics){
        isfinite(gravity)?mowang_dafeiyupet_clamp(gravity,0,3000):1400,
        isfinite(restitution)?mowang_dafeiyupet_clamp(restitution,0,1):.78,
        isfinite(friction)?mowang_dafeiyupet_clamp(friction,0,10):2.5,
        isfinite(power)?mowang_dafeiyupet_clamp(power,.25,2):1};
}
static inline void mowang_dafeiyupet_stepWithPhysics(MowangDaFeiYuPetBody *b,double dt,double w,double h,MowangDaFeiYuPetPhysics p) {
    dt=mowang_dafeiyupet_clamp(dt,0,0.05); w=fmax(0,w); h=fmax(0,h);
    b->vy+=p.gravity*dt; b->x+=b->vx*dt; b->y+=b->vy*dt;
    if(b->x<0) { b->x=0; b->vx=fabs(b->vx)*p.restitution; }
    if(b->x>w) { b->x=w; b->vx=-fabs(b->vx)*p.restitution; }
    if(b->y<0) { b->y=0; b->vy=fabs(b->vy)*p.restitution; }
    if(b->y>=h) { b->y=h; b->vy=-fabs(b->vy)*p.restitution;
        if(fabs(b->vy)<40) b->vy=0;
        b->vx*=exp(-p.friction*dt); if(fabs(b->vx)<15) b->vx=0;
    }
}
static inline void mowang_dafeiyupet_step(MowangDaFeiYuPetBody *b,double dt,double w,double h) {
    mowang_dafeiyupet_stepWithPhysics(b,dt,w,h,mowang_dafeiyupet_physics(1400,.78,2.5,1));
}
static inline double mowang_dafeiyupet_release(double v) {
    return isfinite(v) ? copysign(3600*(1-exp(-fabs(v)/3600)),v) : 0;
}
// Ported from upstream shared/physics.ts (main 7ca2bb3), seconds/points on iOS.
// Fixed storage bounds memory even with high-rate touch delivery.
#define MOWANG_DAFEIYUPET_TRAIL_CAPACITY 128
typedef struct { double t,x,y; } MowangDaFeiYuPetDragSample;
typedef struct { MowangDaFeiYuPetDragSample samples[MOWANG_DAFEIYUPET_TRAIL_CAPACITY]; size_t count; } MowangDaFeiYuPetTrail;
static inline void mowang_dafeiyupet_sample(MowangDaFeiYuPetTrail *trail,double t,double x,double y) {
    if(!isfinite(t)||!isfinite(x)||!isfinite(y)) return;
    if(trail->count && t<=trail->samples[trail->count-1].t) return;
    size_t first=0;
    while(first<trail->count && trail->samples[first].t<t-.2) first++;
    size_t n=trail->count-first;
    if(n==MOWANG_DAFEIYUPET_TRAIL_CAPACITY) { first++; n--; }
    for(size_t i=0;i<n;i++) trail->samples[i]=trail->samples[first+i];
    trail->samples[n]=(MowangDaFeiYuPetDragSample){t,x,y}; trail->count=n+1;
}
static inline void mowang_dafeiyupet_estimateRelease(const MowangDaFeiYuPetTrail *trail,double now,double power,double *vx,double *vy) {
    *vx=0; *vy=0;
    if(!isfinite(now)||trail->count<2) return;
    MowangDaFeiYuPetDragSample last=trail->samples[trail->count-1];
    if(now<last.t || now-last.t>.15) return;
    size_t first=0;
    while(first<trail->count && now-trail->samples[first].t>.15) first++;
    if(first+1>=trail->count) return;
    MowangDaFeiYuPetDragSample start=trail->samples[first], prev=start;
    double span=last.t-start.t;
    if(span<.02) return;
    double bx=(last.x-start.x)/span, by=(last.y-start.y)/span, base=hypot(bx,by);
    if(!isfinite(base)||base<1e-6) return;
    double peak=0,firstSpeed=0,lastSpeed=0,firstEnd=0,lastEnd=0; size_t segments=0;
    for(size_t i=first+1;i<trail->count;i++) {
        MowangDaFeiYuPetDragSample s=trail->samples[i]; double dt=s.t-prev.t;
        if(dt>=.008) {
            double speed=hypot(s.x-prev.x,s.y-prev.y)/dt;
            if(!segments) { firstSpeed=speed; firstEnd=s.t; }
            peak=fmax(peak,speed); lastSpeed=speed; lastEnd=s.t; segments++; prev=s;
        }
    }
    if(!segments) peak=base;
    double accel=segments>=2?(lastSpeed-firstSpeed)/fmax(lastEnd-firstEnd,.02):0;
    double speed=mowang_dafeiyupet_release((base+peak)*.5*(1+mowang_dafeiyupet_clamp(accel/8000,0,1)*.6));
    speed*=isfinite(power)?mowang_dafeiyupet_clamp(power,.25,2):1;
    if(!isfinite(speed)||speed<500) return;
    *vx=bx/base*speed; *vy=by/base*speed;
}
static inline void mowang_dafeiyupet_spring(MowangDaFeiYuPetBody *b,double tx,double ty,double dt,double power) {
    dt=mowang_dafeiyupet_clamp(dt,0,.05);
    power=isfinite(power)?mowang_dafeiyupet_clamp(power,.25,2):1;
    // Substeps keep upstream's K=200/C=30 stable at 30Hz and power=2.
    while(dt>1e-9) {
        double step=fmin(dt,1./120); dt-=step;
        b->vx+=((tx-b->x)*200-b->vx*30)*power*step;
        b->vy+=((ty-b->y)*200-b->vy*30)*power*step;
        b->x+=b->vx*step; b->y+=b->vy*step;
    }
}
static inline double mowang_dafeiyupet_landingSquash(double impact) {
    double t=mowang_dafeiyupet_clamp((fabs(impact)-300)/1200,0,1);
    return fmin(.8,1-t*.45);
}
static inline double mowang_dafeiyupet_squashScale(double u,double depth) {
    u=mowang_dafeiyupet_clamp(u,0,1); depth=mowang_dafeiyupet_clamp(depth,.55,.8);
    if(u<.45) { double p=u/.45; return 1-(1-depth)*p*p; }
    double p=(u-.45)/.55-1, f=1+2.70158*p*p*p+1.70158*p*p;
    return fmin(1.12,depth+(1-depth)*fmax(f,0));
}
// Clamp the vector magnitude, not each axis: diagonal throws must share the same cap.
static inline void mowang_dafeiyupet_releaseVector(double vx,double vy,double power,double *outX,double *outY) {
    *outX=0; *outY=0;
    if(!isfinite(vx)||!isfinite(vy)) return;
    double speed=hypot(vx,vy);
    if(!isfinite(speed)||speed<1e-6) return;
    power=isfinite(power)?mowang_dafeiyupet_clamp(power,.25,2):1;
    double capped=mowang_dafeiyupet_release(speed)*power;
    if(capped<500) return;
    *outX=(vx/speed)*capped; *outY=(vy/speed)*capped;
}
