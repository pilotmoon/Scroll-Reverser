//
//  DebugWindowController.m
//  ScrollReverser
//
//  Created by Nicholas Moore on 07/05/2015.
//
//

#import "DebugWindowController.h"
#import "Logger.h"
#import "LoggerScrollView.h"
#import "AppDelegate.h"

@interface DebugWindowController ()
@property NSTimer *refreshTimer;
@end

@implementation DebugWindowController

- (void)setLogger:(Logger *)logger
{
    if (_logger) {
        [_logger unbind:@"enabled"];
    }
    if (logger) {
        [logger bind:@"enabled" toObject:self withKeyPath:@"paused" options:@{NSValueTransformerNameBindingOption: NSNegateBooleanTransformerName}];
    }
   _logger=logger;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    self.logger=nil;
}

- (void)windowDidLoad {
    [super windowDidLoad];
    self.consoleTableView.dataSource=self;
    self.consoleTableView.delegate=self;
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(updateConsoleNeeded)
                                                 name:LoggerEntriesChanged
                                               object:nil];
    [self addObserver:self forKeyPath:@"paused" options:NSKeyValueObservingOptionInitial context:nil];
    [self updateConsole];
}

- (void)showWindow:(id)sender
{
    [[self window] setLevel:NSFloatingWindowLevel];
    [[self window] center];
    [NSApp activateIgnoringOtherApps:YES];
    // small delay to prevent flash of window drawing
    dispatch_after(0.05, dispatch_get_main_queue(), ^{
        [super showWindow:sender];
    });
}

- (IBAction)clearLog:(id)sender {
    [self.logger clear];
    [(AppDelegate *)[NSApp delegate] logAppEvent:@"Log Cleared"];
}

- (void)updateConsole
{
    [self.consoleTableView reloadData];
    [self scrollToBottom];
}

- (void)updateConsoleNeeded
{
    if (self.window.isVisible && ![self.refreshTimer isValid]) {
        self.refreshTimer=[NSTimer scheduledTimerWithTimeInterval:0.05 target:self selector:@selector(updateConsole) userInfo:nil repeats:NO];
    }
}

- (void)scrollToBottom
{
    NSPoint newScrollOrigin;
    
    // assume that the scrollview is an existing variable
    if ([[self.consoleScrollView documentView] isFlipped]) {
        newScrollOrigin=NSMakePoint(0.0,NSMaxY([[self.consoleScrollView documentView] frame])
                                    -NSHeight([[self.consoleScrollView contentView] bounds]));
    } else {
        newScrollOrigin=NSMakePoint(0.0,0.0);
    }
    
    [[self.consoleScrollView documentView] scrollPoint:newScrollOrigin];
    
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (object==self && [keyPath isEqualToString:@"paused"]) {
        self.consoleScrollView.scrollingAllowed=self.paused;
        self.consoleScrollView.hasVerticalScroller=self.paused;
        self.consoleScrollView.hasHorizontalScroller=NO;
        if (self.paused) {
            [self.consoleScrollView flashScrollers];
        }
        [(AppDelegate *)[NSApp delegate] logAppEvent:self.paused?@"Log Paused":@"Log Started"];
    }
}

- (NSString *)uiStringDebugConsole {
    return @"Scroll Reverser Debug Console";
}

- (NSString *)uiStringClear {
    return @"Clear";
}

- (NSString *)uiStringPause {
    return @"Pause";
}

#pragma mark Table view delegate/datasource

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    return self.logger.entryCount;
}

- (NSView *)tableView:(NSTableView *)tableView
   viewForTableColumn:(NSTableColumn *)tableColumn
                  row:(NSInteger)row
{
    NSTableCellView *result = [tableView makeViewWithIdentifier:tableColumn.identifier owner:self];
    NSAttributedString *as=[self.logger entryAtIndex:row];
    result.textField.attributedStringValue=as;
    
    return result;
}

- (NSIndexSet *)tableView:(NSTableView *)tableView selectionIndexesForProposedSelection:(NSIndexSet *)proposedSelectionIndexes
{
    return self.paused?proposedSelectionIndexes:nil;
}


@end

