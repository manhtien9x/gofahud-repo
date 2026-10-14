#import <Foundation/Foundation.h>
extern const char *const GOFAHUDProducerName;
extern const char *const GOFAHUDLimitName;
extern const char *const GOFAHUDCameraName;
NSNumber *GOFAHUDRetainedLimit(uint64_t state,double uptime,uint64_t producer,uint64_t ready);
NSNumber *GOFAHUDRetainedZero(uint64_t state,double uptime,uint64_t producer,uint64_t ready);
uint64_t GOFAHUDCameraEncode(uint32_t sign,uint32_t distance,double received);
NSDictionary *GOFAHUDCameraDecode(uint64_t state,double uptime);
