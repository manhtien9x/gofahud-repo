#import <Foundation/Foundation.h>
#import "gofa-source-profile.h"
static NSDictionary *Field(NSString *name,NSString *type,NSInteger offset) { return @{@"field":name,@"type":type,@"offset":@(offset)}; }
static int RunTests(void) { @autoreleasepool {
    NSDictionary *required=@{@"a":@{@"type":@"Swift.Int",@"width":@8},@"b":@{@"type":@"Swift.UInt32",@"width":@4}};
    NSDictionary *offsets=nil; NSString *reason=nil; unsigned checks=0;
    #define CHECK(x) do { if(!(x)) { fprintf(stderr,"FAILED line %d: %s\n",__LINE__,#x); return 1; } checks++; } while(0)
    CHECK(GOFAHUDValidateFields(@[Field(@"a",@"Swift.Int",16),Field(@"b",@"Swift.UInt32",40)],required,64,&offsets,&reason));
    CHECK([offsets[@"a"] intValue]==16 && [offsets[@"b"] intValue]==40);
    // A future build may reorder/move fields without requiring another profile.
    CHECK(GOFAHUDValidateFields(@[Field(@"b",@"Swift.UInt32",8),Field(@"a",@"Swift.Int",48)],required,64,&offsets,&reason));
    CHECK([offsets[@"a"] intValue]==48 && [offsets[@"b"] intValue]==8);
    CHECK(!GOFAHUDValidateFields(@[Field(@"a",@"Swift.Double",16),Field(@"b",@"Swift.UInt32",40)],required,64,NULL,&reason));
    CHECK(!GOFAHUDValidateFields(@[Field(@"a",@"Swift.Int",16)],required,64,NULL,&reason));
    CHECK(!GOFAHUDValidateFields(@[Field(@"a",@"Swift.Int",16),Field(@"a",@"Swift.Int",32),Field(@"b",@"Swift.UInt32",40)],required,64,NULL,&reason));
    CHECK(!GOFAHUDValidateFields(@[Field(@"a",@"Swift.Int",60),Field(@"b",@"Swift.UInt32",40)],required,64,NULL,&reason));
    CHECK(!GOFAHUDValidateFields(@[Field(@"a",@"Swift.Int",-1),Field(@"b",@"Swift.UInt32",40)],required,64,NULL,&reason));
    CHECK(!GOFAHUDValidateFields(@[Field(@"a",@"Swift.Int",16),Field(@"b",@"Swift.UInt32",20)],required,64,NULL,&reason));
    CHECK(!GOFAHUDValidateFields(nil,required,64,NULL,&reason));
    CHECK(!GOFAHUDValidateFields(@[],required,0,NULL,&reason));
    CHECK(!GOFAHUDValidateFields(@[Field(@"a",@"Swift.Int",8)],@{@"a":@{@"type":@"Swift.Int",@"width":@8,@"minOffset":@16}},64,NULL,&reason));
    CHECK(GOFAHUDValidateFields(@[Field(@"extra",@"Swift.String",0),Field(@"a",@"Swift.Int",16),Field(@"b",@"Swift.UInt32",40)],required,64,NULL,&reason));
    printf("PASS %u layout validation checks\n",checks); return 0;
} }
__attribute__((constructor)) static void RunAsLibrary(void) {
    @autoreleasepool {
        int result=RunTests();
        NSDictionary *report=@{@"passed":@(result==0),@"exitCode":@(result),@"checks":@14};
        [[NSJSONSerialization dataWithJSONObject:report options:0 error:nil] writeToFile:[NSTemporaryDirectory() stringByAppendingPathComponent:@"gofahud-layout-test-result.json"] atomically:YES];
    }
}
