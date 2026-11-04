// This file is part of Scroll Reverser <https://pilotmoon.com/scrollreverser/>
// Licensed under Apache License v2.0 <http://www.apache.org/licenses/LICENSE-2.0>

#import <Foundation/Foundation.h>
#import <sys/stat.h>

NS_ASSUME_NONNULL_BEGIN

/* Whether the running executable is still the one at the path it was launched from. */
typedef NS_ENUM(NSInteger, ExecutableState) {
    ExecutableStateCurrent,  // the launch path still holds the running executable
    ExecutableStateMoved,    // the app was moved, and nothing else is at the launch path
    ExecutableStateReplaced, // a different file is at the launch path, or the running executable was deleted
};

/* The decision on its own, for testing. `launchStat` is the launch path's stat at launch, and `currentStat`
 is its stat now (NULL if nothing is there). `runningFileExists` says whether the running executable's
 file still exists anywhere. */
ExecutableState ExecutableStateFor(const struct stat *launchStat, const struct stat *_Nullable currentStat, BOOL runningFileExists);

/* Notices when the app is replaced on disk while it runs, for example by an updater that doesn't quit the
 app first (#220). After that, the next change to any app's privacy permissions makes macOS check this
 process again. The check fails, because the code on disk no longer matches, and from then on macOS
 rejects every event the tap returns, which blocks scrolling and typing everywhere. Our own permission
 checks keep saying yes, so this watcher is how we find out. */
@interface ExecutableWatcher : NSObject

/* Starts watching straight away. The handler is called once, on the main queue, when the executable
 is first found to be replaced. */
- (instancetype)initWithHandler:(void (^)(void))handler;

/* Checks now, and calls the handler if this is the first time it's found replaced. Cheap. */
- (BOOL)check;

@property (readonly, getter=isReplaced) BOOL replaced;

/* The app bundle's path at launch, where an updated copy would be. */
@property (readonly) NSURL *launchBundleURL;

/* Whether the bundle now at the launch path is a complete copy of this app, signed by the same developer.
 Slow (it validates the whole bundle), so call it off the main thread. */
- (BOOL)replacementIsValid;

@end

NS_ASSUME_NONNULL_END
