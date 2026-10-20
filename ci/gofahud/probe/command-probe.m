#import "gofa-source-profile.h"
#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>
#import <objc/runtime.h>
#import <mach/mach.h>
#import <mach/vm_map.h>
#include <dlfcn.h>
#include <stdbool.h>
#include <string.h>
#include <notify.h>
#include <unistd.h>
#include <math.h>
#import "speed-state.h"
#import "hud-live-state.h"
static int readyToken=-1,liveSpeedToken=-1,producerToken=-1;
extern void GOFAHUDOnSourceEvent(double received,NSNumber *processedKmH);
static BOOL Ready(void) {
    uint64_t pid=0;
    return readyToken>=0 && notify_get_state(readyToken,&pid)==NOTIFY_STATUS_OK && pid==(uint64_t)getpid();
}
typedef struct { const char *data; size_t length; } CommandTypeName;
typedef CommandTypeName (__attribute__((swiftcall)) *TypeNameFn)(const void *,bool);
typedef const void *(__attribute__((swiftcall)) *ResolveFn)(const char *,size_t,const void *,const void *const *);
typedef void (*SendFn)(const void *,void * __attribute__((swift_context))) __attribute__((swiftcall));
typedef unsigned (__attribute__((swiftcall)) *TagFn)(const void *,const void *);
static SendFn originalSend;
static SendFn originalCurrentSend;
static NSDictionary *specs;
static dispatch_source_t activationTimer;
static NSMutableDictionary *seen;
static __thread BOOL recording;
static NSMutableDictionary *currentEvents;
static BOOL Read(uintptr_t p,void *v,size_t n);
static NSDictionary *LocationSpeed(const void *value) {
    ResolveFn resolve=dlsym(RTLD_DEFAULT,"swift_getTypeByMangledNameInContext");
    const char *mangled="Sqy4GOFA19LocationUpdateEventVG";
    const void *type=resolve ? resolve(mangled,strlen(mangled),NULL,NULL) : NULL;
    uintptr_t kind=0,witness=0,tagAddress=0,pointer=0;
    if(!type || !Read((uintptr_t)type,&kind,8) || kind!=0x202 || !Read((uintptr_t)type-8,&witness,8) || !Read(witness+88,&tagAddress,8) || !tagAddress) return @{@"status":@"unresolved"};
    TagFn tag=(TagFn)tagAddress;
    if(tag(value,type)!=0) return @{@"status":@"no-location"};
    if(!Read((uintptr_t)value+16,&pointer,8) || !pointer) return @{@"status":@"missing-processed-location"};
    CLLocation *location=(__bridge CLLocation *)(void *)pointer;
    if(![location isKindOfClass:CLLocation.class]) return @{@"status":@"unexpected-type"};
    double age=-location.timestamp.timeIntervalSinceNow;
    // Keep both ages: GOFA may retain an older timestamp in its processed location.
    uintptr_t rawPointer=0;
    CLLocation *raw=nil;
    if(Read((uintptr_t)value+8,&rawPointer,8) && rawPointer) raw=(__bridge CLLocation *)(void *)rawPointer;
    double rawAge=[raw isKindOfClass:CLLocation.class] ? -raw.timestamp.timeIntervalSinceNow : INFINITY;
    double sourceAge=isfinite(rawAge) ? rawAge : age;
    return @{@"status":@"processed-location",@"speedMetersPerSecond":@(location.speed),
        @"sampleAgeSeconds":@(sourceAge),@"processedAgeSeconds":@(age),
        @"rawAgeSeconds":isfinite(rawAge) ? @(rawAge) : NSNull.null,
        // Freshness is the actual GOFA emission time. Raw GPS fix age is diagnostic;
        // it must not discard an estimate GOFA's processing pipeline just emitted.
        @"validSpeed":@(isfinite(location.speed) && location.speed>=0 && location.speed*3.6<=400)};
}
static BOOL Read(uintptr_t p,void *v,size_t n) { vm_size_t got=0; return p && vm_read_overwrite(mach_task_self(),p,n,(vm_address_t)v,&got)==KERN_SUCCESS && got==n; }
static uintptr_t Rel(uintptr_t p) { int32_t d=0; return Read(p,&d,4) && d ? p+d : 0; }
static NSString *Text(uintptr_t p) { char b[256]={0}; for(unsigned i=0;i<255;i++) { if(!Read(p+i,b+i,1)) return nil; if(!b[i]) return [[NSString alloc] initWithBytes:b length:i encoding:NSUTF8StringEncoding]; } return nil; }
static NSDictionary *Spec(NSString *name) {
    ResolveFn resolve=dlsym(RTLD_DEFAULT,"swift_getTypeByMangledNameInContext");
    NSString *mangled=[NSString stringWithFormat:@"4GOFA%lu%@O",(unsigned long)name.length,name];
    const void *metadata=resolve ? resolve(mangled.UTF8String,strlen(mangled.UTF8String),NULL,NULL) : NULL;
    uintptr_t kind=0,desc=0,witness=0,tag=0;
    if(!metadata || !Read((uintptr_t)metadata,&kind,8) || kind!=0x201 || !Read((uintptr_t)metadata+8,&desc,8) || !Read((uintptr_t)metadata-8,&witness,8) || !Read(witness+88,&tag,8)) return nil;
    uintptr_t fields=Rel(desc+16); uint16_t size=0; uint32_t count=0;
    if(!Read(fields+10,&size,2) || !Read(fields+12,&count,4) || size<12 || size>64 || count>100 || !tag) return nil;
    NSMutableArray *cases=[NSMutableArray array];
    NSMutableArray *payloads=[NSMutableArray array];
    for(unsigned i=0;i<count;i++) [cases addObject:Text(Rel(fields+16+i*size+8)) ?: @"unknown"];
    TypeNameFn typeName=dlsym(RTLD_DEFAULT,"swift_getTypeName");
    for(unsigned i=0;i<count;i++) {
        uintptr_t p=Rel(fields+16+i*size+4); size_t length=0; unsigned char c=0;
        while(p && length<1024 && Read(p+length,&c,1) && c) { length+=c>=1 && c<=23 ? (c<=17 ? 5 : 9) : 1; }
        const void *t=p && length<1024 ? resolve((const char *)p,length,(const void *)desc,NULL) : NULL;
        CommandTypeName n=t && typeName ? typeName(t,true) : (CommandTypeName){0};
        NSString *s=n.data && n.length<4096 ? [[NSString alloc] initWithBytes:n.data length:n.length encoding:NSUTF8StringEncoding] : nil;
        [payloads addObject:s ?: @"none/unresolved"];
    }
    return @{@"type":name,@"metadata":[NSValue valueWithPointer:metadata],@"tag":[NSValue valueWithPointer:(void *)tag],@"cases":cases,@"payloads":payloads};
}
__attribute__((swiftcall)) static void Send(const void *value,void *subject __attribute__((swift_context))) {
    if(!recording) {
        recording=YES;
        @autoreleasepool { @try {
            TypeNameFn typeName=dlsym(RTLD_DEFAULT,"swift_getTypeName");
            Class cls=object_getClass((__bridge id)subject);
            CommandTypeName n=typeName ? typeName((__bridge const void *)cls,true) : (CommandTypeName){0};
            NSString *name=n.length<4096 && n.data ? [[NSString alloc] initWithBytes:n.data length:n.length encoding:NSUTF8StringEncoding] : nil;
            for(NSString *key in specs) if([name containsString:[@"GOFA." stringByAppendingString:key]]) {
                NSDictionary *spec=specs[key];
                TagFn tag=[spec[@"tag"] pointerValue];
                unsigned index=tag(value,[spec[@"metadata"] pointerValue]);
                NSArray *cases=spec[@"cases"];
                if(index<cases.count) {
                    NSString *caseName=cases[index];
                    @synchronized(seen) {
                        NSMutableDictionary *event=seen[[key stringByAppendingFormat:@"/%@",caseName]];
                        if(!event) { event=[@{@"type":key,@"case":caseName,@"count":@0} mutableCopy]; seen[[key stringByAppendingFormat:@"/%@",caseName]]=event; }
                        event[@"count"]=@([event[@"count"] unsignedIntegerValue]+1);
                        event[@"lastUptime"]=@(NSProcessInfo.processInfo.systemUptime);
                        NSData *json=[NSJSONSerialization dataWithJSONObject:seen options:NSJSONWritingPrettyPrinted error:nil];
                        [json writeToFile:[NSTemporaryDirectory() stringByAppendingPathComponent:@"gofahud-command-events.json"] atomically:YES];
                    }
                }
            }
        } @catch(__unused NSException *e) {} }
        recording=NO;
    }
    originalSend(value,subject);
}
static void Install(void) {
    NSMutableDictionary *found=[NSMutableDictionary dictionary];
    for(NSString *name in @[@"GofaMapViewCommand",@"MapRenderCommand"]) { NSDictionary *s=Spec(name); if(s) found[name]=s; }
    specs=found; seen=[NSMutableDictionary dictionary];
    NSMutableDictionary *publicSpecs=[NSMutableDictionary dictionary];
    for(NSString *name in found) publicSpecs[name]=@{@"cases":found[name][@"cases"],@"payloads":found[name][@"payloads"]};
    NSData *json=[NSJSONSerialization dataWithJSONObject:publicSpecs options:NSJSONWritingPrettyPrinted error:nil];
    [json writeToFile:[NSTemporaryDirectory() stringByAppendingPathComponent:@"gofahud-command-cases.json"] atomically:YES];
    void *lib=dlopen("/var/jb/usr/lib/libsubstrate.dylib",RTLD_NOW);
    void (*hook)(void *,void *,void **)=lib ? dlsym(lib,"MSHookFunction") : NULL;
    void *send=dlsym(RTLD_DEFAULT,"$s7Combine18PassthroughSubjectC4sendyyxF");
    // Enable function interception only during an explicitly prepared debug run.
    BOOL enabled=Ready();
    if(enabled && !originalSend && found.count && hook && send) hook(send,(void *)Send,(void **)&originalSend);
    [[NSString stringWithFormat:@"command hook installed=%d; enums=%lu",originalSend!=NULL,(unsigned long)found.count] writeToFile:[NSTemporaryDirectory() stringByAppendingPathComponent:@"gofahud-command-status.log"] atomically:YES encoding:NSUTF8StringEncoding error:nil];
}
__attribute__((swiftcall)) static void CurrentSend(const void *value,void *subject __attribute__((swift_context))) {
    double hudEventTime=0;
    NSNumber *hudProcessedSpeed=nil;
    if(!recording) {
        recording=YES;
        @autoreleasepool { @try {
            TypeNameFn typeName=dlsym(RTLD_DEFAULT,"swift_getTypeName");
            CommandTypeName n=typeName ? typeName((__bridge const void *)object_getClass((__bridge id)subject),true) : (CommandTypeName){0};
            NSString *name=n.data && n.length<4096 ? [[NSString alloc] initWithBytes:n.data length:n.length encoding:NSUTF8StringEncoding] : nil;
            if([name containsString:@"GOFA."]) @synchronized(currentEvents) {
                NSMutableDictionary *event=currentEvents[name];
                if(!event) currentEvents[name]=event=[@{@"count":@0} mutableCopy];
                event[@"count"]=@([event[@"count"] unsignedIntegerValue]+1);
                event[@"lastUptime"]=@(NSProcessInfo.processInfo.systemUptime);
                if([name isEqual:@"Combine.CurrentValueSubject<Swift.Optional<GOFA.LocationUpdateEvent>, Swift.Never>"]) {
                    NSDictionary *sample=LocationSpeed(value); event[@"speedSample"]=sample;
                    double speed=[sample[@"speedMetersPerSecond"] doubleValue];
                    if([sample[@"status"] isEqual:@"processed-location"] && isfinite(speed) && speed>=0 && speed*3.6<=400) hudEventTime=[event[@"lastUptime"] doubleValue];
                    if(isfinite(speed) && speed>=0 && speed*3.6<=400) hudProcessedSpeed=@(llround(speed*3.6));
                    uint64_t state=[sample[@"validSpeed"] boolValue] && isfinite(speed) && speed*3.6<=400 ?
                        GVMEncodeSample(@(llround(speed*3.6)),[event[@"lastUptime"] doubleValue]) : 0;
                    if(liveSpeedToken>=0 && notify_set_state(liveSpeedToken,state)==NOTIFY_STATUS_OK) notify_post(GVMSpeedStateName);
                    if(state && producerToken>=0 && notify_set_state(producerToken,(uint64_t)getpid())==NOTIFY_STATUS_OK) notify_post(GOFAHUDProducerName);
                }
                [[NSJSONSerialization dataWithJSONObject:currentEvents options:NSJSONWritingPrettyPrinted error:nil] writeToFile:[NSTemporaryDirectory() stringByAppendingPathComponent:@"gofahud-current-events.json"] atomically:YES];
            }
        } @catch(__unused NSException *e) {} }
        recording=NO;
    }
    originalCurrentSend(value,subject);
    if(hudEventTime>0) GOFAHUDOnSourceEvent(hudEventTime,hudProcessedSpeed);
}
static void InstallCurrent(void) {
    if(originalCurrentSend) return;
    void *lib=dlopen("/var/jb/usr/lib/libsubstrate.dylib",RTLD_NOW);
    void (*hook)(void *,void *,void **)=lib ? dlsym(lib,"MSHookFunction") : NULL;
    void *send=dlsym(RTLD_DEFAULT,"$s7Combine19CurrentValueSubjectC4sendyyxF");
    currentEvents=[NSMutableDictionary dictionary];
    if(hook && send) hook(send,(void *)CurrentSend,(void **)&originalCurrentSend);
}
__attribute__((constructor)) static void Start(void) {
    if(!GOFAHUDGetSourceProfile(NULL,NULL)) return;
    notify_register_check("local.gofahud.source.ready",&readyToken);
    notify_register_check(GVMSpeedStateName,&liveSpeedToken);
    notify_register_check(GOFAHUDProducerName,&producerToken);
    dispatch_queue_t queue=dispatch_queue_create("local.gofahud.source.activation",DISPATCH_QUEUE_SERIAL);
    activationTimer=dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER,0,0,queue);
    dispatch_source_set_timer(activationTimer,dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC),NSEC_PER_SEC,NSEC_PER_SEC/10);
    dispatch_source_set_event_handler(activationTimer,^{
        if(Ready()) {
            if(!originalSend) Install();
            InstallCurrent();
        }
    });
    dispatch_resume(activationTimer);
}
