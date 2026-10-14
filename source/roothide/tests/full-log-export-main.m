#import "../prefs/full-log-export.h"
#include <stdio.h>
int main(void) { @autoreleasepool { NSError *error=nil; NSURL *file=GOFAHUDFullLogExport(@"Kiểm tra bộ xuất log",&error); if(!file) { fprintf(stderr,"%s\n",error.description.UTF8String); return 1; } puts(file.path.UTF8String); return 0; } }
