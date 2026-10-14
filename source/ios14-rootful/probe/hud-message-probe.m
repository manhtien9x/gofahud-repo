#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>
#import <objc/runtime.h>
#import <mach/mach.h>
#import <mach/vm_map.h>
#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#include <dlfcn.h>
#include <stdbool.h>
#include <string.h>
#include <notify.h>
#include <unistd.h>
#import "speed-state.h"
#import "hud-live-state.h"
#include "hud-protocol.h"
static int producerToken=-1,hudLimitToken=-1,hudCameraToken=-1,hudSpeedToken=-1;
static NSNumber *previousHUDSpeed;
static BOOL HUDSpeedChanged;
static void Publish(int token,const char *name,uint64_t value) { if(token>=0 && notify_set_state(token,value)==NOTIFY_STATUS_OK) notify_post(name); }
static __weak id owner;
static id (*originalInit)(id,SEL,id,dispatch_queue_t,NSDictionary *);
static dispatch_source_t timer;
static void (*originalActive)(id,SEL);
static void (*originalSign)(id,SEL,NSNotification *);
static void (*originalSound)(id,SEL,NSNotification *);
static NSDictionary *lastNotification;
static void Capture(id value) { if([NSStringFromClass(object_getClass(value)) isEqual:@"GOFA.BleManager"]) owner=value; }
static void RecordNotification(NSString *handler,NSNotification *n) {
    NSMutableDictionary *types=[NSMutableDictionary dictionary],*scalars=[NSMutableDictionary dictionary];
    for(id key in n.userInfo) if([key isKindOfClass:NSString.class]) {
        id v=n.userInfo[key]; types[key]=NSStringFromClass(object_getClass(v)) ?: @"nil";
        NSString *lower=[key lowercaseString];
        BOOL warning=[lower containsString:@"position"] || [lower containsString:@"distance"] || [lower containsString:@"speed"] || [lower containsString:@"sound"] || [lower containsString:@"sign"];
        if(warning && [v isKindOfClass:NSNumber.class]) scalars[key]=v;
        if([v isKindOfClass:NSData.class]) types[key]=@{ @"type":@"NSData",@"length":@([v length]) };
    }
    @synchronized(NSClassFromString(@"GOFA.BleManager")) { lastNotification=@{@"handler":handler,@"name":n.name ?: @"",@"keys":types,@"numbers":scalars,@"receivedAt":@(NSProcessInfo.processInfo.systemUptime)}; }
}
static void Active(id self,SEL cmd) { Capture(self); originalActive(self,cmd); }
static BOOL Read(uintptr_t p,void *v,size_t n);
static void PublishSigns(id current,double received);
static void Sign(id self,SEL cmd,NSNotification *n) { Capture(self); RecordNotification(@"sign",n); originalSign(self,cmd,n); PublishSigns(self,NSProcessInfo.processInfo.systemUptime); }
static void Sound(id self,SEL cmd,NSNotification *n) { Capture(self); RecordNotification(@"sound",n); originalSound(self,cmd,n); }
typedef const void *(__attribute__((swiftcall)) *ResolveFn)(const char *,size_t,const void *,const void *const *);
typedef unsigned (*TagFn)(const void *,const void *);
static BOOL Read(uintptr_t p,void *v,size_t n) { vm_size_t got=0; return p && vm_read_overwrite(mach_task_self(),p,n,(vm_address_t)v,&got)==KERN_SUCCESS && got==n; }
static void PublishSigns(id current,double received) {
    uintptr_t p=(uintptr_t)(__bridge void *)current;
    ResolveFn resolve=dlsym(RTLD_DEFAULT,"swift_getTypeByMangledNameInContext");
    const char *mangled="Sqy4GOFA11SignMessageVG";
    const void *type=resolve ? resolve(mangled,strlen(mangled),NULL,NULL) : NULL;
    uintptr_t kind=0,witness=0,tagAddress=0;
    if(!type || !Read((uintptr_t)type,&kind,8) || kind!=0x202 || !Read((uintptr_t)type-8,&witness,8) || !Read(witness+88,&tagAddress,8) || !tagAddress) return;
    uint32_t v[5]={0};
    if(((TagFn)tagAddress)((const void *)(p+160),type)!=0 || !Read(p+160,v,sizeof(v))) return;
    uint32_t limit=GOFAHUDLimit(v[0]);
    Publish(hudLimitToken,GOFAHUDLimitName,limit ? GVMEncodeSample(@(limit),received) : 0);
    uint32_t sign=GOFAHUDIsCamera(v[1]) ? v[1] : GOFAHUDIsCamera(v[3]) ? v[3] : 0;
    uint32_t distance=sign==v[1] && sign ? v[2] : sign ? v[4] : 0;
    Publish(hudCameraToken,GOFAHUDCameraName,GOFAHUDCameraEncode(sign,distance,received));
    Publish(producerToken,GOFAHUDProducerName,(uint64_t)getpid());
}
void GOFAHUDOnSourceEvent(double received,NSNumber *processedKmH) {
    dispatch_async(dispatch_get_main_queue(),^{
        id current=owner;
        if(!current) return;
        uintptr_t p=(uintptr_t)(__bridge void *)current; int64_t speed=0; uint8_t none=1;
        if(Read(p+200,&speed,8) && Read(p+208,&none,1) && none==0 && speed>=0 && speed<=400) {
            NSNumber *value=@(speed);
            if(previousHUDSpeed && ![previousHUDSpeed isEqual:value]) HUDSpeedChanged=YES;
            previousHUDSpeed=value;
            // Do not let a possibly initial zero cache overwrite a moving source.
            if(!HUDSpeedChanged && (!processedKmH || ![processedKmH isEqual:value])) return;
            Publish(hudSpeedToken,GVMSpeedStateName,GVMEncodeSample(@(speed),received));
        }
    });
}
static BOOL CorrectBuild(void) {
    const struct mach_header_64 *h=NULL;
    for(uint32_t i=0;i<_dyld_image_count();i++) {
        const char *name=_dyld_get_image_name(i);
        if(name && [[NSString stringWithUTF8String:name] hasSuffix:@"/GOFA.app/GOFA"]) { h=(const void *)_dyld_get_image_header(i); break; }
    }
    if(!h || h->magic!=MH_MAGIC_64) return NO;
    const struct load_command *c=(const void *)(h+1);
    for(uint32_t i=0;i<h->ncmds;i++) {
        if(c->cmd==LC_UUID) {
            NSString *uuid=[[[NSUUID alloc] initWithUUIDBytes:((const struct uuid_command *)c)->uuid] UUIDString];
            [uuid writeToFile:[NSTemporaryDirectory() stringByAppendingPathComponent:@"gofahud-hud-loaded-uuid.log"] atomically:YES encoding:NSUTF8StringEncoding error:nil];
            return [uuid isEqual:@"44EBEBC6-B59E-32DA-B194-966837FC2AF2"];
        }
        if(c->cmdsize<sizeof(*c)) return NO;
        c=(const void *)((const char *)c+c->cmdsize);
    }
    return NO;
}
static id Init(id self,SEL cmd,id delegate,dispatch_queue_t queue,NSDictionary *options) {
    id result=originalInit(self,cmd,delegate,queue,options);
    if(delegate && [NSStringFromClass(object_getClass(delegate)) isEqual:@"GOFA.BleManager"]) owner=delegate;
    return result;
}
static void Inspect(void) {
    id current=owner;
    NSMutableDictionary *report=[@{@"captured":@(current!=nil),@"sampledAt":@(NSProcessInfo.processInfo.systemUptime),@"kind":@"cache-inspection-not-a-fresh-source-event"} mutableCopy];
    @synchronized(NSClassFromString(@"GOFA.BleManager")) { if(lastNotification) report[@"lastNotification"]=lastNotification; }
    Class cls=NSClassFromString(@"GOFA.BleManager");
    unsigned count=0; Method *methods=cls ? class_copyMethodList(cls,&count) : NULL;
    NSMutableArray *names=[NSMutableArray array];
    for(unsigned i=0;i<count;i++) [names addObject:@{@"selector":NSStringFromSelector(method_getName(methods[i])),@"encoding":[NSString stringWithUTF8String:method_getTypeEncoding(methods[i])]}];
    free(methods); report[@"methods"]=names;
    if(current) {
        uintptr_t p=(uintptr_t)(__bridge void *)current,connection=0; int64_t speed=0; uint8_t none=1;
        if(Read(p+200,&speed,8) && Read(p+208,&none,1) && none==0 && speed>=0 && speed<=400) report[@"lastUserSpeed"]=@(speed);
        if(Read(p+104,&connection,8)) report[@"hasConnectedPeripheral"]=@(connection!=0);
        ResolveFn resolve=dlsym(RTLD_DEFAULT,"swift_getTypeByMangledNameInContext");
        const char *mangled="Sqy4GOFA11SignMessageVG";
        const void *type=resolve ? resolve(mangled,strlen(mangled),NULL,NULL) : NULL;
        uintptr_t kind=0,witness=0,tagAddress=0;
        if(type && Read((uintptr_t)type,&kind,8) && kind==0x202 && Read((uintptr_t)type-8,&witness,8) && Read(witness+88,&tagAddress,8) && tagAddress) {
            unsigned tag=((TagFn)tagAddress)((const void *)(p+160),type);
            report[@"hasSignMessage"]=@(tag==0);
            uint32_t values[5]={0};
            if(tag==0 && Read(p+160,values,sizeof(values))) report[@"signMessage"]=@{@"position1":@(values[0]),@"position2":@(values[1]),@"distance2":@(values[2]),@"position3":@(values[3]),@"distance3":@(values[4])};
        }
    }
    [[NSJSONSerialization dataWithJSONObject:report options:NSJSONWritingPrettyPrinted error:nil] writeToFile:[NSTemporaryDirectory() stringByAppendingPathComponent:@"gofahud-hud-message-cache.json"] atomically:YES];
}
__attribute__((constructor)) static void Start(void) {
    if(![NSBundle.mainBundle.bundleIdentifier isEqual:@"com.lumi.GOFA"]) return;
    BOOL correct=CorrectBuild();
    [[NSString stringWithFormat:@"HUD probe build guard=%d",correct] writeToFile:[NSTemporaryDirectory() stringByAppendingPathComponent:@"gofahud-hud-startup.log"] atomically:YES encoding:NSUTF8StringEncoding error:nil];
    if(!correct) return;
    notify_register_check(GOFAHUDProducerName,&producerToken); notify_register_check(GOFAHUDLimitName,&hudLimitToken);
    notify_register_check(GOFAHUDCameraName,&hudCameraToken); notify_register_check(GVMSpeedStateName,&hudSpeedToken);
    Publish(producerToken,GOFAHUDProducerName,0); Publish(hudLimitToken,GOFAHUDLimitName,0); Publish(hudCameraToken,GOFAHUDCameraName,0);
    Publish(hudSpeedToken,GVMSpeedStateName,0);
    void *lib=dlopen("/usr/lib/libsubstrate.dylib",RTLD_NOW);
    void (*hook)(Class,SEL,IMP,IMP *)=lib ? dlsym(lib,"MSHookMessageEx") : NULL;
    if(hook) hook(CBCentralManager.class,@selector(initWithDelegate:queue:options:),(IMP)Init,(IMP *)&originalInit);
    Class cls=NSClassFromString(@"GOFA.BleManager");
    if(hook && cls) {
        SEL active=NSSelectorFromString(@"appDidBecomeActive"),sign=NSSelectorFromString(@"bindSignGosafeWithNotification:"),sound=NSSelectorFromString(@"bindSoundGosafeWithNotification:");
        Method m=class_getInstanceMethod(cls,active);
        if(m && method_getNumberOfArguments(m)==2) hook(cls,active,(IMP)Active,(IMP *)&originalActive);
        m=class_getInstanceMethod(cls,sign);
        if(m && method_getNumberOfArguments(m)==3) hook(cls,sign,(IMP)Sign,(IMP *)&originalSign);
        m=class_getInstanceMethod(cls,sound);
        if(m && method_getNumberOfArguments(m)==3) hook(cls,sound,(IMP)Sound,(IMP *)&originalSound);
    }
    timer=dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER,0,0,dispatch_get_main_queue());
    dispatch_source_set_timer(timer,dispatch_time(DISPATCH_TIME_NOW,12*NSEC_PER_SEC),5*NSEC_PER_SEC,NSEC_PER_SEC/10);
    dispatch_source_set_event_handler(timer,^{ Inspect(); }); dispatch_resume(timer);
}
