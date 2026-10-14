#import <UIKit/UIKit.h>
#import <CarPlay/CarPlay.h>
#import <notify.h>
#import "speed-state.h"
#import "hud-live-state.h"
#import "speed-presentation.h"
#import "bubble-style.h"
#import "test-state.h"
#import "background-policy.h"
static int speedToken=-1,limitToken=-1,cameraToken=-1,producerToken=-1,readyToken=-1;
static NSMapTable<CPWindow *,UIView *> *cards;
static NSHashTable<CPWindow *> *knownWindows;
static int positionToken=-1;
static int enabledToken=-1,showToken=-1;
static int carActiveToken=-1;
static const CGFloat CardScale=.7;
#define CardWidth (GOFAHUDBubbleSize(YES).width)
#define CardHeight (GOFAHUDBubbleSize(YES).height)
static CGRect CardRect(CGFloat x,CGFloat y,CGFloat w,CGFloat h) { return CGRectMake(x*CardScale,y*CardScale,w*CardScale,h*CardScale); }
static void InitializeCarControls(void) {
    if(enabledToken>=0) return;
    notify_register_check("local.gofahud.carplay.enabled",&enabledToken);
    notify_register_check("local.gofahud.carplay.gofa-active",&carActiveToken);
    notify_register_dispatch("local.gofahud.carplay.show",&showToken,dispatch_get_main_queue(),^(int token) { (void)token; notify_set_state(enabledToken,2); });
    [NSNotificationCenter.defaultCenter addObserverForName:UIScreenDidConnectNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *n) { if(n.object!=UIScreen.mainScreen) notify_set_state(enabledToken,2); }];
}
void GOFACarHUDSetGOFAActive(BOOL active) {
    InitializeCarControls(); static BOOL previous=NO;
    if(previous && !active) notify_set_state(enabledToken,2);
    previous=active; notify_set_state(carActiveToken,active ? 1 : 0);
}
static uint64_t ReadState(int token) { uint64_t v=0; if(token>=0) notify_get_state(token,&v); return v; }
void GOFACarHUDInitializeSource(void) {
    if(speedToken>=0) return;
    notify_register_check(GVMSpeedStateName,&speedToken); notify_register_check(GOFAHUDLimitName,&limitToken);
    notify_register_check(GOFAHUDCameraName,&cameraToken); notify_register_check(GOFAHUDProducerName,&producerToken);
    notify_register_check("local.gofahud.source.ready",&readyToken);
}
@interface GOFACarHUD : UIView
@property(nonatomic,strong) UILabel *titleLabel;
@property(nonatomic,strong) UILabel *speedLabel;
@property(nonatomic,strong) UILabel *limitLabel;
@property(nonatomic,strong) UILabel *cameraLabel;
@property(nonatomic) BOOL dragging;
@property(nonatomic) CGPoint panStart;
@property(nonatomic,strong) UILabel *dismissTarget;
- (void)refresh;
@end
@implementation GOFACarHUD
- (instancetype)initWithFrame:(CGRect)frame {
    if((self=[super initWithFrame:frame])) {
        self.userInteractionEnabled=NO;
        self.backgroundColor=[UIColor colorWithWhite:.06 alpha:.9]; self.layer.cornerRadius=12*CardScale;
        NSMutableArray *labels=[NSMutableArray array];
        for(unsigned i=0;i<4;i++) { UILabel *l=[UILabel new]; l.textColor=UIColor.whiteColor; l.textAlignment=NSTextAlignmentCenter; l.adjustsFontSizeToFitWidth=YES; l.minimumScaleFactor=.6; [self addSubview:l]; [labels addObject:l]; }
        self.titleLabel=labels[0]; self.speedLabel=labels[1]; self.limitLabel=labels[2]; self.cameraLabel=labels[3];
        self.titleLabel.font=[UIFont systemFontOfSize:10*CardScale weight:UIFontWeightSemibold];
        self.speedLabel.font=[UIFont monospacedDigitSystemFontOfSize:28*CardScale weight:UIFontWeightBold];
        self.limitLabel.font=[UIFont monospacedDigitSystemFontOfSize:18*CardScale weight:UIFontWeightBold];
        self.limitLabel.textColor=UIColor.blackColor; self.limitLabel.backgroundColor=UIColor.whiteColor;
        self.limitLabel.layer.cornerRadius=19*CardScale; self.limitLabel.clipsToBounds=YES;
        self.limitLabel.layer.borderColor=UIColor.systemRedColor.CGColor; self.limitLabel.layer.borderWidth=3*CardScale;
        self.cameraLabel.font=[UIFont systemFontOfSize:10*CardScale];
    }
    return self;
}
- (void)layoutSubviews {
    [super layoutSubviews];
    GOFAHUDLayoutLabels(self,@[self.titleLabel,self.speedLabel,self.limitLabel,self.cameraLabel],YES);
}
- (void)refresh {
    UIWindow *window=self.window;
    if(!window || window.hidden) return;
    InitializeCarControls();
    uint64_t enabled=0; notify_get_state(enabledToken,&enabled);
    uint64_t carActive=0; notify_get_state(carActiveToken,&carActive);
    if(!GOFAHUDEnabled(YES) || enabled==1 || carActive==1) { [self.superview viewWithTag:41060].hidden=YES; self.hidden=YES; self.dismissTarget.hidden=YES; return; }
    double now=NSProcessInfo.processInfo.systemUptime;
    static int hostToken=-1,testToken=-1; if(hostToken<0) notify_register_check(GVM_BACKGROUND_SIGNAL,&hostToken); if(testToken<0) notify_register_check(GVMTestStateName,&testToken); if(hostToken>=0) notify_set_state(hostToken,(uint64_t)(now*1000)); NSDictionary *test=GVMDecodeTest(ReadState(testToken),now);
    uint64_t cameraProducer=ReadState(producerToken),cameraReady=ReadState(readyToken);
    NSDictionary *camera=cameraProducer && cameraProducer==cameraReady ? GOFAHUDCameraDecode(ReadState(cameraToken),now) : nil;
    BOOL cameraAvailable=test || [camera[@"kind"] unsignedIntValue]>0;
    static int residentialToken=-1,noPassingToken=-1;
    if(residentialToken<0) notify_register_check(GOFAHUDResidentialName,&residentialToken); if(noPassingToken<0) notify_register_check(GOFAHUDNoPassingName,&noPassingToken);
    uint64_t residentialState=0,noPassingState=0; notify_get_state(residentialToken,&residentialState); notify_get_state(noPassingToken,&noPassingState);
    NSDictionary *residential=cameraProducer && cameraProducer==cameraReady ? GOFAHUDRoadDecode(residentialState,now) : nil, *noPassing=cameraProducer && cameraProducer==cameraReady ? GOFAHUDRoadDecode(noPassingState,now) : nil;
    if(test) { residential=@{@"sign":@12,@"meters":@300}; noPassing=@{@"sign":@14,@"meters":@400}; }
    GOFAHUDExtraAlerts(YES,residential,noPassing);
    GOFAHUDCameraVisible(YES,cameraAvailable);
    UILayoutGuide *guide=[window isKindOfClass:CPWindow.class] ? ((CPWindow *)window).mapButtonSafeAreaLayoutGuide : nil;
    CGRect area=guide ? guide.layoutFrame : CGRectZero;
    if(guide.owningView && guide.owningView!=window) area=[guide.owningView convertRect:area toView:window];
    if(CGRectIsEmpty(area)) area=UIEdgeInsetsInsetRect(window.bounds,window.safeAreaInsets);
    area=[window convertRect:area toView:self.superview];
    self.hidden=area.size.width<CardWidth+16 || area.size.height<CardHeight+16;
    if(self.hidden) return;
    uint64_t position=0;
    if(positionToken<0) notify_register_check("local.gofahud.carplay.position",&positionToken);
    notify_get_state(positionToken,&position);
    static NSUInteger styleRevision=NSUIntegerMax; if(styleRevision!=GOFAHUDPositionRevision(YES)) { styleRevision=GOFAHUDPositionRevision(YES); CGPoint p=GOFAHUDPosition(YES); position=(1ull<<32) | (uint64_t)(p.x*65535) | ((uint64_t)(p.y*65535)<<16); notify_set_state(positionToken,position); }
    CGFloat x=position&(1ull<<32) ? (CGFloat)(position&65535)/65535 : 1;
    CGFloat y=position&(1ull<<32) ? (CGFloat)((position>>16)&65535)/65535 : 0;
    CGRect frame=CGRectMake(CGRectGetMinX(area)+8+x*MAX(0,area.size.width-CardWidth-16),CGRectGetMinY(area)+8+y*MAX(0,area.size.height-CardHeight-16),CardWidth,CardHeight);
    if(!self.dragging && !CGRectEqualToRect(self.frame,frame)) self.frame=frame;
    GOFAHUDLayoutLabels(self,@[self.titleLabel,self.speedLabel,self.limitLabel,self.cameraLabel],YES);
    uint64_t producer=ReadState(producerToken),ready=ReadState(readyToken),rawSpeed=ReadState(speedToken);
    BOOL active=producer!=0 && producer==ready;
    NSNumber *speed=active ? GVMDecodeSample(rawSpeed,now,YES) : nil;
    BOOL waiting=active && !speed;
    if(waiting) speed=GOFAHUDRetainedZero(rawSpeed,now,producer,ready);
    NSNumber *limit=GOFAHUDRetainedLimit(ReadState(limitToken),now,producer,ready);
    if(test) { speed=test[@"speed"]; limit=test[@"limit"]; waiting=NO; }
    self.titleLabel.text=test ? @"GOFA · TEST" : @"GOFA";
    self.speedLabel.text=speed ? speed.stringValue : @"--";
    self.limitLabel.text=limit ? limit.stringValue : @"--";
    GOFAHUDWarningStyle(self,speed,limit);
    GVMWarning warning=GVMWarningFor(speed,limit);
    self.speedLabel.textColor=warning==GVMWarningOver ? UIColor.systemRedColor : warning==GVMWarningNear ? UIColor.systemYellowColor : UIColor.whiteColor;
    GOFAHUDSetCamera(self,self.cameraLabel,test ? @150 : camera[@"meters"],cameraAvailable);

}
- (void)openGOFA:(UITapGestureRecognizer *)tap {
    if(tap.state!=UIGestureRecognizerStateRecognized) return;
    // The tap already waits for pan to fail. A missing pan-end event must not
    // permanently suppress later taps through a stale drag flag.
    self.dragging=NO;
    uint32_t result=notify_post("local.gofahud.carplay.open-gofa");
    NSDictionary *row=@{@"unixTime":@(NSDate.date.timeIntervalSince1970),@"uptime":@(NSProcessInfo.processInfo.systemUptime),@"event":@"tap-open-gofa",@"notifyResult":@(result),@"process":NSBundle.mainBundle.bundleIdentifier ?: @""};
    NSData *data=[NSJSONSerialization dataWithJSONObject:row options:0 error:nil];
    NSString *path=@"/var/mobile/Library/Logs/GofaHUD-carplay-actions.jsonl";
    FILE *f=fopen(path.fileSystemRepresentation,"a");
    if(!f) f=fopen([[NSTemporaryDirectory() stringByAppendingPathComponent:@"gofahud-carplay-actions.jsonl"] fileSystemRepresentation],"a");
    if(f) { fwrite(data.bytes,1,data.length,f); fputc('\n',f); fclose(f); }
}
- (void)pan:(UIPanGestureRecognizer *)pan {
    if(pan.state==UIGestureRecognizerStateBegan) { self.dragging=YES; self.panStart=self.center; }
    CGPoint delta=[pan translationInView:self.superview]; CGRect bounds=self.superview.bounds;
    CGPoint finger=[pan locationInView:self.superview];
    if(!self.dismissTarget) {
        self.dismissTarget=[[UILabel alloc] initWithFrame:CGRectZero]; self.dismissTarget.text=@"✕";
        self.dismissTarget.textAlignment=NSTextAlignmentCenter; self.dismissTarget.font=[UIFont systemFontOfSize:28 weight:UIFontWeightBold];
        self.dismissTarget.textColor=UIColor.whiteColor; self.dismissTarget.layer.cornerRadius=28; self.dismissTarget.clipsToBounds=YES;
        self.dismissTarget.userInteractionEnabled=NO;
    }
    if(self.dismissTarget.superview!=self.superview) [self.superview addSubview:self.dismissTarget];
    self.dismissTarget.frame=CGRectMake(CGRectGetMidX(bounds)-28,CGRectGetMaxY(bounds)-64,56,56);
    BOOL near= finger.y>CGRectGetMaxY(bounds)-100;
    CGRect dropArea=CGRectInset(self.dismissTarget.frame,-20,-16);
    BOOL inside=CGRectContainsPoint(dropArea,finger);
    self.dismissTarget.hidden=!near; self.dismissTarget.backgroundColor=inside ? UIColor.systemRedColor : [UIColor colorWithWhite:.15 alpha:.9];
    [self.superview bringSubviewToFront:self.dismissTarget]; [self.superview bringSubviewToFront:self];
    CGPoint center=CGPointMake(MIN(CGRectGetMaxX(bounds)-CardWidth/2-8,MAX(CGRectGetMinX(bounds)+CardWidth/2+8,self.panStart.x+delta.x)),MIN(CGRectGetMaxY(bounds)-CardHeight/2-8,MAX(CGRectGetMinY(bounds)+CardHeight/2+8,self.panStart.y+delta.y)));
    self.center=center;
    if(pan.state==UIGestureRecognizerStateEnded || pan.state==UIGestureRecognizerStateCancelled || pan.state==UIGestureRecognizerStateFailed) {
        self.dismissTarget.hidden=YES;
        if(pan.state==UIGestureRecognizerStateEnded && near && (inside || CGRectContainsPoint(dropArea,self.center))) {
            notify_set_state(enabledToken,1); notify_post("local.gofahud.carplay.enabled");
            self.dragging=NO; self.hidden=YES; return;
        }
        double x=MAX(0,MIN(1,(CGRectGetMinX(self.frame)-CGRectGetMinX(bounds)-8)/MAX(1,bounds.size.width-CardWidth-16)));
        double y=MAX(0,MIN(1,(CGRectGetMinY(self.frame)-CGRectGetMinY(bounds)-8)/MAX(1,bounds.size.height-CardHeight-16)));
        uint64_t position=(1ull<<32)|((uint64_t)llround(y*65535)<<16)|(uint64_t)llround(x*65535);
        notify_set_state(positionToken,position); notify_post("local.gofahud.carplay.position");
        [[NSUserDefaults standardUserDefaults] setObject:@(position) forKey:@"GOFAHUDCarPosition"];
        self.dragging=NO;
    }
}
@end
void GOFACarHUDRefresh(UIView *view) { [(GOFACarHUD *)view refresh]; }
void GOFACarHUDEnableInteraction(UIView *view) {
    view.userInteractionEnabled=YES;
    if(view.gestureRecognizers.count) return;
    UIPanGestureRecognizer *pan=[[UIPanGestureRecognizer alloc] initWithTarget:view action:@selector(pan:)];
    UITapGestureRecognizer *tap=[[UITapGestureRecognizer alloc] initWithTarget:view action:@selector(openGOFA:)];
    [tap requireGestureRecognizerToFail:pan]; [view addGestureRecognizer:pan]; [view addGestureRecognizer:tap];
    if(positionToken<0) notify_register_check("local.gofahud.carplay.position",&positionToken);
    uint64_t state=0; notify_get_state(positionToken,&state);
    NSNumber *saved=[[NSUserDefaults standardUserDefaults] objectForKey:@"GOFAHUDCarPosition"];
    if(!state && saved) notify_set_state(positionToken,saved.unsignedLongLongValue);
}
static void Attach(CPWindow *window) {
    if(!window || window.screen==UIScreen.mainScreen || window.bounds.size.width<400 || window.bounds.size.height<240) return;
    GOFACarHUD *card=(GOFACarHUD *)[cards objectForKey:window];
    if(!card) { card=[[GOFACarHUD alloc] initWithFrame:CGRectZero]; [cards setObject:card forKey:window]; }
    // CarPlay renders the map controller's content. Keep the existing Google
    // controller and attach within its view instead of directly to CPWindow.
    UIView *host=window.rootViewController.viewIfLoaded;
    if(!host || host.window!=window) { card.hidden=YES; return; }
    if(card.superview!=host) [host addSubview:card];
    [host bringSubviewToFront:card]; [card refresh];
}
static NSDictionary *ViewSummary(UIView *view) {
    if(!view) return @{};
    return @{@"class":NSStringFromClass(view.class),@"frame":NSStringFromCGRect(view.frame),@"bounds":NSStringFromCGRect(view.bounds),@"hidden":@(view.hidden),@"alpha":@(view.alpha)};
}
static void Diagnostics(void) {
    static double last=0; double now=NSProcessInfo.processInfo.systemUptime;
    static int hostToken=-1,testToken=-1; if(hostToken<0) notify_register_check(GVM_BACKGROUND_SIGNAL,&hostToken); if(testToken<0) notify_register_check(GVMTestStateName,&testToken); if(hostToken>=0) notify_set_state(hostToken,(uint64_t)(now*1000)); NSDictionary *test=GVMDecodeTest(ReadState(testToken),now);
    if(now-last<5) return; last=now;
    NSMutableArray *windows=[NSMutableArray array],*scenes=[NSMutableArray array];
    for(UIScene *scene in UIApplication.sharedApplication.connectedScenes) [scenes addObject:@{@"class":NSStringFromClass(scene.class),@"activation":@(scene.activationState),@"role":scene.session.role ?: @""}];
    for(CPWindow *window in cards.keyEnumerator) {
        UIView *card=[cards objectForKey:window];
        NSMutableDictionary *item=[ViewSummary(window) mutableCopy];
        item[@"mainScreen"]=@(window.screen==UIScreen.mainScreen); item[@"windowLevel"]=@(window.windowLevel);
        item[@"screenBounds"]=NSStringFromCGRect(window.screen.bounds); item[@"controller"]=window.rootViewController ? NSStringFromClass(window.rootViewController.class) : @"nil";
        item[@"root"]=ViewSummary(window.rootViewController.viewIfLoaded); item[@"card"]=ViewSummary(card);
        item[@"host"]=ViewSummary(card.superview); item[@"guide"]=NSStringFromCGRect(window.mapButtonSafeAreaLayoutGuide.layoutFrame);
        [windows addObject:item];
    }
    NSDictionary *row=@{@"unixTime":@(NSDate.date.timeIntervalSince1970),@"uptime":@(now),@"applicationState":@(UIApplication.sharedApplication.applicationState),@"version":@"root-content-v2",@"scenes":scenes,@"windows":windows};
    NSData *data=[NSJSONSerialization dataWithJSONObject:row options:0 error:nil];
    NSString *path=[NSTemporaryDirectory() stringByAppendingPathComponent:@"gofahud-carplay-diagnostics.jsonl"];
    if([NSFileManager.defaultManager attributesOfItemAtPath:path error:nil].fileSize>2*1024*1024) {
        NSString *old=[path stringByAppendingString:@".1"]; [NSFileManager.defaultManager removeItemAtPath:old error:nil]; [NSFileManager.defaultManager moveItemAtPath:path toPath:old error:nil];
    }
    FILE *f=fopen(path.fileSystemRepresentation,"a"); if(f) { fwrite(data.bytes,1,data.length,f); fputc('\n',f); fclose(f); }
}
static void RefreshWindows(void) {
    static int globalToken=-1;
    if(globalToken<0) notify_register_check("local.gofahud.carplay.global",&globalToken);
    uint64_t global=ReadState(globalToken);
    double age=NSProcessInfo.processInfo.systemUptime-(double)(global>>24)/1000;
    if(global && age>=0 && age<3) {
        for(UIView *card in cards.objectEnumerator) card.hidden=YES;
        Diagnostics(); return;
    }
    for(UIScene *scene in UIApplication.sharedApplication.connectedScenes)
        if([scene isKindOfClass:CPTemplateApplicationScene.class]) Attach(((CPTemplateApplicationScene *)scene).carWindow);
    for(UIWindow *window in UIApplication.sharedApplication.windows) if([window isKindOfClass:CPWindow.class]) Attach((CPWindow *)window);
    for(CPWindow *window in knownWindows) Attach(window);
    BOOL visible=NO;
    for(CPWindow *window in cards.keyEnumerator) {
        UIView *card=[cards objectForKey:window];
        if(!window.hidden && window.alpha>0 && card.window==window && !card.hidden && card.superview && !card.superview.hidden && card.superview.alpha>0) { visible=YES; break; }
    }
    static int traceToken=-1;
    if(traceToken<0) notify_register_check("local.gofahud.carplay.trace",&traceToken);
    uint64_t trace=((uint64_t)(NSProcessInfo.processInfo.systemUptime*1000)<<1)|(visible ? 1 : 0);
    if(traceToken>=0) notify_set_state(traceToken,trace);
    Diagnostics();
}
__attribute__((constructor)) static void Start(void) {
    if(![NSBundle.mainBundle.bundleIdentifier isEqual:@"com.google.Maps"]) return;
    dispatch_async(dispatch_get_main_queue(),^{
        cards=[NSMapTable weakToStrongObjectsMapTable]; knownWindows=[NSHashTable weakObjectsHashTable];
        GOFACarHUDInitializeSource();
        [NSNotificationCenter.defaultCenter addObserverForName:UIWindowDidBecomeVisibleNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *n) {
            if([n.object isKindOfClass:CPWindow.class]) { [knownWindows addObject:n.object]; Attach(n.object); }
        }];
        NSTimer *timer=[NSTimer timerWithTimeInterval:.5 repeats:YES block:^(NSTimer *t) { (void)t; RefreshWindows(); }];
        [NSRunLoop.mainRunLoop addTimer:timer forMode:NSRunLoopCommonModes]; RefreshWindows();
        [@"CarPlay root-content-v2 loaded; awaiting Google Maps CPWindow" writeToFile:[NSTemporaryDirectory() stringByAppendingPathComponent:@"gofahud-carplay.log"] atomically:YES encoding:NSUTF8StringEncoding error:nil];
    });
}
