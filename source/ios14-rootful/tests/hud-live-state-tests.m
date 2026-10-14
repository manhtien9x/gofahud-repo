#import <Foundation/Foundation.h>
#import "hud-live-state.h"
#import "speed-state.h"
#include <assert.h>
int main(void) { @autoreleasepool {
    uint64_t limit=GVMEncodeSample(@50,100);
    assert([GOFAHUDRetainedLimit(limit,500,10,10) isEqual:@50]);
    assert(!GOFAHUDRetainedLimit(limit,500,10,11));
    assert(!GOFAHUDRetainedLimit(limit,500,10,0));
    assert(!GOFAHUDRetainedLimit(limit,99,10,10));
    assert([GOFAHUDRetainedZero(GVMEncodeSample(@0,100),500,10,10) isEqual:@0]);
    assert(!GOFAHUDRetainedZero(GVMEncodeSample(@31,100),500,10,10));
    assert(!GOFAHUDRetainedZero(GVMEncodeSample(@0,100),500,10,11));
    const unsigned signs[]={0,32,33,34,36};
    for(unsigned i=0;i<5;i++) {
        uint64_t frame=GOFAHUDCameraEncode(signs[i],150,100);
        NSDictionary *camera=GOFAHUDCameraDecode(frame,101);
        assert([camera[@"kind"] unsignedIntValue]==i && [camera[@"meters"] unsignedIntValue]==150);
        assert(!GOFAHUDCameraDecode(frame,105) && !GOFAHUDCameraDecode(frame,99));
    }
    assert(!GOFAHUDCameraEncode(50,150,100));
    assert(!GOFAHUDCameraEncode(32,70000,100));
    puts("HUD live transport: producer identity, retained decisions, four camera kinds, expiry and bounds passed.");
    return 0;
} }
