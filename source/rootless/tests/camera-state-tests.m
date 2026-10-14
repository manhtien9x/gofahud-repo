#import "camera-state.h"
#import "speed-state.h"
#include <assert.h>
#include <math.h>
int main(void) { @autoreleasepool {
    for (int kind = 1; kind <= 3; kind++) {
        uint64_t state = GOFAEncodeCamera(@(kind), @65535, 100);
        assert([GOFADecodeCamera(state, 104.999)[@"kind"] intValue] == kind);
        assert([GOFADecodeCamera(state, 101)[@"meters"] intValue] == 65535);
        assert(!GOFADecodeCamera(state, 105));
        assert(!GOFADecodeCamera(state, 99));
    }
    assert(!GOFAEncodeCamera(@YES, @50, 100));
    assert(!GOFAEncodeCamera(@1, @YES, 100));
    assert(!GOFAEncodeCamera(@4, @50, 100));
    assert(!GOFAEncodeCamera(@1, @65536, 100));
    assert(!GOFAEncodeCamera(@1, @1.5, 100));
    assert(!GOFAEncodeCamera(@1, @50, NAN));
    assert(!GOFADecodeCamera(0, 100));
    assert(!GOFADecodeCamera(GOFAEncodeCamera(@1, @0, 100), INFINITY));
    uint64_t speed = GVMEncodeSample(@0, 100);
    assert([GVMDecodeSample(speed, 101, YES) isEqual:@0]);
    assert(!GVMDecodeSample(speed, 105, YES));
    assert(!GVMDecodeSample(GVMEncodeSample(@0, 100), 101, NO));
    puts("camera and speed transport tests passed");
} }
