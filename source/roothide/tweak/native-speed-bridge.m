#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#import <notify.h>
#import "speed-state.h"
#import "hud-live-state.h"
#include <math.h>
#include <unistd.h>
#include <sys/sysctl.h>
#include <sys/wait.h>
#include <spawn.h>
#include <signal.h>
#include <fcntl.h>
#include <errno.h>
extern char **environ;
static pid_t PreparedPID;
static int ReadyToken=-1;
static void PrepareGOFA(NSString *path) {
    int mib[]={CTL_KERN,KERN_PROC,KERN_PROC_ALL,0}; size_t size=0;
    if(sysctl(mib,4,NULL,&size,NULL,0)!=0 || !size) return;
    struct kinfo_proc *processes=malloc(size);
    if(!processes) return;
    BOOL found=NO;
    if(sysctl(mib,4,processes,&size,NULL,0)==0) for(size_t i=0;i<size/sizeof(*processes);i++) {
        if(strcmp(processes[i].kp_proc.p_comm,"GOFA")) continue;
        found=YES;
        pid_t pid=processes[i].kp_proc.p_pid;
        if(pid<=1 || pid==PreparedPID) break;
        char number[32]; snprintf(number,sizeof(number),"%d",pid);
        char *args[]={"/var/jb/usr/bin/jbctl","proc_set_debugged",number,NULL};
        pid_t child=0; int result=0;
        int spawned=posix_spawn(&child,args[0],NULL,NULL,args,environ);
        pid_t waited=-1;
        if(spawned==0) do { waited=waitpid(child,&result,0); } while(waited<0 && errno==EINTR);
        if(spawned==0 && waited==child && WIFEXITED(result) && WEXITSTATUS(result)==0) {
            if(ReadyToken>=0 && notify_set_state(ReadyToken,(uint64_t)pid)==NOTIFY_STATUS_OK) {
                notify_post("local.gofahud.source.ready"); PreparedPID=pid; fprintf(stderr,"GOFA source prepared pid=%d\n",pid);
            }
        } else {
            fprintf(stderr,"GOFA preparation failed spawn=%d wait=%d status=%d errno=%d\n",spawned,(int)waited,result,errno);
        }
        break;
    }
    free(processes);
    if(!found && ReadyToken>=0) {
        uint64_t old=0; notify_get_state(ReadyToken,&old);
        if(old) { notify_set_state(ReadyToken,0); notify_post("local.gofahud.source.ready"); }
        PreparedPID=0;
    }
}
// Development bridge only: consumes diagnostic events emitted by the GOFA probe.
// Never refresh the original event timestamp while polling the same snapshot.
static BOOL Number(id n) {
    return [n isKindOfClass:NSNumber.class] && CFGetTypeID((__bridge CFTypeRef)n)!=CFBooleanGetTypeID();
}
static uint64_t State(NSDictionary *event,double now) {
    if(![event isKindOfClass:NSDictionary.class] || !Number(event[@"lastUptime"])) return 0;
    double received=[event[@"lastUptime"] doubleValue];
    NSDictionary *sample=event[@"speedSample"];
    if(![sample isKindOfClass:NSDictionary.class] || ![sample[@"status"] isEqual:@"processed-location"] ||
       ![sample[@"validSpeed"] isKindOfClass:NSNumber.class] || ![sample[@"validSpeed"] boolValue] ||
       !Number(sample[@"speedMetersPerSecond"]) || !Number(sample[@"sampleAgeSeconds"])) return 0;
    double meters=[sample[@"speedMetersPerSecond"] doubleValue],age=[sample[@"sampleAgeSeconds"] doubleValue];
    if(!isfinite(received) || received>now || now-received>=5 || !isfinite(meters) || meters<0 || meters*3.6>400 ||
       !isfinite(age) || age< -2 || age+now-received>10) return 0;
    return GVMEncodeSample(@(llround(meters*3.6)),received);
}
static int RecordDrive(BOOL test) {
    const char *names[]={"local.gofahud.source.ready",GOFAHUDProducerName,GOFAHUDLimitName,GVMSpeedStateName,GOFAHUDCameraName,"local.gofahud.gofa.foreground","local.gofahud.carplay.trace"};
    int tokens[7]; uint64_t previous[7]={0}; BOOL first=YES; double last=0;
    NSString *sessionID=nil; NSDate *sessionStart=nil; double sessionUptime=0;
    NSDateFormatter *clock=[NSDateFormatter new]; clock.locale=[[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
    clock.timeZone=[NSTimeZone timeZoneWithName:@"Asia/Ho_Chi_Minh"]; clock.dateFormat=@"yyyy-MM-dd'T'HH:mm:ss.SSSXXX";
    for(unsigned i=0;i<7;i++) if(notify_register_check(names[i],&tokens[i])!=NOTIFY_STATUS_OK) return 1;
    NSString *path=test ? @"/tmp/gofahud-runtime/session-test.jsonl" : @"/var/mobile/Library/Logs/GofaHUD-drive.jsonl";
    unsigned stage=0;
    if(test) [NSFileManager.defaultManager removeItemAtPath:path error:nil];
    while(YES) { @autoreleasepool {
        uint64_t values[7]={0}; BOOL changed=first;
        for(unsigned i=0;i<7;i++) { notify_get_state(tokens[i],&values[i]); if(i<6 && values[i]!=previous[i]) changed=YES; }
        double now=NSProcessInfo.processInfo.systemUptime;
        if(test) {
            if(stage>=6) return 0;
            values[6]=stage==5 ? 0 : ((uint64_t)(now*1000)<<1)|((stage==1 || stage==2 || stage==4) ? 1 : 0);
            changed=YES; stage++;
        }
        NSDate *date=NSDate.date;
        double traceAge=now-(double)(values[6]>>1)/1000;
        BOOL known=values[6] && traceAge>=0 && traceAge<3;
        BOOL visible=known && (values[6]&1);
        BOOL started=visible && !sessionID, ended=!visible && sessionID!=nil;
        if(started) { sessionID=NSUUID.UUID.UUIDString; sessionStart=date; sessionUptime=now; }
        if(changed || started || ended || now-last>=10) {
            BOOL active=values[0] && values[0]==values[1];
            id fresh=active ? GVMDecodeSample(values[3],now,YES) : nil;
            id zero=active && !fresh ? GOFAHUDRetainedZero(values[3],now,values[1],values[0]) : nil;
            id limit=GOFAHUDRetainedLimit(values[2],now,values[1],values[0]);
            id camera=active ? GOFAHUDCameraDecode(values[4],now) : nil;
            NSMutableArray *raw=[NSMutableArray array]; for(unsigned i=0;i<7;i++) [raw addObject:@(values[i])];
            id carplay=known ? @(visible) : NSNull.null;
            NSDictionary *row=@{@"unixTime":@(date.timeIntervalSince1970),@"timeVietnam":[clock stringFromDate:date],@"timezone":@"Asia/Ho_Chi_Minh",@"uptime":@(now),@"readyPID":@(values[0]),@"producerPID":@(values[1]),@"foreground":@(values[5]),@"carplayOverlayVisible":carplay,@"speedKmH":fresh ?: zero ?: NSNull.null,@"speedQuality":fresh ? @"fresh" : zero ? @"held-zero" : @"unavailable",@"speedEventUptime":values[3]&512 ? @((double)(values[3]>>10)/1000) : NSNull.null,@"limitKmH":limit ?: NSNull.null,@"camera":camera ?: NSNull.null,@"rawStates":raw,@"kind":started ? @"carplay-session-start" : ended ? @"carplay-session-end" : first ? @"recorder-start" : changed ? @"state-change" : @"heartbeat",@"sessionID":sessionID ?: NSNull.null,@"sessionStartVietnam":sessionStart ? [clock stringFromDate:sessionStart] : NSNull.null,@"sessionStartUnixTime":sessionStart ? @(sessionStart.timeIntervalSince1970) : NSNull.null,@"sessionEndVietnam":ended ? [clock stringFromDate:date] : NSNull.null,@"sessionEndUnixTime":ended ? @(date.timeIntervalSince1970) : NSNull.null,@"sessionDurationSeconds":sessionID ? @(now-sessionUptime) : NSNull.null,@"sessionEndReason":ended ? known ? @"overlay-no-longer-visible" : @"trace-unavailable" : NSNull.null};
            NSData *data=[NSJSONSerialization dataWithJSONObject:row options:0 error:nil];
            NSFileManager *fm=NSFileManager.defaultManager;
            if([[fm attributesOfItemAtPath:path error:nil][NSFileSize] unsignedLongLongValue]>=10*1024*1024) {
                [fm removeItemAtPath:[path stringByAppendingString:@".3"] error:nil];
                for(int i=2;i>=1;i--) [fm moveItemAtPath:[path stringByAppendingFormat:@".%d",i] toPath:[path stringByAppendingFormat:@".%d",i+1] error:nil];
                [fm moveItemAtPath:path toPath:[path stringByAppendingString:@".1"] error:nil];
            }
            FILE *f=fopen(path.fileSystemRepresentation,"a");
            if(!f) { perror("drive log"); return 1; }
            fwrite(data.bytes,1,data.length,f); fputc('\n',f); fclose(f);
            memcpy(previous,values,sizeof(values)); first=NO; last=now;
            if(ended) { sessionID=nil; sessionStart=nil; sessionUptime=0; }
        }
    } usleep(250000); }
}
int main(int argc,char **argv) {
    @autoreleasepool {
        if(argc==2 && !strcmp(argv[1],"--record")) return RecordDrive(NO);
        if(argc==2 && !strcmp(argv[1],"--record-self-test")) return RecordDrive(YES);
        if(argc==2 && !strcmp(argv[1],"--status")) {
            const char *names[]={"local.gofahud.source.ready",GOFAHUDProducerName,GOFAHUDLimitName,GVMSpeedStateName,GOFAHUDCameraName};
            uint64_t values[5]={0};
            for(unsigned i=0;i<5;i++) { int t=-1; if(notify_register_check(names[i],&t)==NOTIFY_STATUS_OK) { notify_get_state(t,&values[i]); notify_cancel(t); } }
            double now=NSProcessInfo.processInfo.systemUptime;
            id limit=GOFAHUDRetainedLimit(values[2],now,values[1],values[0]);
            id speed=GVMDecodeSample(values[3],now,YES);
            id camera=values[0] && values[0]==values[1] ? GOFAHUDCameraDecode(values[4],now) : nil;
            NSDictionary *report=@{@"readyPID":@(values[0]),@"producerPID":@(values[1]),@"limitKmH":limit ?: NSNull.null,@"speedKmH":speed ?: NSNull.null,@"camera":camera ?: NSNull.null};
            NSData *json=[NSJSONSerialization dataWithJSONObject:report options:0 error:nil];
            fwrite(json.bytes,1,json.length,stdout); puts(""); return 0;
        }
        if(argc==2 && !strcmp(argv[1],"--self-test")) {
            NSMutableDictionary *sample=[@{@"status":@"processed-location",@"validSpeed":@YES,@"speedMetersPerSecond":@10,@"sampleAgeSeconds":@3} mutableCopy];
            NSMutableDictionary *event=[@{@"lastUptime":@100,@"speedSample":sample} mutableCopy];
            uint64_t state=State(event,101);
            if(![GVMDecodeSample(state,101,YES) isEqual:@36] || State(event,105)!=0 || State(event,99)!=0) return 1;
            sample[@"speedMetersPerSecond"]=@0;
            if(![GVMDecodeSample(State(event,101),101,YES) isEqual:@0]) return 2;
            sample[@"speedMetersPerSecond"]=@-1;
            if(State(event,101)) return 3;
            sample[@"speedMetersPerSecond"]=@YES;
            if(State(event,101)) return 4;
            sample[@"speedMetersPerSecond"]=@10; sample[@"sampleAgeSeconds"]=@10;
            if(State(event,101)) return 5;
            sample[@"sampleAgeSeconds"]=@3;
            if(State(event,102)!=state) return 6;
            puts("Native speed bridge: conversion, zero, expiry, future, invalid value, original timestamp passed."); return 0;
        }
        BOOL daemon=(argc==2 || argc==3) && !strcmp(argv[1],"--daemon");
        if(!daemon && argc!=2) return 64;
        if(daemon && geteuid()!=0) return 77;
        if(daemon) signal(SIGCHLD,SIG_DFL);
        if(daemon && notify_register_check("local.gofahud.source.ready",&ReadyToken)!=NOTIFY_STATUS_OK) return 1;
        NSString *path=daemon ? nil : [NSString stringWithUTF8String:argv[1]];
        int token=-1;
        if(!daemon && notify_register_check(GVMSpeedStateName,&token)!=NOTIFY_STATUS_OK) return 1;
        uint64_t previous=UINT64_MAX;
        unsigned iteration=0;
        while(YES) {
            @autoreleasepool {
                if(daemon) { if(iteration++%4==0) PrepareGOFA(path); }
                else {
                NSData *data=[NSData dataWithContentsOfFile:path];
                id report=data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
                NSDictionary *event=[report isKindOfClass:NSDictionary.class] ? report[@"Combine.CurrentValueSubject<Swift.Optional<GOFA.LocationUpdateEvent>, Swift.Never>"] : nil;
                uint64_t state=State(event,NSProcessInfo.processInfo.systemUptime);
                if(state!=previous) {
                    if(notify_set_state(token,state)==NOTIFY_STATUS_OK) { notify_post(GVMSpeedStateName); previous=state; }
                }
                }
            }
            usleep(250000);
        }
    }
}
