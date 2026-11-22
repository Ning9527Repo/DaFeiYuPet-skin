#pragma once
#import <Foundation/Foundation.h>
#include <math.h>
static inline double mowang_dafeiyupet_frameDelay(id value) {
    double delay=[value isKindOfClass:NSNumber.class]?[value doubleValue]:NAN;
    return isfinite(delay)&&delay>0?fmin(fmax(delay,.01),10):.1;
}
static inline double mowang_dafeiyupet_frameProgress(NSArray *times,NSUInteger displayed,double age) {
    if(!times.count || !displayed) return 0;
    double total=0,elapsed=0;
    if(!isfinite(age)||age<0) age=0;
    for(NSUInteger i=0;i<times.count;i++) {
        double delay=mowang_dafeiyupet_frameDelay(times[i]); total+=delay;
        if(i+1<displayed) elapsed+=delay;
        else if(i+1==displayed) elapsed+=fmin(delay,age);
    }
    return total>0?fmin(elapsed/total,1):0;
}
