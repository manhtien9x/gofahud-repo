#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#include <dlfcn.h>
#include <stdbool.h>
typedef struct { const char *data; size_t length; } NameResult;
typedef struct { const char *name; void (*freeName)(const char *); bool strong; bool variable; } FieldInfo;
typedef intptr_t (__attribute__((swiftcall)) *CountFn)(const void *);
typedef const void *(__attribute__((swiftcall)) *FieldFn)(const void *,intptr_t,FieldInfo *);
typedef intptr_t (__attribute__((swiftcall)) *OffsetFn)(const void *,intptr_t);
typedef NameResult (__attribute__((swiftcall)) *NameFn)(const void *,bool);
static NSArray *DescribeType(const void *type) {
    CountFn count=dlsym(RTLD_DEFAULT,"swift_reflectionMirror_recursiveCount");
    FieldFn child=dlsym(RTLD_DEFAULT,"swift_reflectionMirror_recursiveChildMetadata");
    OffsetFn offset=dlsym(RTLD_DEFAULT,"swift_reflectionMirror_recursiveChildOffset");
    NameFn name=dlsym(RTLD_DEFAULT,"swift_getTypeName");
    if(!type || !count || !child || !offset || !name) return @[];
    intptr_t total=count(type);
    if(total<0 || total>256) return @[];
    NSMutableArray *result=[NSMutableArray array];
    for(intptr_t i=0;i<total;i++) {
        FieldInfo field={0};
        const void *fieldType=child(type,i,&field);
        if(!fieldType || !field.name) continue;
        NameResult typed=name(fieldType,true);
        NSString *fieldName=[NSString stringWithUTF8String:field.name];
        NSString *typeName=typed.length<2048 ? [[NSString alloc] initWithBytes:typed.data length:typed.length encoding:NSUTF8StringEncoding] : nil;
        if(fieldName && typeName) [result addObject:@{@"field":fieldName,@"type":typeName,@"offset":@(offset(type,i)),@"strong":@(field.strong)}];
        if(field.freeName) field.freeName(field.name);
    }
    return result;
}
static NSArray *Describe(Class cls) { return DescribeType((__bridge const void *)cls); }
static void Inspect(void) {
    NSMutableDictionary *report=[NSMutableDictionary dictionary];
    for(NSString *name in @[@"GOFA.GofaMapViewModel",@"GOFA.MapViewModel",@"GOFA.DefaultMapUsecase",@"GOFA.DefaultCarUsecase",@"GOFA.SpeedScaleVM",@"GOFA.BaseLocationProvider",@"GOFA.DefaultLocationProvider",@"GOFA.FocusViewModel",@"GOFA.GofaLocationManager",@"GOFA.LimitSpeedView",@"GOFA.BoardDistanceView"])
        report[name]=Describe(NSClassFromString(name));
    typedef const void *(__attribute__((swiftcall)) *ResolveFn)(const char *,size_t,const void *,const void * const *);
    ResolveFn resolve=dlsym(RTLD_DEFAULT,"swift_getTypeByMangledNameInContext");
    if(resolve) for(NSString *name in @[@"DatapointModel",@"BoardInfo",@"UserLocation",@"LocationUpdateEvent",@"GofaMapState",@"MapSignRenderResult",@"MapSignRenderItem",@"MapSignLayer"]){
        NSString *mangled=[NSString stringWithFormat:@"4GOFA%lu%@V",(unsigned long)name.length,name];
        const void *type=resolve(mangled.UTF8String,strlen(mangled.UTF8String),NULL,NULL);
        if(type && *(const uintptr_t *)type==0x200) report[[NSString stringWithFormat:@"GOFA.%@",name]]=DescribeType(type);
    }
    int count=objc_getClassList(NULL,0);
    __unsafe_unretained Class *classes=(__unsafe_unretained Class *)calloc((size_t)count,sizeof(Class));
    int copied=objc_getClassList(classes,count);
    NSMutableArray *subjects=[NSMutableArray array];
    for(int i=0;i<MIN(copied,count);i++) {
        NSString *name=NSStringFromClass(classes[i]);
        if([name containsString:@"Combine"] && ([name containsString:@"Board"] || [name containsString:@"Speed"] || [name containsString:@"MapState"] || [name containsString:@"Location"])) [subjects addObject:name];
    }
    free(classes); report[@"subjectClasses"]=subjects;
    NSData *data=[NSJSONSerialization dataWithJSONObject:report options:NSJSONWritingPrettyPrinted error:nil];
    [data writeToFile:[NSTemporaryDirectory() stringByAppendingPathComponent:@"gofahud-publishers.json"] atomically:YES];
}
static dispatch_source_t inspectionTimer;
static NSData *lastRequest;
static void InspectRequestedTypes(void) {
    NSData *data=[NSData dataWithContentsOfFile:[NSTemporaryDirectory() stringByAppendingPathComponent:@"gofahud-inspect-types.json"]];
    if(!data || [data isEqual:lastRequest]) return;
    lastRequest=data;
    id names=[NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    if(![names isKindOfClass:NSArray.class] || [names count]>40) return;
    typedef const void *(__attribute__((swiftcall)) *ResolveFn)(const char *,size_t,const void *,const void * const *);
    ResolveFn resolve=dlsym(RTLD_DEFAULT,"swift_getTypeByMangledNameInContext");
    NSMutableDictionary *result=[NSMutableDictionary dictionary];
    NSCharacterSet *allowed=[NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_"];
    for(id name in names) {
        if(![name isKindOfClass:NSString.class] || [name length]>100 || [name rangeOfCharacterFromSet:allowed.invertedSet].location!=NSNotFound) continue;
        Class cls=NSClassFromString([@"GOFA." stringByAppendingString:name]);
        const void *type=(__bridge const void *)cls;
        if(!type && resolve) {
            NSString *mangled=[NSString stringWithFormat:@"4GOFA%lu%@V",(unsigned long)[name length],name];
            type=resolve(mangled.UTF8String,strlen(mangled.UTF8String),NULL,NULL);
            if(type && *(const uintptr_t *)type!=0x200) type=NULL;
        }
        result[name]=type ? DescribeType(type) : @[];
    }
    [[NSJSONSerialization dataWithJSONObject:result options:NSJSONWritingPrettyPrinted error:nil] writeToFile:[NSTemporaryDirectory() stringByAppendingPathComponent:@"gofahud-requested-types.json"] atomically:YES];
}
__attribute__((constructor)) static void Start(void) {
    if(![NSBundle.mainBundle.bundleIdentifier isEqual:@"com.lumi.GOFA"]) return;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,12*NSEC_PER_SEC),dispatch_get_main_queue(),^{ Inspect(); });
    inspectionTimer=dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER,0,0,dispatch_get_main_queue());
    dispatch_source_set_timer(inspectionTimer,dispatch_time(DISPATCH_TIME_NOW,13*NSEC_PER_SEC),2*NSEC_PER_SEC,NSEC_PER_SEC/10);
    dispatch_source_set_event_handler(inspectionTimer,^{ InspectRequestedTypes(); });
    dispatch_resume(inspectionTimer);
}
