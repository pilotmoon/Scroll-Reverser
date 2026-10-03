// This file is part of Scroll Reverser <https://pilotmoon.com/scrollreverser/>
// Licensed under Apache License v2.0 <http://www.apache.org/licenses/LICENSE-2.0>

#import <Cocoa/Cocoa.h>
@class Logger, LoggerScrollView, AppDelegate;

@interface DebugWindowController : NSWindowController  <NSTableViewDataSource, NSTableViewDelegate, NSWindowDelegate>

@property (readonly) NSTableView *consoleTableView;
@property (readonly) LoggerScrollView *consoleScrollView;
@property (weak, nonatomic) Logger *logger;
@property BOOL paused;

@property (readonly) AppDelegate *appDelegate;

- (IBAction)clearLog:(id)sender;
- (IBAction)logState:(id)sender;
- (IBAction)showDemoWindow:(id)sender;

@end
