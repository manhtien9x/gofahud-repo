#import "hud-live-state.h"
#include <math.h>
const char *const GOFAHUDProducerName="local.gofahud.hud.producer";
const char *const GOFAHUDLimitName="local.gofahud.hud.limit.v2";
const char *const GOFAHUDCameraName="local.gofahud.hud.camera.v2";
NSNumber *GOFAHUDRetainedZero(uint64_t state,double uptime,uint64_t producer,uint64_t ready) {
    if(!producer || producer!=ready || !(state&512) || (state&511)!=0 || !isfinite(uptime) || uptime<0 || (double)(state>>10)/1000>uptime) return nil;
    return @0;
}
NSNumber *GOFAHUDRetainedLimit(uint64_t state,double uptime,uint64_t producer,uint64_t ready) {
    // A sign decision is retained until replaced or its GOFA process ends.
    // This does not turn a cached sign into a new decision or update its timestamp.
    if(!producer || producer!=ready || !(state&512) || !isfinite(uptime) || uptime<0) return nil;
    uint64_t limit=state&511;
    double received=(double)(state>>10)/1000;
    if(!limit || limit>400 || received>uptime) return nil;
    return @(limit);
}
uint64_t GOFAHUDCameraEncode(uint32_t sign,uint32_t distance,double received) {
    unsigned kind=sign==32 ? 1 : sign==33 ? 2 : sign==34 ? 3 : sign==36 ? 4 : sign==0 ? 0 : 7;
    if(kind==7 || distance>65535 || !isfinite(received) || received<0 || received>=(double)(UINT64_MAX>>20)/1000) return 0;
    return ((uint64_t)floor(received*1000)<<20) | (1ull<<19) | ((uint64_t)kind<<16) | distance;
}
NSDictionary *GOFAHUDCameraDecode(uint64_t state,double uptime) {
    if(!(state&(1ull<<19)) || !isfinite(uptime)) return nil;
    unsigned kind=(state>>16)&7; double age=uptime-(double)(state>>20)/1000;
    if(kind>4 || age<0 || age>=5) return nil;
    return @{@"kind":@(kind),@"meters":@(state&65535)};
}
