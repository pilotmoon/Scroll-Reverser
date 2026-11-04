// This file is part of Scroll Reverser <https://pilotmoon.com/scrollreverser/>
// Licensed under Apache License v2.0 <http://www.apache.org/licenses/LICENSE-2.0>

#import <XCTest/XCTest.h>
#import "ExecutableWatcher.h"

/* The decision, on real files, the way updaters change them: replacing the file at the path,
 moving the old bundle aside, and deleting it. */
@interface ExecutableWatcherTests : XCTestCase
@property NSString *dir;
@property NSString *path;
@end

@implementation ExecutableWatcherTests {
    struct stat _launch;
}

- (void)setUp
{
    self.dir=[NSTemporaryDirectory() stringByAppendingPathComponent:[[NSUUID UUID] UUIDString]];
    [[NSFileManager defaultManager] createDirectoryAtPath:self.dir withIntermediateDirectories:YES attributes:nil error:nil];
    self.path=[self.dir stringByAppendingPathComponent:@"exe"];
    [self writeFileAtPath:self.path];
    XCTAssertEqual(stat(self.path.fileSystemRepresentation, &_launch), 0);
}

- (void)tearDown
{
    [[NSFileManager defaultManager] removeItemAtPath:self.dir error:nil];
}

- (void)writeFileAtPath:(NSString *)path
{
    XCTAssertTrue([[[NSUUID UUID] UUIDString] writeToFile:path atomically:NO encoding:NSUTF8StringEncoding error:nil]);
}

// the state now, with whether the launched file still exists anywhere
- (ExecutableState)stateWithRunningFileExists:(BOOL)exists
{
    struct stat current;
    const BOOL have=stat(self.path.fileSystemRepresentation, &current)==0;
    return ExecutableStateFor(&_launch, have?&current:NULL, exists);
}

- (NSString *)moveAside
{
    NSString *const aside=[self.dir stringByAppendingPathComponent:@"aside"];
    XCTAssertTrue([[NSFileManager defaultManager] moveItemAtPath:self.path toPath:aside error:nil]);
    return aside;
}

- (void)testUnchanged
{
    XCTAssertEqual([self stateWithRunningFileExists:YES], ExecutableStateCurrent);
}

- (void)testRewrittenInPlaceIsCurrent
{
    // same file, new contents: installers don't do this, and we only compare which file is at the path
    [self writeFileAtPath:self.path];
    XCTAssertEqual([self stateWithRunningFileExists:YES], ExecutableStateCurrent);
}

- (void)testMovedWithNothingAtPath
{
    [self moveAside];
    XCTAssertEqual([self stateWithRunningFileExists:YES], ExecutableStateMoved);
}

- (void)testMovedAsideAndReplaced
{
    [self moveAside];
    [self writeFileAtPath:self.path];
    XCTAssertEqual([self stateWithRunningFileExists:YES], ExecutableStateReplaced);
}

- (void)testReplacedByRename
{
    NSString *const staged=[self.dir stringByAppendingPathComponent:@"staged"];
    [self writeFileAtPath:staged];
    XCTAssertEqual(rename(staged.fileSystemRepresentation, self.path.fileSystemRepresentation), 0);
    XCTAssertEqual([self stateWithRunningFileExists:YES], ExecutableStateReplaced);
}

- (void)testMovedAsideReplacedAndDeleted
{
    NSString *const aside=[self moveAside];
    [self writeFileAtPath:self.path];
    [[NSFileManager defaultManager] removeItemAtPath:aside error:nil];
    XCTAssertEqual([self stateWithRunningFileExists:NO], ExecutableStateReplaced);
}

- (void)testDeletedWithNothingAtPath
{
    [[NSFileManager defaultManager] removeItemAtPath:self.path error:nil];
    XCTAssertEqual([self stateWithRunningFileExists:NO], ExecutableStateReplaced);
}

@end
