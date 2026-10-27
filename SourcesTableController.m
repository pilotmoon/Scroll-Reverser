// This file is part of Scroll Reverser <https://pilotmoon.com/scrollreverser/>
// Licensed under Apache License v2.0 <http://www.apache.org/licenses/LICENSE-2.0>

#import "SourcesTableController.h"
#import "SourceInfoViewController.h"
#import "SourceRow+Display.h"

static NSString *const kColumnIcon=@"icon";
static NSString *const kColumnName=@"name";
static NSString *const kColumnDirection=@"direction";
static NSString *const kColumnStepSize=@"stepSize";
static NSString *const kColumnLastUsed=@"lastUsed";
static NSString *const kColumnInfo=@"info";
// the direction column's cells differ by kind of source
static NSString *const kCellDirectionDevice=@"directionDevice";
static NSString *const kCellDirectionApp=@"directionApp";

// "Just now" for this long after a source last scrolled, then a relative time
static const CFTimeInterval kJustNowInterval=60;
static const NSTimeInterval kLastUsedRefreshInterval=10;

static void *_contextRows=&_contextRows;

static NSFont *_smallFont(void)
{
    return [NSFont systemFontOfSize:[NSFont smallSystemFontSize]];
}

static NSDictionary *_negated(void)
{
    return @{NSValueTransformerNameBindingOption: NSNegateBooleanTransformerName};
}

// Labels and images don't dim while disabled, as the controls beside them do, so fade them.
@interface DimmingLabel : NSTextField
@end

@implementation DimmingLabel

- (void)setEnabled:(BOOL)enabled
{
    [super setEnabled:enabled];
    self.alphaValue=enabled?1:0.5;
}

@end

@interface DimmingImageView : NSImageView
@end

@implementation DimmingImageView

- (void)setEnabled:(BOOL)enabled
{
    [super setEnabled:enabled];
    self.alphaValue=enabled?1:0.5;
}

@end

/* A row view that is tinted while its source is scrolling. It draws the tint itself rather than
 setting backgroundColor, which takes the selected style away from a selected row's pop-up menu.
 On a selected row, the selection is lightened (darkened in dark mode) instead, since it covers the
 background. */
@interface SourceRowView : NSTableRowView
@property (nonatomic) BOOL scrolling;
@end

@implementation SourceRowView

- (void)setScrolling:(BOOL)scrolling
{
    if (scrolling!=_scrolling) {
        _scrolling=scrolling;
        self.needsDisplay=YES;
    }
}

- (void)drawBackgroundInRect:(NSRect)dirtyRect
{
    [super drawBackgroundInRect:dirtyRect];
    if (self.scrolling) {
        [[[NSColor controlAccentColor] colorWithAlphaComponent:0.25] setFill];
        NSRectFillUsingOperation(self.bounds, NSCompositingOperationSourceOver);
    }
}

- (void)drawSelectionInRect:(NSRect)dirtyRect
{
    [super drawSelectionInRect:dirtyRect];
    if (self.scrolling) {
        const BOOL dark=[[self.effectiveAppearance bestMatchFromAppearancesWithNames:@[NSAppearanceNameAqua, NSAppearanceNameDarkAqua]] isEqualToString:NSAppearanceNameDarkAqua];
        [[NSColor colorWithWhite:dark?0:1 alpha:0.25] setFill];
        NSRectFillUsingOperation(self.bounds, NSCompositingOperationSourceOver);
    }
}

@end

static NSArray<SourceRow *> *_sortedByRecentUse(NSArray<SourceRow *> *rows)
{
    return [rows sortedArrayUsingComparator:^NSComparisonResult(SourceRow *a, SourceRow *b) {
        return [@(b.lastSeenTime) compare:@(a.lastSeenTime)];
    }];
}

@interface SourcesTableController ()
@property SourceTable *sourceTable;
@property NSMutableArray<SourceRow *> *rows; // in the order shown
@property NSTableView *tableView;
@property NSButton *removeButton;
@property NSTextField *placeholder;
@property NSView *view;
@property NSPopover *infoPopover;
@property NSTimer *lastUsedTimer;
@property NSRelativeDateTimeFormatter *dateFormatter;
@property BOOL visible;
@end

@implementation SourcesTableController

- (instancetype)initWithSourceTable:(SourceTable *)sourceTable
{
    self=[super init];
    if (self) {
        self.sourceTable=sourceTable;
        self.rows=[NSMutableArray array];
        self.dateFormatter=[[NSRelativeDateTimeFormatter alloc] init];
        self.dateFormatter.unitsStyle=NSRelativeDateTimeFormatterUnitsStyleShort;
        self.view=[self makeView];
    }
    return self;
}

- (void)dealloc
{
    [self windowWillClose];
}

- (NSView *)makeView
{
    NSTableView *const table=[[NSTableView alloc] init];
    table.style=NSTableViewStyleFullWidth;
    table.rowHeight=24;
    table.allowsMultipleSelection=NO;
    table.allowsColumnReordering=NO;
    // only the name column resizes, so it takes up any spare width
    table.columnAutoresizingStyle=NSTableViewUniformColumnAutoresizingStyle;
    // wide enough for the longest scrolling mode in the user's language
    NSPopUpButton *const widestPopUp=[self directionPopUpForCell:nil modes:@[@(ScrollDirectionModeNatural), @(ScrollDirectionModeClassic), @(ScrollDirectionModeUnchanged), @(ScrollDirectionModeReversed)]];
    const CGFloat directionWidth=MAX(104, ceil(widestPopUp.fittingSize.width)+8);
    CGFloat tableWidth=0;
    for (NSArray *definition in @[@[kColumnIcon, @"", @26],
                                  @[kColumnName, NSLocalizedString(@"Source", @"Sources table column header: the device or app that scrolls"), @240],
                                  @[kColumnDirection, NSLocalizedString(@"Scrolling", @"Preferences pane for `Scrolling` settings; also the sources table column header for natural or classic scrolling"), @(directionWidth)],
                                  @[kColumnStepSize, NSLocalizedString(@"Step size", @"Sources table column header: scroll wheel step size"), @96],
                                  @[kColumnLastUsed, NSLocalizedString(@"Last used", @"Sources table column header: when the source last scrolled"), @100],
                                  @[kColumnInfo, @"", @24]]) {
        NSTableColumn *const column=[[NSTableColumn alloc] initWithIdentifier:definition[0]];
        column.title=definition[1];
        // and wide enough for its header in the user's language
        column.width=MAX([definition[2] doubleValue], ceil(column.headerCell.cellSize.width)+12);
        const BOOL nameColumn=[column.identifier isEqualToString:kColumnName];
        column.resizingMask=nameColumn?NSTableColumnAutoresizingMask:NSTableColumnNoResizing;
        if (!nameColumn) {
            column.headerCell.alignment=NSTextAlignmentCenter;
        }
        [table addTableColumn:column];
        tableWidth+=column.width+table.intercellSpacing.width;
    }
    table.dataSource=self;
    table.delegate=self;
    self.tableView=table;

    NSScrollView *const scrollView=[[NSScrollView alloc] init];
    scrollView.translatesAutoresizingMaskIntoConstraints=NO;
    scrollView.documentView=table;
    scrollView.hasVerticalScroller=YES;
    scrollView.autohidesScrollers=YES;
    scrollView.borderType=NSBezelBorder;

    self.removeButton=[NSButton buttonWithImage:[NSImage imageNamed:NSImageNameRemoveTemplate] target:self action:@selector(removeClicked:)];
    self.removeButton.translatesAutoresizingMaskIntoConstraints=NO;
    self.removeButton.bezelStyle=NSBezelStyleSmallSquare;
    self.removeButton.toolTip=NSLocalizedString(@"Remove the selected source. It will be added again if it scrolls.", @"Tooltip for the button below the sources table");
    self.removeButton.enabled=NO;

    // shown while there are no rows, as on first run
    self.placeholder=[DimmingLabel wrappingLabelWithString:NSLocalizedString(@"Start scrolling to see your devices here.", @"Shown in the empty sources table, which fills with devices and apps as they scroll")];
    self.placeholder.translatesAutoresizingMaskIntoConstraints=NO;
    self.placeholder.alignment=NSTextAlignmentCenter;
    self.placeholder.textColor=[NSColor secondaryLabelColor];
    self.placeholder.hidden=YES;
    [self.placeholder bind:NSEnabledBinding toObject:self withKeyPath:@"enabled" options:nil];

    NSView *const view=[[NSView alloc] init];
    view.translatesAutoresizingMaskIntoConstraints=NO;
    for (NSView *subview in @[scrollView, self.removeButton, self.placeholder]) {
        [view addSubview:subview];
    }
    // the area below the header, where the rows go (the clip view extends under the header)
    NSLayoutGuide *const rowsArea=[[NSLayoutGuide alloc] init];
    [view addLayoutGuide:rowsArea];
    [NSLayoutConstraint activateConstraints:@[
        [rowsArea.topAnchor constraintEqualToAnchor:table.headerView.bottomAnchor],
        [rowsArea.bottomAnchor constraintEqualToAnchor:scrollView.bottomAnchor],
        [scrollView.topAnchor constraintEqualToAnchor:view.topAnchor],
        [scrollView.leadingAnchor constraintEqualToAnchor:view.leadingAnchor],
        [view.trailingAnchor constraintEqualToAnchor:scrollView.trailingAnchor],
        [scrollView.widthAnchor constraintGreaterThanOrEqualToConstant:tableWidth+2],
        [scrollView.heightAnchor constraintEqualToConstant:200],
        [self.removeButton.topAnchor constraintEqualToAnchor:scrollView.bottomAnchor constant:-1],
        [self.removeButton.leadingAnchor constraintEqualToAnchor:view.leadingAnchor],
        [self.removeButton.widthAnchor constraintEqualToConstant:24],
        [self.removeButton.heightAnchor constraintEqualToConstant:22],
        [view.bottomAnchor constraintEqualToAnchor:self.removeButton.bottomAnchor],
        [self.placeholder.centerXAnchor constraintEqualToAnchor:scrollView.centerXAnchor],
        [self.placeholder.centerYAnchor constraintEqualToAnchor:rowsArea.centerYAnchor],
        [self.placeholder.widthAnchor constraintLessThanOrEqualToAnchor:scrollView.widthAnchor constant:-40],
    ]];
    return view;
}

#pragma mark Window

- (void)windowWillShow
{
    if (self.visible) {
        return;
    }
    self.visible=YES;
    [self.rows setArray:_sortedByRecentUse(self.sourceTable.rows)];
    [self.tableView deselectAll:nil];
    [self.tableView reloadData];
    [self updatePlaceholder];

    [self.sourceTable addObserver:self forKeyPath:@"rows" options:0 context:_contextRows];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(rowDidStartScrolling:) name:SourceRowDidStartScrollingNotification object:nil];
    self.lastUsedTimer=[NSTimer timerWithTimeInterval:kLastUsedRefreshInterval target:self selector:@selector(lastUsedTimerFired:) userInfo:nil repeats:YES];
    self.lastUsedTimer.tolerance=1;
    [[NSRunLoop mainRunLoop] addTimer:self.lastUsedTimer forMode:NSRunLoopCommonModes];
}

- (void)windowWillClose
{
    if (!self.visible) {
        return;
    }
    self.visible=NO;
    [self.sourceTable removeObserver:self forKeyPath:@"rows" context:_contextRows];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:SourceRowDidStartScrollingNotification object:nil];
    [self.lastUsedTimer invalidate];
    self.lastUsedTimer=nil;
    [self.infoPopover close];
}

#pragma mark Keeping up to date

// New rows are added at the top, and removed rows go.
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context
{
    if (context!=_contextRows) {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
        return;
    }
    NSArray<SourceRow *> *const current=self.sourceTable.rows;
    NSIndexSet *const removed=[self.rows indexesOfObjectsPassingTest:^BOOL(SourceRow *row, NSUInteger idx, BOOL *stop) {
        return [current indexOfObjectIdenticalTo:row]==NSNotFound;
    }];
    SourceRow *const infoRow=((SourceInfoViewController *)self.infoPopover.contentViewController).row;
    if (infoRow&&[current indexOfObjectIdenticalTo:infoRow]==NSNotFound) {
        [self.infoPopover close];
    }
    if ([removed count]) {
        [self.rows removeObjectsAtIndexes:removed];
        [self.tableView removeRowsAtIndexes:removed withAnimation:NSTableViewAnimationEffectFade];
    }
    for (SourceRow *row in current) {
        if ([self.rows indexOfObjectIdenticalTo:row]==NSNotFound) {
            [self.rows insertObject:row atIndex:0];
            // Not faded in: in a window that isn't on screen, the fade can stop short and leave the row invisible.
            [self.tableView insertRowsAtIndexes:[NSIndexSet indexSetWithIndex:0] withAnimation:NSTableViewAnimationEffectNone];
        }
    }
    [self updatePlaceholder];
}

- (void)updatePlaceholder
{
    self.placeholder.hidden=[self.rows count]>0;
}

// A source that starts scrolling moves to the top, by moving its row so that the selection follows it,
// and is highlighted until it stops.
- (void)rowDidStartScrolling:(NSNotification *)notification
{
    SourceRow *const row=notification.object;
    const NSUInteger index=[self.rows indexOfObjectIdenticalTo:row];
    if (index==NSNotFound) {
        return;
    }
    if (index>0) {
        [self.rows removeObjectAtIndex:index];
        [self.rows insertObject:row atIndex:0];
        [self.tableView moveRowAtIndex:index toIndex:0];
    }
    [self updateRowAtIndex:0];
    [self scheduleUpdateForRow:row];
}

// Update the row when it stops scrolling. Events keep arriving meanwhile, so look again then.
- (void)scheduleUpdateForRow:(SourceRow *)row
{
    const CFTimeInterval delay=MAX(row.lastSeenTime+SourceRowScrollingInterval-CFAbsoluteTimeGetCurrent(), 0.01);
    __weak SourcesTableController *const weakSelf=self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay*NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        SourcesTableController *const strongSelf=weakSelf;
        const NSUInteger index=[strongSelf.rows indexOfObjectIdenticalTo:row];
        if (!strongSelf.visible||index==NSNotFound) {
            return;
        }
        [strongSelf updateRowAtIndex:index];
        if (row.scrolling) {
            [strongSelf scheduleUpdateForRow:row];
        }
    });
}

- (void)lastUsedTimerFired:(NSTimer *)timer
{
    [self.tableView enumerateAvailableRowViewsUsingBlock:^(NSTableRowView *rowView, NSInteger index) {
        [self updateRowAtIndex:index];
    }];
}

// The highlight and Last used time, which change with time rather than by observation.
- (void)updateRowAtIndex:(NSInteger)index
{
    SourceRowView *const rowView=[self.tableView rowViewAtRow:index makeIfNecessary:NO];
    [self updateRowView:rowView forRow:self.rows[index]];
}

- (void)updateRowView:(SourceRowView *)rowView forRow:(SourceRow *)row
{
    rowView.scrolling=row.scrolling;
    NSTableCellView *const lastUsedCell=[rowView viewAtColumn:[self.tableView columnWithIdentifier:kColumnLastUsed]];
    lastUsedCell.textField.stringValue=[self lastUsedStringForRow:row];
}

- (NSString *)lastUsedStringForRow:(SourceRow *)row
{
    if (CFAbsoluteTimeGetCurrent()-row.lastSeenTime<kJustNowInterval) {
        return NSLocalizedString(@"Just now", @"Sources table: the source scrolled within the last minute");
    }
    return [self.dateFormatter localizedStringForDate:row.lastSeen relativeToDate:[NSDate date]];
}

#pragma mark Actions

- (void)setEnabled:(BOOL)enabled
{
    _enabled=enabled;
    // its settings were enabled or not when it opened
    [self.infoPopover close];
}

- (void)infoClicked:(NSButton *)sender
{
    const NSInteger index=[self.tableView rowForView:sender];
    if (index<0) {
        return;
    }
    [self.infoPopover close];
    self.infoPopover=[[NSPopover alloc] init];
    self.infoPopover.behavior=NSPopoverBehaviorTransient;
    self.infoPopover.contentViewController=[[SourceInfoViewController alloc] initWithRow:self.rows[index] editable:self.enabled];
    [self.infoPopover showRelativeToRect:sender.bounds ofView:sender preferredEdge:NSRectEdgeMaxX];
}

- (void)removeClicked:(id)sender
{
    const NSInteger index=self.tableView.selectedRow;
    if (index>=0) {
        [self.sourceTable removeRow:self.rows[index]];
    }
}

#pragma mark Table data source and delegate

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    return [self.rows count];
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    return self.rows[row];
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification
{
    // removing works whether or not reversing is on
    self.removeButton.enabled=self.tableView.selectedRow>=0;
}

- (NSTableRowView *)tableView:(NSTableView *)tableView rowViewForRow:(NSInteger)row
{
    return [[SourceRowView alloc] init];
}

- (void)tableView:(NSTableView *)tableView didAddRowView:(SourceRowView *)rowView forRow:(NSInteger)row
{
    [self updateRowView:rowView forRow:self.rows[row]];
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)rowIndex
{
    SourceRow *const row=self.rows[rowIndex];
    NSString *identifier=tableColumn.identifier;
    if ([identifier isEqualToString:kColumnDirection]) {
        identifier=row.hasDeviceDirection?kCellDirectionDevice:kCellDirectionApp;
    }
    NSTableCellView *const cell=[tableView makeViewWithIdentifier:identifier owner:self]?:[self makeCellWithIdentifier:identifier];
    if ([identifier isEqualToString:kColumnIcon]) {
        cell.imageView.image=row.icon;
    }
    return cell;
}

#pragma mark Cells

// Cells show their row, as their object value, mostly through bindings.
- (NSTableCellView *)makeCellWithIdentifier:(NSString *)identifier
{
    NSTableCellView *const cell=[[NSTableCellView alloc] init];
    cell.identifier=identifier;
    NSView *content;
    if ([identifier isEqualToString:kColumnIcon]) {
        NSImageView *const imageView=[[DimmingImageView alloc] init];
        imageView.imageScaling=NSImageScaleNone;
        [imageView.widthAnchor constraintEqualToConstant:22].active=YES;
        [imageView.heightAnchor constraintEqualToConstant:18].active=YES;
        cell.imageView=imageView;
        content=imageView;
    }
    else if ([identifier isEqualToString:kColumnName]) {
        NSTextField *const field=[DimmingLabel labelWithString:@""];
        field.lineBreakMode=NSLineBreakByTruncatingTail;
        field.cell.usesSingleLineMode=YES;
        [field bind:NSValueBinding toObject:cell withKeyPath:@"objectValue.displayName" options:nil];
        // the full name, for when it's truncated
        [field bind:NSToolTipBinding toObject:cell withKeyPath:@"objectValue.displayName" options:nil];
        cell.textField=field;
        content=field;
    }
    else if ([identifier isEqualToString:kCellDirectionDevice]) {
        content=[self directionPopUpForCell:cell modes:@[@(ScrollDirectionModeNatural), @(ScrollDirectionModeClassic), @(ScrollDirectionModeUnchanged)]];
    }
    else if ([identifier isEqualToString:kCellDirectionApp]) {
        // an app chooses its own direction, so all we can do is reverse it
        content=[self directionPopUpForCell:cell modes:@[@(ScrollDirectionModeReversed), @(ScrollDirectionModeUnchanged)]];
    }
    else if ([identifier isEqualToString:kColumnStepSize]) {
        content=[self stepSizeViewForCell:cell];
    }
    else if ([identifier isEqualToString:kColumnLastUsed]) {
        NSTextField *const field=[DimmingLabel labelWithString:@""];
        field.font=_smallFont();
        field.textColor=[NSColor secondaryLabelColor];
        field.lineBreakMode=NSLineBreakByTruncatingTail;
        cell.textField=field;
        content=field;
    }
    else if ([identifier isEqualToString:kColumnInfo]) {
        NSButton *const button=[NSButton buttonWithImage:[NSImage imageWithSystemSymbolName:@"gearshape" accessibilityDescription:NSLocalizedString(@"Details", @"Accessibility label of the button that shows a source's details")] target:self action:@selector(infoClicked:)];
        button.bordered=NO;
        button.toolTip=NSLocalizedString(@"Details and horizontal scrolling", @"Tooltip of the button that shows a source's details");
        content=button;
    }

    if (![identifier isEqualToString:kColumnInfo]) {
        [self bindEnabledOfControlsInView:content];
    }
    content.translatesAutoresizingMaskIntoConstraints=NO;
    [cell addSubview:content];
    const BOOL leading=[identifier isEqualToString:kColumnName];
    [NSLayoutConstraint activateConstraints:@[
        [content.centerYAnchor constraintEqualToAnchor:cell.centerYAnchor],
        leading?[content.leadingAnchor constraintEqualToAnchor:cell.leadingAnchor constant:2]:[content.centerXAnchor constraintEqualToAnchor:cell.centerXAnchor],
        leading?[cell.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:2]:[cell.trailingAnchor constraintGreaterThanOrEqualToAnchor:content.trailingAnchor],
    ]];
    return cell;
}

// Controls are enabled only while reversing is on, as well as by any enabled binding they already have.
- (void)bindEnabledOfControlsInView:(NSView *)view
{
    if ([view isKindOfClass:[NSControl class]]) {
        NSString *const binding=[view infoForBinding:NSEnabledBinding]?@"enabled2":NSEnabledBinding;
        [view bind:binding toObject:self withKeyPath:@"enabled" options:nil];
    }
    for (NSView *subview in view.subviews) {
        [self bindEnabledOfControlsInView:subview];
    }
}

// The cell may be nil, for measuring.
- (NSPopUpButton *)directionPopUpForCell:(NSTableCellView *)cell modes:(NSArray<NSNumber *> *)modes
{
    NSPopUpButton *const popUp=[[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
    popUp.controlSize=NSControlSizeSmall;
    popUp.font=_smallFont();
    for (NSNumber *mode in modes) {
        [popUp addItemWithTitle:SourceDirectionModeTitle([mode integerValue])];
        popUp.lastItem.tag=[mode integerValue];
    }
    if (cell) {
        [popUp bind:NSSelectedTagBinding toObject:cell withKeyPath:@"objectValue.verticalMode" options:nil];
    }
    return popUp;
}

// A checkbox, number field and stepper, or "Continuous" for a source with no steps to size.
- (NSView *)stepSizeViewForCell:(NSTableCellView *)cell
{
    NSButton *const checkbox=[NSButton checkboxWithTitle:@"" target:nil action:nil];
    checkbox.accessibilityLabel=NSLocalizedString(@"Step size", @"Sources table column header: scroll wheel step size");
    [checkbox bind:NSValueBinding toObject:cell withKeyPath:@"objectValue.stepSizeEnabled" options:nil];

    NSNumberFormatter *const formatter=[[NSNumberFormatter alloc] init];
    formatter.allowsFloats=NO;
    formatter.minimum=@(SourceRowMinStepSize);
    formatter.maximum=@(SourceRowMaxStepSize);
    NSTextField *const field=[NSTextField textFieldWithString:@""];
    field.formatter=formatter;
    field.alignment=NSTextAlignmentRight;
    field.controlSize=NSControlSizeSmall;
    field.font=_smallFont();
    [field.widthAnchor constraintEqualToConstant:30].active=YES;
    [field bind:NSValueBinding toObject:cell withKeyPath:@"objectValue.stepSize" options:@{NSValidatesImmediatelyBindingOption: @YES}];

    NSStepper *const stepper=[[NSStepper alloc] init];
    stepper.controlSize=NSControlSizeSmall;
    stepper.minValue=SourceRowMinStepSize;
    stepper.maxValue=SourceRowMaxStepSize;
    stepper.increment=1;
    stepper.valueWraps=NO;
    [stepper bind:NSValueBinding toObject:cell withKeyPath:@"objectValue.stepSize" options:nil];

    for (NSControl *control in @[field, stepper]) {
        [control bind:NSEnabledBinding toObject:cell withKeyPath:@"objectValue.stepSizeEnabled" options:nil];
    }
    NSStackView *const controls=[NSStackView stackViewWithViews:@[checkbox, field, stepper]];
    controls.spacing=4;
    [controls setCustomSpacing:0 afterView:field];
    [controls bind:NSHiddenBinding toObject:cell withKeyPath:@"objectValue.continuous" options:nil];

    NSTextField *const continuousLabel=[DimmingLabel labelWithString:NSLocalizedString(@"Continuous", @"Scrolling type of a source that scrolls continuously, like a trackpad")];
    continuousLabel.font=_smallFont();
    continuousLabel.textColor=[NSColor secondaryLabelColor];
    [continuousLabel bind:NSHiddenBinding toObject:cell withKeyPath:@"objectValue.continuous" options:_negated()];

    return [NSStackView stackViewWithViews:@[controls, continuousLabel]];
}

@end
