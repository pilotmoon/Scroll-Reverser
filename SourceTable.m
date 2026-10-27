// This file is part of Scroll Reverser <https://pilotmoon.com/scrollreverser/>
// Licensed under Apache License v2.0 <http://www.apache.org/licenses/LICENSE-2.0>

#import "SourceTable.h"

NSNotificationName const SourceRowDidStartScrollingNotification=@"SourceRowDidStartScrollingNotification";
NSNotificationName const SourceRowDidStartScrollingHorizontallyNotification=@"SourceRowDidStartScrollingHorizontallyNotification";

static NSString *const PrefsSources=@"Sources";

static NSString *const kRowKind=@"Kind";
static NSString *const kRowCategory=@"Category";
static NSString *const kRowContinuous=@"Continuous";
static NSString *const kRowReportedName=@"ReportedName";
static NSString *const kRowPath=@"Path";
static NSString *const kRowCustomName=@"CustomName";
static NSString *const kRowVerticalMode=@"VerticalMode";
static NSString *const kRowHorizontalMode=@"HorizontalMode";
// replaced by HorizontalMode: YES for Match vertical, NO for Unchanged
static NSString *const kRowHorizontalMatchesVertical=@"HorizontalMatchesVertical";
static NSString *const kRowStepSizeEnabled=@"StepSizeEnabled";
static NSString *const kRowStepSize=@"StepSize";
static NSString *const kRowFirstSeen=@"FirstSeen";
static NSString *const kRowLastSeen=@"LastSeen";
static NSString *const kRowScrollTotal=@"ScrollTotal";
static NSString *const kRowSeenNatural=@"SeenNatural";
static NSString *const kRowSeenClassic=@"SeenClassic";
static NSString *const kRowLastNatural=@"LastNatural";

// New rows and settings changes are saved soon. Sightings alone are saved at most once a minute.
static const CFTimeInterval kChangeSaveDelay=1;
static const CFTimeInterval kSightingSaveDelay=60;

static NSString *_stringValue(id obj)
{
    return [obj isKindOfClass:[NSString class]]&&[obj length]?obj:nil;
}

static NSNumber *_numberValue(id obj)
{
    return [obj isKindOfClass:[NSNumber class]]?obj:nil;
}

static NSDate *_dateValue(id obj)
{
    return [obj isKindOfClass:[NSDate class]]?obj:nil;
}

@interface SourceTable ()
- (void)rowSettingsDidChange;
@end

static BOOL _reverses(ScrollDirectionMode mode, BOOL natural);

#pragma mark -

@interface SourceRow ()
@property (weak) SourceTable *table;
@property (readwrite) NSString *key;
@property (readwrite) ScrollSourceKind kind;
@property (readwrite) ScrollSourceCategory category;
@property (readwrite) BOOL continuous;
@property (readwrite, nullable, nonatomic, copy) NSString *reportedName;
@property (readwrite, nullable, nonatomic, copy) NSString *path;
@property (readwrite) NSDate *firstSeen;
@property (readwrite) CFAbsoluteTime lastSeenTime;
@property (readwrite) double scrollTotal;
@property (readwrite) BOOL seenNatural;
@property (readwrite) BOOL seenClassic;
- (BOOL)recordSightingAtTime:(CFAbsoluteTime)time natural:(BOOL)natural amount:(double)amount;
- (BOOL)recordHorizontalAtTime:(CFAbsoluteTime)time;
- (void)updateFromSource:(ScrollSource *)source;
@end

@implementation SourceRow {
    // when the source last scrolled only horizontally, for this session only
    CFAbsoluteTime _lastHorizontalTime;
}

/* Defaults: trackpads natural, other devices classic, and apps unchanged. Horizontal scrolling is
 unchanged: continuous horizontal scrolling, as on trackpads and the Magic Mouse, doubles as gestures
 such as swiping between pages, and thumb wheels, as on the MX Master, roll at right angles to the way
 they scroll, so matching vertical surprises people. Step size is as in 1.x. */
- (instancetype)initWithSource:(ScrollSource *)source table:(SourceTable *)table
{
    self=[super init];
    if (self) {
        _table=table;
        _key=source.key;
        _kind=source.kind;
        _category=source.category;
        _continuous=source.continuous;
        _reportedName=source.name;
        _path=source.path;
        const BOOL trackpad=_category==ScrollSourceCategoryTrackpad;
        _verticalMode=!self.hasDeviceDirection?ScrollDirectionModeUnchanged:trackpad?ScrollDirectionModeNatural:ScrollDirectionModeClassic;
        _horizontalMode=ScrollDirectionModeUnchanged;
        _stepSizeEnabled=YES;
        _stepSize=3;
        _lastSeenTime=CFAbsoluteTimeGetCurrent();
        _firstSeen=[NSDate dateWithTimeIntervalSinceReferenceDate:_lastSeenTime];
    }
    return self;
}

// A saved row. Returns nil if the saved data is unusable.
- (instancetype)initWithKey:(NSString *)key dictionary:(NSDictionary *)dict table:(SourceTable *)table
{
    if (![dict isKindOfClass:[NSDictionary class]]||!_numberValue(dict[kRowKind])||!_numberValue(dict[kRowCategory])) {
        return nil;
    }
    self=[super init];
    if (self) {
        _table=table;
        _key=key;
        _kind=[dict[kRowKind] integerValue];
        _category=[dict[kRowCategory] integerValue];
        _continuous=[_numberValue(dict[kRowContinuous]) boolValue];
        _reportedName=_stringValue(dict[kRowReportedName]);
        _path=_stringValue(dict[kRowPath]);
        _customName=_stringValue(dict[kRowCustomName]);
        _verticalMode=[_numberValue(dict[kRowVerticalMode]) integerValue];
        _stepSizeEnabled=[_numberValue(dict[kRowStepSizeEnabled]) boolValue];
        _stepSize=[_numberValue(dict[kRowStepSize]) integerValue];
        NSDate *const lastSeen=_dateValue(dict[kRowLastSeen])?:[NSDate date];
        _lastSeenTime=[lastSeen timeIntervalSinceReferenceDate];
        _firstSeen=_dateValue(dict[kRowFirstSeen])?:lastSeen;
        _scrollTotal=[_numberValue(dict[kRowScrollTotal]) doubleValue];
        _seenNatural=[_numberValue(dict[kRowSeenNatural]) boolValue];
        _seenClassic=[_numberValue(dict[kRowSeenClassic]) boolValue];
        // rows saved before this was kept: natural if it's been seen, which is a guess if classic has too
        _lastNatural=[(_numberValue(dict[kRowLastNatural])?:@(_seenNatural)) boolValue];
        /* Horizontal was once Natural or Classic for devices. Those become whichever of Reversed and Unchanged
         does the same with the direction the system last delivered the source's scrolling in, or natural, as
         macOS has by default, if it hasn't been seen. Rows with only the older HorizontalMatchesVertical key
         are Match vertical or Unchanged. */
        NSNumber *const horizontalMode=_numberValue(dict[kRowHorizontalMode]);
        if (horizontalMode?[horizontalMode integerValue]==ScrollDirectionModeMatchVertical:[_numberValue(dict[kRowHorizontalMatchesVertical]) boolValue]) {
            _horizontalMode=ScrollDirectionModeMatchVertical;
        }
        else {
            const BOOL natural=_seenNatural||_seenClassic?_lastNatural:YES;
            _horizontalMode=_reverses([horizontalMode integerValue], natural)?ScrollDirectionModeReversed:ScrollDirectionModeUnchanged;
        }
    }
    return self;
}

- (NSDictionary *)dictionaryRepresentation
{
    NSMutableDictionary *const dict=[@{
        kRowKind: @(self.kind),
        kRowCategory: @(self.category),
        kRowContinuous: @(self.continuous),
        kRowVerticalMode: @(self.verticalMode),
        kRowHorizontalMode: @(self.horizontalMode),
        kRowStepSizeEnabled: @(self.stepSizeEnabled),
        kRowStepSize: @(self.stepSize),
        kRowFirstSeen: self.firstSeen,
        kRowLastSeen: self.lastSeen,
        kRowScrollTotal: @(self.scrollTotal),
        kRowSeenNatural: @(self.seenNatural),
        kRowSeenClassic: @(self.seenClassic),
        kRowLastNatural: @(self.lastNatural),
    } mutableCopy];
    dict[kRowReportedName]=self.reportedName;
    dict[kRowPath]=self.path;
    dict[kRowCustomName]=self.customName;
    return dict;
}

/* Called for every event, so the totals, time and last direction are set directly, without change
 notifications. The flags change at most once each, and are observed. Returns whether the source has
 started scrolling. */
- (BOOL)recordSightingAtTime:(CFAbsoluteTime)time natural:(BOOL)natural amount:(double)amount
{
    const BOOL started=time-_lastSeenTime>=SourceRowScrollingInterval;
    _lastSeenTime=time;
    _scrollTotal+=amount;
    _lastNatural=natural;
    if (natural&&!_seenNatural) {
        self.seenNatural=YES;
    }
    else if (!natural&&!_seenClassic) {
        self.seenClassic=YES;
    }
    return started;
}

// Returns whether the source has started scrolling horizontally.
- (BOOL)recordHorizontalAtTime:(CFAbsoluteTime)time
{
    const BOOL started=time-_lastHorizontalTime>=SourceRowScrollingInterval;
    _lastHorizontalTime=time;
    return started;
}

// Whether a mode other than Match vertical reverses an event.
static BOOL _reverses(ScrollDirectionMode mode, BOOL natural)
{
    return mode==ScrollDirectionModeReversed||
        (mode==ScrollDirectionModeNatural&&!natural)||
        (mode==ScrollDirectionModeClassic&&natural);
}

- (SourceAdjustment)adjustmentForNatural:(BOOL)natural
{
    const BOOL reverseVertical=_reverses(self.verticalMode, natural);
    const ScrollDirectionMode horizontalMode=self.horizontalMode;
    return (SourceAdjustment){
        .reverseVertical=reverseVertical,
        .reverseHorizontal=horizontalMode==ScrollDirectionModeMatchVertical?reverseVertical:_reverses(horizontalMode, natural),
        .stepSize=self.continuous||!self.stepSizeEnabled?0:MIN(MAX(self.stepSize, SourceRowMinStepSize), SourceRowMaxStepSize),
    };
}

- (NSDate *)lastSeen
{
    return [NSDate dateWithTimeIntervalSinceReferenceDate:self.lastSeenTime];
}

- (BOOL)isScrolling
{
    return CFAbsoluteTimeGetCurrent()-self.lastSeenTime<SourceRowScrollingInterval;
}

- (BOOL)hasDeviceDirection
{
    return self.kind==ScrollSourceKindLocalDevice||self.kind==ScrollSourceKindRemoteDevice||self.kind==ScrollSourceKindUnidentifiedDevice;
}

// What a source reports can change after its row is created: a Bluetooth device can be renamed,
// and an app can move while keeping its bundle ID.
- (void)updateFromSource:(ScrollSource *)source
{
    if (source.name&&![source.name isEqualToString:self.reportedName]) {
        self.reportedName=source.name;
    }
    if (source.path&&![source.path isEqualToString:self.path]) {
        self.path=source.path;
    }
}

- (void)setReportedName:(NSString *)reportedName
{
    _reportedName=[reportedName copy];
    [self.table rowSettingsDidChange];
}

- (void)setPath:(NSString *)path
{
    _path=[path copy];
    [self.table rowSettingsDidChange];
}

- (void)setCustomName:(NSString *)customName
{
    _customName=[customName length]?[customName copy]:nil;
    [self.table rowSettingsDidChange];
}

- (void)setVerticalMode:(ScrollDirectionMode)verticalMode
{
    _verticalMode=verticalMode;
    [self.table rowSettingsDidChange];
}

- (void)setHorizontalMode:(ScrollDirectionMode)horizontalMode
{
    _horizontalMode=horizontalMode;
    [self.table rowSettingsDidChange];
}

- (void)setStepSizeEnabled:(BOOL)stepSizeEnabled
{
    _stepSizeEnabled=stepSizeEnabled;
    [self.table rowSettingsDidChange];
}

- (void)setStepSize:(NSInteger)stepSize
{
    _stepSize=stepSize;
    [self.table rowSettingsDidChange];
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@ %@ %@>", [self class], self.key, [self dictionaryRepresentation]];
}

@end

#pragma mark -

@interface SourceTable ()
@property NSUserDefaults *defaults;
@property NSMutableDictionary<NSString *, SourceRow *> *rowsByKey;
// the row for the most recent source, since consecutive events nearly always share one
@property ScrollSource *lastSource;
@property SourceRow *lastRow;
// when the next save is scheduled for, or 0 if there are no unsaved changes
@property CFAbsoluteTime saveTime;
@end

@implementation SourceTable

- (instancetype)init
{
    return [self initWithUserDefaults:[NSUserDefaults standardUserDefaults]];
}

- (instancetype)initWithUserDefaults:(NSUserDefaults *)defaults
{
    self=[super init];
    if (self) {
        self.defaults=defaults;
        self.rowsByKey=[NSMutableDictionary dictionary];
        [[defaults dictionaryForKey:PrefsSources] enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
            SourceRow *const row=_stringValue(key)?[[SourceRow alloc] initWithKey:key dictionary:obj table:self]:nil;
            if (row) {
                self.rowsByKey[key]=row;
                // save a row whose horizontal mode was converted, so it's converted only once
                if (![obj[kRowHorizontalMode] isEqual:@(row.horizontalMode)]) {
                    [self rowSettingsDidChange];
                }
            }
        }];
        NSLog(@"Loaded %lu source rows", (unsigned long)[self.rowsByKey count]);
    }
    return self;
}

- (NSArray<SourceRow *> *)rows
{
    return [self.rowsByKey allValues];
}

- (SourceRow *)recordSource:(ScrollSource *)source natural:(BOOL)natural amount:(double)amount
{
    return [self recordSource:source natural:natural amount:amount horizontal:NO];
}

- (SourceRow *)recordSource:(ScrollSource *)source natural:(BOOL)natural amount:(double)amount horizontal:(BOOL)horizontal
{
    const CFAbsoluteTime now=CFAbsoluteTimeGetCurrent();
    SourceRow *row=source==self.lastSource?self.lastRow:nil;
    BOOL started=NO;
    if (!row) {
        row=self.rowsByKey[source.key];
        if (!row) {
            row=[[SourceRow alloc] initWithSource:source table:self];
            [self willChangeValueForKey:@"rows"];
            self.rowsByKey[source.key]=row;
            [self didChangeValueForKey:@"rows"];
            NSLog(@"New source row %@", row);
            [self rowSettingsDidChange];
            started=YES;
        }
        else {
            [row updateFromSource:source];
        }
        self.lastSource=source;
        self.lastRow=row;
    }
    started=[row recordSightingAtTime:now natural:natural amount:amount]||started;
    [self setNeedsSaveBy:now+kSightingSaveDelay];
    if (started) {
        // after the event has been handled, since observers may update the settings window
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:SourceRowDidStartScrollingNotification object:row];
        });
    }
    if (horizontal&&[row recordHorizontalAtTime:now]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:SourceRowDidStartScrollingHorizontallyNotification object:row];
        });
    }
    return row;
}

- (void)removeRow:(SourceRow *)row
{
    if (self.rowsByKey[row.key]!=row) {
        return;
    }
    if (self.lastRow==row) {
        self.lastSource=nil;
        self.lastRow=nil;
    }
    [self willChangeValueForKey:@"rows"];
    [self.rowsByKey removeObjectForKey:row.key];
    [self didChangeValueForKey:@"rows"];
    [self rowSettingsDidChange];
}

- (void)rowSettingsDidChange
{
    [self setNeedsSaveBy:CFAbsoluteTimeGetCurrent()+kChangeSaveDelay];
}

// Schedule a save for the given time, unless one is already due by then.
- (void)setNeedsSaveBy:(CFAbsoluteTime)time
{
    if (self.saveTime&&self.saveTime<=time) {
        return;
    }
    self.saveTime=time;
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(save) object:nil];
    [self performSelector:@selector(save) withObject:nil afterDelay:MAX(0, time-CFAbsoluteTimeGetCurrent()) inModes:@[NSRunLoopCommonModes]];
}

- (void)save
{
    if (!self.saveTime) {
        return;
    }
    self.saveTime=0;
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(save) object:nil];
    NSMutableDictionary *const dict=[NSMutableDictionary dictionaryWithCapacity:[self.rowsByKey count]];
    [self.rowsByKey enumerateKeysAndObjectsUsingBlock:^(NSString *key, SourceRow *row, BOOL *stop) {
        dict[key]=[row dictionaryRepresentation];
    }];
    [self.defaults setObject:dict forKey:PrefsSources];
}

@end
