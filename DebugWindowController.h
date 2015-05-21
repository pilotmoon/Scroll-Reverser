//
//  DebugWindowController.h
//  ScrollReverser
//
//  Created by Nicholas Moore on 07/05/2015.
//
//

#import <Cocoa/Cocoa.h>
@class Logger, LoggerScrollView, AppDelegate;

@interface DebugWindowController : NSWindowController  <NSTableViewDataSource, NSTableViewDelegate>

@property (weak) IBOutlet NSTableView *consoleTableView;
@property (weak) IBOutlet LoggerScrollView *consoleScrollView;
@property (weak, nonatomic) Logger *logger;
@property BOOL paused;

@property (readonly) NSString *uiStringDebugConsole;
@property (readonly) NSString *uiStringClear;
@property (readonly) NSString *uiStringPause;
@property (readonly) NSString *uiStringLogState;
@property (readonly) NSString *uiStringShowTestWindow;

@property (readonly) AppDelegate *appDelegate;

- (IBAction)clearLog:(id)sender;
- (IBAction)logState:(id)sender;
- (IBAction)showDemoWindow:(id)sender;

@end
