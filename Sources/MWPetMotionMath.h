#pragma once
#include <math.h>
#include <stddef.h>
// Native motion channels, in model coordinates and radians; independent of UIKit/skin.
enum { MWX, MWY, MWAngle, MWSX, MWSY, MWWaist, MWHead, MWArmN, MWArmF, MWLegB, MWLegF, MWTail, MWFin, MWAhoge, MWSit, MWYaw, MWLookX, MWLookY, MWMouth, MWChannels };
typedef struct { double t, v[MWChannels]; } MWKeyframe;
static inline double MWUnit(double x) { return isfinite(x)?fmin(1,fmax(0,x)):0; }
static inline double MWCurve(double x) { x=MWUnit(x);return x*x*(3-2*x); }
static inline void MWNeutral(double *v) { for(size_t i=0;i<MWChannels;i++)v[i]=0;v[MWSX]=v[MWSY]=1; }
static inline void MWSample(const MWKeyframe *keys,size_t count,double phase,double *out) {
 MWNeutral(out); if(!keys||!count)return;phase=MWUnit(phase);size_t hi=0;
 while(hi<count&&keys[hi].t<phase)hi++;
 if(!hi){for(size_t c=0;c<MWChannels;c++)out[c]=keys[0].v[c];return;}
 if(hi==count)hi=count-1;
 const MWKeyframe *a=&keys[hi-1],*b=&keys[hi];double span=b->t-a->t;
 double k=span>0?MWCurve((phase-a->t)/span):1;
 for(size_t c=0;c<MWChannels;c++)out[c]=a->v[c]+(b->v[c]-a->v[c])*k;
}
