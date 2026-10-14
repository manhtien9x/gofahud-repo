#import "full-log-export.h"
#import <CommonCrypto/CommonDigest.h>
#include <stdio.h>
#include <errno.h>
#include <stdlib.h>
#include <string.h>
static BOOL Write(FILE *file,NSData *data) { return data.length==0 || fwrite(data.bytes,1,data.length,file)==data.length; }
static BOOL Text(FILE *file,NSString *text) { return Write(file,[text dataUsingEncoding:NSUTF8StringEncoding]); }
// Validate UTF-8 without loading the complete file into memory.
static BOOL ValidUTF8(FILE *input,unsigned long long limit) {
 unsigned char bytes[8192]; unsigned remaining=0,code=0,minimum=0;
 while(limit) { size_t count=fread(bytes,1,(size_t)MIN(limit,sizeof(bytes)),input); if(!count) break; limit-=count;
  for(size_t i=0;i<count;i++) { unsigned c=bytes[i]; if(!remaining) { if(c<128) continue; if(c>=194 && c<=223) { remaining=1; code=c&31; minimum=128; } else if(c>=224 && c<=239) { remaining=2; code=c&15; minimum=2048; } else if(c>=240 && c<=244) { remaining=3; code=c&7; minimum=65536; } else return NO; }
   else { if((c&192)!=128) return NO; code=(code<<6)|(c&63); if(--remaining==0 && (code<minimum || code>0x10ffff || (code>=0xd800 && code<=0xdfff))) return NO; }
  }
 }
 return !remaining && !ferror(input);
}
NSURL *GOFAHUDFullLogExport(NSString *summary,NSError **error) {
 @autoreleasepool {
  NSString *identifier=NSUUID.UUID.UUIDString;
  NSString *path=[NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"GOFAHUD-full-logs-%@.txt",identifier]];
  FILE *output=fopen(path.fileSystemRepresentation,"wb");
  if(!output) { if(error) *error=[NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:nil]; return nil; }
  BOOL ok=YES; NSMutableArray *issues=[NSMutableArray new],*manifest=[NSMutableArray new]; NSFileManager *fm=NSFileManager.defaultManager;
  NSDate *start=NSDate.date;
  ok&=Text(output,[NSString stringWithFormat:@"GOFA HUD — TOÀN BỘ LOG ĐỌC ĐƯỢC\nBắt đầu: %@\niOS: %@\nMã phân cách: %@\nNội dung từng tệp được giữ nguyên. Tệp không phải UTF-8 dùng Base64. Đây là ảnh chụp dữ liệu theo thời điểm đọc, không phải bản sao nguyên tử toàn hệ thống.\n\n%@\n",start,NSProcessInfo.processInfo.operatingSystemVersionString,identifier,summary ?: @""]);
  NSMutableArray *roots=[NSMutableArray arrayWithObjects:@"/var/mobile/Library/Logs",@"/Library/Logs/CrashReporter",nil];
  // Include GOFA's probe logs, which live in the application's sandbox tmp directory.
  NSString *containers=@"/var/mobile/Containers/Data/Application";
  NSError *listError=nil; NSArray *containerNames=[fm contentsOfDirectoryAtPath:containers error:&listError];
  if(listError) [issues addObject:@{@"path":containers,@"reason":listError.localizedDescription}];
  for(NSString *name in containerNames) {
   NSString *container=[containers stringByAppendingPathComponent:name];
   NSDictionary *metadata=[NSDictionary dictionaryWithContentsOfFile:[container stringByAppendingPathComponent:@".com.apple.mobile_container_manager.metadata.plist"]];
   if([metadata[@"MCMMetadataIdentifier"] isEqual:@"com.lumi.GOFA"]) [roots addObject:[container stringByAppendingPathComponent:@"tmp"]];
  }
  NSMutableSet *seen=[NSMutableSet new];
  for(NSString *root in roots) {
   BOOL directory=NO;
   if(![fm fileExistsAtPath:root isDirectory:&directory] || !directory) { [issues addObject:@{@"path":root,@"reason":@"Thư mục không tồn tại hoặc không truy cập được"}]; continue; }
   NSDirectoryEnumerator *enumerator=[fm enumeratorAtURL:[NSURL fileURLWithPath:root] includingPropertiesForKeys:@[NSURLIsRegularFileKey,NSURLIsSymbolicLinkKey] options:0 errorHandler:^BOOL(NSURL *url,NSError *problem) { [issues addObject:@{@"path":url.path,@"reason":problem.localizedDescription}]; return YES; }];
   for(NSURL *url in enumerator) { @autoreleasepool {
    NSNumber *regular=nil,*symlink=nil; NSError *problem=nil;
    if(![url getResourceValue:&regular forKey:NSURLIsRegularFileKey error:&problem]) { [issues addObject:@{@"path":url.path,@"reason":problem.localizedDescription ?: @"Không đọc được metadata"}]; continue; }
    [url getResourceValue:&symlink forKey:NSURLIsSymbolicLinkKey error:nil];
    if(symlink.boolValue) { [enumerator skipDescendants]; [issues addObject:@{@"path":url.path,@"reason":@"Liên kết tượng trưng; không theo ra ngoài thư mục"}]; continue; }
    if(!regular.boolValue || [seen containsObject:url.path]) continue;
    if([root hasSuffix:@"/tmp"] && ![url.lastPathComponent.lowercaseString containsString:@"gofa"]) continue;
    [seen addObject:url.path]; NSDictionary *before=[fm attributesOfItemAtPath:url.path error:nil];
    FILE *input=fopen(url.path.fileSystemRepresentation,"rb");
    if(!input) { [issues addObject:@{@"path":url.path,@"reason":[NSString stringWithUTF8String:strerror(errno)]}]; continue; }
    unsigned long long expected=[before[NSFileSize] unsignedLongLongValue];
    BOOL utf8=ValidUTF8(input,expected); clearerr(input); rewind(input);
    NSString *encoding=utf8 ? @"UTF-8" : @"Base64";
    NSDictionary *headerEntry=@{@"path":url.path,@"expectedBytes":@(expected),@"encoding":encoding};
    NSData *header=[NSJSONSerialization dataWithJSONObject:headerEntry options:NSJSONWritingSortedKeys error:nil];
    ok&=Text(output,[NSString stringWithFormat:@"\n===== BEGIN FILE %@ =====\n",identifier]); ok&=Write(output,header); ok&=Text(output,@"\n===== CONTENT =====\n");
    unsigned char *buffer=malloc(196608); unsigned long long countTotal=0;
    if(!buffer) { fclose(input); ok=NO; break; }
    CC_SHA256_CTX digest; CC_SHA256_Init(&digest);
    while(countTotal<expected) { @autoreleasepool {
      size_t count=fread(buffer,1,(size_t)MIN(expected-countTotal,196608ull),input); if(!count) break;
      CC_SHA256_Update(&digest,buffer,(CC_LONG)count); countTotal+=count;
      NSData *chunk=[NSData dataWithBytesNoCopy:buffer length:count freeWhenDone:NO];
      if(utf8) ok&=Write(output,chunk); else { ok&=Text(output,[chunk base64EncodedStringWithOptions:NSDataBase64Encoding76CharacterLineLength]); ok&=Text(output,@"\n"); }
    }}
    if(ferror(input) || countTotal!=expected) [issues addObject:@{@"path":url.path,@"reason":@"Không đọc đủ dung lượng tệp lúc bắt đầu; xem bytes trong manifest"}];
    fclose(input); free(buffer);
    unsigned char hash[CC_SHA256_DIGEST_LENGTH]; CC_SHA256_Final(hash,&digest); NSMutableString *sha=[NSMutableString new]; for(unsigned i=0;i<sizeof(hash);i++) [sha appendFormat:@"%02x",hash[i]];
    NSDictionary *entry=@{@"path":url.path,@"bytes":@(countTotal),@"sha256":sha,@"encoding":encoding,@"modified":before[NSFileModificationDate] ? [before[NSFileModificationDate] description] : @"unknown"}; [manifest addObject:entry];
    ok&=Text(output,[NSString stringWithFormat:@"\n===== END FILE %@ =====\n",identifier]);
    NSDictionary *after=[fm attributesOfItemAtPath:url.path error:nil];
    if(![before[NSFileSize] isEqual:after[NSFileSize]] || ![before[NSFileModificationDate] isEqual:after[NSFileModificationDate]]) [issues addObject:@{@"path":url.path,@"reason":@"Tệp thay đổi trong khi xuất; có thể có sự kiện mới chưa được lấy"}];
   }}
  }
  NSDictionary *footer=@{@"started":start.description,@"finished":NSDate.date.description,@"filesExported":@(manifest.count),@"issues":issues,@"files":manifest,@"completeForReadableFiles":@(issues.count==0)};
  NSData *json=[NSJSONSerialization dataWithJSONObject:footer options:NSJSONWritingPrettyPrinted|NSJSONWritingSortedKeys error:nil];
  ok&=Text(output,@"\n===== EXPORT MANIFEST / TỆP THIẾU HOẶC THAY ĐỔI =====\n"); ok&=Write(output,json); ok&=Text(output,@"\n");
  if(fflush(output)!=0) ok=NO; if(fclose(output)!=0) ok=NO;
  if(!ok) { [fm removeItemAtPath:path error:nil]; if(error) *error=[NSError errorWithDomain:NSPOSIXErrorDomain code:EIO userInfo:@{NSLocalizedDescriptionKey:@"Không ghi đầy đủ báo cáo; có thể bộ nhớ lưu trữ đã đầy."}]; return nil; }
  return [NSURL fileURLWithPath:path];
 }
}
