#import <Foundation/Foundation.h>
#import <objc/message.h>
#include <notify.h>
static int launchToken=-1;
__attribute__((constructor)) static void StartLaunchHelper(void) {
    if(![NSBundle.mainBundle.bundleIdentifier isEqual:@"com.apple.springboard"]) return;
    notify_register_dispatch("local.gofahud.phone.open-gofa",&launchToken,dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0),^(int token) {
        (void)token;
        @autoreleasepool { @try {
            BOOL accepted=NO;
            Class cls=NSClassFromString(@"LSApplicationWorkspace");
            SEL shared=NSSelectorFromString(@"defaultWorkspace"),action=NSSelectorFromString(@"openApplicationWithBundleID:");
            if(cls && [cls respondsToSelector:shared]) {
                id workspace=((id(*)(id,SEL))objc_msgSend)(cls,shared);
                if([workspace respondsToSelector:action]) accepted=((BOOL(*)(id,SEL,id))objc_msgSend)(workspace,action,@"com.lumi.GOFA");
            }
            [[NSString stringWithFormat:@"GOFA launch accepted=%d",accepted] writeToFile:@"/var/mobile/Library/Logs/GofaHUD-launch.log" atomically:YES encoding:NSUTF8StringEncoding error:nil];
        } @catch(__unused NSException *exception) {} }
    });
}
