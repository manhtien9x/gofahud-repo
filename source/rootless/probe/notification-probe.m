#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#include <dlfcn.h>
#include <string.h>
static NSMutableDictionary *originals;
static NSMutableArray *events;
static void (*postOriginal)(id,SEL,id,id,id);
static void Record(NSNotification *n,NSString *receiver,NSString *selector);
static id Schema(id value, unsigned depth) {
    if (!value) return @"nil";
    if (depth>3) return NSStringFromClass([value class]);
    if ([value isKindOfClass:NSDictionary.class]) {
        NSMutableDictionary *result=[NSMutableDictionary dictionary];
        for (id key in value) {
            if (![key isKindOfClass:NSString.class] || [key length]>100) continue;
            result[key]=Schema(value[key],depth+1);
        }
        return result;
    }
    if ([value isKindOfClass:NSArray.class]) {
        NSMutableArray *result=[NSMutableArray array];
        for (id item in value) { if (result.count>=3) break; [result addObject:Schema(item,depth+1)]; }
        return result;
    }
    // Deliberately inspect types, never descriptions or account/location values.
    return NSStringFromClass([value class]);
}
static void GOFAHandleNotification(id self,SEL selector,id notification) {
    NSString *key=[NSString stringWithFormat:@"%@/%@",NSStringFromClass([self class]),NSStringFromSelector(selector)];
    IMP original=[originals[key] pointerValue];
    if (!original) {
        Class cls=class_getSuperclass([self class]);
        while(cls && !original) {
            key=[NSString stringWithFormat:@"%@/%@",NSStringFromClass(cls),NSStringFromSelector(selector)];
            original=[originals[key] pointerValue]; cls=class_getSuperclass(cls);
        }
    }
    @try {
        if ([notification isKindOfClass:NSNotification.class]) {
            Record(notification,NSStringFromClass([self class]),NSStringFromSelector(selector));
        }
    } @catch (__unused NSException *exception) {}
    if (original) ((void(*)(id,SEL,id))original)(self,selector,notification);
}
static void Record(NSNotification *n,NSString *receiver,NSString *selector) {
    NSDictionary *event=@{@"receiver":receiver,@"selector":selector,@"name":n.name,
        @"objectType":n.object ? NSStringFromClass([n.object class]) : @"nil",@"userInfoSchema":Schema(n.userInfo,0)};
    @synchronized(events) {
        if (![events containsObject:event]) [events addObject:event];
        while(events.count>40) [events removeObjectAtIndex:0];
        NSData *data=[NSJSONSerialization dataWithJSONObject:events options:NSJSONWritingPrettyPrinted error:nil];
        [data writeToFile:[NSTemporaryDirectory() stringByAppendingPathComponent:@"gofahud-notification-schema.json"] atomically:YES];
    }
}
static void Post(id self,SEL sel,id name,id object,id info) {
    @try {
        if([name isKindOfClass:NSString.class]) {
            NSRegularExpression *pattern=[NSRegularExpression regularExpressionWithPattern:@"speed|board|camera|traffic" options:NSRegularExpressionCaseInsensitive error:nil];
            if([pattern firstMatchInString:name options:0 range:NSMakeRange(0,[name length])])
                Record([NSNotification notificationWithName:name object:object userInfo:info],@"NSNotificationCenter",@"postNotificationName:object:userInfo:");
        }
    } @catch(__unused NSException *e) {}
    postOriginal(self,sel,name,object,info);
}
__attribute__((constructor)) static void Start(void) {
    if (![NSBundle.mainBundle.bundleIdentifier isEqual:@"com.lumi.GOFA"] ||
        ![[NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"] isEqual:@"4.2.1"]) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        originals=[NSMutableDictionary dictionary]; events=[NSMutableArray array];
        void *lib=dlopen("/var/jb/usr/lib/libsubstrate.dylib",RTLD_NOW);
        void (*hook)(Class,SEL,IMP,IMP *)=lib ? dlsym(lib,"MSHookMessageEx") : NULL;
        NSString *statusPath=[NSTemporaryDirectory() stringByAppendingPathComponent:@"gofahud-hook-status.log"];
        if (!hook) { [@"hook export unavailable" writeToFile:statusPath atomically:YES encoding:NSUTF8StringEncoding error:nil]; return; }
        Class center=object_getClass(NSNotificationCenter.defaultCenter);
        SEL post=NSSelectorFromString(@"postNotificationName:object:userInfo:");
        Method m=class_getInstanceMethod(center,post);
        if(m && !strcmp(method_getTypeEncoding(m),"v40@0:8@16@24@32"))
            hook(center,post,(IMP)Post,(IMP *)&postOriginal);
        for (NSString *className in @[@"GOFA.MapViewModel",@"GOFA.MapCarplayViewModel",@"GOFA.FocusViewController",@"GOFA.FocusCarplayVC"])
            for (NSString *name in @[@"bindSpeedBoardWithNotification:",@"bindNextBoardWithNotification:",@"bindOtherBoardWithNotification:",@"bindDataWithNotification:",@"bindOtherBoardFocusViewWithNotification:",@"bindBoardInfoWithNotification:"]) {
                Class cls=NSClassFromString(className); SEL selector=NSSelectorFromString(name);
                Method method=class_getInstanceMethod(cls,selector);
                if (!method || strcmp(method_getTypeEncoding(method),"v24@0:8@16")) continue;
                IMP original=NULL; hook(cls,selector,(IMP)GOFAHandleNotification,&original);
                if(original) originals[[NSString stringWithFormat:@"%@/%@",className,name]]=[NSValue valueWithPointer:original];
            }
        [[NSString stringWithFormat:@"center hooked=%d; selectors=%lu",postOriginal!=NULL,(unsigned long)originals.count] writeToFile:statusPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
    });
}
