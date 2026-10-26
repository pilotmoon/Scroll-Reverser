// This file is part of Scroll Reverser <https://pilotmoon.com/scrollreverser/>
// Licensed under Apache License v2.0 <http://www.apache.org/licenses/LICENSE-2.0>

#import <XCTest/XCTest.h>
#import <IOKit/hid/IOHIDKeys.h>
#import "ScrollSource.h"
#import "SourceTable.h"

// the device's non-continuous source
static ScrollSource *_device(NSDictionary *properties)
{
    return [ScrollSource deviceSourcesWithKind:ScrollSourceKindLocalDevice properties:properties trackpadDriver:NO][0];
}

static ScrollSource *_continuousDevice(NSDictionary *properties)
{
    return [ScrollSource deviceSourcesWithKind:ScrollSourceKindLocalDevice properties:properties trackpadDriver:NO][1];
}

#pragma mark - Keys

@interface ScrollSourceKeyTests : XCTestCase
@end

@implementation ScrollSourceKeyTests

- (void)testDeviceWithSerial
{
    ScrollSource *const source=_device(@{@kIOHIDTransportKey: @"Bluetooth", @kIOHIDVendorIDKey: @76, @kIOHIDProductIDKey: @617,
                                         @kIOHIDSerialNumberKey: @"A8:91:3D:31:4C:6A", @kIOHIDProductKey: @"Nick's Mouse"});
    XCTAssertEqualObjects(source.key, @"device|Bluetooth|76|617|sn:A8:91:3D:31:4C:6A#discrete");
    XCTAssertEqualObjects(source.name, @"Nick's Mouse");
    XCTAssertEqual(source.kind, ScrollSourceKindLocalDevice);
    XCTAssertFalse(source.continuous);
}

- (void)testDeviceIsSplitByContinuity
{
    NSArray<ScrollSource *> *const sources=[ScrollSource deviceSourcesWithKind:ScrollSourceKindLocalDevice
                                                                     properties:@{@kIOHIDTransportKey: @"USB", @kIOHIDVendorIDKey: @1118, @kIOHIDProductIDKey: @64, @kIOHIDProductKey: @"Mouse"}
                                                                 trackpadDriver:NO];
    XCTAssertEqual([sources count], 2);
    XCTAssertEqualObjects(sources[0].key, @"device|USB|1118|64#discrete");
    XCTAssertEqualObjects(sources[1].key, @"device|USB|1118|64#continuous");
    XCTAssertFalse(sources[0].continuous);
    XCTAssertTrue(sources[1].continuous);
    for (ScrollSource *source in sources) {
        XCTAssertEqual(source.category, ScrollSourceCategoryMouse);
        XCTAssertEqualObjects(source.name, @"Mouse");
    }
}

// the name is left out, so renaming a Bluetooth device keeps its row
- (void)testDeviceWithoutSerial
{
    ScrollSource *const source=_device(@{@kIOHIDTransportKey: @"USB", @kIOHIDVendorIDKey: @1118, @kIOHIDProductIDKey: @64,
                                         @kIOHIDProductKey: @"Microsoft 3-Button Mouse with IntelliEye(TM)", @kIOHIDLocationIDKey: @0x14100000});
    XCTAssertEqualObjects(source.key, @"device|USB|1118|64#discrete");
}

- (void)testDeviceWithoutSerialOrIDsUsesName
{
    ScrollSource *const source=_device(@{@kIOHIDTransportKey: @"FIFO", @kIOHIDVendorIDKey: @0, @kIOHIDProductIDKey: @0,
                                         @kIOHIDProductKey: @"Apple Internal Keyboard / Trackpad"});
    XCTAssertEqualObjects(source.key, @"device|FIFO|0|0|Apple Internal Keyboard / Trackpad#discrete");
}

- (void)testDeviceWithNoProperties
{
    XCTAssertEqualObjects(_device(@{}).key, @"device||||#discrete");
}

- (void)testEmptySerialIsIgnored
{
    XCTAssertEqualObjects(_device(@{@kIOHIDTransportKey: @"USB", @kIOHIDVendorIDKey: @1, @kIOHIDProductIDKey: @2, @kIOHIDSerialNumberKey: @""}).key, @"device|USB|1|2#discrete");
}

- (void)testRemoteDevice
{
    ScrollSource *const source=[ScrollSource deviceSourcesWithKind:ScrollSourceKindRemoteDevice
                                                        properties:@{@kIOHIDTransportKey: @"Virtual", @kIOHIDVendorIDKey: @76, @kIOHIDProductIDKey: @613, @kIOHIDProductKey: @"V-Magic Trackpad"}
                                                    trackpadDriver:NO][1];
    XCTAssertEqualObjects(source.key, @"remote|Virtual|76|613#continuous");
    XCTAssertEqual(source.kind, ScrollSourceKindRemoteDevice);
}

- (void)testSeparatorsInFieldsAreEscaped
{
    ScrollSource *const serial=_device(@{@kIOHIDTransportKey: @"a|b", @kIOHIDVendorIDKey: @1, @kIOHIDProductIDKey: @2, @kIOHIDSerialNumberKey: @"x#y%z|"});
    XCTAssertEqualObjects(serial.key, @"device|a%7Cb|1|2|sn:x%23y%25z%7C#discrete");
    ScrollSource *const product=_device(@{@kIOHIDTransportKey: @"SPI", @kIOHIDProductKey: @"100% #1 | best"});
    XCTAssertEqualObjects(product.key, @"device|SPI|||100%25 %231 %7C best#discrete");
    // an escape sequence in the original text is escaped too, so it can't be mistaken for a separator
    XCTAssertEqualObjects(_device(@{@kIOHIDTransportKey: @"%7C"}).key, @"device|%257C|||#discrete");
}

- (void)testCategory
{
    XCTAssertEqual(_device(@{@"HIDScrollAccelerationType": @"HIDTrackpadScrollAcceleration"}).category, ScrollSourceCategoryTrackpad);
    XCTAssertEqual(_device(@{@"HIDScrollAccelerationType": @"HIDMouseScrollAcceleration"}).category, ScrollSourceCategoryMouse);
    XCTAssertEqual(_device(@{}).category, ScrollSourceCategoryMouse);
    XCTAssertEqual([ScrollSource deviceSourcesWithKind:ScrollSourceKindLocalDevice properties:@{} trackpadDriver:YES][1].category, ScrollSourceCategoryTrackpad);
}

- (void)testAppIsSplitByContinuity
{
    NSArray<ScrollSource *> *const sources=[ScrollSource appSourcesWithIdentifier:@"com.logi.cp-dev-mgr" name:@"Logi Options+" path:@"/Applications/logioptionsplus.app"];
    XCTAssertEqual([sources count], 2);
    XCTAssertEqualObjects(sources[0].key, @"app|com.logi.cp-dev-mgr#discrete");
    XCTAssertEqualObjects(sources[1].key, @"app|com.logi.cp-dev-mgr#continuous");
    XCTAssertFalse(sources[0].continuous);
    XCTAssertTrue(sources[1].continuous);
    for (ScrollSource *source in sources) {
        XCTAssertEqual(source.kind, ScrollSourceKindApp);
        XCTAssertEqual(source.category, ScrollSourceCategoryOther);
        XCTAssertEqualObjects(source.name, @"Logi Options+");
        XCTAssertEqualObjects(source.path, @"/Applications/logioptionsplus.app");
    }
}

- (void)testAppPathIsEscaped
{
    NSArray<ScrollSource *> *const sources=[ScrollSource appSourcesWithIdentifier:@"/opt/tools #2/scroll|er" name:nil path:@"/opt/tools #2/scroll|er"];
    XCTAssertEqualObjects(sources[1].key, @"app|/opt/tools %232/scroll%7Cer#continuous");
}

@end

#pragma mark - Rows and the reversing rule

@interface SourceRowTests : XCTestCase
@property NSString *suiteName;
@property NSUserDefaults *defaults;
@property SourceTable *table;
@end

@implementation SourceRowTests

- (void)setUp
{
    self.suiteName=[NSString stringWithFormat:@"com.pilotmoon.scroll-reverser.tests.%@", [NSUUID UUID].UUIDString];
    self.defaults=[[NSUserDefaults alloc] initWithSuiteName:self.suiteName];
    self.table=[[SourceTable alloc] initWithUserDefaults:self.defaults];
}

- (void)tearDown
{
    [self.defaults removePersistentDomainForName:self.suiteName];
}

- (SourceRow *)trackpad
{
    ScrollSource *const source=_continuousDevice(@{@kIOHIDTransportKey: @"FIFO", @kIOHIDProductKey: @"Trackpad", @"HIDScrollAccelerationType": @"HIDTrackpadScrollAcceleration"});
    return [self.table recordSource:source natural:YES amount:1];
}

- (SourceRow *)wheelMouse
{
    ScrollSource *const source=_device(@{@kIOHIDTransportKey: @"USB", @kIOHIDVendorIDKey: @1118, @kIOHIDProductIDKey: @64});
    return [self.table recordSource:source natural:YES amount:1];
}

- (SourceRow *)app
{
    ScrollSource *const source=[ScrollSource appSourcesWithIdentifier:@"com.example.app" name:@"Example" path:@"/Applications/Example.app"][0];
    return [self.table recordSource:source natural:NO amount:1];
}

- (void)testDefaults
{
    SourceRow *const trackpad=[self trackpad];
    XCTAssertEqual(trackpad.verticalMode, ScrollDirectionModeNatural);
    XCTAssertEqual(trackpad.horizontalMode, ScrollDirectionModeUnchanged);
    XCTAssertTrue(trackpad.hasDeviceDirection);

    SourceRow *const mouse=[self wheelMouse];
    XCTAssertEqual(mouse.verticalMode, ScrollDirectionModeClassic);
    XCTAssertEqual(mouse.horizontalMode, ScrollDirectionModeUnchanged);
    XCTAssertTrue(mouse.stepSizeEnabled);
    XCTAssertEqual(mouse.stepSize, 3);

    // continuous scrolling from a mouse, like the Magic Mouse's, keeps horizontal swipes for gestures
    SourceRow *const magicMouse=[self.table recordSource:_continuousDevice(@{@kIOHIDTransportKey: @"Bluetooth", @kIOHIDSerialNumberKey: @"1"}) natural:YES amount:1];
    XCTAssertEqual(magicMouse.verticalMode, ScrollDirectionModeClassic);
    XCTAssertEqual(magicMouse.horizontalMode, ScrollDirectionModeUnchanged);

    SourceRow *const app=[self app];
    XCTAssertEqual(app.verticalMode, ScrollDirectionModeUnchanged);
    XCTAssertEqual(app.horizontalMode, ScrollDirectionModeUnchanged);
    XCTAssertFalse(app.hasDeviceDirection);
}

- (void)testNatural
{
    SourceRow *const row=[self trackpad];
    row.verticalMode=ScrollDirectionModeNatural;
    XCTAssertFalse([row adjustmentForNatural:YES].reverseVertical);
    XCTAssertTrue([row adjustmentForNatural:NO].reverseVertical);
}

- (void)testClassic
{
    SourceRow *const row=[self wheelMouse];
    row.verticalMode=ScrollDirectionModeClassic;
    XCTAssertTrue([row adjustmentForNatural:YES].reverseVertical);
    XCTAssertFalse([row adjustmentForNatural:NO].reverseVertical);
}

- (void)testReversedAndUnchanged
{
    SourceRow *const row=[self app];
    row.verticalMode=ScrollDirectionModeReversed;
    XCTAssertTrue([row adjustmentForNatural:NO].reverseVertical);
    XCTAssertTrue([row adjustmentForNatural:YES].reverseVertical);
    row.verticalMode=ScrollDirectionModeUnchanged;
    row.horizontalMode=ScrollDirectionModeUnchanged;
    for (NSNumber *natural in @[@NO, @YES]) {
        const SourceAdjustment adjustment=[row adjustmentForNatural:[natural boolValue]];
        XCTAssertFalse(adjustment.reverseVertical);
        XCTAssertFalse(adjustment.reverseHorizontal);
    }
}

// Every vertical and horizontal mode, for events with and without natural scrolling applied.
- (void)testHorizontalModes
{
    SourceRow *const row=[self wheelMouse];
    const ScrollDirectionMode verticalModes[]={ScrollDirectionModeNatural, ScrollDirectionModeClassic, ScrollDirectionModeReversed, ScrollDirectionModeUnchanged};
    for (size_t v=0; v<sizeof(verticalModes)/sizeof(verticalModes[0]); v++) {
        for (NSNumber *naturalNumber in @[@NO, @YES]) {
            const BOOL natural=[naturalNumber boolValue];
            row.verticalMode=verticalModes[v];
            const BOOL reverseVertical=verticalModes[v]==ScrollDirectionModeReversed||
                (verticalModes[v]==ScrollDirectionModeNatural&&!natural)||
                (verticalModes[v]==ScrollDirectionModeClassic&&natural);
            NSString *const context=[NSString stringWithFormat:@"vertical %ld, natural %d", (long)verticalModes[v], natural];
            // horizontal modes don't depend on vertical, or on the system's direction
            row.horizontalMode=ScrollDirectionModeReversed;
            XCTAssertEqual([row adjustmentForNatural:natural].reverseVertical, reverseVertical, @"%@", context);
            XCTAssertTrue([row adjustmentForNatural:natural].reverseHorizontal, @"%@", context);
            row.horizontalMode=ScrollDirectionModeUnchanged;
            XCTAssertFalse([row adjustmentForNatural:natural].reverseHorizontal, @"%@", context);
        }
    }
}

// a thumb wheel reversed while its wheel follows the system's natural scrolling
- (void)testHorizontalIndependentOfVertical
{
    SourceRow *const row=[self wheelMouse];
    row.verticalMode=ScrollDirectionModeNatural;
    row.horizontalMode=ScrollDirectionModeReversed;
    const SourceAdjustment adjustment=[row adjustmentForNatural:YES];
    XCTAssertFalse(adjustment.reverseVertical);
    XCTAssertTrue(adjustment.reverseHorizontal);
}

- (void)testStepSize
{
    SourceRow *const row=[self wheelMouse];
    row.stepSize=5;
    XCTAssertEqual([row adjustmentForNatural:YES].stepSize, 5);
    XCTAssertEqual([[self trackpad] adjustmentForNatural:YES].stepSize, 1, @"step size is only for non-continuous scrolling");
    row.stepSize=0;
    XCTAssertEqual([row adjustmentForNatural:YES].stepSize, SourceRowMinStepSize);
    row.stepSize=1000;
    XCTAssertEqual([row adjustmentForNatural:YES].stepSize, SourceRowMaxStepSize);
    row.stepSizeEnabled=NO;
    XCTAssertEqual([row adjustmentForNatural:YES].stepSize, 1);
}

- (void)testSightings
{
    SourceRow *const row=[self wheelMouse];
    XCTAssertFalse(row.continuous);
    XCTAssertTrue(row.seenNatural);
    XCTAssertFalse(row.seenClassic);
    XCTAssertTrue(row.lastNatural);
    XCTAssertEqual([self.table recordSource:_device(@{@kIOHIDTransportKey: @"USB", @kIOHIDVendorIDKey: @1118, @kIOHIDProductIDKey: @64}) natural:NO amount:10], row);
    XCTAssertTrue(row.seenClassic);
    XCTAssertFalse(row.lastNatural);
    [self.table recordSource:_device(@{@kIOHIDTransportKey: @"USB", @kIOHIDVendorIDKey: @1118, @kIOHIDProductIDKey: @64}) natural:YES amount:0];
    XCTAssertTrue(row.lastNatural);
    XCTAssertEqual(row.scrollTotal, 11);
    XCTAssertTrue(row.seenNatural&&row.seenClassic);
    XCTAssertEqual([self.table.rows count], 1);
    // continuous scrolling from the same device has its own row
    SourceRow *const continuousRow=[self.table recordSource:_continuousDevice(@{@kIOHIDTransportKey: @"USB", @kIOHIDVendorIDKey: @1118, @kIOHIDProductIDKey: @64}) natural:NO amount:1];
    XCTAssertNotEqual(continuousRow, row);
    XCTAssertTrue(continuousRow.continuous);
    XCTAssertEqual([self.table.rows count], 2);
}

// an app that moves keeps its row, by bundle ID, and the row follows it
- (void)testReportedNameAndPathAreRefreshed
{
    SourceRow *const row=[self app];
    ScrollSource *const moved=[ScrollSource appSourcesWithIdentifier:@"com.example.app" name:@"Example 2" path:@"/Applications/Utilities/Example.app"][0];
    XCTAssertEqual([self.table recordSource:moved natural:NO amount:1], row);
    XCTAssertEqualObjects(row.reportedName, @"Example 2");
    XCTAssertEqualObjects(row.path, @"/Applications/Utilities/Example.app");
}

- (void)testCustomName
{
    SourceRow *const row=[self app];
    row.customName=@"Mine";
    XCTAssertEqualObjects(row.customName, @"Mine");
    row.customName=@"";
    XCTAssertNil(row.customName);
}

- (void)testSaveAndLoad
{
    SourceRow *const mouse=[self wheelMouse];
    mouse.verticalMode=ScrollDirectionModeUnchanged;
    mouse.horizontalMode=ScrollDirectionModeReversed;
    mouse.stepSize=7;
    mouse.customName=@"Wheel";
    [self.table recordSource:_device(@{@kIOHIDTransportKey: @"USB", @kIOHIDVendorIDKey: @1118, @kIOHIDProductIDKey: @64}) natural:NO amount:1];
    SourceRow *const removed=[self trackpad];
    [self.table removeRow:removed];
    [self.table save];

    SourceTable *const loaded=[[SourceTable alloc] initWithUserDefaults:self.defaults];
    XCTAssertEqual([loaded.rows count], 1);
    SourceRow *const row=loaded.rows[0];
    XCTAssertEqualObjects(row.key, mouse.key);
    XCTAssertEqual(row.kind, ScrollSourceKindLocalDevice);
    XCTAssertEqual(row.category, ScrollSourceCategoryMouse);
    XCTAssertEqual(row.verticalMode, ScrollDirectionModeUnchanged);
    XCTAssertEqual(row.horizontalMode, ScrollDirectionModeReversed);
    XCTAssertEqual(row.stepSize, 7);
    XCTAssertEqualObjects(row.customName, @"Wheel");
    XCTAssertFalse(row.continuous);
    XCTAssertTrue(row.seenNatural&&row.seenClassic);
    XCTAssertFalse(row.lastNatural);
    XCTAssertEqualWithAccuracy(row.lastSeenTime, mouse.lastSeenTime, 0.001);
}

// rows saved with the old Match vertical mode (4), or with only the older HorizontalMatchesVertical key
- (void)testMatchVerticalLoadsAsUnchanged
{
    NSDictionary *const saved=@{@"Kind": @(ScrollSourceKindLocalDevice), @"Category": @(ScrollSourceCategoryMouse)};
    NSMutableDictionary *const matchVertical=[saved mutableCopy];
    matchVertical[@"HorizontalMode"]=@4;
    NSMutableDictionary *const oldMatching=[saved mutableCopy];
    oldMatching[@"HorizontalMatchesVertical"]=@YES;
    NSMutableDictionary *const oldUnchanged=[saved mutableCopy];
    oldUnchanged[@"HorizontalMatchesVertical"]=@NO;
    NSMutableDictionary *const reversed=[saved mutableCopy];
    reversed[@"HorizontalMatchesVertical"]=@YES;
    reversed[@"HorizontalMode"]=@(ScrollDirectionModeReversed);
    [self.defaults setObject:@{@"matchVertical": matchVertical, @"oldMatching": oldMatching, @"oldUnchanged": oldUnchanged, @"reversed": reversed} forKey:@"Sources"];

    SourceTable *const loaded=[[SourceTable alloc] initWithUserDefaults:self.defaults];
    NSMutableDictionary<NSString *, SourceRow *> *const rows=[NSMutableDictionary dictionary];
    for (SourceRow *row in loaded.rows) {
        rows[row.key]=row;
    }
    XCTAssertEqual(rows[@"matchVertical"].horizontalMode, ScrollDirectionModeUnchanged);
    XCTAssertEqual(rows[@"oldMatching"].horizontalMode, ScrollDirectionModeUnchanged);
    XCTAssertEqual(rows[@"oldUnchanged"].horizontalMode, ScrollDirectionModeUnchanged);
    XCTAssertEqual(rows[@"reversed"].horizontalMode, ScrollDirectionModeReversed);

    // saved again as Unchanged, without the older key
    [loaded save];
    NSDictionary *const resaved=[self.defaults dictionaryForKey:@"Sources"];
    XCTAssertEqualObjects(resaved[@"matchVertical"][@"HorizontalMode"], @(ScrollDirectionModeUnchanged));
    XCTAssertNil(resaved[@"oldMatching"][@"HorizontalMatchesVertical"]);
}

// Natural and Classic horizontal, from earlier versions, become whichever of Reversed and Unchanged does
// the same with the direction the source was last seen in, or natural if it hasn't been seen.
- (void)testNaturalAndClassicHorizontalAreConverted
{
    NSDictionary *const saved=@{@"Kind": @(ScrollSourceKindLocalDevice), @"Category": @(ScrollSourceCategoryMouse)};
    NSDictionary *const seenNatural=@{@"SeenNatural": @YES, @"LastNatural": @YES};
    NSDictionary *const seenClassic=@{@"SeenClassic": @YES, @"LastNatural": @NO};
    NSDictionary *const unseen=@{};
    NSArray *const cases=@[
        // mode, how it was last seen, whether it was seen natural, expected
        @[@(ScrollDirectionModeNatural), seenNatural, @YES, @(ScrollDirectionModeUnchanged)],
        @[@(ScrollDirectionModeNatural), seenClassic, @NO, @(ScrollDirectionModeReversed)],
        @[@(ScrollDirectionModeNatural), unseen, @YES, @(ScrollDirectionModeUnchanged)],
        @[@(ScrollDirectionModeClassic), seenNatural, @YES, @(ScrollDirectionModeReversed)],
        @[@(ScrollDirectionModeClassic), seenClassic, @NO, @(ScrollDirectionModeUnchanged)],
        @[@(ScrollDirectionModeClassic), unseen, @YES, @(ScrollDirectionModeReversed)],
        @[@(ScrollDirectionModeReversed), seenNatural, @YES, @(ScrollDirectionModeReversed)],
        @[@(ScrollDirectionModeUnchanged), seenClassic, @NO, @(ScrollDirectionModeUnchanged)],
    ];
    NSMutableDictionary *const sources=[NSMutableDictionary dictionary];
    [cases enumerateObjectsUsingBlock:^(NSArray *c, NSUInteger i, BOOL *stop) {
        NSMutableDictionary *const dict=[saved mutableCopy];
        dict[@"HorizontalMode"]=c[0];
        [dict addEntriesFromDictionary:c[1]];
        sources[[NSString stringWithFormat:@"%lu", (unsigned long)i]]=dict;
    }];
    [self.defaults setObject:sources forKey:@"Sources"];

    SourceTable *const loaded=[[SourceTable alloc] initWithUserDefaults:self.defaults];
    NSMutableDictionary<NSString *, SourceRow *> *const rows=[NSMutableDictionary dictionary];
    for (SourceRow *row in loaded.rows) {
        rows[row.key]=row;
    }
    [cases enumerateObjectsUsingBlock:^(NSArray *c, NSUInteger i, BOOL *stop) {
        SourceRow *const row=rows[[NSString stringWithFormat:@"%lu", (unsigned long)i]];
        const ScrollDirectionMode old=[c[0] integerValue];
        const BOOL natural=[c[2] boolValue];
        XCTAssertEqual(row.horizontalMode, [c[3] integerValue], @"case %lu", (unsigned long)i);
        // the same as before for scrolling in the direction last seen
        const BOOL reversedBefore=old==ScrollDirectionModeReversed||(old==ScrollDirectionModeNatural&&!natural)||(old==ScrollDirectionModeClassic&&natural);
        XCTAssertEqual([row adjustmentForNatural:natural].reverseHorizontal, reversedBefore, @"case %lu", (unsigned long)i);
    }];

    // and saved, so they're converted only once
    [loaded save];
    NSDictionary *const resaved=[self.defaults dictionaryForKey:@"Sources"];
    [cases enumerateObjectsUsingBlock:^(NSArray *c, NSUInteger i, BOOL *stop) {
        NSString *const key=[NSString stringWithFormat:@"%lu", (unsigned long)i];
        XCTAssertEqualObjects(resaved[key][@"HorizontalMode"], c[3], @"case %lu", (unsigned long)i);
    }];
}

// rows saved before the last direction was kept
- (void)testLastNaturalFromOlderRows
{
    NSDictionary *const saved=@{@"Kind": @(ScrollSourceKindLocalDevice), @"Category": @(ScrollSourceCategoryMouse)};
    NSMutableDictionary *const natural=[saved mutableCopy];
    natural[@"SeenNatural"]=@YES;
    NSMutableDictionary *const classic=[saved mutableCopy];
    classic[@"SeenClassic"]=@YES;
    NSMutableDictionary *const both=[saved mutableCopy];
    both[@"SeenNatural"]=@YES;
    both[@"SeenClassic"]=@YES;
    [self.defaults setObject:@{@"natural": natural, @"classic": classic, @"both": both} forKey:@"Sources"];

    SourceTable *const loaded=[[SourceTable alloc] initWithUserDefaults:self.defaults];
    NSMutableDictionary<NSString *, SourceRow *> *const rows=[NSMutableDictionary dictionary];
    for (SourceRow *row in loaded.rows) {
        rows[row.key]=row;
    }
    XCTAssertTrue(rows[@"natural"].lastNatural);
    XCTAssertFalse(rows[@"classic"].lastNatural);
    XCTAssertTrue(rows[@"both"].lastNatural, @"a guess");
}

- (void)testRemovedSourceGetsNewRow
{
    SourceRow *const row=[self wheelMouse];
    row.verticalMode=ScrollDirectionModeNatural;
    [self.table removeRow:row];
    XCTAssertEqual([self.table.rows count], 0);
    SourceRow *const again=[self wheelMouse];
    XCTAssertNotEqual(again, row);
    XCTAssertEqual(again.verticalMode, ScrollDirectionModeClassic);
}

// only scrolling that is only horizontal, as from a thumb wheel or a sideways swipe, and once per burst
- (void)testStartedScrollingHorizontallyNotification
{
    NSMutableArray *const posted=[NSMutableArray array];
    id const observer=[[NSNotificationCenter defaultCenter] addObserverForName:SourceRowDidStartScrollingHorizontallyNotification object:nil queue:nil usingBlock:^(NSNotification *notification) {
        [posted addObject:notification.object];
    }];
    ScrollSource *const wheel=_device(@{@kIOHIDTransportKey: @"USB", @kIOHIDVendorIDKey: @1118, @kIOHIDProductIDKey: @64});
    SourceRow *const row=[self.table recordSource:wheel natural:YES amount:1];
    [self.table recordSource:wheel natural:YES amount:1 horizontal:YES];
    [self.table recordSource:wheel natural:YES amount:1 horizontal:YES];
    SourceRow *const trackpad=[self.table recordSource:_continuousDevice(@{@kIOHIDTransportKey: @"FIFO", @kIOHIDProductKey: @"Trackpad"}) natural:YES amount:1 horizontal:YES];
    // the notifications are posted asynchronously
    XCTestExpectation *const drained=[self expectationWithDescription:@"main queue drained"];
    dispatch_async(dispatch_get_main_queue(), ^{
        [drained fulfill];
    });
    [self waitForExpectationsWithTimeout:1 handler:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:observer];
    XCTAssertEqualObjects(posted, (@[row, trackpad]));
}

- (void)testStartedScrollingNotification
{
    [self expectationForNotification:SourceRowDidStartScrollingNotification object:nil handler:nil];
    [self wheelMouse];
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

@end
