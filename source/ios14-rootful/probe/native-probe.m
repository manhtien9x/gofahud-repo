#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#include <stdlib.h>
#include <string.h>

// Structural diagnostics only: no property values, user text, routes or location.
static void Inspect(void) {
    @autoreleasepool {
        NSBundle *bundle = NSBundle.mainBundle;
        if (![@[@"com.lumi.GOFA", @"com.google.Maps"] containsObject:bundle.bundleIdentifier]) return;
        int count = objc_getClassList(NULL, 0);
        __unsafe_unretained Class *classes = (__unsafe_unretained Class *)calloc((size_t)count, sizeof(Class));
        if (!classes) return;
        int copied = objc_getClassList(classes, count);
        NSMutableArray *allNames = [NSMutableArray array], *details = [NSMutableArray array];
        NSRegularExpression *pattern = [NSRegularExpression regularExpressionWithPattern:
            @"speed|camera|alert|warning|traffic|carplay|navigation|sign|overlay|mapview|MapProvider" options:NSRegularExpressionCaseInsensitive error:nil];
        for (int i = 0; i < MIN(copied, count); i++) {
            Class cls = classes[i];
            const char *image = class_getImageName(cls);
            if (!image) continue;
            NSString *path = [NSString stringWithUTF8String:image];
            BOOL mainImage = [path.lastPathComponent isEqual:bundle.executablePath.lastPathComponent];
            if (!mainImage && ![path containsString:@"MapProviderCore.framework"]) continue;
            NSString *name = NSStringFromClass(cls);
            [allNames addObject:name];
            if (![pattern firstMatchInString:name options:0 range:NSMakeRange(0, name.length)]) continue;
            NSMutableArray *methods = [NSMutableArray array], *ivars = [NSMutableArray array], *properties = [NSMutableArray array];
            unsigned n = 0;
            Method *list = class_copyMethodList(cls, &n);
            for (unsigned j = 0; j < n; j++) {
                const char *type = method_getTypeEncoding(list[j]);
                [methods addObject:@{@"selector": NSStringFromSelector(method_getName(list[j])),
                    @"encoding": type ? [NSString stringWithUTF8String:type] : @""}];
            }
            free(list);
            Ivar *vars = class_copyIvarList(cls, &n);
            for (unsigned j = 0; j < n; j++) {
                const char *key = ivar_getName(vars[j]), *type = ivar_getTypeEncoding(vars[j]);
                [ivars addObject:@{@"name": key ? [NSString stringWithUTF8String:key] : @"",
                    @"type": type ? [NSString stringWithUTF8String:type] : @""}];
            }
            free(vars);
            objc_property_t *props = class_copyPropertyList(cls, &n);
            for (unsigned j = 0; j < n; j++) {
                const char *key = property_getName(props[j]);
                if (key) [properties addObject:[NSString stringWithUTF8String:key]];
            }
            free(props);
            [details addObject:@{@"name":name, @"methods":methods, @"ivars":ivars, @"properties":properties}];
        }
        free(classes);
        NSDictionary *report = @{@"bundle":bundle.bundleIdentifier, @"version":[bundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @"",
            @"classes":allNames, @"details":details};
        NSData *json = [NSJSONSerialization dataWithJSONObject:report options:NSJSONWritingPrettyPrinted error:nil];
        [json writeToFile:[NSTemporaryDirectory() stringByAppendingPathComponent:@"gofahud-native-probe.json"] atomically:YES];
    }
}
__attribute__((constructor)) static void Start(void) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{ Inspect(); });
}
