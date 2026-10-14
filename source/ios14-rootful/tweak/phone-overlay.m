#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <notify.h>
#import "speed-state.h"
#import "camera-state.h"
#import "test-state.h"
#import "speed-presentation.h"
#import "phone-interaction.h"
#import "hud-live-state.h"
static int hudProducerToken=-1,hudReadyToken=-1,hudLimitToken=-1,hudCameraToken=-1;

static UIWindow *overlay;
static UIView *bubble;
static UILabel *dismissTarget;
static BOOL dismissed;
static BOOL openingGOFA;
static BOOL dragging, wasGOFAForeground;
static int foregroundToken=-1;
static int showToken=-1;
static UILabel *heading, *speedLabel, *limitLabel, *cameraLabel;
static int speedToken=-1, limitToken=-1, cameraToken=-1, testToken=-1;
static NSUserDefaults *settings;
static void Refresh(void);
static void Log(NSString *text) {
    [text writeToFile:@"/var/mobile/Library/Logs/GofaHUD-phone.log" atomically:YES encoding:NSUTF8StringEncoding error:nil];
}
static NSNumber *Value(int token, BOOL zero) {
    uint64_t state=0;
    return token >= 0 && notify_get_state(token,&state)==NOTIFY_STATUS_OK ? GVMDecodeSample(state,NSProcessInfo.processInfo.systemUptime,zero) : nil;
}
static BOOL Locked(void) {
    Class cls=NSClassFromString(@"SBLockScreenManager");
    SEL shared=NSSelectorFromString(@"sharedInstance"), query=NSSelectorFromString(@"isUILocked");
    if (!cls || ![cls respondsToSelector:shared]) return YES;
    id manager=((id(*)(id,SEL))objc_msgSend)(cls,shared);
    if (![manager respondsToSelector:query]) return YES;
    return ((BOOL(*)(id,SEL))objc_msgSend)(manager,query);
}
static BOOL GOFAForeground(void) {
    UIApplication *application=UIApplication.sharedApplication;
    SEL front=NSSelectorFromString(@"_accessibilityFrontMostApplication");
    if([application respondsToSelector:front]) {
        id app=((id(*)(id,SEL))objc_msgSend)(application,front);
        SEL bundle=NSSelectorFromString(@"bundleIdentifier");
        if(!app) return NO;
        if([app respondsToSelector:bundle])
            return [((id(*)(id,SEL))objc_msgSend)(app,bundle) isEqual:@"com.lumi.GOFA"];
    }
    uint64_t state=0;
    return foregroundToken>=0 && notify_get_state(foregroundToken,&state)==NOTIFY_STATUS_OK && state==1;
}
@interface GOFAPhoneWindow : UIWindow
@end
@implementation GOFAPhoneWindow
- (UIView *)hitTest:(CGPoint)p withEvent:(UIEvent *)event {
    if (self.hidden || bubble.hidden || ![bubble pointInside:[bubble convertPoint:p fromView:self] withEvent:event]) return nil;
    return [super hitTest:p withEvent:event];
}
@end
@interface GOFAPhoneController : UIViewController
- (void)pan:(UIPanGestureRecognizer *)gesture;
- (void)openGOFA:(UITapGestureRecognizer *)gesture;
@end
@implementation GOFAPhoneController
- (BOOL)prefersStatusBarHidden { return NO; }
- (BOOL)shouldAutorotate { return YES; }
- (UIInterfaceOrientationMask)supportedInterfaceOrientations { return UIInterfaceOrientationMaskAllButUpsideDown; }
- (void)openGOFA:(UITapGestureRecognizer *)gesture {
    if (gesture.state!=UIGestureRecognizerStateEnded || openingGOFA) return;
    openingGOFA=YES;
    overlay.hidden=YES;
    // Direct bundle launch avoids the URL confirmation. Never block SpringBoard's UI thread.
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0), ^{
        BOOL accepted=NO;
        @try {
            Class cls=NSClassFromString(@"LSApplicationWorkspace");
            SEL shared=NSSelectorFromString(@"defaultWorkspace"), action=NSSelectorFromString(@"openApplicationWithBundleID:");
            if(cls && [cls respondsToSelector:shared]) {
                id workspace=((id(*)(id,SEL))objc_msgSend)(cls,shared);
                if([workspace respondsToSelector:action])
                    accepted=((BOOL(*)(id,SEL,id))objc_msgSend)(workspace,action,@"com.lumi.GOFA");
            }
        } @catch (__unused NSException *exception) {}
        dispatch_async(dispatch_get_main_queue(), ^{
            openingGOFA=NO; Refresh(); Log(accepted ? @"direct GOFA launch accepted" : @"direct GOFA launch refused");
        });
    });
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,5*NSEC_PER_SEC),dispatch_get_main_queue(), ^{ openingGOFA=NO; Refresh(); });
}
- (void)pan:(UIPanGestureRecognizer *)gesture {
    dragging=YES;
    CGPoint delta=[gesture translationInView:self.view];
    CGPoint center=bubble.center;
    CGFloat halfW=bubble.bounds.size.width/2, halfH=bubble.bounds.size.height/2;
    UIEdgeInsets insets=self.view.safeAreaInsets;
    center.x=MAX(insets.left+halfW,MIN(self.view.bounds.size.width-insets.right-halfW,center.x+delta.x));
    center.y=MAX(insets.top+halfH,MIN(self.view.bounds.size.height-insets.bottom-halfH,center.y+delta.y));
    bubble.center=center; [gesture setTranslation:CGPointZero inView:self.view];
    CGPoint finger=[gesture locationInView:self.view];
    CGRect target=CGRectMake(self.view.bounds.size.width/2-30,self.view.bounds.size.height-insets.bottom-76,60,60);
    BOOL nearBottom=MAX(center.y,finger.y)>self.view.bounds.size.height-insets.bottom-180;
    BOOL overTarget=nearBottom && GOFAPhoneDropMatches(center,finger,target);
    dismissTarget.hidden=!nearBottom;
    dismissTarget.backgroundColor=overTarget ? UIColor.systemRedColor : [UIColor colorWithWhite:.12 alpha:.92];
    dismissTarget.transform=overTarget ? CGAffineTransformMakeScale(1.15,1.15) : CGAffineTransformIdentity;
    if (gesture.state==UIGestureRecognizerStateEnded) {
        dragging=NO;
        dismissTarget.hidden=YES;
        if (overTarget) {
            dismissed=YES; [settings setBool:NO forKey:@"phoneEnabled"];
            overlay.hidden=YES; Log(@"phone bubble dismissed by drop target"); return;
        }
        [settings setDouble:center.x/MAX(1,self.view.bounds.size.width) forKey:@"phoneX"];
        [settings setDouble:center.y/MAX(1,self.view.bounds.size.height) forKey:@"phoneY"];
    }
    if (gesture.state==UIGestureRecognizerStateCancelled || gesture.state==UIGestureRecognizerStateFailed) { dragging=NO; dismissTarget.hidden=YES; }
}
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    if (!bubble || dragging) return;
    dismissTarget.transform=CGAffineTransformIdentity;
    dismissTarget.frame=CGRectMake(self.view.bounds.size.width/2-30,self.view.bounds.size.height-self.view.safeAreaInsets.bottom-76,60,60);
    CGFloat x=[settings objectForKey:@"phoneX"] ? [settings doubleForKey:@"phoneX"] : .74;
    CGFloat y=[settings objectForKey:@"phoneY"] ? [settings doubleForKey:@"phoneY"] : .25;
    bubble.center=CGPointMake(MAX(86,MIN(self.view.bounds.size.width-86,x*self.view.bounds.size.width)),
        MAX(self.view.safeAreaInsets.top+48,MIN(self.view.bounds.size.height-self.view.safeAreaInsets.bottom-48,y*self.view.bounds.size.height)));
}
@end
static UILabel *Label(CGRect frame, CGFloat size) {
    UILabel *label=[[UILabel alloc] initWithFrame:frame];
    label.textAlignment=NSTextAlignmentCenter; label.textColor=UIColor.whiteColor;
    label.font=[UIFont monospacedDigitSystemFontOfSize:size weight:UIFontWeightBold];
    [bubble addSubview:label]; return label;
}
static void Refresh(void) {
    if (!overlay) return;
    BOOL foreground=GOFAForeground();
    if(foreground!=wasGOFAForeground) Log(foreground ? @"GOFA foreground: bubble hidden" : @"GOFA background: bubble restored");
    if(wasGOFAForeground && !foreground) { dismissed=NO; [settings setBool:YES forKey:@"phoneEnabled"]; }
    wasGOFAForeground=foreground;
    overlay.hidden=Locked() || dismissed || foreground || openingGOFA;
    uint64_t state=0;
    NSDictionary *test=nil, *camera=nil;
    if (testToken>=0 && notify_get_state(testToken,&state)==NOTIFY_STATUS_OK)
        test=GVMDecodeTest(state,NSProcessInfo.processInfo.systemUptime);
    NSNumber *speed=test ? test[@"speed"] : Value(speedToken,YES);
    NSNumber *limit=test ? test[@"limit"] : Value(limitToken,NO);
    uint64_t producer=0,ready=0,hudLimit=0,hudCamera=0;
    notify_get_state(hudProducerToken,&producer); notify_get_state(hudReadyToken,&ready);
    BOOL hudActive=producer!=0 && producer==ready;
    BOOL waitingSpeed=NO;
    if(!test && hudActive && !speed) {
        uint64_t last=0; notify_get_state(speedToken,&last);
        speed=GOFAHUDRetainedZero(last,NSProcessInfo.processInfo.systemUptime,producer,ready);
        waitingSpeed=YES;
    }
    if(!test && hudActive) {
        notify_get_state(hudLimitToken,&hudLimit);
        limit=GOFAHUDRetainedLimit(hudLimit,NSProcessInfo.processInfo.systemUptime,producer,ready);
        notify_get_state(hudCameraToken,&hudCamera);
    }
    if (cameraToken>=0 && notify_get_state(cameraToken,&state)==NOTIFY_STATUS_OK)
        camera=GOFADecodeCamera(state,NSProcessInfo.processInfo.systemUptime);
    heading.text=test ? @"GOFA · TEST" : waitingSpeed ? @"GOFA · CHỜ DỮ LIỆU" : @"GOFA";
    heading.textColor=test ? UIColor.systemYellowColor : UIColor.whiteColor;
    speedLabel.text=speed ? speed.stringValue : @"--";
    limitLabel.text=limit ? limit.stringValue : @"--";
    GVMWarning warning=GVMWarningFor(speed,limit);
    speedLabel.textColor=warning==GVMWarningOver ? UIColor.systemRedColor : warning==GVMWarningNear ? UIColor.systemYellowColor : UIColor.whiteColor;
    if (test) cameraLabel.text=@"CAM thử · 150 m";
    else if(hudActive && GOFAHUDCameraDecode(hudCamera,NSProcessInfo.processInfo.systemUptime)) {
        NSDictionary *hud=GOFAHUDCameraDecode(hudCamera,NSProcessInfo.processInfo.systemUptime);
        NSArray *names=@[@"",@"CAM giao thông",@"CAM phạt",@"CAM đèn đỏ",@"CAM AI"];
        unsigned kind=[hud[@"kind"] unsignedIntValue];
        cameraLabel.text=kind ? [NSString stringWithFormat:@"%@ · %@ m",names[kind],hud[@"meters"]] : @"Chưa có cảnh báo CAM";
    }
    else if (camera) {
        NSArray *names=@[@"",@"CAM tốc độ",@"CAM đèn đỏ",@"CAM giám sát"];
        cameraLabel.text=[NSString stringWithFormat:@"%@ · %@ m",names[[camera[@"kind"] unsignedIntegerValue]],camera[@"meters"]];
    } else cameraLabel.text=@"Chờ cảnh báo GOFA";
}
static void StartWindow(void) {
    if (overlay) return;
    settings=[[NSUserDefaults alloc] initWithSuiteName:@"local.gofahud"];
    dismissed=[settings objectForKey:@"phoneEnabled"] && ![settings boolForKey:@"phoneEnabled"];
    UIWindowScene *scene=nil;
    for (UIScene *candidate in UIApplication.sharedApplication.connectedScenes)
        if ([candidate isKindOfClass:UIWindowScene.class] && ((UIWindowScene *)candidate).screen==UIScreen.mainScreen) { scene=(UIWindowScene *)candidate; break; }
    overlay=scene ? [[GOFAPhoneWindow alloc] initWithWindowScene:scene] : [[GOFAPhoneWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    overlay.frame=UIScreen.mainScreen.bounds; overlay.windowLevel=10000000;
    overlay.backgroundColor=UIColor.clearColor;
    GOFAPhoneController *controller=[GOFAPhoneController new];
    overlay.rootViewController=controller;
    controller.view.backgroundColor=UIColor.clearColor;
    bubble=[[UIView alloc] initWithFrame:CGRectMake(0,0,172,96)];
    bubble.backgroundColor=[UIColor colorWithWhite:.08 alpha:.94]; bubble.layer.cornerRadius=18;
    bubble.layer.borderColor=[UIColor colorWithWhite:1 alpha:.25].CGColor; bubble.layer.borderWidth=1;
    [controller.view addSubview:bubble];
    dismissTarget=[[UILabel alloc] initWithFrame:CGRectZero];
    dismissTarget.text=@"✕"; dismissTarget.textColor=UIColor.whiteColor;
    dismissTarget.font=[UIFont systemFontOfSize:32 weight:UIFontWeightMedium]; dismissTarget.textAlignment=NSTextAlignmentCenter;
    dismissTarget.layer.cornerRadius=30; dismissTarget.clipsToBounds=YES; dismissTarget.hidden=YES; dismissTarget.userInteractionEnabled=NO;
    [controller.view addSubview:dismissTarget];
    heading=Label(CGRectMake(8,4,156,18),11);
    speedLabel=Label(CGRectMake(6,22,92,42),34);
    UILabel *unit=Label(CGRectMake(6,62,92,12),9); unit.text=@"km/h";
    limitLabel=Label(CGRectMake(108,24,48,48),22);
    limitLabel.backgroundColor=UIColor.whiteColor; limitLabel.textColor=UIColor.blackColor;
    limitLabel.layer.borderColor=UIColor.systemRedColor.CGColor; limitLabel.layer.borderWidth=4;
    limitLabel.layer.cornerRadius=24; limitLabel.clipsToBounds=YES;
    cameraLabel=Label(CGRectMake(4,78,164,14),10);
    UIPanGestureRecognizer *pan=[[UIPanGestureRecognizer alloc] initWithTarget:controller action:@selector(pan:)];
    UITapGestureRecognizer *tap=[[UITapGestureRecognizer alloc] initWithTarget:controller action:@selector(openGOFA:)];
    [tap requireGestureRecognizerToFail:pan];
    [bubble addGestureRecognizer:pan]; [bubble addGestureRecognizer:tap];
    notify_register_check(GVMSpeedStateName,&speedToken); notify_register_check(GVMLimitStateName,&limitToken);
    notify_register_check(GOFACameraStateName,&cameraToken); notify_register_check(GVMTestStateName,&testToken);
    notify_register_check(GOFAHUDProducerName,&hudProducerToken); notify_register_check("local.gofahud.source.ready",&hudReadyToken);
    notify_register_check(GOFAHUDLimitName,&hudLimitToken); notify_register_check(GOFAHUDCameraName,&hudCameraToken);
    notify_register_dispatch("local.gofahud.gofa.foreground",&foregroundToken,dispatch_get_main_queue(), ^(int token) { (void)token; Refresh(); });
    notify_register_dispatch("local.gofahud.phone.show",&showToken,dispatch_get_main_queue(), ^(int token) {
        (void)token; dismissed=NO; [settings setBool:YES forKey:@"phoneEnabled"]; Refresh();
    });
    [controller.view setNeedsLayout]; [controller.view layoutIfNeeded];
    Refresh();
    NSTimer *timer=[NSTimer timerWithTimeInterval:.5 repeats:YES block:^(NSTimer *t) { (void)t; Refresh(); }];
    [NSRunLoop.mainRunLoop addTimer:timer forMode:NSRunLoopCommonModes];
    Log([NSString stringWithFormat:@"overlay 0.0.4 ready; scene=%@ locked=%d",scene ? NSStringFromClass(scene.class) : @"none",Locked()]);
}
__attribute__((constructor)) static void Start(void) {
    if (![NSBundle.mainBundle.bundleIdentifier isEqual:@"com.apple.springboard"]) return;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 3*NSEC_PER_SEC),dispatch_get_main_queue(), ^{ StartWindow(); });
}
