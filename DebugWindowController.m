// This file is part of Scroll Reverser <https://pilotmoon.com/scrollreverser/>
// Licensed under Apache License v2.0 <http://www.apache.org/licenses/LICENSE-2.0>

#import "DebugWindowController.h"
#import "Logger.h"
#import "LoggerScrollView.h"
#import "AppDelegate.h"

static NSUserInterfaceItemIdentifier const kLogCellIdentifier=@"LogCell";

@interface DebugWindowController ()
@property NSTableView *consoleTableView;
@property LoggerScrollView *consoleScrollView;
@property NSDateFormatter *df;
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
    // a new logger starts with its own entries, so drop any rows from the previous one
    [self.consoleTableView reloadData];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    self.logger=nil;
}

- (instancetype)init
{
    NSWindow *const window=[[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 800, 276)
                                                       styleMask:NSWindowStyleMaskTitled|NSWindowStyleMaskClosable|NSWindowStyleMaskMiniaturizable|NSWindowStyleMaskResizable
                                                         backing:NSBackingStoreBuffered
                                                           defer:YES];
    window.title=@"Scroll Reverser Debug Console";
    window.releasedWhenClosed=NO;
    window.restorable=NO;

    self=[super initWithWindow:window];
    if (self) {
        window.delegate=self;
        self.df=[[NSDateFormatter alloc] init];
        self.df.dateFormat=@"HH:mm:ss.S";
        [self buildContentView:window.contentView];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(observeLogEntriesChange:) name:LoggerEntriesChanged object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(observeLogUpdatesWaiting:) name:LoggerUpdatesWaiting object:nil];
        [self addObserver:self forKeyPath:@"paused" options:NSKeyValueObservingOptionInitial context:nil];
    }
    return self;
}

- (void)buildContentView:(NSView *)contentView
{
    // one wide column, so long lines can be scrolled to horizontally while paused
    NSTableColumn *const column=[[NSTableColumn alloc] initWithIdentifier:kLogCellIdentifier];
    column.editable=NO;
    column.width=2000;
    column.minWidth=2000;
    column.maxWidth=100000;
    column.resizingMask=NSTableColumnAutoresizingMask;

    self.consoleTableView=[[NSTableView alloc] init];
    self.consoleTableView.style=NSTableViewStyleFullWidth;
    self.consoleTableView.rowSizeStyle=NSTableViewRowSizeStyleCustom;
    self.consoleTableView.rowHeight=17;
    self.consoleTableView.headerView=nil;
    self.consoleTableView.allowsColumnReordering=NO;
    self.consoleTableView.allowsColumnResizing=NO;
    self.consoleTableView.allowsMultipleSelection=YES;
    self.consoleTableView.allowsTypeSelect=NO;
    self.consoleTableView.allowsExpansionToolTips=YES;
    self.consoleTableView.intercellSpacing=NSMakeSize(3, 2);
    [self.consoleTableView addTableColumn:column];
    self.consoleTableView.dataSource=self;
    self.consoleTableView.delegate=self;

    self.consoleScrollView=[[LoggerScrollView alloc] init];
    self.consoleScrollView.translatesAutoresizingMaskIntoConstraints=NO;
    self.consoleScrollView.borderType=NSBezelBorder;
    self.consoleScrollView.autohidesScrollers=YES;
    self.consoleScrollView.usesPredominantAxisScrolling=NO;
    self.consoleScrollView.contentView.drawsBackground=NO;
    self.consoleScrollView.documentView=self.consoleTableView;
    [contentView addSubview:self.consoleScrollView];

    NSButton *const clearButton=[NSButton buttonWithTitle:@"Clear" target:self action:@selector(clearLog:)];
    NSButton *const pauseCheckbox=[NSButton checkboxWithTitle:@"Pause" target:nil action:nil];
    [pauseCheckbox bind:NSValueBinding toObject:self withKeyPath:@"paused" options:nil];
    NSButton *const testWindowButton=[NSButton buttonWithTitle:@"Show Test Window" target:self action:@selector(showDemoWindow:)];
    for (NSButton *button in @[clearButton, pauseCheckbox, testWindowButton]) {
        button.translatesAutoresizingMaskIntoConstraints=NO;
        button.controlSize=NSControlSizeSmall;
        button.font=[NSFont systemFontOfSize:[NSFont systemFontSizeForControlSize:NSControlSizeSmall]];
        [contentView addSubview:button];
    }

    // the scroll view overhangs the window edges by 1pt to hide its border at the sides and top
    [NSLayoutConstraint activateConstraints:@[
        [self.consoleScrollView.topAnchor constraintEqualToAnchor:contentView.topAnchor constant:-1],
        [self.consoleScrollView.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:-1],
        [self.consoleScrollView.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:1],
        [clearButton.topAnchor constraintEqualToAnchor:self.consoleScrollView.bottomAnchor constant:5],
        [clearButton.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:7],
        [clearButton.bottomAnchor constraintEqualToAnchor:contentView.bottomAnchor constant:-5],
        [pauseCheckbox.leadingAnchor constraintEqualToAnchor:clearButton.trailingAnchor constant:6],
        [pauseCheckbox.bottomAnchor constraintEqualToAnchor:contentView.bottomAnchor constant:-8],
        [testWindowButton.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-7],
        [testWindowButton.bottomAnchor constraintEqualToAnchor:contentView.bottomAnchor constant:-5],
    ]];
}

- (void)observeLogEntriesChange:(NSNotification *)note
{
    NSIndexSet *const appendedIndexes=[note userInfo][LoggerEntriesAppended];
    NSIndexSet *const removedIndexes=[note userInfo][LoggerEntriesRemoved];

    if (removedIndexes) {
        [self.consoleTableView removeRowsAtIndexes:removedIndexes withAnimation:NSTableViewAnimationEffectNone];
    }
    else if (appendedIndexes) {
        [self.consoleTableView insertRowsAtIndexes:appendedIndexes withAnimation:NSTableViewAnimationEffectNone];
    }
    else {
         [self.consoleTableView reloadData];
    }
}

- (void)observeLogUpdatesWaiting:(NSNotification *)note
{
    if (self.window.isVisible && ![self.refreshTimer isValid]) {
        self.refreshTimer=[NSTimer scheduledTimerWithTimeInterval:0.05 target:self selector:@selector(updateConsole) userInfo:nil repeats:NO];
    }
}

- (void)showWindow:(id)sender
{
    [[self window] setLevel:NSFloatingWindowLevel];
    [[self window] setFrameAutosaveName:@"DebugWindow"];
    [[self window] center];
    [NSApp activateIgnoringOtherApps:YES];
    // small delay to prevent flash of window drawing
    dispatch_after(0.05, dispatch_get_main_queue(), ^{
        [super showWindow:sender];
    });
}

- (IBAction)clearLog:(id)sender {
    [self.logger clear];
    [self.appDelegate logAppEvent:@"Log cleared"];
}

- (IBAction)logState:(id)sender {
    [self.appDelegate logAppEvent:@"Settings"];
}

- (IBAction)showDemoWindow:(id)sender {
    [self.appDelegate showTestWindow:sender];
}

- (void)updateConsole
{
    [self.consoleTableView beginUpdates];
    [self.logger process];
    [self.consoleTableView endUpdates];
    [self scrollToBottom];
}

- (void)scrollToBottom
{
    const NSPoint newScrollOrigin=NSMakePoint(0.0,NSMaxY([[self.consoleScrollView documentView] frame])
                                              -NSHeight([[self.consoleScrollView contentView] bounds]));
    [[self.consoleScrollView documentView] scrollPoint:newScrollOrigin];
    
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (object==self && [keyPath isEqualToString:@"paused"]) {
        self.consoleScrollView.scrollingAllowed=self.paused;
        self.consoleScrollView.hasVerticalScroller=self.paused;
        self.consoleScrollView.hasHorizontalScroller=self.paused;
        if (self.paused) {
            [self.consoleScrollView flashScrollers];
        }
        else {
            [self.consoleTableView selectRowIndexes:[NSIndexSet indexSet] byExtendingSelection:NO];
        }
        [self.appDelegate logAppEvent:self.paused?@"Log paused":@"Log started"];
    }
}

- (AppDelegate *)appDelegate {
    return (AppDelegate *)[NSApp delegate];
}

#pragma mark pasteboard copy

- (void)copy:(id)sender
{
    NSMutableString *str=[@"" mutableCopy];
    [[self.consoleTableView selectedRowIndexes] enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
        [str appendString:[[self formatEntry:[self.logger entryAtIndex:idx]] string]];
        [str appendString:@"\n"];
    }];
    
    if ([str length]>0) {
        NSPasteboard *const pb = [NSPasteboard generalPasteboard];
        [pb clearContents];
        [pb writeObjects:@[str]];
    }
    
}

#pragma mark Table view delegate/datasource

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    return self.logger.entryCount;
}

- (NSAttributedString *)formatEntry:(NSDictionary *)entry
{
    NSMutableAttributedString *result=[[NSMutableAttributedString alloc] initWithString:@""];
    
    // data to log
    NSString *const messageString=entry[LoggerKeyMessage];
    const BOOL special=[entry[LoggerKeyType] isEqualToString:LoggerTypeSpecial];
    NSDate *const timestamp=entry[LoggerKeyTimestamp];
    
    if (timestamp) {
        NSDictionary *const dateAttributes=@{NSForegroundColorAttributeName: [NSColor grayColor]};
        NSString *const dateString=[[self.df stringFromDate:timestamp] stringByAppendingString:@" "];
        [result appendAttributedString:[[NSAttributedString alloc] initWithString:dateString
                                                                       attributes:dateAttributes]];
        
    }
    
    if (messageString) {
        NSDictionary *const messageAttributes=special?@{NSForegroundColorAttributeName: [NSColor blueColor]}:@{};
        [result appendAttributedString:[[NSAttributedString alloc] initWithString:messageString
                                                                       attributes:messageAttributes]];
    }
    
    return result;
}

- (NSView *)tableView:(NSTableView *)tableView
   viewForTableColumn:(NSTableColumn *)tableColumn
                  row:(NSInteger)row
{
    NSTableCellView *result=[tableView makeViewWithIdentifier:kLogCellIdentifier owner:self];
    if (!result) {
        result=[self makeLogCellView];
    }
    result.textField.attributedStringValue=[self formatEntry:[self.logger entryAtIndex:row]];
    return result;
}

- (NSTableCellView *)makeLogCellView
{
    NSTextField *const textField=[NSTextField labelWithString:@""];
    textField.translatesAutoresizingMaskIntoConstraints=NO;
    // keep each entry on one line, running off the edge rather than wrapping into the next row.
    // single line mode is needed because the attributed string's default paragraph style would otherwise wrap.
    textField.lineBreakMode=NSLineBreakByClipping;
    textField.usesSingleLineMode=YES;
    [textField setContentCompressionResistancePriority:NSLayoutPriorityDefaultLow forOrientation:NSLayoutConstraintOrientationHorizontal];

    NSTableCellView *const cellView=[[NSTableCellView alloc] init];
    cellView.identifier=kLogCellIdentifier;
    cellView.textField=textField;
    [cellView addSubview:textField];
    [NSLayoutConstraint activateConstraints:@[
        [textField.leadingAnchor constraintEqualToAnchor:cellView.leadingAnchor constant:3],
        [textField.trailingAnchor constraintEqualToAnchor:cellView.trailingAnchor],
        [textField.centerYAnchor constraintEqualToAnchor:cellView.centerYAnchor],
    ]];
    return cellView;
}

- (NSIndexSet *)tableView:(NSTableView *)tableView selectionIndexesForProposedSelection:(NSIndexSet *)proposedSelectionIndexes
{
    return self.paused?proposedSelectionIndexes:nil;
}

@end
