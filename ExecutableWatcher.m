// This file is part of Scroll Reverser <https://pilotmoon.com/scrollreverser/>
// Licensed under Apache License v2.0 <http://www.apache.org/licenses/LICENSE-2.0>

#import "ExecutableWatcher.h"
#import <Security/Security.h>
#import <libproc.h>
#import <fcntl.h>

// how often to look at the launch path, as a backstop for the file events
static const int64_t kCheckInterval=5*NSEC_PER_SEC; // 5 seconds

ExecutableState ExecutableStateFor(const struct stat *launchStat, const struct stat *currentStat, BOOL runningFileExists)
{
    if (!runningFileExists) {
        return ExecutableStateReplaced;
    }
    if (!currentStat) {
        return ExecutableStateMoved;
    }
    if (currentStat->st_dev!=launchStat->st_dev || currentStat->st_ino!=launchStat->st_ino) {
        return ExecutableStateReplaced;
    }
    return ExecutableStateCurrent;
}

@interface ExecutableWatcher ()
@property (getter=isReplaced) BOOL replaced;
@property NSURL *launchBundleURL;
@property NSString *executablePath;
@property (copy) void (^handler)(void);
@property dispatch_source_t fileSource;
@property dispatch_source_t timer;
@end

@implementation ExecutableWatcher {
    struct stat _launchStat;
    SecRequirementRef _requirement;
}

- (instancetype)initWithHandler:(void (^)(void))handler
{
    self=[super init];
    if (self) {
        _handler=[handler copy];
        _launchBundleURL=[[NSBundle mainBundle] bundleURL];
        _executablePath=[[NSBundle mainBundle] executablePath];
        if (stat(_executablePath.fileSystemRepresentation, &_launchStat)!=0) {
            NSLog(@"ExecutableWatcher: can't stat %@ (errno %d), not watching", _executablePath, errno);
            return self;
        }
        // Take our signing requirement now, while our code still validates; it can't be read once
        // the executable is gone. An updated copy must meet the same requirement to be relaunched.
        SecCodeRef code=NULL;
        if (SecCodeCopySelf(kSecCSDefaultFlags, &code)==errSecSuccess) {
            SecCodeCopyDesignatedRequirement(code, kSecCSDefaultFlags, &_requirement);
            CFRelease(code);
        }
        [self startWatching];
    }
    return self;
}

- (void)dealloc
{
    [self stopWatching];
    if (_requirement) {
        CFRelease(_requirement);
    }
}

- (void)startWatching
{
    __weak ExecutableWatcher *weakSelf=self;

    // Immediate notice when the running executable is deleted or renamed. This doesn't fire when an
    // updater moves the whole bundle aside, so the timer below covers that.
    const int fd=open(self.executablePath.fileSystemRepresentation, O_EVTONLY);
    if (fd>=0) {
        self.fileSource=dispatch_source_create(DISPATCH_SOURCE_TYPE_VNODE, fd,
                                               DISPATCH_VNODE_DELETE|DISPATCH_VNODE_RENAME|DISPATCH_VNODE_REVOKE,
                                               dispatch_get_main_queue());
        dispatch_source_set_event_handler(self.fileSource, ^{
            [weakSelf check];
        });
        dispatch_source_set_cancel_handler(self.fileSource, ^{
            close(fd);
        });
        dispatch_resume(self.fileSource);
    }

    self.timer=dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
    dispatch_source_set_timer(self.timer, dispatch_time(DISPATCH_TIME_NOW, kCheckInterval), kCheckInterval, NSEC_PER_SEC);
    dispatch_source_set_event_handler(self.timer, ^{
        [weakSelf check];
    });
    dispatch_resume(self.timer);
}

- (void)stopWatching
{
    if (self.fileSource) {
        dispatch_source_cancel(self.fileSource);
        self.fileSource=nil;
    }
    if (self.timer) {
        dispatch_source_cancel(self.timer);
        self.timer=nil;
    }
}

- (ExecutableState)state
{
    // proc_pidpath follows the running executable's file, wherever it has moved, and fails once it's deleted
    char runningPath[PROC_PIDPATHINFO_MAXSIZE];
    const BOOL runningFileExists=proc_pidpath(getpid(), runningPath, sizeof(runningPath))>0;
    struct stat current;
    const BOOL haveCurrent=stat(self.executablePath.fileSystemRepresentation, &current)==0;
    return ExecutableStateFor(&_launchStat, haveCurrent?&current:NULL, runningFileExists);
}

- (BOOL)check
{
    if (self.replaced) {
        return YES;
    }
    if (!self.timer || [self state]!=ExecutableStateReplaced) { // not watching, or not replaced
        return NO;
    }
    self.replaced=YES;
    [self stopWatching];
    void (^const handler)(void)=self.handler;
    self.handler=nil;
    // async, because this can be called from inside the tap's callback
    dispatch_async(dispatch_get_main_queue(), ^{
        handler();
    });
    return YES;
}

- (BOOL)replacementIsValid
{
    NSDictionary *const info=[NSDictionary dictionaryWithContentsOfURL:[self.launchBundleURL URLByAppendingPathComponent:@"Contents/Info.plist"]];
    if (![info[@"CFBundleIdentifier"] isEqualToString:[[NSBundle mainBundle] bundleIdentifier]]) {
        return NO;
    }
    if (!_requirement) {
        return YES; // we weren't signed, so there's nothing to compare the copy against
    }
    SecStaticCodeRef code=NULL;
    if (SecStaticCodeCreateWithPath((__bridge CFURLRef)self.launchBundleURL, kSecCSDefaultFlags, &code)!=errSecSuccess) {
        return NO;
    }
    // a copy that is still being written fails this, so the caller can try again shortly
    const OSStatus status=SecStaticCodeCheckValidity(code, kSecCSCheckAllArchitectures|kSecCSStrictValidate|kSecCSCheckNestedCode, _requirement);
    CFRelease(code);
    if (status!=errSecSuccess) {
        NSLog(@"ExecutableWatcher: copy at %@ doesn't validate yet (%d)", self.launchBundleURL.path, (int)status);
    }
    return status==errSecSuccess;
}

@end
