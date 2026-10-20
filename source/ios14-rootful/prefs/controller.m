// Adapted from GMapHUD preferences-controller.m (MIT, chou); see upstream/GMapHUD-LICENSE.
#import <UIKit/UIKit.h>
#import <CoreFoundation/CoreFoundation.h>
#import "bubble-style.h"
#import "test-state.h"
#import "full-log-export.h"
#import "speed-state.h"
#import "hud-live-state.h"
#include <notify.h>
#include <math.h>
#import <objc/runtime.h>
@interface PSSpecifier : NSObject
@property(nonatomic,copy) NSString *name;
+ (instancetype)groupSpecifierWithName:(NSString *)name;
+ (instancetype)preferenceSpecifierNamed:(NSString *)name target:(id)target set:(SEL)set get:(SEL)get detail:(Class)detail cell:(NSInteger)cell edit:(Class)edit;
- (void)setProperty:(id)value forKey:(NSString *)key;
- (id)propertyForKey:(NSString *)key;
- (void)setButtonAction:(SEL)action;
@end
@interface PSListController : UIViewController
@property(nonatomic,strong) PSSpecifier *specifier;
- (NSArray *)specifiers;
@end
@interface PSTableCell : UITableViewCell
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)identifier specifier:(PSSpecifier *)specifier;
@end
static NSString *const GOFAPreferencesValueChanged=@"GOFAPreferencesValueChanged";
@interface GOFASegmentedCell : PSTableCell
@property(nonatomic,strong) UISegmentedControl *picker;
@property(nonatomic,strong) PSSpecifier *settingSpecifier;
@end
@implementation GOFASegmentedCell
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)identifier specifier:(PSSpecifier *)specifier {
    if (!(self=[super initWithStyle:style reuseIdentifier:identifier specifier:specifier])) return nil;
    self.settingSpecifier=specifier; self.selectionStyle=UITableViewCellSelectionStyleNone;
    UILabel *label=[UILabel new]; label.text=specifier.name; label.numberOfLines=0;
    label.font=[UIFont preferredFontForTextStyle:UIFontTextStyleBody]; label.textColor=UIColor.labelColor; label.adjustsFontForContentSizeCategory=YES;
    self.picker=[[UISegmentedControl alloc] initWithItems:[specifier propertyForKey:@"titles"]]; self.picker.accessibilityLabel=specifier.name;
    NSArray *values=[specifier propertyForKey:@"values"];
    CFPreferencesAppSynchronize(CFSTR("local.gofahud"));
    id saved=CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)[specifier propertyForKey:@"key"],CFSTR("local.gofahud")));
    NSUInteger index=[values indexOfObject:saved ?: [specifier propertyForKey:@"default"]];
    self.picker.selectedSegmentIndex=index==NSNotFound ? 0 : (NSInteger)index;
    [self.picker addTarget:self action:@selector(changed:) forControlEvents:UIControlEventValueChanged];
    [self.picker.heightAnchor constraintGreaterThanOrEqualToConstant:44].active=YES;
    UIStackView *stack=[[UIStackView alloc] initWithArrangedSubviews:@[label,self.picker]]; stack.axis=UILayoutConstraintAxisVertical; stack.spacing=8; stack.translatesAutoresizingMaskIntoConstraints=NO;
    [self.contentView addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[[stack.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16],[stack.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16],[stack.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:8],[stack.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-8]]];
    return self;
}
- (void)layoutSubviews { [super layoutSubviews]; self.textLabel.hidden=YES; self.detailTextLabel.hidden=YES; }
- (void)changed:(UISegmentedControl *)picker {
    NSArray *values=[self.settingSpecifier propertyForKey:@"values"];
    if (picker.selectedSegmentIndex<0 || (NSUInteger)picker.selectedSegmentIndex>=values.count) return;
    NSString *key=[self.settingSpecifier propertyForKey:@"key"];
    if (![@[@"carLayout",@"phoneLayout",@"overspeedScope",@"theme",@"phonePosition",@"carPosition"] containsObject:key]) return;
    CFPreferencesSetAppValue((__bridge CFStringRef)key,(__bridge CFPropertyListRef)values[picker.selectedSegmentIndex],CFSTR("local.gofahud"));
    if (CFPreferencesAppSynchronize(CFSTR("local.gofahud"))) { notify_post("local.gofahud.style.changed"); [NSNotificationCenter.defaultCenter postNotificationName:GOFAPreferencesValueChanged object:nil]; [NSNotificationCenter.defaultCenter postNotificationName:GOFAPreferencesValueChanged object:key]; }
}
@end

@interface GOFASizeSliderCell : PSTableCell
@property(nonatomic,copy) NSString *sizeKey;
@property(nonatomic,strong) UISlider *sizeSlider;
@property(nonatomic,strong) UILabel *valueLabel;
@property(nonatomic) BOOL offset;
@end
@implementation GOFASizeSliderCell
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)identifier specifier:(PSSpecifier *)specifier {
    self=[super initWithStyle:style reuseIdentifier:identifier specifier:specifier];
    if (!self) return nil;
    self.selectionStyle=UITableViewCellSelectionStyleNone;
    self.contentView.userInteractionEnabled=YES;
    self.sizeKey=[specifier propertyForKey:@"key"];
    self.offset=[@[@"phoneXPercent",@"phoneYPercent"] containsObject:self.sizeKey];
    UILabel *label=[UILabel new]; label.text=specifier.name; label.numberOfLines=0;
    label.font=[UIFont preferredFontForTextStyle:UIFontTextStyleBody]; label.textColor=UIColor.labelColor; label.adjustsFontForContentSizeCategory=YES;
    self.valueLabel=[UILabel new]; self.valueLabel.textColor=UIColor.secondaryLabelColor;
    self.valueLabel.font=[UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];
    self.valueLabel.textAlignment=NSTextAlignmentRight; self.valueLabel.adjustsFontForContentSizeCategory=YES;
    [self.valueLabel setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    UIButton *reset=[UIButton buttonWithType:UIButtonTypeSystem];
    [reset setTitle:@"Đặt lại" forState:UIControlStateNormal];
    reset.contentHorizontalAlignment=UIControlContentHorizontalAlignmentLeft;
    reset.accessibilityLabel=[@"Đặt lại " stringByAppendingString:specifier.name];
    [reset addTarget:self action:@selector(resetSize) forControlEvents:UIControlEventTouchUpInside];

    [reset.heightAnchor constraintEqualToConstant:44].active=YES;
    UIStackView *header=[[UIStackView alloc] initWithArrangedSubviews:@[label,self.valueLabel]];
    header.axis=UILayoutConstraintAxisHorizontal; header.alignment=UIStackViewAlignmentCenter; header.spacing=8;
    self.sizeSlider=[UISlider new]; self.sizeSlider.minimumValue=self.offset ? -100 : 50; self.sizeSlider.maximumValue=self.offset ? 100 : 150;
    self.sizeSlider.accessibilityLabel=specifier.name;
    self.sizeSlider.accessibilityHint=self.offset ? @"0 phần trăm giữ nguyên góc đã chọn" : @"100 phần trăm là kích cỡ mặc định";
    CFPreferencesAppSynchronize(CFSTR("local.gofahud"));
    id saved=CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)self.sizeKey,CFSTR("local.gofahud")));
    self.sizeSlider.value=self.offset ? GOFAHUDSizePercent(saved) : GOFAHUDSizePercent(saved);
    [self.sizeSlider addTarget:self action:@selector(sizeChanged:) forControlEvents:UIControlEventValueChanged];
    [self.sizeSlider.heightAnchor constraintEqualToConstant:44].active=YES;
    UIView *separator=[UIView new]; separator.backgroundColor=UIColor.separatorColor;
    [separator.heightAnchor constraintEqualToConstant:1.0/UIScreen.mainScreen.scale].active=YES;
    UIStackView *stack=[[UIStackView alloc] initWithArrangedSubviews:@[header,self.sizeSlider,separator,reset]];
    stack.axis=UILayoutConstraintAxisVertical; stack.spacing=0; stack.translatesAutoresizingMaskIntoConstraints=NO;
    [self.contentView addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[
        [stack.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16],
        [stack.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16],
        [stack.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:8],
        [stack.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-8]]];
    [self updateValue]; return self;
}
- (void)layoutSubviews { [super layoutSubviews]; self.textLabel.hidden=YES; self.detailTextLabel.hidden=YES; }
- (void)updateValue {
    self.valueLabel.text=[NSString stringWithFormat:@"%ld%%",(long)lroundf(self.sizeSlider.value)];
    self.sizeSlider.accessibilityValue=self.valueLabel.text;
}
- (void)sizeChanged:(UISlider *)slider {
    if (![@[@"carSize",@"phoneSize"] containsObject:self.sizeKey]) return;
    float neutral=self.offset ? 0 : 100;
    if (fabsf(slider.value-neutral)<=2) slider.value=neutral;
    NSNumber *value=self.offset ? @(GOFAHUDSizePercent(@(slider.value))) : @(GOFAHUDSizePercent(@(slider.value)));
    CFPreferencesSetAppValue((__bridge CFStringRef)self.sizeKey,(__bridge CFPropertyListRef)value,CFSTR("local.gofahud"));
    if (CFPreferencesAppSynchronize(CFSTR("local.gofahud"))) { notify_post("local.gofahud.style.changed"); [NSNotificationCenter.defaultCenter postNotificationName:GOFAPreferencesValueChanged object:nil]; }
    [self updateValue];
}
- (void)resetSize { [self.sizeSlider setValue:self.offset ? 0 : 100 animated:!UIAccessibilityIsReduceMotionEnabled()]; [self sizeChanged:self.sizeSlider]; }
@end


// Same image-view preview pattern as GMapHUD, rendered with GOFA HUD's actual layout.
@interface GOFAPreviewCell : PSTableCell
@property(nonatomic,strong) UIImageView *preview;
@property(nonatomic) BOOL car;
@end
@implementation GOFAPreviewCell
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)identifier specifier:(PSSpecifier *)specifier {
    if (!(self=[super initWithStyle:style reuseIdentifier:identifier specifier:specifier])) return nil;
    self.car=[[specifier propertyForKey:@"car"] boolValue];
    self.selectionStyle=UITableViewCellSelectionStyleNone;
    self.preview=[UIImageView new]; self.preview.contentMode=UIViewContentModeScaleAspectFit;
    self.preview.translatesAutoresizingMaskIntoConstraints=NO;
    self.preview.isAccessibilityElement=YES; self.preview.accessibilityLabel=@"Minh họa bong bóng GOFA HUD";
    [self.contentView addSubview:self.preview];
    [NSLayoutConstraint activateConstraints:@[
      [self.preview.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16],
      [self.preview.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16],
      [self.preview.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:8],
      [self.preview.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-8]]];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(refreshPreview) name:GOFAPreferencesValueChanged object:nil];
    [self refreshPreview]; return self;
}
- (void)dealloc { [NSNotificationCenter.defaultCenter removeObserver:self]; }
- (void)layoutSubviews { [super layoutSubviews]; self.textLabel.hidden=YES; self.detailTextLabel.hidden=YES; }
- (void)refreshPreview {
    // Darwin preference callbacks run asynchronously; defer until the shared style cache updates.
    dispatch_async(dispatch_get_main_queue(), ^{
      GOFAHUDReloadStyle(); GOFAHUDCameraVisible(self.car,YES); CGSize size=GOFAHUDBubbleSize(self.car);
      UIView *canvas=[[UIView alloc] initWithFrame:self.car ? CGRectMake(0,0,800,480) : CGRectMake(0,0,320,270)];
      if (self.car) {
        UIImageView *map=[[UIImageView alloc] initWithFrame:canvas.bounds]; map.image=[UIImage imageNamed:@"full-map-top-right.png" inBundle:[NSBundle bundleForClass:self.class] compatibleWithTraitCollection:nil]; [canvas addSubview:map];
        UIView *cover=[[UIView alloc] initWithFrame:CGRectMake(530,100,268,102)]; cover.backgroundColor=[UIColor colorWithRed:0 green:.30 blue:.38 alpha:1]; [canvas addSubview:cover];
      }
      canvas.backgroundColor=[UIColor colorWithWhite:.12 alpha:1]; canvas.layer.cornerRadius=12; canvas.clipsToBounds=YES;
      UILabel *caption=[[UILabel alloc] initWithFrame:CGRectMake(12,8,296,22)]; caption.text=@"MINH HỌA · DỮ LIỆU MẪU";
      caption.textColor=UIColor.lightGrayColor; caption.textAlignment=NSTextAlignmentCenter; caption.font=[UIFont systemFontOfSize:11]; [canvas addSubview:caption];
      UIView *bubble=[[UIView alloc] initWithFrame:CGRectMake((320-size.width)/2,(300-size.height)/2,size.width,size.height)];
      bubble.backgroundColor=[UIColor colorWithWhite:.04 alpha:.95]; if (self.car) { bubble.transform=CGAffineTransformMakeScale(2,2); bubble.center=CGPointMake(660,220); caption.frame=CGRectMake(100,440,690,24); } [canvas addSubview:bubble];
      NSMutableArray *labels=[NSMutableArray new];
      for (NSString *text in @[@"GOFA",@"42",@"50",@"200 m"]) {
        UILabel *label=[UILabel new]; label.text=text; label.textColor=UIColor.whiteColor;
        label.textAlignment=NSTextAlignmentCenter; [bubble addSubview:label]; [labels addObject:label];
      }
      UILabel *limit=labels[2]; limit.backgroundColor=UIColor.whiteColor; limit.textColor=UIColor.blackColor; limit.layer.borderColor=UIColor.systemRedColor.CGColor;
      GOFAHUDLayoutLabels(bubble,labels,self.car); GOFAHUDSetCamera(bubble,labels[3],@200,YES);
      UIGraphicsImageRenderer *renderer=[[UIGraphicsImageRenderer alloc] initWithSize:canvas.bounds.size];
      self.preview.image=[renderer imageWithActions:^(UIGraphicsImageRendererContext *context){ [canvas.layer renderInContext:context.CGContext]; }];
    });
}
@end

@interface GVMModuleOrderCell : PSTableCell
@end
static NSArray<NSString *> *GVMReadModuleOrder(NSString *key) {
    CFPreferencesAppSynchronize(CFSTR("local.gofahud"));
    id saved=CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)key,CFSTR("local.gofahud")));
    NSString *layoutKey=[key stringByReplacingOccurrencesOfString:@"Modules" withString:@"Layout"];
    id layout=CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)layoutKey,CFSTR("local.gofahud")));
    BOOL vertical=[layout isEqual:@"vertical"] || (![layout isEqual:@"horizontal"] &&
        ([key isEqual:@"dashboardModules"] || ([key isEqual:@"phoneModules"] && UIScreen.mainScreen.bounds.size.height>UIScreen.mainScreen.bounds.size.width)));
    return GVMNormalizeModuleOrder(saved,vertical);
}

@interface GVMModuleOrderDataSource : NSObject <UITableViewDataSource,UITableViewDelegate>
@property(nonatomic,strong) NSMutableArray<NSString *> *order;
@property(nonatomic,copy) NSString *preferenceKey;
@property(nonatomic,copy) void (^orderChanged)(void);
@end
@interface GVMModuleOrderCell ()
@property(nonatomic,strong) UITableView *moduleTable;
@property(nonatomic,strong) GVMModuleOrderDataSource *moduleDataSource;
@property(nonatomic,strong) UIStackView *horizontalPreview;
@property(nonatomic,strong) UIStackView *verticalPreview;
@end
@implementation GVMModuleOrderCell
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)identifier specifier:(PSSpecifier *)specifier {
    if (!(self=[super initWithStyle:style reuseIdentifier:identifier specifier:specifier])) return nil;
    self.selectionStyle=UITableViewCellSelectionStyleNone;
    NSString *key=[specifier propertyForKey:@"key"];
    self.moduleDataSource=[GVMModuleOrderDataSource new];
    self.moduleDataSource.order=[GVMReadModuleOrder(key) mutableCopy];
    self.moduleDataSource.preferenceKey=key;
    self.moduleTable=[[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.moduleTable.scrollEnabled=NO; self.moduleTable.backgroundColor=UIColor.clearColor;
    self.moduleTable.rowHeight=48; self.moduleTable.dataSource=self.moduleDataSource; self.moduleTable.delegate=self.moduleDataSource;
    [self.moduleTable.heightAnchor constraintEqualToConstant:144].active=YES;
    [self.moduleTable setEditing:YES animated:NO];
    UILabel *caption=[UILabel new]; caption.text=@"Minh họa ngang và dọc"; caption.font=[UIFont preferredFontForTextStyle:UIFontTextStyleFootnote]; caption.textColor=UIColor.secondaryLabelColor;
    self.horizontalPreview=[UIStackView new]; self.verticalPreview=[UIStackView new];
    UIStackView *previews=[[UIStackView alloc] initWithArrangedSubviews:@[self.horizontalPreview,self.verticalPreview]];
    previews.axis=UILayoutConstraintAxisHorizontal; previews.alignment=UIStackViewAlignmentCenter; previews.distribution=UIStackViewDistributionEqualSpacing; previews.spacing=8;
    UIButton *reset=[UIButton buttonWithType:UIButtonTypeSystem]; [reset setTitle:@"Đặt lại" forState:UIControlStateNormal]; reset.contentHorizontalAlignment=UIControlContentHorizontalAlignmentLeft;
    [reset.heightAnchor constraintEqualToConstant:44].active=YES;
    [reset addTarget:self action:@selector(resetOrder) forControlEvents:UIControlEventTouchUpInside];
    UIStackView *stack=[[UIStackView alloc] initWithArrangedSubviews:@[caption,previews,self.moduleTable,reset]];
    stack.axis=UILayoutConstraintAxisVertical; stack.spacing=8; stack.translatesAutoresizingMaskIntoConstraints=NO;
    [self.contentView addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[[stack.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16],[stack.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16],[stack.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:12],[stack.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-12]]];
    __weak GVMModuleOrderCell *weakSelf=self;
    self.moduleDataSource.orderChanged=^{ [weakSelf refreshPreview]; };
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(settingsChanged) name:@"GVMPreferencesValueChanged" object:nil];
    [self refreshPreview]; return self;
}
- (void)dealloc { [NSNotificationCenter.defaultCenter removeObserver:self]; }
- (void)layoutSubviews { [super layoutSubviews]; self.textLabel.hidden=YES; self.detailTextLabel.hidden=YES; }
- (void)settingsChanged { self.moduleDataSource.order=[GVMReadModuleOrder(self.moduleDataSource.preferenceKey) mutableCopy]; [self.moduleTable reloadData]; [self refreshPreview]; }
- (void)refreshPreview {
    for (UIStackView *preview in @[self.horizontalPreview,self.verticalPreview]) {
    preview.axis=preview==self.verticalPreview ? UILayoutConstraintAxisVertical : UILayoutConstraintAxisHorizontal;
    preview.spacing=0; preview.distribution=UIStackViewDistributionFillEqually;
    preview.backgroundColor=[UIColor colorWithWhite:0.12 alpha:0.65]; preview.layer.cornerRadius=preview==self.verticalPreview ? 25 : 14; preview.clipsToBounds=YES;
    for (UIView *view in preview.arrangedSubviews.copy) { [preview removeArrangedSubview:view]; [view removeFromSuperview]; }
    id saved=CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)self.moduleDataSource.preferenceKey,CFSTR("local.gofahud")));
    NSArray *previewOrder=GVMNormalizeModuleOrder(saved,preview==self.verticalPreview);
    for (NSString *module in previewOrder) {
        UIView *tile=[UIView new]; tile.backgroundColor=UIColor.clearColor;
        [tile.widthAnchor constraintEqualToConstant:50].active=YES; [tile.heightAnchor constraintEqualToConstant:50].active=YES;
        BOOL speed=[module isEqual:@"speed"], limit=[module isEqual:@"limit"];
        UILabel *value=[UILabel new]; value.text=speed ? @"54" : limit ? @"60" : @"80"; value.textAlignment=NSTextAlignmentCenter;
        value.font=[UIFont systemFontOfSize:19 weight:UIFontWeightSemibold]; value.textColor=speed ? UIColor.whiteColor : UIColor.blackColor;
        value.translatesAutoresizingMaskIntoConstraints=NO;
        if (!speed) { value.backgroundColor=UIColor.whiteColor; value.layer.cornerRadius=17; value.layer.masksToBounds=YES; value.layer.borderColor=UIColor.systemRedColor.CGColor; value.layer.borderWidth=4; }
        [tile addSubview:value];
        if (!speed) {
            NSString *filename=limit ? @"speed_limit_60.png" : @"speed_limit_80.png";
            UIImage *image=nil;
            for (NSString *root in @[@"/usr/share/gmaphud/gmaphud",@"/usr/share/gmaphud/gmaphud"]) { image=[UIImage imageWithContentsOfFile:[root stringByAppendingPathComponent:filename]]; if (image) break; }
            if (image) {
                value.text=@""; value.layer.borderWidth=0; value.backgroundColor=UIColor.clearColor;
                UIImageView *sign=[[UIImageView alloc] initWithImage:image]; sign.contentMode=UIViewContentModeScaleAspectFit; sign.translatesAutoresizingMaskIntoConstraints=NO; [value addSubview:sign];
                [NSLayoutConstraint activateConstraints:@[[sign.leadingAnchor constraintEqualToAnchor:value.leadingAnchor],[sign.trailingAnchor constraintEqualToAnchor:value.trailingAnchor],[sign.topAnchor constraintEqualToAnchor:value.topAnchor],[sign.bottomAnchor constraintEqualToAnchor:value.bottomAnchor]]];
            }
        }
        UILabel *unit=[UILabel new]; unit.text=speed ? @"km/h" : limit ? @"" : @"200 m"; unit.font=[UIFont systemFontOfSize:9]; unit.textAlignment=NSTextAlignmentCenter; unit.textColor=UIColor.whiteColor; unit.translatesAutoresizingMaskIntoConstraints=NO; [tile addSubview:unit];
        [NSLayoutConstraint activateConstraints:@[[value.widthAnchor constraintEqualToConstant:34],[value.heightAnchor constraintEqualToConstant:34],[value.centerXAnchor constraintEqualToAnchor:tile.centerXAnchor],[value.topAnchor constraintEqualToAnchor:tile.topAnchor constant:3],[unit.topAnchor constraintEqualToAnchor:value.bottomAnchor constant:1],[unit.centerXAnchor constraintEqualToAnchor:tile.centerXAnchor]]];
        tile.isAccessibilityElement=YES; tile.accessibilityLabel=@{@"speed":@"Tốc độ hiện tại",@"limit":@"Giới hạn hiện tại",@"alerts":@"Cảnh báo sắp tới"}[module];
        [preview addArrangedSubview:tile];
    }
    }
}
- (void)resetOrder {
    NSString *key=self.moduleDataSource.preferenceKey;
    if (![@[@"carModules",@"phoneModules"] containsObject:key]) return;
    // Removing the override keeps the default responsive to the selected orientation.
    CFPreferencesSetAppValue((__bridge CFStringRef)key,NULL,CFSTR("local.gofahud"));
    if (!CFPreferencesAppSynchronize(CFSTR("local.gofahud"))) return;
    notify_post("local.gofahud.style.changed"); [NSNotificationCenter.defaultCenter postNotificationName:GOFAPreferencesValueChanged object:nil];
    self.moduleDataSource.order=[GVMReadModuleOrder(key) mutableCopy];
    [self.moduleTable reloadData];
    [self refreshPreview];
}
@end
// A plain UIKit delegate avoids PSListController callbacks that expect specifiers.
@implementation GVMModuleOrderDataSource
- (NSInteger)numberOfSectionsInTableView:(__unused UITableView *)table { return 1; }
- (NSInteger)tableView:(__unused UITableView *)table numberOfRowsInSection:(__unused NSInteger)section { return self.order.count; }
- (UITableViewCell *)tableView:(UITableView *)table cellForRowAtIndexPath:(NSIndexPath *)path {
    UITableViewCell *cell=[table dequeueReusableCellWithIdentifier:@"module"] ?: [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"module"];
    cell.textLabel.text=@{@"speed":@"Tốc độ hiện tại",@"limit":@"Giới hạn hiện tại",@"alerts":@"Cảnh báo sắp tới"}[self.order[path.row]];
    cell.textLabel.font=[UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    cell.textLabel.adjustsFontForContentSizeCategory=YES; cell.textLabel.numberOfLines=0;
    cell.showsReorderControl=YES; cell.selectionStyle=UITableViewCellSelectionStyleNone; return cell;
}
- (BOOL)tableView:(__unused UITableView *)table canMoveRowAtIndexPath:(__unused NSIndexPath *)path { return YES; }
- (UITableViewCellEditingStyle)tableView:(__unused UITableView *)table editingStyleForRowAtIndexPath:(__unused NSIndexPath *)path { return UITableViewCellEditingStyleNone; }
- (BOOL)tableView:(__unused UITableView *)table shouldIndentWhileEditingRowAtIndexPath:(__unused NSIndexPath *)path { return NO; }

- (void)tableView:(__unused UITableView *)table moveRowAtIndexPath:(NSIndexPath *)from toIndexPath:(NSIndexPath *)to {
    NSString *item=self.order[from.row]; [self.order removeObjectAtIndex:from.row]; [self.order insertObject:item atIndex:to.row];
    NSString *key=self.preferenceKey;
    if (![@[@"carModules",@"phoneModules"] containsObject:key]) return;
    CFPreferencesSetAppValue((__bridge CFStringRef)key,(__bridge CFArrayRef)self.order,CFSTR("local.gofahud"));
    if (CFPreferencesAppSynchronize(CFSTR("local.gofahud"))) { notify_post("local.gofahud.style.changed"); [NSNotificationCenter.defaultCenter postNotificationName:GOFAPreferencesValueChanged object:nil]; if (self.orderChanged) self.orderChanged(); }
}
@end

// Keep each explanation attached to its actual section, without empty spacer groups.
static PSSpecifier *GOFAHUDGroup(NSString *name) {
 PSSpecifier *group=[PSSpecifier groupSpecifierWithName:name];
 [group setProperty:@YES forKey:@"gofaGroup"];
 return group;
}
static PSSpecifier *GOFAHUDGroupForSection(PSListController *controller,NSInteger section) {
 NSInteger index=0;
 for(PSSpecifier *item in [controller specifiers]) if([[item propertyForKey:@"gofaGroup"] boolValue]) {
  if(index++==section) return item;
 }
 return nil;
}
static NSString *GOFAHUDFooterText(PSListController *controller,NSInteger section) {
 id text=[GOFAHUDGroupForSection(controller,section) propertyForKey:@"footerText"];
 return [text isKindOfClass:NSString.class] ? text : @"";
}
@interface GOFAHUDBaseController : PSListController
- (id)readPreferenceValue:(PSSpecifier *)specifier;
- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier;
@end
@implementation GOFAHUDBaseController
- (CGFloat)tableView:(UITableView *)table heightForHeaderInSection:(NSInteger)section {
 NSString *name=GOFAHUDGroupForSection(self,section).name;
 return name.length ? ceil([UIFont preferredFontForTextStyle:UIFontTextStyleFootnote].lineHeight)+12 : (section==0 ? 8 : 10);
}
- (CGFloat)tableView:(UITableView *)table heightForFooterInSection:(NSInteger)section {
 NSString *text=GOFAHUDFooterText(self,section);
 if(!text.length) return CGFLOAT_MIN;
 CGFloat width=MAX(1,CGRectGetWidth(table.bounds)-MAX(16,table.layoutMargins.left)-MAX(16,table.layoutMargins.right));
 UIFont *font=[UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];
 CGRect rect=[text boundingRectWithSize:CGSizeMake(width,CGFLOAT_MAX) options:NSStringDrawingUsesLineFragmentOrigin|NSStringDrawingUsesFontLeading attributes:@{NSFontAttributeName:font} context:nil];
 return ceil(rect.size.height)+10;
}
- (UIView *)tableView:(UITableView *)table viewForFooterInSection:(NSInteger)section {
 NSString *text=GOFAHUDFooterText(self,section);
 if(!text.length) return nil;
 UIView *footer=[UIView new];
 UILabel *label=[UILabel new]; label.text=text; label.numberOfLines=0;
 label.font=[UIFont preferredFontForTextStyle:UIFontTextStyleFootnote]; label.adjustsFontForContentSizeCategory=YES;
 label.textColor=UIColor.secondaryLabelColor; label.translatesAutoresizingMaskIntoConstraints=NO;
 [footer addSubview:label];
 [NSLayoutConstraint activateConstraints:@[[label.topAnchor constraintEqualToAnchor:footer.topAnchor constant:4],[label.leadingAnchor constraintEqualToAnchor:footer.leadingAnchor constant:MAX(16,table.layoutMargins.left)],[label.trailingAnchor constraintEqualToAnchor:footer.trailingAnchor constant:-MAX(16,table.layoutMargins.right)],[label.bottomAnchor constraintEqualToAnchor:footer.bottomAnchor constant:-6]]];
 return footer;
}

- (id)readPreferenceValue:(PSSpecifier *)specifier { CFPreferencesAppSynchronize(CFSTR("local.gofahud")); id value=CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)[specifier propertyForKey:@"key"],CFSTR("local.gofahud"))); return value ?: [specifier propertyForKey:@"default"]; }
- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier { CFPreferencesSetAppValue((__bridge CFStringRef)[specifier propertyForKey:@"key"],(__bridge CFPropertyListRef)value,CFSTR("local.gofahud")); if(CFPreferencesAppSynchronize(CFSTR("local.gofahud"))) { notify_post("local.gofahud.style.changed"); [NSNotificationCenter.defaultCenter postNotificationName:GOFAPreferencesValueChanged object:nil]; } }
@end
static PSSpecifier *GOFASwitch(NSString *title,id target,NSString *key) { PSSpecifier *item=[PSSpecifier preferenceSpecifierNamed:title target:target set:@selector(setPreferenceValue:specifier:) get:@selector(readPreferenceValue:) detail:Nil cell:6 edit:Nil]; [item setProperty:key forKey:@"key"]; [item setProperty:@YES forKey:@"default"]; return item; }
static PSSpecifier *GOFAChoice(NSString *title,id target,NSString *key,NSArray *values,NSArray *titles,id def) { PSSpecifier *item=[PSSpecifier preferenceSpecifierNamed:title target:target set:NULL get:NULL detail:Nil cell:4 edit:Nil]; [item setProperty:key forKey:@"key"]; [item setProperty:values forKey:@"values"]; [item setProperty:titles forKey:@"titles"]; [item setProperty:def forKey:@"default"]; [item setProperty:GOFASegmentedCell.class forKey:@"cellClass"]; [item setProperty:@YES forKey:@"enabled"]; [item setProperty:@110 forKey:@"height"]; return item; }
@interface GOFAHUDSurfaceController : GOFAHUDBaseController
@property(nonatomic,strong) NSArray *items;
@end
@implementation GOFAHUDSurfaceController
- (NSArray *)specifiers {
    if (self.items) return self.items;
    BOOL car=[[self.specifier propertyForKey:@"car"] boolValue];
    self.title=car ? @"CarPlay" : @"iPhone";
    NSMutableArray *items=[NSMutableArray new];
    for (NSUInteger i=car ? 1 : 0;i<(car ? 2 : 1);i++) {
      NSString *prefix=i ? @"car" : @"phone";
      PSSpecifier *group=GOFAHUDGroup(i ? @"Bong bóng trên CarPlay" : @"Bong bóng trên iPhone");
      [group setProperty:@"Thay đổi áp dụng ngay. Kéo bong bóng trực tiếp để đổi vị trí." forKey:@"footerText"]; [items addObject:group];
      [items addObject:GOFASwitch(@"Hiển thị bong bóng",self,[prefix stringByAppendingString:@"Enabled"])];
      [items addObject:GOFAHUDGroup(@"")];
      [items addObject:GOFAChoice(@"Vị trí",self,[prefix stringByAppendingString:@"Position"],@[@"top-left",@"top-right",@"bottom-left",@"bottom-right"],@[@"Trên trái",@"Trên phải",@"Dưới trái",@"Dưới phải"],@"top-right")];
      PSSpecifier *preview=[PSSpecifier preferenceSpecifierNamed:@"Minh họa" target:self set:NULL get:NULL detail:Nil cell:4 edit:Nil];
      [preview setProperty:GOFAPreviewCell.class forKey:@"cellClass"]; [preview setProperty:@(i==1) forKey:@"car"]; [preview setProperty:@(car ? 200 : 250) forKey:@"height"]; [items addObject:preview];
      PSSpecifier *layout=[PSSpecifier preferenceSpecifierNamed:@"Bố cục" target:self set:NULL get:NULL detail:Nil cell:4 edit:Nil];
      [layout setProperty:[prefix stringByAppendingString:@"Layout"] forKey:@"key"];
      [layout setProperty:@[@"horizontal",@"vertical"] forKey:@"values"]; [layout setProperty:@[@"Ngang",@"Dọc"] forKey:@"titles"]; [layout setProperty:@"horizontal" forKey:@"default"];
      [layout setProperty:GOFASegmentedCell.class forKey:@"cellClass"]; [layout setProperty:@YES forKey:@"enabled"]; [layout setProperty:@110 forKey:@"height"]; [items addObject:layout];
      PSSpecifier *order=[PSSpecifier preferenceSpecifierNamed:@"Thứ tự các phần" target:self set:NULL get:NULL detail:Nil cell:4 edit:Nil]; [order setProperty:[prefix stringByAppendingString:@"Modules"] forKey:@"key"]; [order setProperty:GVMModuleOrderCell.class forKey:@"cellClass"]; [order setProperty:@YES forKey:@"enabled"]; [order setProperty:@400 forKey:@"height"]; [items addObject:order];
      PSSpecifier *sizeGroup=GOFAHUDGroup(@""); [sizeGroup setProperty:@"100% là kích cỡ mặc định." forKey:@"footerText"]; [items addObject:sizeGroup];
      PSSpecifier *size=[PSSpecifier preferenceSpecifierNamed:@"Kích cỡ" target:self set:NULL get:NULL detail:Nil cell:4 edit:Nil];
      [size setProperty:[prefix stringByAppendingString:@"Size"] forKey:@"key"]; [size setProperty:GOFASizeSliderCell.class forKey:@"cellClass"]; [size setProperty:@YES forKey:@"enabled"]; [size setProperty:@160 forKey:@"height"]; [items addObject:size];
    }
    self.items=items; Ivar storage=class_getInstanceVariable(PSListController.class,"_specifiers"); if (storage) object_setIvar(self,storage,items); return self.items;
}
@end


static NSString *GOFAHUDLogsSummary(void) {
 NSMutableString *text=[NSMutableString stringWithFormat:@"GOFA HUD — Báo cáo chẩn đoán\nThời gian: %@\niOS: %@\n\n",NSDate.date,NSProcessInfo.processInfo.operatingSystemVersionString];
 for(NSString *name in @[@"local.gofahud.source.ready",@"local.gofahud.gofa.foreground",@"local.gofahud.carplay.enabled",@"local.gofahud.carplay.gofa-active"]) { int token=-1; uint64_t value=0; if(notify_register_check(name.UTF8String,&token)==NOTIFY_STATUS_OK) { notify_get_state(token,&value); notify_cancel(token); } [text appendFormat:@"%@: %llu\n",name,(unsigned long long)value]; }
 NSString *dir=@"/var/mobile/Library/Logs";
 for(NSString *name in @[@"GofaHUD-phone.log",@"GofaHUD-launch.log",@"GofaHUD-background.log",@"GofaHUD-carplay-open-result.json",@"GofaHUD-native-bridge.log"]) { NSString *path=[dir stringByAppendingPathComponent:name]; NSData *data=[NSData dataWithContentsOfFile:path options:NSDataReadingMappedIfSafe error:nil]; if(data.length>32768) data=[data subdataWithRange:NSMakeRange(data.length-32768,32768)]; NSString *log=[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]; [text appendFormat:@"\n--- %@ ---\n%@\n",name,log ?: @"Chưa có log đọc được"]; }
 return text;
}
@interface GOFATestCell : PSTableCell
@end
@implementation GOFATestCell
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)identifier specifier:(PSSpecifier *)specifier {
 if(!(self=[super initWithStyle:style reuseIdentifier:identifier specifier:specifier])) return nil;
 self.selectionStyle=UITableViewCellSelectionStyleNone;
 UIStackView *stack=[UIStackView new]; stack.axis=UILayoutConstraintAxisHorizontal; stack.distribution=UIStackViewDistributionFillEqually; stack.translatesAutoresizingMaskIntoConstraints=NO;
 for(NSUInteger i=0;i<4;i++) { UIButton *b=[UIButton buttonWithType:UIButtonTypeSystem]; [b setTitle:@[@"42 / 50",@"48 / 50",@"62 / 50",@"Tắt thử"][i] forState:UIControlStateNormal]; b.tag=i; [b addTarget:self action:@selector(test:) forControlEvents:UIControlEventTouchUpInside]; [stack addArrangedSubview:b]; }
 [self.contentView addSubview:stack]; [NSLayoutConstraint activateConstraints:@[[stack.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:8],[stack.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-8],[stack.topAnchor constraintEqualToAnchor:self.contentView.topAnchor],[stack.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor]]]; return self;
}
- (void)layoutSubviews { [super layoutSubviews]; self.textLabel.hidden=YES; self.detailTextLabel.hidden=YES; }
- (void)test:(UIButton *)button { int token=-1; if(notify_register_check(GVMTestStateName,&token)!=NOTIFY_STATUS_OK) return; uint64_t value=button.tag==3 ? 0 : GVMEncodeTest([@[@42,@48,@62][button.tag] integerValue],50,NSProcessInfo.processInfo.systemUptime,60); notify_set_state(token,value); notify_post(GVMTestStateName); notify_cancel(token); }
@end
@interface GOFAHUDPrefsController : GOFAHUDBaseController
@property(nonatomic,strong) NSArray *items;
@property(nonatomic) BOOL preparingLogs;
@end
@implementation GOFAHUDPrefsController
- (void)sendLogs {
 if(self.preparingLogs || self.presentedViewController) return;
 self.preparingLogs=YES;
 UIAlertController *progress=[UIAlertController alertControllerWithTitle:@"Đang gom logs…" message:@"Đợi một chút để tạo file. Bảng chia sẻ của iOS sẽ tự mở khi hoàn tất." preferredStyle:UIAlertControllerStyleAlert];
 [self presentViewController:progress animated:YES completion:^{
  dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY,0),^{
   NSError *error=nil;
   NSURL *file=GOFAHUDFullLogExport(GOFAHUDLogsSummary(),&error);
   dispatch_async(dispatch_get_main_queue(),^{
    [progress dismissViewControllerAnimated:YES completion:^{
     self.preparingLogs=NO;
     if(!file) {
      UIAlertController *alert=[UIAlertController alertControllerWithTitle:@"Không thể tạo file logs" message:error.localizedDescription ?: @"Không đọc được log hoặc máy không đủ dung lượng trống." preferredStyle:UIAlertControllerStyleAlert];
      [alert addAction:[UIAlertAction actionWithTitle:@"Đóng" style:UIAlertActionStyleCancel handler:nil]];
      [self presentViewController:alert animated:YES completion:nil]; return;
     }
     UIActivityViewController *share=[[UIActivityViewController alloc] initWithActivityItems:@[file] applicationActivities:nil];
     UIPopoverPresentationController *popover=share.popoverPresentationController;
     if(popover) {
      popover.sourceView=self.view;
      popover.sourceRect=CGRectMake(CGRectGetMidX(self.view.bounds),CGRectGetMidY(self.view.bounds),1,1);
      popover.permittedArrowDirections=0;
     }
     [self presentViewController:share animated:YES completion:nil];
    }];
   });
  });
 }];
}

- (NSArray *)specifiers {
 if(self.items) return self.items;
 self.title=@"GOFA HUD";
 NSMutableArray *items=[NSMutableArray new];
 [items addObject:GOFAHUDGroup(@"Hiển thị")]; [items addObject:GOFASwitch(@"Hiển thị bong bóng",self,@"bubbleEnabled")];
 PSSpecifier *automationGroup=GOFAHUDGroup(@"Tự động hóa"); [automationGroup setProperty:@"Tự mở nguồn khi bong bóng hoạt động. Tự thoát sau 20 giây ngắt CarPlay; kết nối lại sẽ hủy đếm giờ." forKey:@"footerText"]; [items addObject:automationGroup];
 PSSpecifier *wake=GOFASwitch(@"Tự mở GOFA",self,@"autoWake"); [wake setProperty:@NO forKey:@"default"]; [items addObject:wake];
 PSSpecifier *exit=GOFASwitch(@"Thoát GOFA khi ngắt CarPlay",self,@"autoExit"); [exit setProperty:@NO forKey:@"default"]; [items addObject:exit];
 [items addObject:GOFAHUDGroup(@"Cảnh báo vượt tốc độ")];
 [items addObject:GOFAChoice(@"Phạm vi",self,@"overspeedScope",@[@"off",@"map",@"screen"],@[@"Tắt",@"Bong bóng",@"Màn hình"],@"off")];
 [items addObject:GOFAChoice(@"Màu giao diện",self,@"theme",@[@"auto",@"light",@"dark"],@[@"Tự động",@"Sáng",@"Tối"],@"auto")];
 PSSpecifier *group=GOFAHUDGroup(@"Bố cục bong bóng");
 [group setProperty:@"Điều chỉnh riêng cho từng màn hình." forKey:@"footerText"]; [items addObject:group];
 for (NSUInteger i=0;i<2;i++) {
   PSSpecifier *surface=[PSSpecifier preferenceSpecifierNamed:i ? @"CarPlay" : @"iPhone" target:self set:NULL get:NULL detail:GOFAHUDSurfaceController.class cell:1 edit:Nil];
   [surface setProperty:@(i==1) forKey:@"car"]; [surface setProperty:@YES forKey:@"isController"]; [items addObject:surface];
 }
 PSSpecifier *help=GOFAHUDGroup(@"Sử dụng");
 [help setProperty:@"Kéo bong bóng để đổi vị trí. Chạm một lần để mở GOFA. Kéo vào dấu X để tắt; mở lại GOFA rồi chuyển ứng dụng để hiện lại." forKey:@"footerText"]; [items addObject:help];
 PSSpecifier *supportGroup=GOFAHUDGroup(@"Hỗ trợ"); [supportGroup setProperty:@"Gom đầy đủ log đọc được rồi mở bảng chia sẻ file của iOS. Bạn chọn ứng dụng và người nhận; tweak không tự gửi log." forKey:@"footerText"]; [items addObject:supportGroup]; PSSpecifier *send=[PSSpecifier preferenceSpecifierNamed:@"Gửi logs" target:self set:NULL get:NULL detail:Nil cell:13 edit:Nil]; [send setButtonAction:@selector(sendLogs)]; [items addObject:send];
 PSSpecifier *testGroup=GOFAHUDGroup(@"Test hiển thị bong bóng"); [testGroup setProperty:@"Dữ liệu thử có nhãn TEST và tự tắt sau 60 giây. Chỉ dùng thử khi xe đang đỗ." forKey:@"footerText"]; [items addObject:testGroup];
 PSSpecifier *test=[PSSpecifier preferenceSpecifierNamed:@"Thử hiển thị" target:self set:NULL get:NULL detail:Nil cell:4 edit:Nil]; [test setProperty:GOFATestCell.class forKey:@"cellClass"]; [test setProperty:@YES forKey:@"enabled"]; [test setProperty:@52 forKey:@"height"]; [items addObject:test];
 self.items=items; Ivar storage=class_getInstanceVariable(PSListController.class,"_specifiers"); if(storage) object_setIvar(self,storage,items); return items;
}
@end
