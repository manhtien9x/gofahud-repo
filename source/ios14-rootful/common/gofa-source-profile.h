#pragma once
#import <Foundation/Foundation.h>
#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#include <string.h>
typedef struct {
    const char *version;
    const char *uuid;
    uintptr_t signOffset, speedOffset, peripheralOffset;
} GOFAHUDSourceProfile;
// Offsets are verified against each listed app build. Never guess for an update.
static inline BOOL GOFAHUDGetSourceProfile(GOFAHUDSourceProfile *profile, NSString **loadedUUID) {
    NSBundle *bundle=NSBundle.mainBundle;
    if(![bundle.bundleIdentifier isEqual:@"com.lumi.GOFA"]) return NO;
    const struct mach_header_64 *h=NULL;
    for(uint32_t i=0;i<_dyld_image_count();i++) {
        const char *name=_dyld_get_image_name(i);
        if(name && !strcmp(name,bundle.executablePath.fileSystemRepresentation)) { h=(const void *)_dyld_get_image_header(i); break; }
    }
    if(!h || h->magic!=MH_MAGIC_64) return NO;
    const char *end=(const char *)(h+1)+h->sizeofcmds;
    const struct load_command *cmd=(const void *)(h+1);
    NSString *uuid=nil;
    for(uint32_t i=0;i<h->ncmds;i++) {
        if((const char *)cmd+sizeof(*cmd)>end || cmd->cmdsize<sizeof(*cmd) || cmd->cmdsize>(uintptr_t)(end-(const char *)cmd)) return NO;
        if(cmd->cmd==LC_UUID && cmd->cmdsize>=sizeof(struct uuid_command)) {
            uuid=[[[NSUUID alloc] initWithUUIDBytes:((const struct uuid_command *)cmd)->uuid] UUIDString]; break;
        }
        cmd=(const void *)((const char *)cmd+cmd->cmdsize);
    }
    if(loadedUUID) *loadedUUID=uuid;
    static const GOFAHUDSourceProfile profiles[]={
        {"4.2.1","44EBEBC6-B59E-32DA-B194-966837FC2AF2",160,200,104},
        {"4.2.2","083A8351-4BD5-3F58-B014-AA10B06180D7",176,296,120}
    };
    NSString *version=[bundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    for(unsigned i=0;i<sizeof(profiles)/sizeof(profiles[0]);i++) {
        if([version isEqual:[NSString stringWithUTF8String:profiles[i].version]] && [uuid isEqual:[NSString stringWithUTF8String:profiles[i].uuid]]) {
            if(profile) *profile=profiles[i]; return YES;
        }
    }
    return NO;
}
