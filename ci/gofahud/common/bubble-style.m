#import "bubble-style.h"
#import <CoreFoundation/CoreFoundation.h>
#include <notify.h>
#include <math.h>
#import <objc/runtime.h>
static BOOL cameraVisible[2];
static NSDictionary *residentialAlerts[2],*noPassingAlerts[2];
static BOOL vertical[2], enabled[2]={YES,YES};
static CGPoint positions[2]={{1,0},{1,0}};
static NSArray *orders[2];
static NSUInteger revision,overspeed,positionRevision[2];
static NSString *theme;
static NSUInteger percent[2]={100,100};
static void ReadPreferences(void) {
    CFStringRef domain=CFSTR("local.gofahud");
    CFPreferencesAppSynchronize(domain);
    id master=CFBridgingRelease(CFPreferencesCopyAppValue(CFSTR("bubbleEnabled"),domain));
    id scope=CFBridgingRelease(CFPreferencesCopyAppValue(CFSTR("overspeedScope"),domain));
    overspeed=[scope isEqual:@"screen"] ? 2 : [scope isEqual:@"map"] ? 1 : 0;
    theme=CFBridgingRelease(CFPreferencesCopyAppValue(CFSTR("theme"),domain));
    revision++;

    for (unsigned i=0;i<2;i++) {
        NSString *prefix=i ? @"car" : @"phone";
        id layout=CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)[prefix stringByAppendingString:@"Layout"],domain));
        id size=CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)[prefix stringByAppendingString:@"Size"],domain));
        vertical[i]=[layout isKindOfClass:NSString.class] && [layout isEqual:@"vertical"];
        percent[i]=GOFAHUDSizePercent(size);
        id toggle=CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)[prefix stringByAppendingString:@"Enabled"],domain));
        enabled[i]=(![master isKindOfClass:NSNumber.class] || [master boolValue]) && (![toggle isKindOfClass:NSNumber.class] || [toggle boolValue]);
        id corner=CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)[prefix stringByAppendingString:@"Position"],domain));
        CGPoint previousPosition=positions[i]; positions[i]=CGPointMake([corner isEqual:@"top-left"] || [corner isEqual:@"bottom-left"] ? 0 : 1,[corner isEqual:@"bottom-left"] || [corner isEqual:@"bottom-right"] ? 1 : 0);
        if(!CGPointEqualToPoint(previousPosition,positions[i])) positionRevision[i]++;
        id order=CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)[prefix stringByAppendingString:@"Modules"],domain));
        orders[i]=GVMNormalizeModuleOrder(order,vertical[i]);
    }
}
static void Initialize(void) {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        ReadPreferences();
        static int token=-1;
        notify_register_dispatch("local.gofahud.style.changed",&token,dispatch_get_main_queue(),^(__unused int t){ReadPreferences();});
    });
}
NSUInteger GOFAHUDSizePercent(id value) {
    if (![value isKindOfClass:NSNumber.class] || CFGetTypeID((__bridge CFTypeRef)value)==CFBooleanGetTypeID()) return 100;
    double number=[value doubleValue];
    return isfinite(number) ? (NSUInteger)lround(MAX(50,MIN(150,number))) : 100;
}
BOOL GOFAHUDVertical(BOOL car) { Initialize();return vertical[car ? 1 : 0]; }
CGFloat GOFAHUDScale(BOOL car) { Initialize();return (car ? .7 : 1.0)*percent[car ? 1 : 0]/100.0; }
CGSize GOFAHUDBubbleSize(BOOL car) {
    CGFloat scale=GOFAHUDScale(car);BOOL v=GOFAHUDVertical(car);
    NSUInteger idx=car ? 1 : 0; NSUInteger count=2+cameraVisible[idx]+(residentialAlerts[idx]!=nil)+(noPassingAlerts[idx]!=nil);
    return CGSizeMake((v ? 56 : 8+count*48)*scale,(v ? 22+count*48 : 70)*scale);
}
void GOFAHUDLayoutLabels(UIView *bubble,NSArray<UILabel *> *labels,BOOL car) {
    if (labels.count!=4) return;
    CGFloat s=GOFAHUDScale(car);BOOL v=GOFAHUDVertical(car);
    static char styleKey;
    NSUInteger idx=car ? 1 : 0;
    NSUInteger key=revision*8192 + (residentialAlerts[idx] ? 2048 : 0) + (noPassingAlerts[idx] ? 4096 : 0) + (cameraVisible[idx] ? 1024 : 0) + percent[car ? 1 : 0] + (v ? 256 : 0) + (car ? 512 : 0);
    if ([objc_getAssociatedObject(bubble,&styleKey) unsignedIntegerValue]==key) return;
    objc_setAssociatedObject(bubble,&styleKey,@(key),OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    BOOL showCamera=cameraVisible[car ? 1 : 0];
    NSUInteger alertCount=showCamera+(residentialAlerts[idx]!=nil)+(noPassingAlerts[idx]!=nil);
    CGFloat width=v ? 56 : 104+alertCount*48;
    CGRect r[4]; r[0]=CGRectMake(4,2,width-8,14);
    NSMutableArray *order=[orders[car ? 1 : 0] mutableCopy];
    if(!alertCount) [order removeObject:@"alerts"];
    NSUInteger alertSlot=[order indexOfObject:@"alerts"];
    NSArray *moduleNames=@[@"speed",@"limit",@"alerts"];
    for(NSUInteger j=0;j<3;j++) {
      NSUInteger slot=[order indexOfObject:moduleNames[j]]; if(slot==NSNotFound) slot=0;
      if(alertCount && j!=2 && slot>alertSlot) slot+=alertCount-1;
      r[j+1]=v ? CGRectMake(4,18+slot*48,48,44) : CGRectMake(4+slot*48,18,48,44);
    }
    bubble.clipsToBounds=YES;
    CGFloat fonts[4]={9,28,19,9};
    for(unsigned i=0;i<4;i++) {
      CGRect frame=r[i];
      if(i==1) frame.size.height=32;
      if(i==2) frame=CGRectMake(frame.origin.x+6,frame.origin.y,36,36);
      if(i==3) frame=CGRectMake(frame.origin.x,frame.origin.y+37,48,10);
      labels[i].frame=CGRectMake(frame.origin.x*s,frame.origin.y*s,frame.size.width*s,frame.size.height*s);
      labels[i].font=[UIFont monospacedDigitSystemFontOfSize:fonts[i]*s weight:i==1 ? UIFontWeightBold : UIFontWeightSemibold];
      labels[i].adjustsFontSizeToFitWidth=YES; labels[i].minimumScaleFactor=.6;
    }
    labels[3].numberOfLines=1; labels[3].hidden=!showCamera;
    labels[2].layer.cornerRadius=18*s; labels[2].layer.borderWidth=3*s;
    bubble.layer.cornerRadius=12*s;
    UIImageView *icon=(UIImageView *)[bubble viewWithTag:41061];
    if(!icon) {
      static UIImage *camera; static dispatch_once_t once;
      dispatch_once(&once,^{camera=[UIImage systemImageNamed:@"camera.fill"];});
      icon=[[UIImageView alloc] initWithImage:camera]; icon.tag=41061; icon.contentMode=UIViewContentModeCenter;
      icon.backgroundColor=UIColor.whiteColor; icon.tintColor=UIColor.blackColor; icon.clipsToBounds=YES;
      [bubble addSubview:icon];
    }
    icon.hidden=!showCamera;
    icon.frame=CGRectMake((r[3].origin.x+6)*s,r[3].origin.y*s,36*s,36*s);
    icon.preferredSymbolConfiguration=[UIImageSymbolConfiguration configurationWithPointSize:18*s weight:UIImageSymbolWeightSemibold];
    icon.layer.cornerRadius=18*s; icon.layer.borderWidth=3*s;
    UILabel *unit=(UILabel *)[bubble viewWithTag:41062];
    if(!unit) { unit=[UILabel new]; unit.tag=41062; unit.text=@"km/h"; unit.textAlignment=NSTextAlignmentCenter; [bubble addSubview:unit]; }
    unit.frame=CGRectMake(r[1].origin.x*s,(r[1].origin.y+33)*s,48*s,10*s);
    unit.font=[UIFont systemFontOfSize:9*s]; unit.textColor=UIColor.whiteColor;
    NSUInteger extraSlot=alertSlot==NSNotFound ? 2 : alertSlot+showCamera;
    for(NSUInteger a=0;a<2;a++) {
      NSDictionary *alert=a ? noPassingAlerts[idx] : residentialAlerts[idx];
      UIImageView *sign=(UIImageView *)[bubble viewWithTag:41200+a]; UILabel *distance=(UILabel *)[bubble viewWithTag:41210+a];
      if(!sign) { sign=[UIImageView new]; sign.tag=41200+a; sign.contentMode=UIViewContentModeScaleAspectFit; [bubble addSubview:sign]; distance=[UILabel new]; distance.tag=41210+a; distance.textAlignment=NSTextAlignmentCenter; [bubble addSubview:distance]; }
      sign.hidden=distance.hidden=!alert; if(!alert) continue;
      NSString *filename=[@{@12:@"residential_area_in.png",@13:@"residential_area_out.png",@14:@"no_passing_in.png",@15:@"no_passing_out.png"} objectForKey:alert[@"sign"]];
      static NSMutableDictionary *images; if(!images) images=[NSMutableDictionary new]; UIImage *image=images[filename];
      if(!image) { image=[UIImage imageWithContentsOfFile:[@"/var/jb/usr/share/gofahud" stringByAppendingPathComponent:filename]]; if(image) images[filename]=image; }
      sign.image=image;
      CGFloat x=v ? 4 : 4+extraSlot*48, y=v ? 18+extraSlot*48 : 18;
      sign.frame=CGRectMake((x+6)*s,y*s,36*s,36*s); distance.frame=CGRectMake(x*s,(y+37)*s,48*s,10*s);
      distance.text=[alert[@"meters"] unsignedIntValue] ? [NSString stringWithFormat:@"%@ m",alert[@"meters"]] : @""; distance.font=[UIFont systemFontOfSize:9*s]; distance.textColor=UIColor.whiteColor;
      sign.isAccessibilityElement=YES; sign.accessibilityLabel=a ? @"Cấm vượt / Hết cấm vượt" : @"Khu dân cư / Hết khu dân cư"; sign.accessibilityValue=distance.text; extraSlot++;
    }


}

NSArray<NSString *> *GVMNormalizeModuleOrder(id value,BOOL v) {
    NSArray *modules=@[@"speed",@"limit",@"alerts"];
    if([value isKindOfClass:NSArray.class] && [value count]==3 && [NSSet setWithArray:value].count==3 && [[NSSet setWithArray:value] isEqual:[NSSet setWithArray:modules]]) return value;
    return v ? @[@"limit",@"speed",@"alerts"] : modules;
}
void GOFAHUDReloadStyle(void) { Initialize(); ReadPreferences(); }
BOOL GOFAHUDEnabled(BOOL car) { Initialize();return enabled[car ? 1 : 0]; }
CGPoint GOFAHUDPosition(BOOL car) { Initialize();return positions[car ? 1 : 0]; }
NSUInteger GOFAHUDStyleRevision(void) { Initialize();return revision; }
void GOFAHUDWarningStyle(UIView *bubble,NSNumber *speed,NSNumber *limit) {
    Initialize(); BOOL light=[theme isEqual:@"light"] || (![theme isEqual:@"dark"] && bubble.traitCollection.userInterfaceStyle==UIUserInterfaceStyleLight);
    bubble.backgroundColor=light ? [UIColor colorWithWhite:.92 alpha:.94] : [UIColor colorWithWhite:.06 alpha:.94];
    for(UIView *view in bubble.subviews) if([view isKindOfClass:UILabel.class] && ((UILabel *)view).backgroundColor!=UIColor.whiteColor) ((UILabel *)view).textColor=light ? UIColor.blackColor : UIColor.whiteColor;
    BOOL over=speed && limit && speed.doubleValue>limit.doubleValue;
    bubble.layer.borderWidth=overspeed && over ? 3 : 0;
    bubble.layer.borderColor=UIColor.systemRedColor.CGColor;
    UIView *host=bubble.superview;
    UIView *border=[host viewWithTag:41060];
    if(overspeed==2 && over && host) {
      if(!border) { border=[[UIView alloc] initWithFrame:host.bounds]; border.tag=41060; border.userInteractionEnabled=NO; border.backgroundColor=UIColor.clearColor; [host insertSubview:border belowSubview:bubble]; }
      border.frame=host.bounds; border.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
      border.layer.borderColor=UIColor.systemRedColor.CGColor; border.layer.borderWidth=5; border.hidden=bubble.hidden;
    } else border.hidden=YES;
}

NSUInteger GOFAHUDPositionRevision(BOOL car) { Initialize();return positionRevision[car ? 1 : 0]; }

void GOFAHUDSetCamera(UIView *bubble,UILabel *distance,NSNumber *meters,BOOL available) {
    UIImageView *icon=(UIImageView *)[bubble viewWithTag:41061];
    icon.layer.borderColor=(available ? UIColor.systemRedColor : UIColor.systemGrayColor).CGColor;
    icon.alpha=available ? 1 : .5;
    distance.text=available && meters ? [NSString stringWithFormat:@"%@ m",meters] : @"—";
    icon.isAccessibilityElement=YES; icon.accessibilityLabel=@"Camera giao thông";
    icon.accessibilityValue=available ? distance.text : @"Chưa có cảnh báo camera";
}

void GOFAHUDCameraVisible(BOOL car,BOOL visible) { cameraVisible[car ? 1 : 0]=visible; }

void GOFAHUDExtraAlerts(BOOL car,NSDictionary *residential,NSDictionary *noPassing) {
 NSUInteger i=car ? 1 : 0; BOOL changed=![residentialAlerts[i] isEqual:residential] && (residentialAlerts[i] || residential); changed|=![noPassingAlerts[i] isEqual:noPassing] && (noPassingAlerts[i] || noPassing);
 residentialAlerts[i]=residential; noPassingAlerts[i]=noPassing; if(changed) revision++;
}
