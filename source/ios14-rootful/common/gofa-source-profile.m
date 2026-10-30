#import "gofa-source-profile.h"
#import <objc/runtime.h>
#import <mach/mach.h>
#include <dlfcn.h>
#include <stdbool.h>
static BOOL Read(uintptr_t p,void *v,size_t n) { vm_size_t got=0; return p && vm_read_overwrite(mach_task_self(),p,n,(vm_address_t)v,&got)==KERN_SUCCESS && got==n; }
typedef struct { const char *data; size_t length; } TypeName;
typedef struct { const char *name; void (*freeName)(const char *); bool strong; bool variable; } FieldInfo;
typedef intptr_t (__attribute__((swiftcall)) *CountFn)(const void *);
typedef const void *(__attribute__((swiftcall)) *FieldFn)(const void *,intptr_t,FieldInfo *);
typedef intptr_t (__attribute__((swiftcall)) *OffsetFn)(const void *,intptr_t);
typedef TypeName (__attribute__((swiftcall)) *NameFn)(const void *,bool);
typedef const void *(__attribute__((swiftcall)) *ResolveFn)(const char *,size_t,const void *,const void *const *);
static BOOL IsGOFA(void) { return [NSBundle.mainBundle.bundleIdentifier isEqual:@"com.lumi.GOFA"]; }
static BOOL CanReflect(void) { return NSProcessInfo.processInfo.operatingSystemVersion.majorVersion>=15; }
static NSString *LoadedUUID(void) {
    const char *exe=NSBundle.mainBundle.executablePath.fileSystemRepresentation;
    for(uint32_t i=0;i<_dyld_image_count();i++) {
        const char *name=_dyld_get_image_name(i);
        if(!name || !exe || strcmp(name,exe)) continue;
        const struct mach_header_64 *h=(const void *)_dyld_get_image_header(i);
        if(h->magic!=MH_MAGIC_64) return nil;
        const char *end=(const char *)(h+1)+h->sizeofcmds;
        const struct load_command *cmd=(const void *)(h+1);
        for(uint32_t j=0;j<h->ncmds;j++) {
            if((const char *)cmd+sizeof(*cmd)>end || cmd->cmdsize<sizeof(*cmd) || cmd->cmdsize>(uintptr_t)(end-(const char *)cmd)) return nil;
            if(cmd->cmd==LC_UUID && cmd->cmdsize>=sizeof(struct uuid_command)) return [[[NSUUID alloc] initWithUUIDBytes:((const struct uuid_command *)cmd)->uuid] UUIDString];
            cmd=(const void *)((const char *)cmd+cmd->cmdsize);
        }
    }
    return nil;
}
static NSArray *Fields(const void *type) {
    // Preserve the iOS 14 login-crash fix: no automatic Swift reflection there.
    if(!type || !CanReflect()) return nil;
    CountFn count=dlsym(RTLD_DEFAULT,"swift_reflectionMirror_recursiveCount");
    FieldFn child=dlsym(RTLD_DEFAULT,"swift_reflectionMirror_recursiveChildMetadata");
    OffsetFn offset=dlsym(RTLD_DEFAULT,"swift_reflectionMirror_recursiveChildOffset");
    NameFn typeName=dlsym(RTLD_DEFAULT,"swift_getTypeName");
    uintptr_t readable=0;
    if(!count || !child || !offset || !typeName || !Read((uintptr_t)type,&readable,8)) return nil;
    intptr_t total=count(type); if(total<0 || total>256) return nil;
    NSMutableArray *result=[NSMutableArray array];
    for(intptr_t i=0;i<total;i++) {
        FieldInfo field={0}; const void *childType=child(type,i,&field);
        TypeName name=childType ? typeName(childType,true) : (TypeName){0};
        NSString *key=field.name ? [NSString stringWithUTF8String:field.name] : nil;
        NSString *value=name.data && name.length<2048 ? [[NSString alloc] initWithBytes:name.data length:name.length encoding:NSUTF8StringEncoding] : nil;
        if(key && value) [result addObject:@{@"field":key,@"type":value,@"offset":@(offset(type,i))}];
        if(field.freeName) field.freeName(field.name);
    }
    return result;
}
static const void *Struct(NSString *name) {
    ResolveFn resolve=dlsym(RTLD_DEFAULT,"swift_getTypeByMangledNameInContext");
    NSString *mangled=[NSString stringWithFormat:@"4GOFA%lu%@V",(unsigned long)name.length,name];
    const void *type=resolve ? resolve(mangled.UTF8String,strlen(mangled.UTF8String),NULL,NULL) : NULL;
    uintptr_t kind=0; return Read((uintptr_t)type,&kind,8) && kind==0x200 ? type : NULL;
}
static size_t StructSize(const void *type) {
    uintptr_t witness=0; size_t size=0;
    return Read((uintptr_t)type-8,&witness,8) && Read(witness+64,&size,8) && size<=65536 ? size : 0;
}
BOOL GOFAHUDValidateFields(NSArray *fields,NSDictionary *required,size_t size,NSDictionary **offsets,NSString **reason) {
    if(!fields || !size || size>65536) { if(reason) *reason=@"metadata-unavailable"; return NO; }
    NSMutableDictionary *found=[NSMutableDictionary dictionary];
    for(NSDictionary *field in fields) {
        NSString *key=field[@"field"]; NSDictionary *spec=required[key]; if(!spec) continue;
        NSInteger off=[field[@"offset"] integerValue]; NSUInteger width=[spec[@"width"] unsignedIntegerValue];
        if(found[key] || ![spec[@"type"] isEqual:field[@"type"]] || off<[spec[@"minOffset"] integerValue] || !width || (NSUInteger)off>size || width>size-(NSUInteger)off) {
            if(reason) *reason=[@"incompatible-field:" stringByAppendingString:key ?: @"?"]; return NO;
        }
        for(NSString *other in found) {
            NSUInteger prior=[found[other] unsignedIntegerValue], priorWidth=[required[other][@"width"] unsignedIntegerValue];
            if((NSUInteger)off<prior+priorWidth && prior<(NSUInteger)off+width) { if(reason) *reason=@"overlapping-fields"; return NO; }
        }
        found[key]=@(off);
    }
    if(found.count!=required.count) { if(reason) *reason=@"required-field-missing"; return NO; }
    if(offsets) *offsets=found; if(reason) *reason=@"validated"; return YES;
}
static void Report(NSString *capability,BOOL supported,NSString *mode,NSString *reason,NSDictionary *offsets) {
    if(!IsGOFA()) return;
    static NSMutableDictionary *report; static dispatch_once_t once;
    dispatch_once(&once,^{ report=[NSMutableDictionary dictionary]; });
    @synchronized(report) {
        report[@"version"]=[NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @"";
        report[@"build"]=[NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleVersion"] ?: @"";
        report[@"uuid"]=LoadedUUID() ?: @"unavailable";
        report[capability]=@{@"supported":@(supported),@"mode":mode ?: @"",@"reason":reason ?: @"",@"offsets":offsets ?: @{}};
        [[NSJSONSerialization dataWithJSONObject:report options:NSJSONWritingPrettyPrinted error:nil] writeToFile:[NSTemporaryDirectory() stringByAppendingPathComponent:@"gofahud-source-compatibility.json"] atomically:YES];
    }
}
static BOOL Known(GOFAHUDSourceProfile *profile) {
    static const GOFAHUDSourceProfile profiles[]={
        {"4.2.1","44EBEBC6-B59E-32DA-B194-966837FC2AF2",160,200,104,{0,4,8,12,16}},
        {"4.2.2","083A8351-4BD5-3F58-B014-AA10B06180D7",176,296,120,{0,4,8,12,16}},
        {"4.2.3","819AFE0B-4933-3D16-8D74-4DBBA46D25E1",176,296,120,{0,4,8,12,16}}
    };
    NSString *version=[NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"], *uuid=LoadedUUID();
    for(unsigned i=0;i<sizeof(profiles)/sizeof(*profiles);i++) if([version isEqual:[NSString stringWithUTF8String:profiles[i].version]] && [uuid isEqual:[NSString stringWithUTF8String:profiles[i].uuid]]) { if(profile) *profile=profiles[i]; return YES; }
    return NO;
}
BOOL GOFAHUDGetSourceProfile(GOFAHUDSourceProfile *profile,NSString **loadedUUID) {
    if(!IsGOFA()) return NO;
    if(loadedUUID) *loadedUUID=LoadedUUID();
    GOFAHUDSourceProfile result;
#ifndef GOFAHUD_TEST_UNKNOWN_BUILD
    if(Known(&result)) { if(profile) *profile=result; Report(@"nativeSigns",YES,@"verified-build",@"version-and-uuid-match",nil); return YES; }
#endif
    Class cls=NSClassFromString(@"GOFA.BleManager"); NSDictionary *ble=nil,*sign=nil; NSString *reason=nil;
    // Resolve the actual offsets by field name AND type, including value bounds.
    const void *type=CanReflect() ? Struct(@"SignMessage") : NULL; size_t signSize=StructSize(type);
    ResolveFn resolve=CanReflect() ? dlsym(RTLD_DEFAULT,"swift_getTypeByMangledNameInContext") : NULL;
    const char *mangled="Sqy4GOFA11SignMessageVG";
    const void *optional=resolve ? resolve(mangled,strlen(mangled),NULL,NULL) : NULL;
    uintptr_t optionalKind=0;
    size_t optionalSize=Read((uintptr_t)optional,&optionalKind,8) && optionalKind==0x202 ? StructSize(optional) : 0;
    NSDictionary *requirements=@{@"signGosafeMessage":@{@"type":@"Swift.Optional<GOFA.SignMessage>",@"minOffset":@16,@"width":@(optionalSize)},@"lastUserSpeed":@{@"type":@"Swift.Optional<Swift.Int>",@"minOffset":@16,@"width":@9},@"connectedPeripheral":@{@"type":@"Swift.Optional<__C.CBPeripheral>",@"minOffset":@16,@"width":@8}};
    BOOL valid=cls && signSize && optionalSize>=signSize && optionalSize<=signSize+8 && GOFAHUDValidateFields(Fields((__bridge const void *)cls),requirements,class_getInstanceSize(cls),&ble,&reason);
    NSMutableDictionary *signRequired=[NSMutableDictionary dictionary];
    NSArray *names=@[@"position1",@"position2",@"distance2",@"position3",@"distance3"];
    for(NSString *name in names) signRequired[name]=@{@"type":@"Swift.UInt32",@"width":@4};
    valid=valid && GOFAHUDValidateFields(Fields(type),signRequired,signSize,&sign,&reason);
    if(valid) {
        memset(&result,0,sizeof(result)); result.version="runtime-validated"; result.uuid="runtime-metadata";
        result.signOffset=[ble[@"signGosafeMessage"] unsignedLongLongValue]; result.speedOffset=[ble[@"lastUserSpeed"] unsignedLongLongValue]; result.peripheralOffset=[ble[@"connectedPeripheral"] unsignedLongLongValue];
        for(unsigned i=0;i<5;i++) result.signFieldOffsets[i]=[sign[names[i]] unsignedLongLongValue];
        if(profile) *profile=result;
    }
    Report(@"nativeSigns",valid,@"runtime-layout",reason ?: @"metadata-unavailable",ble); return valid;
}
BOOL GOFAHUDGetLocationOffsets(uintptr_t *raw,uintptr_t *processed) {
    if(!IsGOFA()) return NO;
    if(!CanReflect()) { BOOL valid=Known(NULL); if(valid) { if(raw) *raw=8; if(processed) *processed=16; } Report(@"location",valid,@"legacy-verified-build",valid ? @"verified-layout" : @"automatic-reflection-disabled-on-ios14",nil); return valid; }
    const void *type=Struct(@"LocationUpdateEvent"); NSDictionary *offsets=nil; NSString *reason=nil;
    BOOL valid=GOFAHUDValidateFields(Fields(type),@{@"trueLocation":@{@"type":@"CLLocation",@"width":@8},@"processedLocation":@{@"type":@"CLLocation",@"width":@8}},StructSize(type),&offsets,&reason);
    if(valid) { if(raw) *raw=[offsets[@"trueLocation"] unsignedLongLongValue]; if(processed) *processed=[offsets[@"processedLocation"] unsignedLongLongValue]; }
    Report(@"location",valid,@"runtime-layout",reason,offsets); return valid;
}
BOOL GOFAHUDGetDisplayLimitOffset(uintptr_t *offset) {
    if(!IsGOFA()) return NO;
    Class cls=NSClassFromString(@"GOFA.LimitSpeedView"); Ivar ivar=cls ? class_getInstanceVariable(cls,"maxSpeedLimit") : NULL;
    NSDictionary *offsets=nil; NSString *reason=nil;
    BOOL valid=cls && ivar && GOFAHUDValidateFields(Fields((__bridge const void *)cls),@{@"maxSpeedLimit":@{@"type":@"Swift.Int",@"minOffset":@16,@"width":@8}},class_getInstanceSize(cls),&offsets,&reason);
    valid=valid && [offsets[@"maxSpeedLimit"] longLongValue]==ivar_getOffset(ivar);
    if(valid && offset) *offset=[offsets[@"maxSpeedLimit"] unsignedLongLongValue];
    Report(@"displayLimit",valid,@"runtime-field-name-and-type",reason ?: @"field-unavailable",offsets); return valid;
}
