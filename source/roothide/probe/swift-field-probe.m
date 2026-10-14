#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <mach/mach.h>
#import <mach/vm_map.h>
#include <string.h>
#include <math.h>

static BOOL Read(uintptr_t address,void *buffer,size_t size) {
    vm_size_t copied=0;
    return address && vm_read_overwrite(mach_task_self(),address,size,(vm_address_t)buffer,&copied)==KERN_SUCCESS && copied==size;
}
static uintptr_t Relative(uintptr_t field) { int32_t offset=0; return Read(field,&offset,4) && offset ? field+offset : 0; }
static NSString *StringAt(uintptr_t address) {
    char bytes[256]={0};
    for(unsigned i=0;i<255;i++) {
        if(!Read(address+i,bytes+i,1)) return nil;
        if(!bytes[i]) return [[NSString alloc] initWithBytes:bytes length:i encoding:NSUTF8StringEncoding];
    }
    return nil;
}
static NSDictionary *Fields(Class cls) {
    uintptr_t metadata=(uintptr_t)(__bridge const void *)cls, descriptor=0;
    if(!Read(metadata+64,&descriptor,8)) return @{};
    uint32_t flags=0;
    if(!Read(descriptor,&flags,4) || (flags&31)!=16) return @{};
    NSString *name=StringAt(Relative(descriptor+8));
    if(![NSStringFromClass(cls) hasSuffix:[@"." stringByAppendingString:name ?: @"INVALID"]]) return @{};
    uintptr_t fieldDescriptor=Relative(descriptor+16);
    uint16_t size=0; uint32_t count=0;
    if(!Read(fieldDescriptor+10,&size,2) || !Read(fieldDescriptor+12,&count,4) || size<12 || size>64 || count>256) return @{};
    NSMutableDictionary *fields=[NSMutableDictionary dictionary];
    for(uint32_t i=0;i<count;i++) {
        uintptr_t record=fieldDescriptor+16+i*size;
        NSString *field=StringAt(Relative(record+8));
        NSString *type=StringAt(Relative(record+4));
        if(field) fields[field]=type ?: @"symbolic-type";
    }
    return fields;
}
static NSDictionary *Values(UIView *view,NSDictionary *fields) {
    NSMutableDictionary *values=[NSMutableDictionary dictionary];
    for(NSString *field in @[@"maxSpeedLimit",@"userSpeed"]) {
        NSString *type=fields[field];
        Ivar ivar=class_getInstanceVariable(view.class,field.UTF8String);
        if(!ivar || !type) continue;
        uint8_t bytes[16]={0}; double number=0; BOOL valid=NO;
        uintptr_t address=(uintptr_t)(__bridge const void *)view+ivar_getOffset(ivar);
        if([type isEqual:@"Si"] || [type isEqual:@"SiSg"]) {
            if(Read(address,bytes,[type hasSuffix:@"Sg"] ? 9 : 8) && (![type hasSuffix:@"Sg"] || !bytes[8])) { int64_t v; memcpy(&v,bytes,8); number=v; valid=YES; }
        } else if([type isEqual:@"Sd"] || [type isEqual:@"SdSg"]) {
            if(Read(address,bytes,[type hasSuffix:@"Sg"] ? 9 : 8) && (![type hasSuffix:@"Sg"] || !bytes[8])) { memcpy(&number,bytes,8); valid=YES; }
        } else if([type isEqual:@"Sf"]) { float v; if(Read(address,&v,4)) { number=v; valid=YES; } }
        if(valid && isfinite(number) && number>=0 && number<=400) values[field]=@(number);
    }
    return values;
}
static void Traverse(UIView *view,NSMutableArray *reports,unsigned depth) {
    if(depth>30) return;
    NSString *name=NSStringFromClass(view.class);
    if([@[@"GOFA.LimitSpeedView",@"GOFA.FocusSpeedInfoView"] containsObject:name]) {
        NSDictionary *fields=Fields(view.class);
        NSMutableArray *children=[NSMutableArray array];
        for(UIView *child in view.subviews) [children addObject:@{@"class":NSStringFromClass(child.class),@"frame":NSStringFromCGRect(child.frame)}];
        [reports addObject:@{@"class":name,@"fields":fields,@"values":Values(view,fields),@"children":children}];
        if(view.bounds.size.width>0 && view.bounds.size.height>0 && view.bounds.size.width<1000 && view.bounds.size.height<1000) {
            UIGraphicsImageRenderer *renderer=[[UIGraphicsImageRenderer alloc] initWithSize:view.bounds.size];
            UIImage *image=[renderer imageWithActions:^(UIGraphicsImageRendererContext *context) { [view.layer renderInContext:context.CGContext]; }];
            [UIImagePNGRepresentation(image) writeToFile:[NSTemporaryDirectory() stringByAppendingPathComponent:[name stringByAppendingString:@"-probe.png"]] atomically:YES];
        }
    }
    for(UIView *child in view.subviews) Traverse(child,reports,depth+1);
}
static void Inspect(void) {
    NSMutableArray *reports=[NSMutableArray array];
    for(UIScene *scene in UIApplication.sharedApplication.connectedScenes)
        if([scene isKindOfClass:UIWindowScene.class]) for(UIWindow *window in ((UIWindowScene *)scene).windows) Traverse(window,reports,0);
    NSData *json=[NSJSONSerialization dataWithJSONObject:reports options:NSJSONWritingPrettyPrinted error:nil];
    [json writeToFile:[NSTemporaryDirectory() stringByAppendingPathComponent:@"gofahud-swift-fields.json"] atomically:YES];
}
__attribute__((constructor)) static void Start(void) {
    if(![NSBundle.mainBundle.bundleIdentifier isEqual:@"com.lumi.GOFA"]) return;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,10*NSEC_PER_SEC),dispatch_get_main_queue(),^{ Inspect(); });
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,25*NSEC_PER_SEC),dispatch_get_main_queue(),^{ Inspect(); });
}
