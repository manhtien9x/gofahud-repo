#import <Foundation/Foundation.h>
extern const char *const GOFACameraStateName;
// kind: 1 speed camera, 2 red-light camera, 3 surveillance camera.
uint64_t GOFAEncodeCamera(NSNumber *kind, NSNumber *meters, NSTimeInterval received);
NSDictionary *GOFADecodeCamera(uint64_t state, NSTimeInterval uptime);
