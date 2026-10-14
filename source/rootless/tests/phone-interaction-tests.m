#import "phone-interaction.h"
#include <assert.h>
int main(void) { @autoreleasepool {
    CGRect target=CGRectMake(157.5,591,60,60);
    // Finger can be 80pt away from card center when it grabs an edge.
    assert(GOFAPhoneDropMatches(CGPointMake(267.5,621),CGPointMake(187.5,621),target));
    assert(GOFAPhoneDropMatches(CGPointMake(187.5,621),CGPointMake(270,621),target));
    assert(!GOFAPhoneDropMatches(CGPointMake(80,621),CGPointMake(20,621),target));
    assert(!GOFAPhoneDropMatches(CGPointMake(187.5,400),CGPointMake(187.5,440),target));
    assert(GOFAPhoneDropMatches(CGPointMake(187.5,610),CGPointMake(190,620),target));
    puts("phone drop-target tests passed");
} }
