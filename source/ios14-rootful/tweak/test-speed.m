#import <Foundation/Foundation.h>
#import "test-state.h"
#include <notify.h>
#include <errno.h>
#include <stdlib.h>

static BOOL Number(const char *text, NSInteger *value) {
    char *end; errno = 0;
    long parsed = strtol(text, &end, 10);
    if (errno || end == text || *end) return NO;
    *value = parsed; return YES;
}
int main(int argc, char **argv) {
    @autoreleasepool {
        if(argc==2 && strcmp(argv[1],"carplay-show")==0) return notify_post("local.gofahud.carplay.show")==NOTIFY_STATUS_OK ? 0 : 3;
        if(argc==2 && strcmp(argv[1],"carplay-open")==0) return notify_post("local.gofahud.carplay.open-gofa")==NOTIFY_STATUS_OK ? 0 : 3;
        if (argc==2 && strcmp(argv[1],"open")==0) return notify_post("local.gofahud.phone.open-gofa")==NOTIFY_STATUS_OK ? 0 : 3;
        if (argc==2 && strcmp(argv[1],"show")==0) return notify_post("local.gofahud.phone.show")==NOTIFY_STATUS_OK ? 0 : 3;
        uint64_t state = 0;
        if (!(argc == 2 && strcmp(argv[1], "off") == 0)) {
            NSInteger speed, limit, duration;
            if (argc != 4 || !Number(argv[1], &speed) || !Number(argv[2], &limit) || !Number(argv[3], &duration) ||
                !(state = GVMEncodeTest(speed, limit, NSProcessInfo.processInfo.systemUptime, duration))) {
                fprintf(stderr, "Usage: gvm-test-speed SPEED_KMH LIMIT_KMH SECONDS (1..300), or off\n"); return 2;
            }
        }
        int token;
        if (notify_register_check(GVMTestStateName, &token) != NOTIFY_STATUS_OK) return 3;
        uint32_t result = notify_set_state(token, state);
        if (result == NOTIFY_STATUS_OK) notify_post(GVMTestStateName);
        notify_cancel(token);
        if (result != NOTIFY_STATUS_OK) { fprintf(stderr, "Test publication refused\n"); return 3; }
        printf(state ? "TEST active; automatic expiry; GOFA phone/CarPlay display only\n" : "TEST off; live GOFA display restored\n");
        return 0;
    }
}
