#import <UIKit/UIKit.h>
// Size validation adapted from GMapHUD (chou), MIT. See upstream/NOTICE.md.
NSUInteger GOFAHUDSizePercent(id value);
BOOL GOFAHUDVertical(BOOL car);
CGFloat GOFAHUDScale(BOOL car);
CGSize GOFAHUDBubbleSize(BOOL car);
void GOFAHUDLayoutLabels(UIView *bubble, NSArray<UILabel *> *labels, BOOL car);

BOOL GOFAHUDEnabled(BOOL car);
CGPoint GOFAHUDPosition(BOOL car);
NSUInteger GOFAHUDStyleRevision(void);
void GOFAHUDReloadStyle(void);
NSArray<NSString *> *GVMNormalizeModuleOrder(id value,BOOL vertical);
void GOFAHUDWarningStyle(UIView *bubble,NSNumber *speed,NSNumber *limit);

NSUInteger GOFAHUDPositionRevision(BOOL car);

void GOFAHUDSetCamera(UIView *bubble,UILabel *distance,NSNumber *meters,BOOL available);

void GOFAHUDCameraVisible(BOOL car,BOOL visible);

void GOFAHUDExtraAlerts(BOOL car,NSDictionary *residential,NSDictionary *noPassing);
