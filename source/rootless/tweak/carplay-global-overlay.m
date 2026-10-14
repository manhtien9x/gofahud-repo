#import <UIKit/UIKit.h>
#import <notify.h>
#include <unistd.h>
#include <dlfcn.h>
#import <objc/runtime.h>
#import <objc/message.h>
extern void GOFACarHUDInitializeSource(void);
extern void GOFACarHUDRefresh(UIView *view);
extern void GOFACarHUDEnableInteraction(UIView *view);
extern void GOFACarHUDSetGOFAActive(BOOL active);
@interface GOFACarGlobalWindow : UIWindow
@end
@implementation GOFACarGlobalWindow
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *card=[self.rootViewController.view viewWithTag:41059];
    if(!card || card.hidden || ![card pointInside:[self convertPoint:point toView:card] withEvent:event]) return nil;
    return [super hitTest:point withEvent:event];
}
@end
static NSInteger Rank(UIWindow *window) {
    NSString *name=NSStringFromClass(window.class);
    if([name isEqual:@"CARNotificationWindow"]) return 100;
    if([name isEqual:@"CARStatusBarHostWindow"]) return 80;
    if([name isEqual:@"CPSWindow"]) return 60;
    if([name isEqual:@"UIWindow"]) return 40;
    return 0;
}
static NSMapTable<UIWindow *,GOFACarGlobalWindow *> *overlays;
static NSMapTable<UIWindow *,UIView *> *nativeCards;
static int ownerToken=-1,traceToken=-1;
static int carLaunchToken=-1;
static void LaunchReport(NSString *stage,id app,id dashboard,NSString *detail) {
    NSDictionary *row=@{@"unixTime":@(NSDate.date.timeIntervalSince1970),@"target":@"CarPlay",@"stage":stage,@"applicationClass":app ? NSStringFromClass([app class]) : @"nil",@"dashboardClass":dashboard ? NSStringFromClass([dashboard class]) : @"nil",@"detail":detail ?: @""};
    [[NSJSONSerialization dataWithJSONObject:row options:0 error:nil] writeToFile:@"/var/mobile/Library/Logs/GofaHUD-carplay-open-result.json" atomically:YES];
}
static void OpenGOFAOnCarPlay(void) {
    @try {
        id delegate=UIApplication.sharedApplication.delegate;
        SEL librarySel=NSSelectorFromString(@"sharedApplicationLibrary");
        if(![delegate respondsToSelector:librarySel]) { LaunchReport(@"missing-library",nil,nil,nil); return; }
        id library=((id(*)(id,SEL))objc_msgSend)(delegate,librarySel);
        SEL lookup=NSSelectorFromString(@"installedApplicationWithBundleIdentifier:");
        if(![library respondsToSelector:lookup]) { LaunchReport(@"missing-lookup",nil,nil,nil); return; }
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0),^{ @autoreleasepool { @try {
            id application=((id(*)(id,SEL,id))objc_msgSend)(library,lookup,@"com.lumi.GOFA");
            dispatch_async(dispatch_get_main_queue(),^{ @try {
                SEL current=NSSelectorFromString(@"_currentDashboard"),route=NSSelectorFromString(@"_launchAppWithInfo:forURL:");
                id dashboard=[delegate respondsToSelector:current] ? ((id(*)(id,SEL))objc_msgSend)(delegate,current) : nil;
                Method method=dashboard ? class_getInstanceMethod([dashboard class],route) : NULL;
                if(!application || !method || method_getNumberOfArguments(method)!=4) { LaunchReport(@"missing-target-or-route",application,dashboard,nil); return; }
                Class infoClass=NSClassFromString(@"CARApplicationLaunchInfo");
                SEL factory=NSSelectorFromString(@"launchInfoForApplication:");
                if(![infoClass respondsToSelector:factory]) { LaunchReport(@"missing-launch-info-factory",application,dashboard,nil); return; }
                id info=((id(*)(id,SEL,id))objc_msgSend)(infoClass,factory,application);
                if(!info || ![info respondsToSelector:NSSelectorFromString(@"application")]) { LaunchReport(@"invalid-launch-info",application,dashboard,nil); return; }
                LaunchReport(@"submitting",application,dashboard,nil);
                ((void(*)(id,SEL,id,id))objc_msgSend)(dashboard,route,info,nil);
                LaunchReport(@"submitted",application,dashboard,nil);
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW,2*NSEC_PER_SEC),dispatch_get_main_queue(),^{
                    SEL active=NSSelectorFromString(@"activeBundleIdentifier");
                    id bundle=[dashboard respondsToSelector:active] ? ((id(*)(id,SEL))objc_msgSend)(dashboard,active) : nil;
                    LaunchReport([bundle isEqual:@"com.lumi.GOFA"] ? @"gofa-active-on-carplay" : @"different-carplay-app",application,dashboard,[bundle isKindOfClass:NSString.class] ? bundle : @"unknown");
                });
            } @catch(NSException *e) { LaunchReport(@"route-exception",application,nil,e.reason); } });
        } @catch(NSException *e) { LaunchReport(@"lookup-exception",nil,nil,e.reason); } } });
    } @catch(NSException *e) { LaunchReport(@"request-exception",nil,nil,e.reason); }
}
static void (*originalLaunchRoute)(id,SEL,id,id);
static void ObserveLaunch(id dashboard,SEL selector,id info,id url) {
    NSDictionary *row=@{@"unixTime":@(NSDate.date.timeIntervalSince1970),@"infoClass":info ? NSStringFromClass([info class]) : @"nil",@"hasBundleIdentifier":@([info respondsToSelector:NSSelectorFromString(@"bundleIdentifier")]),@"hasApplication":@([info respondsToSelector:NSSelectorFromString(@"application")])};
    [[NSJSONSerialization dataWithJSONObject:row options:0 error:nil] writeToFile:@"/var/mobile/Library/Logs/GofaHUD-carplay-native-launch.json" atomically:YES];
    originalLaunchRoute(dashboard,selector,info,url);
}
static void ProbeLaunchRoutes(void) {
    unsigned count=0; Class *classes=objc_copyClassList(&count); NSMutableArray *rows=[NSMutableArray array];
    for(unsigned i=0;i<count;i++) {
        NSString *name=NSStringFromClass(classes[i]);
        if(![name hasPrefix:@"CAR"] && ![name hasPrefix:@"_CAR"] && ![name hasPrefix:@"CRS"]) continue;
        NSMutableArray *methods=[NSMutableArray array];
        for(unsigned meta=0;meta<2;meta++) {
            unsigned n=0; Method *list=class_copyMethodList(meta ? object_getClass(classes[i]) : classes[i],&n);
            for(unsigned j=0;j<n;j++) {
                NSString *sel=NSStringFromSelector(method_getName(list[j])); NSString *lower=sel.lowercaseString;
                if([@[@"CARApplication",@"CARDashboard",@"CARAppHistory",@"CARApplicationLaunchInfo",@"CARLeafIcon",@"CARApplicationLibrary",@"CARIconProvider",@"CARApplicationInfo"] containsObject:name] || [lower containsString:@"launch"] || [lower containsString:@"activateapplication"] || [lower containsString:@"openapplication"] || [lower containsString:@"shared"] || [lower containsString:@"workspace"])
                    [methods addObject:@{@"selector":sel,@"encoding":[NSString stringWithUTF8String:method_getTypeEncoding(list[j])],@"classMethod":@(meta)}];
            }
            free(list);
        }
        if(methods.count) {
            NSMutableArray *ivars=[NSMutableArray array]; unsigned n=0; Ivar *vars=class_copyIvarList(classes[i],&n);
            for(unsigned j=0;j<n;j++) [ivars addObject:@{@"name":[NSString stringWithUTF8String:ivar_getName(vars[j])],@"type":[NSString stringWithUTF8String:ivar_getTypeEncoding(vars[j])]}]; free(vars);
            [rows addObject:@{@"class":name,@"methods":methods,@"ivars":ivars}];
        }
    }
    free(classes);
    id delegate=UIApplication.sharedApplication.delegate;
    if([delegate respondsToSelector:NSSelectorFromString(@"sharedApplicationLibrary")]) {
        id library=((id(*)(id,SEL))objc_msgSend)(delegate,NSSelectorFromString(@"sharedApplicationLibrary"));
        unsigned n=0; Method *list=class_copyMethodList(object_getClass(library),&n); NSMutableArray *methods=[NSMutableArray array];
        for(unsigned i=0;i<n;i++) [methods addObject:@{@"selector":NSStringFromSelector(method_getName(list[i])),@"encoding":[NSString stringWithUTF8String:method_getTypeEncoding(list[i])]}]; free(list);
        [rows addObject:@{@"class":library ? NSStringFromClass([library class]) : @"nil-library",@"methods":methods,@"role":@"active-application-library"}];
    }
    [[NSJSONSerialization dataWithJSONObject:rows options:NSJSONWritingPrettyPrinted error:nil] writeToFile:@"/var/mobile/Library/Logs/GofaHUD-carplay-launch-routes.json" atomically:YES];
}
static UIView *(*originalHit)(UIWindow *,SEL,CGPoint,UIEvent *);
static UIView *NotificationHit(UIWindow *window,SEL selector,CGPoint point,UIEvent *event) {
    UIView *card=[nativeCards objectForKey:window];
    if(card && !card.hidden && [card pointInside:[window convertPoint:point toView:card] withEvent:event])
        return [card hitTest:[window convertPoint:point toView:card] withEvent:event];
    return originalHit ? originalHit(window,selector,point,event) : nil;
}
static BOOL IsCarWindow(UIWindow *window) {
    if([window isKindOfClass:GOFACarGlobalWindow.class] || !Rank(window) || window.bounds.size.width<400 || window.bounds.size.height<240) return NO;
    NSString *role=window.windowScene.session.role;
    return [role containsString:@"CarPlay"] || window.screen!=UIScreen.mainScreen;
}
static void Tick(void) {
    double now=NSProcessInfo.processInfo.systemUptime;
    uint64_t lease=0; notify_get_state(ownerToken,&lease);
    double age=now-(double)(lease>>24)/1000;
    BOOL other=lease && age>=0 && age<3 && (lease&0xffffff)!=(uint64_t)getpid();
    BOOL primary=[NSBundle.mainBundle.bundleIdentifier isEqual:@"com.apple.CarPlayApp"];
    if(primary) other=NO;
    if(primary) {
        id delegate=UIApplication.sharedApplication.delegate;
        SEL current=NSSelectorFromString(@"_currentDashboard"),active=NSSelectorFromString(@"activeBundleIdentifier");
        id dashboard=[delegate respondsToSelector:current] ? ((id(*)(id,SEL))objc_msgSend)(delegate,current) : nil;
        if([dashboard respondsToSelector:active]) {
            id bundle=((id(*)(id,SEL))objc_msgSend)(dashboard,active);
            GOFACarHUDSetGOFAActive([bundle isKindOfClass:NSString.class] && [bundle isEqual:@"com.lumi.GOFA"]);
        }
    }
    BOOL visible=NO;
    NSMutableArray *report=[NSMutableArray array];
    NSMutableSet *bases=[NSMutableSet set];
    for(UIWindow *window in UIApplication.sharedApplication.windows) [bases addObject:window];
    for(UIScene *scene in UIApplication.sharedApplication.connectedScenes) if([scene isKindOfClass:UIWindowScene.class])
        for(UIWindow *window in ((UIWindowScene *)scene).windows) [bases addObject:window];
    NSArray *ordered=[bases.allObjects sortedArrayUsingComparator:^NSComparisonResult(UIWindow *a,UIWindow *b) {
        if(Rank(a)!=Rank(b)) return Rank(a)>Rank(b) ? NSOrderedAscending : NSOrderedDescending;
        return [a.windowScene.session.persistentIdentifier ?: @"" compare:b.windowScene.session.persistentIdentifier ?: @""];
    }];
    for(UIWindow *base in ordered) {
        if([base isKindOfClass:GOFACarGlobalWindow.class]) continue;
        BOOL eligible=IsCarWindow(base) && !base.hidden && base.alpha>0;
        [report addObject:@{@"class":NSStringFromClass(base.class),@"frame":NSStringFromCGRect(base.frame),@"bounds":NSStringFromCGRect(base.bounds),@"hidden":@(base.hidden),@"alpha":@(base.alpha),@"role":base.windowScene.session.role ?: @"legacy",@"sceneID":base.windowScene.session.persistentIdentifier ?: @"legacy",@"activation":@(base.windowScene.activationState),@"level":@(base.windowLevel),@"controller":base.rootViewController ? NSStringFromClass(base.rootViewController.class) : @"nil",@"mainScreen":@(base.screen==UIScreen.mainScreen),@"eligible":@(eligible)}];
        GOFACarGlobalWindow *overlay=[overlays objectForKey:base];
        UIView *native=[nativeCards objectForKey:base];
        if(!eligible || other || visible) { overlay.hidden=YES; native.hidden=YES; continue; }
        if(primary && [NSStringFromClass(base.class) isEqual:@"CARNotificationWindow"]) {
            UIView *host=base.rootViewController.viewIfLoaded;
            if(!host || host.window!=base) continue;
            if(!native) { native=[[NSClassFromString(@"GOFACarHUD") alloc] initWithFrame:CGRectMake(0,0,148,84)]; GOFACarHUDEnableInteraction(native); [nativeCards setObject:native forKey:base]; }
            if(native.superview!=host) [host addSubview:native];
            [host bringSubviewToFront:native]; GOFACarHUDRefresh(native); visible=!native.hidden;
            continue;
        }
        if(!overlay) {
            overlay=base.windowScene ? [[GOFACarGlobalWindow alloc] initWithWindowScene:base.windowScene] : [[GOFACarGlobalWindow alloc] initWithFrame:base.bounds];
            if(!base.windowScene) overlay.screen=base.screen;
            overlay.backgroundColor=UIColor.clearColor; overlay.windowLevel=10000000;
            UIViewController *controller=[UIViewController new]; controller.view.backgroundColor=UIColor.clearColor;
            overlay.rootViewController=controller;
            UIView *card=[[NSClassFromString(@"GOFACarHUD") alloc] initWithFrame:CGRectMake(0,0,148,84)]; card.tag=41059;
            GOFACarHUDEnableInteraction(card);
            [controller.view addSubview:card]; [overlays setObject:overlay forKey:base];
        }
        overlay.frame=base.frame; overlay.hidden=NO;
        UIView *card=[overlay.rootViewController.view viewWithTag:41059]; GOFACarHUDRefresh(card);
        visible=card && !card.hidden;
    }
    for(UIWindow *base in overlays.keyEnumerator) if(![bases containsObject:base]) [overlays objectForKey:base].hidden=YES;
    if(visible && !other) {
        notify_set_state(ownerToken,((uint64_t)(now*1000)<<24)|((uint64_t)getpid()&0xffffff));
        notify_set_state(traceToken,((uint64_t)(now*1000)<<1)|1);
    } else if(!other && (lease&0xffffff)==(uint64_t)getpid()) {
        notify_set_state(ownerToken,0); notify_set_state(traceToken,(uint64_t)(now*1000)<<1);
    }
    static double last=0;
    if(now-last>=5) {
        last=now;
        NSDictionary *row=@{@"unixTime":@(NSDate.date.timeIntervalSince1970),@"uptime":@(now),@"process":NSBundle.mainBundle.bundleIdentifier ?: @"",@"globalVisible":@(visible),@"anotherHostOwnsHUD":@(other),@"applicationState":@(UIApplication.sharedApplication.applicationState),@"windows":report};
        NSString *path=[@"/var/mobile/Library/Logs/GofaHUD-carplay-global-" stringByAppendingFormat:@"%@.jsonl",NSBundle.mainBundle.bundleIdentifier];
        NSFileManager *fm=NSFileManager.defaultManager;
        if([fm attributesOfItemAtPath:path error:nil].fileSize>2*1024*1024) { NSString *old=[path stringByAppendingString:@".1"]; [fm removeItemAtPath:old error:nil]; [fm moveItemAtPath:path toPath:old error:nil]; }
        NSData *data=[NSJSONSerialization dataWithJSONObject:row options:0 error:nil];
        FILE *f=fopen(path.fileSystemRepresentation,"a");
        if(!f) {
            path=[NSTemporaryDirectory() stringByAppendingPathComponent:@"gofahud-carplay-global.jsonl"];
            if([fm attributesOfItemAtPath:path error:nil].fileSize>2*1024*1024) { NSString *old=[path stringByAppendingString:@".1"]; [fm removeItemAtPath:old error:nil]; [fm moveItemAtPath:path toPath:old error:nil]; }
            f=fopen(path.fileSystemRepresentation,"a");
        }
        if(f) { fwrite(data.bytes,1,data.length,f); fputc('\n',f); fclose(f); }
    }
}
__attribute__((constructor)) static void StartGlobal(void) {
    NSString *bundle=NSBundle.mainBundle.bundleIdentifier;
    if(![bundle isEqual:@"com.apple.CarPlayApp"] && ![bundle isEqual:@"com.apple.CarPlayTemplateUIHost"]) return;
    dispatch_async(dispatch_get_main_queue(),^{
        overlays=[NSMapTable weakToStrongObjectsMapTable]; nativeCards=[NSMapTable weakToStrongObjectsMapTable]; GOFACarHUDInitializeSource();
        if([bundle isEqual:@"com.apple.CarPlayApp"]) {
            void *lib=dlopen("/var/jb/usr/lib/libsubstrate.dylib",RTLD_NOW);
            void (*hook)(Class,SEL,IMP,IMP *)=lib ? dlsym(lib,"MSHookMessageEx") : NULL;
            Class windowClass=NSClassFromString(@"CARNotificationWindow");
            if(hook && windowClass) hook(windowClass,@selector(hitTest:withEvent:),(IMP)NotificationHit,(IMP *)&originalHit);
            Class dashboardClass=NSClassFromString(@"CARDashboard");
            SEL route=NSSelectorFromString(@"_launchAppWithInfo:forURL:");
            Method method=class_getInstanceMethod(dashboardClass,route);
            if(hook && method && method_getNumberOfArguments(method)==4) hook(dashboardClass,route,(IMP)ObserveLaunch,(IMP *)&originalLaunchRoute);
            notify_register_dispatch("local.gofahud.carplay.open-gofa",&carLaunchToken,dispatch_get_main_queue(),^(int token) { (void)token; OpenGOFAOnCarPlay(); });
        }
        notify_register_check("local.gofahud.carplay.global",&ownerToken); notify_register_check("local.gofahud.carplay.trace",&traceToken);
        [NSNotificationCenter.defaultCenter addObserverForName:UIWindowDidBecomeVisibleNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *n) { if(![n.object isKindOfClass:GOFACarGlobalWindow.class]) dispatch_async(dispatch_get_main_queue(),^{ Tick(); }); }];
        NSTimer *timer=[NSTimer timerWithTimeInterval:.5 repeats:YES block:^(NSTimer *t) { (void)t; Tick(); }];
        [NSRunLoop.mainRunLoop addTimer:timer forMode:NSRunLoopCommonModes]; Tick();
        if([bundle isEqual:@"com.apple.CarPlayApp"]) dispatch_after(dispatch_time(DISPATCH_TIME_NOW,2*NSEC_PER_SEC),dispatch_get_main_queue(),^{ ProbeLaunchRoutes(); });
    });
}
