// This file is part of Scroll Reverser <https://pilotmoon.com/scrollreverser/>
// Licensed under Apache License v2.0 <http://www.apache.org/licenses/LICENSE-2.0>

#import <Foundation/Foundation.h>
#import "ScrollSource.h"

NS_ASSUME_NONNULL_BEGIN

/* What to do with a source's scrolling direction. Natural and Classic are for sources whose events come
 from HID devices, where the system says whether it applied natural scrolling. Events posted by apps don't
 say, since the app chose the direction itself, so those sources are just Reversed or not. */
typedef NS_ENUM(NSInteger, ScrollDirectionMode) {
    ScrollDirectionModeUnchanged=0, // as the system delivers it
    ScrollDirectionModeNatural,
    ScrollDirectionModeClassic,
    ScrollDirectionModeReversed,
    ScrollDirectionModeMatchVertical, // horizontal only: reversed whenever vertical is
};

// Step size is in lines per step of a non-continuous scroll wheel.
static const NSInteger SourceRowMinStepSize=1;
static const NSInteger SourceRowMaxStepSize=30;

// A source counts as scrolling for this long after its last event.
static const CFTimeInterval SourceRowScrollingInterval=0.25;

// Posted, with the row as the object, when a source starts scrolling: on its first event, or its
// first after SourceRowScrollingInterval without one.
extern NSNotificationName const SourceRowDidStartScrollingNotification;

// How to change one scroll event.
typedef struct {
    BOOL reverseVertical;
    BOOL reverseHorizontal;
    NSInteger stepSize; // 1 for no change
} SourceAdjustment;

// The settings and history for one source. Settings changes are saved automatically.
@interface SourceRow : NSObject

@property (readonly) NSString *key;
@property (readonly) ScrollSourceKind kind;
@property (readonly) ScrollSourceCategory category;
// Whether the source's scrolling is continuous, like a trackpad's, rather than in steps, like a wheel's.
@property (readonly) BOOL continuous;
// Whether the source's events are HID events, which offer Natural and Classic rather than Reversed.
@property (readonly) BOOL hasDeviceDirection;
// As reported by the device or app when the source was last looked up.
@property (readonly, nullable, nonatomic, copy) NSString *reportedName;
@property (readonly, nullable, nonatomic, copy) NSString *path;

// The user's name for the source, or nil to use the reported one. Empty strings are stored as nil.
@property (nullable, nonatomic, copy) NSString *customName;
@property (nonatomic) ScrollDirectionMode verticalMode;
// Any mode, including Match vertical. Natural and Classic are absolute, as for vertical, which matters
// for devices such as thumb wheels that roll one way but scroll the other.
@property (nonatomic) ScrollDirectionMode horizontalMode;
@property (nonatomic) BOOL stepSizeEnabled;
@property (nonatomic) NSInteger stepSize;

@property (readonly) NSDate *firstSeen;
@property (readonly) NSDate *lastSeen;
@property (readonly) CFAbsoluteTime lastSeenTime;
@property (readonly, getter=isScrolling) BOOL scrolling;
// Total distance scrolled, in points, on both axes.
@property (readonly) double scrollTotal;
// Whether the system has delivered this source's events with natural scrolling applied
// (NSEvent's isDirectionInvertedFromDevice), without, or both.
@property (readonly) BOOL seenNatural;
@property (readonly) BOOL seenClassic;
// The reversing rule. `natural` is whether the system applied natural scrolling to the event.
// Step size applies only to non-continuous scrolling.
- (SourceAdjustment)adjustmentForNatural:(BOOL)natural;

@end

/* The persisted table of sources, keyed by ScrollSource.key and stored in user defaults. A row is
 created the first time its source is seen. Main thread only. */
@interface SourceTable : NSObject

- (instancetype)initWithUserDefaults:(NSUserDefaults *)defaults NS_DESIGNATED_INITIALIZER;
- (instancetype)init; // with the standard user defaults

// Observable: changes when rows are added or removed.
@property (readonly) NSArray<SourceRow *> *rows;

// Called for every scroll event, so it is cheap: sightings are saved in batches.
- (SourceRow *)recordSource:(ScrollSource *)source natural:(BOOL)natural amount:(double)amount;
- (void)removeRow:(SourceRow *)row;

// Write any unsaved changes now.
- (void)save;

@end

NS_ASSUME_NONNULL_END
