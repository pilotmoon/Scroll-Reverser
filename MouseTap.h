// This file is part of Scroll Reverser <https://pilotmoon.com/scrollreverser/>
// Licensed under Apache License v2.0 <http://www.apache.org/licenses/LICENSE-2.0>

#import <Foundation/Foundation.h>

// We abstract the system defined scrolling phases into these possibilities.
typedef enum {
    ScrollPhaseStart=0,
    ScrollPhaseNormal, // fingers on pad
    ScrollPhaseMomentum, // fingers off pad, but scrolling with momentum
    ScrollPhaseEnd,      // scrolling ended
    ScrollPhaseMax
} ScrollPhase;

@class TapLogger, SourceTable;

/* The event tap that reverses scrolling. Each event's source is looked up and recorded in the
 source table, and the event is changed according to the source's row. */
@interface MouseTap : NSObject {
@public
    __weak TapLogger *logger;    
}

- (instancetype)initWithSourceTable:(SourceTable *)sourceTable;

@property (getter=isActive) BOOL active;
- (void)enableTap;

@end


