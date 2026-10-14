#pragma once
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
// Field numbers confirmed in GOFA Android 4.2.1's generated protobuf classes.
typedef struct { uint32_t position1,position2,distance2,position3,distance3; } GOFAHUDSigns;
bool GOFAHUDDecodeSigns(const uint8_t *data,size_t size,GOFAHUDSigns *out);
bool GOFAHUDDecodeSpeed(const uint8_t *data,size_t size,uint32_t *out);
// Zero means no recognized speed-limit sign; it must not become a default 50.
uint32_t GOFAHUDLimit(uint32_t sign);
bool GOFAHUDIsCamera(uint32_t sign);
