#pragma once
#import <Foundation/Foundation.h>
#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#include <string.h>
typedef struct {
    const char *version;
    const char *uuid;
    uintptr_t signOffset, speedOffset, peripheralOffset;
    uintptr_t signFieldOffsets[5];
} GOFAHUDSourceProfile;
BOOL GOFAHUDGetSourceProfile(GOFAHUDSourceProfile *profile, NSString **loadedUUID);
BOOL GOFAHUDGetLocationOffsets(uintptr_t *raw,uintptr_t *processed);
BOOL GOFAHUDGetDisplayLimitOffset(uintptr_t *offset);
BOOL GOFAHUDValidateFields(NSArray *fields,NSDictionary *required,size_t size,NSDictionary **offsets,NSString **reason);
