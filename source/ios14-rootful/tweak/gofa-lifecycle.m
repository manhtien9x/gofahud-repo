#import <UIKit/UIKit.h>
#import <notify.h>
static int token=-1;
static void Publish(BOOL active) {
    if(token>=0 && notify_set_state(token,active ? 1 : 0)==NOTIFY_STATUS_OK)
        notify_post("local.gofahud.gofa.foreground");
    [[NSString stringWithFormat:@"GOFA active=%d",active] writeToFile:[NSTemporaryDirectory() stringByAppendingPathComponent:@"gofahud-lifecycle.log"] atomically:YES encoding:NSUTF8StringEncoding error:nil];
}
__attribute__((constructor)) static void Start(void) {
    if(![NSBundle.mainBundle.bundleIdentifier isEqual:@"com.lumi.GOFA"]) return;
    notify_register_check("local.gofahud.gofa.foreground",&token);
    dispatch_async(dispatch_get_main_queue(), ^{
        Publish(UIApplication.sharedApplication.applicationState==UIApplicationStateActive);
        [NSNotificationCenter.defaultCenter addObserverForName:UIApplicationDidBecomeActiveNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *n) { (void)n; Publish(YES); }];
        [NSNotificationCenter.defaultCenter addObserverForName:UIApplicationWillResignActiveNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *n) { (void)n; Publish(NO); }];
        [NSNotificationCenter.defaultCenter addObserverForName:UIApplicationDidEnterBackgroundNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *n) { (void)n; Publish(NO); }];
        [NSNotificationCenter.defaultCenter addObserverForName:UIApplicationWillTerminateNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *n) { (void)n; Publish(NO); }];
    });
}
