#import "phone-interaction.h"
BOOL GOFAPhoneDropMatches(CGPoint bubbleCenter, CGPoint finger, CGRect target) {
    CGRect hit=CGRectInset(target,-24,-24);
    return CGRectContainsPoint(hit,finger) || CGRectContainsPoint(hit,bubbleCenter);
}
