#include "hud-protocol.h"
#include <assert.h>
#include <stdio.h>
int main(void) {
    GOFAHUDSigns signs;
    // Limit 50, traffic camera 150m, AI camera 300m; varint distances >127.
    const uint8_t board[]={8,5,16,32,24,150,1,32,36,40,172,2};
    assert(GOFAHUDDecodeSigns(board,sizeof(board),&signs));
    assert(GOFAHUDLimit(signs.position1)==50 && signs.distance2==150 && signs.distance3==300);
    assert(GOFAHUDIsCamera(signs.position2) && GOFAHUDIsCamera(signs.position3));
    assert(GOFAHUDIsCamera(33) && GOFAHUDIsCamera(34) && !GOFAHUDIsCamera(5));
    assert(GOFAHUDLimit(11)==120 && GOFAHUDLimit(0)==0 && GOFAHUDLimit(99)==0);
    uint32_t speed=999;
    const uint8_t moving[]={8,31}; assert(GOFAHUDDecodeSpeed(moving,2,&speed) && speed==31);
    assert(GOFAHUDDecodeSpeed(NULL,0,&speed) && speed==0);
    const uint8_t extra[]={8,60,82,3,1,2,3}; assert(GOFAHUDDecodeSpeed(extra,sizeof(extra),&speed) && speed==60);
    const uint8_t duplicate[]={8,40,8,50}; assert(GOFAHUDDecodeSpeed(duplicate,4,&speed) && speed==50);
    const uint8_t truncated[]={8,128}; assert(!GOFAHUDDecodeSpeed(truncated,2,&speed));
    const uint8_t invalidTag[]={0}; assert(!GOFAHUDDecodeSpeed(invalidTag,1,&speed));
    const uint8_t wrongWire[]={10,0}; assert(!GOFAHUDDecodeSpeed(wrongWire,2,&speed));
    const uint8_t huge[]={8,255,255,255,255,31}; assert(!GOFAHUDDecodeSpeed(huge,sizeof(huge),&speed));
    const uint8_t longUnknown[]={80,255,255,255,255,255,255,255,255,255,2};
    assert(!GOFAHUDDecodeSigns(longUnknown,sizeof(longUnknown),&signs));
    assert(GOFAHUDDecodeSigns(NULL,0,&signs) && signs.position1==0 && signs.distance2==0);
    puts("GOFA HUD protobuf: speed, sign IDs, distances, zero, unknown fields, duplicates and malformed frames passed.");
    return 0;
}
