#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>
#import <objc/runtime.h>
#include <dlfcn.h>
static void (*originalStart)(id,SEL);
static void (*originalStop)(id,SEL);
static void (*originalBackground)(id,SEL,BOOL);
static NSMutableArray *events;
static void Record(CLLocationManager *manager,NSString *action) {
    @synchronized(events) {
        [events addObject:@{@"action":action,@"uptime":@(NSProcessInfo.processInfo.systemUptime),
            @"applicationState":@(UIApplication.sharedApplication.applicationState),
            @"authorization":@(manager.authorizationStatus),
            @"allowsBackground":@(manager.allowsBackgroundLocationUpdates),
            @"pausesAutomatically":@(manager.pausesLocationUpdatesAutomatically),
            @"distanceFilter":@(manager.distanceFilter),
            @"delegateType":manager.delegate ? NSStringFromClass(object_getClass(manager.delegate)) : @"none"}];
        if(events.count>200) [events removeObjectAtIndex:0];
        [[NSJSONSerialization dataWithJSONObject:events options:NSJSONWritingPrettyPrinted error:nil]
            writeToFile:[NSTemporaryDirectory() stringByAppendingPathComponent:@"gofahud-location-audit.json"] atomically:YES];
    }
}
static void Start(id self,SEL cmd) { Record(self,@"startUpdatingLocation"); originalStart(self,cmd); }
static void Stop(id self,SEL cmd) { Record(self,@"stopUpdatingLocation"); originalStop(self,cmd); }
static void Background(id self,SEL cmd,BOOL value) {
    originalBackground(self,cmd,value); Record(self,@"setAllowsBackgroundLocationUpdates");
}
__attribute__((constructor)) static void InstallLocationAudit(void) {
    if(![NSBundle.mainBundle.bundleIdentifier isEqual:@"com.lumi.GOFA"]) return;
    events=[NSMutableArray array];
    void *lib=dlopen("/usr/lib/libsubstrate.dylib",RTLD_NOW);
    void (*hook)(Class,SEL,IMP,IMP *)=lib ? dlsym(lib,"MSHookMessageEx") : NULL;
    if(!hook) return;
    hook(CLLocationManager.class,@selector(startUpdatingLocation),(IMP)Start,(IMP *)&originalStart);
    hook(CLLocationManager.class,@selector(stopUpdatingLocation),(IMP)Stop,(IMP *)&originalStop);
    hook(CLLocationManager.class,@selector(setAllowsBackgroundLocationUpdates:),(IMP)Background,(IMP *)&originalBackground);
}
