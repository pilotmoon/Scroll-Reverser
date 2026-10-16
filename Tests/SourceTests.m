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
    XCTAssertFalse(trackpad.horizontalMatchesVertical);
    XCTAssertTrue(trackpad.hasDeviceDirection);

    SourceRow *const mouse=[self wheelMouse];
    XCTAssertEqual(mouse.verticalMode, ScrollDirectionModeClassic);
    XCTAssertTrue(mouse.horizontalMatchesVertical);
    XCTAssertTrue(mouse.stepSizeEnabled);
    XCTAssertEqual(mouse.stepSize, 3);

    // continuous scrolling from a mouse, like the Magic Mouse's, keeps horizontal swipes for gestures
    SourceRow *const magicMouse=[self.table recordSource:_continuousDevice(@{@kIOHIDTransportKey: @"Bluetooth", @kIOHIDSerialNumberKey: @"1"}) natural:YES amount:1];
    XCTAssertEqual(magicMouse.verticalMode, ScrollDirectionModeClassic);
    XCTAssertFalse(magicMouse.horizontalMatchesVertical);

    SourceRow *const app=[self app];
    XCTAssertEqual(app.verticalMode, ScrollDirectionModeUnchanged);
    XCTAssertFalse(app.hasDeviceDirection);
}

- (void)testNatural
{
    SourceRow *const row=[self trackpad];
    row.verticalMode=ScrollDirectionModeNatural;
    row.horizontalMatchesVertical=YES;
    XCTAssertFalse([row adjustmentForNatural:YES].reverseVertical);
    XCTAssertFalse([row adjustmentForNatural:YES].reverseHorizontal);
    XCTAssertTrue([row adjustmentForNatural:NO].reverseVertical);
    XCTAssertTrue([row adjustmentForNatural:NO].reverseHorizontal);
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
    row.horizontalMatchesVertical=YES;
    for (NSNumber *natural in @[@NO, @YES]) {
        const SourceAdjustment adjustment=[row adjustmentForNatural:[natural boolValue]];
        XCTAssertFalse(adjustment.reverseVertical);
        XCTAssertFalse(adjustment.reverseHorizontal);
    }
}

- (void)testHorizontalFollowsVerticalOnlyWhenMatching
{
    SourceRow *const row=[self wheelMouse];
    row.horizontalMatchesVertical=NO;
    const SourceAdjustment adjustment=[row adjustmentForNatural:YES];
    XCTAssertTrue(adjustment.reverseVertical);
    XCTAssertFalse(adjustment.reverseHorizontal);
    row.horizontalMatchesVertical=YES;
    XCTAssertTrue([row adjustmentForNatural:YES].reverseHorizontal);
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
    XCTAssertEqual([self.table recordSource:_device(@{@kIOHIDTransportKey: @"USB", @kIOHIDVendorIDKey: @1118, @kIOHIDProductIDKey: @64}) natural:NO amount:10], row);
    XCTAssertTrue(row.seenClassic);
    XCTAssertEqual(row.scrollTotal, 11);
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
    mouse.stepSize=7;
    mouse.customName=@"Wheel";
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
    XCTAssertTrue(row.horizontalMatchesVertical);
    XCTAssertEqual(row.stepSize, 7);
    XCTAssertEqualObjects(row.customName, @"Wheel");
    XCTAssertFalse(row.continuous);
    XCTAssertEqualWithAccuracy(row.lastSeenTime, mouse.lastSeenTime, 0.001);
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

- (void)testStartedScrollingNotification
{
    [self expectationForNotification:SourceRowDidStartScrollingNotification object:nil handler:nil];
    [self wheelMouse];
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

@end
