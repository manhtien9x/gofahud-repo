#import "camera-state.h"
#import <CoreFoundation/CoreFoundation.h>
#include <math.h>
const char *const GOFACameraStateName = "local.gofahud.camera";
static BOOL Integer(id n, double min, double max) {
    if (![n isKindOfClass:NSNumber.class] || CFGetTypeID((__bridge CFTypeRef)n) == CFBooleanGetTypeID()) return NO;
    double v = [n doubleValue];
    return isfinite(v) && v >= min && v <= max && floor(v) == v;
}
uint64_t GOFAEncodeCamera(NSNumber *kind, NSNumber *meters, NSTimeInterval received) {
    if (!Integer(kind, 1, 3) || !Integer(meters, 0, 65535) || !isfinite(received) || received < 0 ||
        received >= (double)(UINT64_MAX >> 18) / 1000) return 0;
    return ((uint64_t)floor(received * 1000) << 18) | ((uint64_t)kind.unsignedIntValue << 16) | meters.unsignedIntValue;
}
NSDictionary *GOFADecodeCamera(uint64_t state, NSTimeInterval uptime) {
    unsigned kind = (state >> 16) & 3;
    double age = uptime - (double)(state >> 18) / 1000;
    if (!kind || !isfinite(uptime) || !isfinite(age) || age < 0 || age >= 5) return nil;
    return @{@"kind": @(kind), @"meters": @(state & 65535)};
}
