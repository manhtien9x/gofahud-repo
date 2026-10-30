#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <mach/mach.h>
#include <notify.h>
#include <unistd.h>
#include <math.h>
#import "gofa-source-profile.h"
#import "speed-state.h"
#import "hud-live-state.h"

// GOFA can update its visible limit without populating BleManager.
// Observe the verified Int ivar, never infer a limit from a road or GPS speed.
// A repeated display value is a retained observation, not a fresh road event.
static __weak UIView *limitView;
static dispatch_source_t displayTimer;
static int limitToken=-1, producerToken=-1, readyToken=-1;
static NSNumber *lastLimit;
static BOOL nativeSignsSeen, displayValidated;
static uintptr_t displayLimitOffset;
static double lastValidationTry=-INFINITY;
void GOFAHUDDisplayBridgeNativeSignsSeen(void) { nativeSignsSeen=YES; }
static BOOL ReadDisplayInt(UIView *view,int64_t *result) {
    Class cls=NSClassFromString(@"GOFA.LimitSpeedView");
    if(!cls || ![view isKindOfClass:cls]) return NO;
    Ivar ivar=class_getInstanceVariable(cls,"maxSpeedLimit");
    if(!ivar || !displayValidated || ivar_getOffset(ivar)!=(ptrdiff_t)displayLimitOffset) return NO;
    vm_size_t copied=0;
    return vm_read_overwrite(mach_task_self(),(uintptr_t)(__bridge void *)view+ivar_getOffset(ivar),8,(vm_address_t)result,&copied)==KERN_SUCCESS && copied==8;
}
static UIView *FindLimit(UIView *view,unsigned depth) {
    if(depth>30 || view.hidden) return nil;
    if([NSStringFromClass(view.class) isEqual:@"GOFA.LimitSpeedView"]) return view;
    for(UIView *child in view.subviews) { UIView *found=FindLimit(child,depth+1); if(found) return found; }
    return nil;
}
static void ObserveDisplay(void) {
    if(nativeSignsSeen) return;
    double now=NSProcessInfo.processInfo.systemUptime;
    if(!displayValidated) {
        if(now-lastValidationTry<5) return;
        lastValidationTry=now;
        displayValidated=GOFAHUDGetDisplayLimitOffset(&displayLimitOffset);
        if(!displayValidated) return;
    }
    uint64_t ready=0;
    if(notify_get_state(readyToken,&ready)!=NOTIFY_STATUS_OK || ready!=(uint64_t)getpid()) return;
    UIView *view=limitView;
    if(!view || !view.window) {
        for(UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
            if(![scene isKindOfClass:UIWindowScene.class]) continue;
            for(UIWindow *window in ((UIWindowScene *)scene).windows) {
                view=FindLimit(window,0); if(view) break;
            }
            if(view) break;
        }
        limitView=view;
    }
    int64_t number=0;
    if(!view || !view.window || view.hidden || !ReadDisplayInt(view,&number)) return;
    // Unknown display values never turn into a guessed speed limit.
    if(number<0 || number>160 || (number!=0 && number%5!=0)) return;
    NSNumber *value=@(number);
    if([lastLimit isEqual:value]) return;
    double observed=NSProcessInfo.processInfo.systemUptime;
    uint64_t sample=number ? GVMEncodeSample(value,observed) : 0;
    if(notify_set_state(limitToken,sample)!=NOTIFY_STATUS_OK) return;
    lastLimit=value;
    notify_post(GOFAHUDLimitName);
    if(notify_set_state(producerToken,(uint64_t)getpid())==NOTIFY_STATUS_OK) notify_post(GOFAHUDProducerName);
    NSDictionary *report=@{@"source":@"GOFA.LimitSpeedView.maxSpeedLimit",@"limitKmH":value,@"observedUptime":@(observed),@"observation":@"display-value-change-or-initial-snapshot",@"foreground":@(UIApplication.sharedApplication.applicationState==UIApplicationStateActive),@"repeatedValueDoesNotRefreshTimestamp":@YES};
    [[NSJSONSerialization dataWithJSONObject:report options:NSJSONWritingPrettyPrinted error:nil] writeToFile:[NSTemporaryDirectory() stringByAppendingPathComponent:@"gofahud-display-limit.json"] atomically:YES];
}
__attribute__((constructor)) static void Start(void) {
    if(![NSBundle.mainBundle.bundleIdentifier isEqual:@"com.lumi.GOFA"]) return;
    notify_register_check(GOFAHUDLimitName,&limitToken);
    notify_register_check(GOFAHUDProducerName,&producerToken);
    notify_register_check("local.gofahud.source.ready",&readyToken);
    displayTimer=dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER,0,0,dispatch_get_main_queue());
    dispatch_source_set_timer(displayTimer,dispatch_time(DISPATCH_TIME_NOW,2*NSEC_PER_SEC),NSEC_PER_SEC,NSEC_PER_SEC/10);
    dispatch_source_set_event_handler(displayTimer,^{ ObserveDisplay(); });
    dispatch_resume(displayTimer);
}
