#include "../Sources/MowangDaFeiYuPetPhysics.h"
#include <assert.h>
#include <stdio.h>
int main(void) {
    assert(mowang_dafeiyupet_clamp(NAN,0,1)==0);
    assert(mowang_dafeiyupet_clamp(200,100,300)==200);
    assert(mowang_dafeiyupet_clamp(-1,.2,1)==.2);
    assert(fabs(mowang_dafeiyupet_release(100000))<=3600);
    assert(mowang_dafeiyupet_release(NAN)==0);
    MowangDaFeiYuPetBody b={20,20,1300,-2000};
    for(int i=0;i<20000;i++) { mowang_dafeiyupet_step(&b,.016,200,600); assert(b.x>=0 && b.x<=200 && b.y>=0 && b.y<=600); }
    assert(b.vx==0 && b.vy==0);
    b=(MowangDaFeiYuPetBody){1,1,0,0}; mowang_dafeiyupet_step(&b,100,200,600); assert(b.y<10);
    b=(MowangDaFeiYuPetBody){1,1,0,0}; mowang_dafeiyupet_step(&b,.01,0,0); assert(b.x==0&&b.y==0);
    MowangDaFeiYuPetPhysics p=mowang_dafeiyupet_physics(NAN,NAN,NAN,NAN);
    assert(p.gravity==1400 && p.restitution==.78 && p.friction==2.5 && p.power==1);
    p=mowang_dafeiyupet_physics(-1,3,100,100); assert(p.gravity==0 && p.restitution==1 && p.friction==10 && p.power==2);
    double vx,vy;
    mowang_dafeiyupet_releaseVector(100000,100000,1,&vx,&vy);
    assert(hypot(vx,vy)<=3600 && fabs(vx-vy)<1e-6);
    mowang_dafeiyupet_releaseVector(100,0,1,&vx,&vy); assert(vx==0 && vy==0);
    mowang_dafeiyupet_releaseVector(NAN,100,1,&vx,&vy); assert(vx==0 && vy==0);
    mowang_dafeiyupet_releaseVector(2000,0,.5,&vx,&vy); double light=vx;
    mowang_dafeiyupet_releaseVector(2000,0,1.5,&vx,&vy); assert(fabs(vx-3*light)<1e-6);
    MowangDaFeiYuPetBody a={100,100,0,0}; b=a;
    mowang_dafeiyupet_stepWithPhysics(&a,.02,200,600,mowang_dafeiyupet_physics(700,.78,2.5,1));
    mowang_dafeiyupet_stepWithPhysics(&b,.02,200,600,mowang_dafeiyupet_physics(2100,.78,2.5,1));
    assert(b.vy==3*a.vy);
    a=(MowangDaFeiYuPetBody){200,100,1000,0}; b=a;
    mowang_dafeiyupet_stepWithPhysics(&a,.02,200,600,mowang_dafeiyupet_physics(1400,.4,2.5,1));
    mowang_dafeiyupet_stepWithPhysics(&b,.02,200,600,mowang_dafeiyupet_physics(1400,.9,2.5,1));
    assert(fabs(a.vx)==400 && fabs(b.vx)==900);
    a=(MowangDaFeiYuPetBody){100,600,500,0}; b=a;
    mowang_dafeiyupet_stepWithPhysics(&a,.02,200,600,mowang_dafeiyupet_physics(1400,.78,1,1));
    mowang_dafeiyupet_stepWithPhysics(&b,.02,200,600,mowang_dafeiyupet_physics(1400,.78,5,1));
    assert(b.vx<a.vx);
    MowangDaFeiYuPetTrail trail={0};
    for(int i=0;i<=10;i++) mowang_dafeiyupet_sample(&trail,i*.01,i*20,i*20);
    mowang_dafeiyupet_estimateRelease(&trail,.1,1,&vx,&vy);
    double expected=mowang_dafeiyupet_release(hypot(2000,2000));
    assert(fabs(hypot(vx,vy)-expected)<1e-6 && fabs(vx-vy)<1e-6);
    mowang_dafeiyupet_estimateRelease(&trail,.1,.5,&vx,&vy);
    assert(fabs(hypot(vx,vy)-expected*.5)<1e-6);
    mowang_dafeiyupet_estimateRelease(&trail,.3,1,&vx,&vy); assert(vx==0&&vy==0);
    trail=(MowangDaFeiYuPetTrail){0};
    mowang_dafeiyupet_sample(&trail,0,0,0); mowang_dafeiyupet_sample(&trail,.01,100,0);
    mowang_dafeiyupet_estimateRelease(&trail,.01,1,&vx,&vy); assert(vx==0&&vy==0);
    trail=(MowangDaFeiYuPetTrail){0};
    for(int i=0;i<=100;i++) mowang_dafeiyupet_sample(&trail,i*.001,i*2,0);
    mowang_dafeiyupet_estimateRelease(&trail,.1,1,&vx,&vy);
    assert(fabs(vx-mowang_dafeiyupet_release(2000))<1e-6 && vy==0);
    trail=(MowangDaFeiYuPetTrail){0};
    mowang_dafeiyupet_sample(&trail,0,0,0); mowang_dafeiyupet_sample(&trail,.05,10,0); mowang_dafeiyupet_sample(&trail,.1,200,0);
    mowang_dafeiyupet_estimateRelease(&trail,.1,1,&vx,&vy);
    assert(fabs(vx-mowang_dafeiyupet_release((2000+3800)*.5*1.6))<1e-6);
    trail=(MowangDaFeiYuPetTrail){0};
    for(int i=0;i<10000;i++) mowang_dafeiyupet_sample(&trail,i*.0001,i,0);
    assert(trail.count==128 && trail.samples[0].t>=.9999-.2);
    size_t count=trail.count;
    mowang_dafeiyupet_sample(&trail,NAN,0,0); mowang_dafeiyupet_sample(&trail,.9999,0,0);
    assert(trail.count==count);
    for(double power=.25;power<=2;power+=.25) {
        b=(MowangDaFeiYuPetBody){0,0,0,0};
        for(int i=0;i<600;i++) {
            mowang_dafeiyupet_spring(&b,200,500,1./30,power);
            // Low power scales both K/C upstream and may overshoot; require
            // bounded convergence, not a false overdamped invariant at p<1.
            assert(isfinite(b.x)&&isfinite(b.y) && b.x>=0 && b.x<400 && b.y>=0 && b.y<1000);
        }
        assert(fabs(b.x-200)<.001 && fabs(b.y-500)<.001);
    }
    assert(mowang_dafeiyupet_landingSquash(0)==.8);
    assert(fabs(mowang_dafeiyupet_landingSquash(1500)-.55)<1e-6);
    assert(mowang_dafeiyupet_squashScale(0,.55)==1);
    assert(fabs(mowang_dafeiyupet_squashScale(.45,.55)-.55)<1e-6);
    assert(mowang_dafeiyupet_squashScale(1,.55)==1);
    double maxScale=1;
    for(int i=0;i<=1000;i++) {
        double scale=mowang_dafeiyupet_squashScale(i/1000.,.55);
        assert(scale>=.55 && scale<=1.12); maxScale=fmax(maxScale,scale);
    }
    assert(maxScale>1.04);
    puts("PASS physics: 20k integration; bounds/rest/config/vector cap; trail constant/peak/accel/stale/short/dense/bounded; spring powers .25..2; squash depth/overshoot/endpoints");
}
