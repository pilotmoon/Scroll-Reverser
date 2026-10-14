// This file is part of Scroll Reverser <https://pilotmoon.com/scrollreverser/>
// Licensed under Apache License v2.0 <http://www.apache.org/licenses/LICENSE-2.0>

#import "PrefsWindowController.h"
#import "AppDelegate.h"
#import "LinkView.h"


static NSString *const kPanelScrolling=@"scrolling";
static NSString *const kPanelApp=@"app";

static NSString *const kKeyView=@"view";
static NSString *const kKeyTitle=@"title";
static NSString *const kKeyImageName=@"image";

static NSString *const kPrefsToolbarIdentifer=@"PrefsToolbar";
static NSString *const kPrefsLastUsedPanel=@"PrefsLastUsedPanel";


static void *_contextPermissions=&_contextPermissions;


// a label that dims while disabled, to match the controls beside it
@interface DimmingLabel : NSTextField
@end

@implementation DimmingLabel

- (void)setEnabled:(BOOL)enabled
{
    [super setEnabled:enabled];
    self.textColor=enabled?[NSColor labelColor]:[NSColor disabledControlTextColor];
}

@end


@interface PrefsWindowController ()
@property NSTabView *tabView;
@property NSToolbar *toolbar;
@property NSDictionary *panels;
@property CGFloat width;
@property NSView *scrollingSettings;
@property NSView *appSettings;
@property NSTextField *axStatusLabel;
@property NSButton *axButton;
@property NSTextField *imStatusLabel;
@property NSButton *imButton;
@end

@implementation PrefsWindowController

#pragma mark Updater

- (SPUUpdater *)updater
{
    return ((AppDelegate *)[NSApp delegate]).updater;
}

- (IBAction)buttonCheckForUpdatesClicked:(id)sender
{    
    [self.updater checkForUpdates];
}

#pragma mark Window showing

// animate window frame to draw user's attention
- (void)callAttention
{
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC*0.05), dispatch_get_main_queue(), ^{
        const NSRect frame = [self.window frame];
        const float offset = 0.04 * frame.size.height;
        [NSAnimationContext currentContext].duration = 0.08;
        [NSAnimationContext runAnimationGroup:^(NSAnimationContext * _Nonnull context) {
            [[self.window animator] setFrame:NSMakeRect(frame.origin.x, frame.origin.y+offset, frame.size.width, frame.size.height)
                                     display:NO];
        } completionHandler:^{
            [NSAnimationContext runAnimationGroup:^(NSAnimationContext * _Nonnull context) {
                [[self.window animator] setFrame:frame display:NO];
            }];
        }];
    });
}

- (instancetype)init
{
    NSWindow *const window=[[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 480, 270)
                                                       styleMask:NSWindowStyleMaskTitled|NSWindowStyleMaskClosable|NSWindowStyleMaskMiniaturizable
                                                         backing:NSBackingStoreBuffered
                                                           defer:YES];
    window.releasedWhenClosed=NO;

    self=[super initWithWindow:window];
    if (self) {
        window.title=self.appDelegate.appName;
        window.delegate=self;
        self.scrollingSettings=[self makeScrollingSettings];
        self.appSettings=[self makeAppSettings];

        // fill in the permission labels before the panes are measured, and keep them up to date
        for (NSString *keyPath in @[PermissionsManagerKeyAccessibilityEnabled, PermissionsManagerKeyInputMonitoringEnabled, @"inputMonitoringRequested"]) {
            [self.appDelegate.permissionsManager addObserver:self forKeyPath:keyPath options:NSKeyValueObservingOptionInitial context:_contextPermissions];
        }
        [self setUpPanels];
    }
    return self;
}

- (void)setUpPanels
{
    self.width=400; // minimum width to avoid toolbar collapse
    
    NSArray *const toolbarDefinition=@[kPanelScrolling, kPanelApp];
    NSDictionary *const panelsDefinition=@{kPanelScrolling: @{kKeyView: self.scrollingSettings,
                                                              kKeyTitle: NSLocalizedString(@"Scrolling", @"Preferences pane for `Scrolling` serttings"),
                                                              kKeyImageName: NSImageNamePreferencesGeneral},
                                           kPanelApp: @{kKeyView: self.appSettings,
                                                        kKeyTitle: NSLocalizedString(@"App", @"Preferences pane for `App` settings"),
                                                        kKeyImageName: NSImageNameApplicationIcon}};
    
    // set up tab view
    self.tabView=[[NSTabView alloc] initWithFrame:[(NSView *)[self.window contentView] frame]];
    [self.tabView setAutoresizingMask:NSViewWidthSizable|NSViewHeightSizable];
    [self.tabView setTabViewType:NSNoTabsNoBorder];
    [self.tabView setDelegate:self];
    [[self.window contentView] addSubview:self.tabView];
    
    // set up panels
    self.panels=[NSMutableDictionary dictionary];
    for(NSString *key in [panelsDefinition allKeys]) {
        // make mutable copy of definition
        NSMutableDictionary *panelData=[panelsDefinition[key] mutableCopy];
        
        // get the view
        NSView *view=panelData[kKeyView];
        
        // create tab view item
        NSTabViewItem *tabViewItem=[[NSTabViewItem alloc] initWithIdentifier:key];
        [tabViewItem setLabel:panelData[kKeyTitle]];
        [tabViewItem setView:view];
        
        // save to panels dict
        const NSSize size=[view fittingSize];

        // set window width to largest view fitting width
        self.width=MAX(self.width, size.width);
        ((NSMutableDictionary *)self.panels)[key] = panelData;
        
        // add to tab bar
        [self.tabView addTabViewItem:tabViewItem];
    }

    // set up toolbar
    self.toolbar = [[NSToolbar alloc] initWithIdentifier:kPrefsToolbarIdentifer];
    [self.toolbar setAllowsUserCustomization:NO];
    [self.toolbar setAutosavesConfiguration:NO];
    [self.toolbar setDisplayMode:NSToolbarDisplayModeIconAndLabel];
    [self.toolbar setDelegate:self];
    [self.window setToolbar:self.toolbar];
    [toolbarDefinition enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        [self.toolbar insertItemWithItemIdentifier:obj atIndex:idx];
    }];
    
    // identify the starting pane
    NSString *startingIdentifier=[[NSUserDefaults standardUserDefaults] stringForKey:kPrefsLastUsedPanel];
    if(!startingIdentifier||
       ![[self.panels allKeys] containsObject:startingIdentifier]||
       ![toolbarDefinition containsObject:startingIdentifier])
    {
        startingIdentifier=[toolbarDefinition firstObject];
    }
    

    // select the initial pane
    [self.tabView selectTabViewItemWithIdentifier:startingIdentifier];
    [self.toolbar setSelectedItemIdentifier:startingIdentifier];
    [self updateWindowForIdentifier:startingIdentifier];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context
{
    if (context==_contextPermissions) {
        [self updatePermissionLabels];
    }
}

- (void)showWindow:(id)sender
{
    self.window.delegate=self;
    self.window.level=NSNormalWindowLevel;
    if (![NSApp isActive]) {
        [NSApp activateIgnoringOtherApps:YES];
    }
    const BOOL wasVisible=self.window.visible;
    if (wasVisible) {
        [self callAttention];
    }
    else {
        [self.window center];
    }
    [super showWindow:sender];
    if (!wasVisible) {
        // don't start with the step size field focused
        [self.window makeFirstResponder:nil];
    }
}

- (void)setPane:(NSString *)identifier
{
    // select the appropriate tab view item
    [self.tabView selectTabViewItemWithIdentifier:identifier];
    [self.toolbar setSelectedItemIdentifier:identifier];
    
    // save this as the last used panel
    [[NSUserDefaults standardUserDefaults] setObject:identifier forKey:kPrefsLastUsedPanel];
}

// Futz about with the geometry
- (void)updateWindowForIdentifier:(NSString *)identifier
{
    // set the width to our pre-stored width, and the height to fit the pane, keeping the top edge in place.
    // autolayout then keeps the height fitted as parts of the pane are shown and hidden.
    NSView *const pane=[[self.tabView tabViewItemAtIndex:[self.tabView indexOfTabViewItemWithIdentifier:identifier]] view];
    NSRect frame=[self.window frame];
    const CGFloat chromeHeight=NSHeight(frame)-NSHeight([[self.window contentView] frame]);
    const CGFloat height=[pane fittingSize].height+chromeHeight;
    frame.origin.y+=NSHeight(frame)-height;
    frame.size.height=height;
    frame.size.width=self.width;
    [self.window setFrame:frame display:YES animate:NO];
}

#pragma mark Permissions

- (void)showPermissionsPane {
    [self setPane:kPanelScrolling];
}

- (IBAction)buttonAXClicked:(id)sender {
    if (self.appDelegate.permissionsManager.accessibilityEnabled) {
        [self.appDelegate.permissionsManager openAccessibilityPrefs];
    }
    else {
        [self.appDelegate.permissionsManager requestAccessibilityPermission];
    }
}

- (IBAction)buttonIMClicked:(id)sender {
    if (self.appDelegate.permissionsManager.inputMonitoringRequested) {
        [self.appDelegate.permissionsManager openInputMonitoringPrefs];
    }
    else {
        [self.appDelegate.permissionsManager requestInputMonitoringPermission];
    }
}

- (IBAction)buttonPermissionsHelpClicked:(id)sender {
    NSLog(@"Permissions help clicked %@", sender);
    [[NSWorkspace sharedWorkspace] openURL:self.appDelegate.appPermissionsHelpLink];
}

#pragma mark Toolbar Delegate methods

// Called when a toolbar button is clicked, to effect the pane switch
- (void)toolbarItemClicked:(id)sender
{
    [self setPane:[[self.tabView tabViewItemAtIndex:[sender tag]] identifier]];
}

// This is where we actually create the toolbar item.
- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)identifier willBeInsertedIntoToolbar:(BOOL)flag
{
    NSDictionary *const panelInfo=(self.panels)[identifier];
    
    // Set up the toolbar item
    NSToolbarItem *const toolbarItem=[[NSToolbarItem alloc] initWithItemIdentifier:identifier];
    [toolbarItem setTarget:self];
    [toolbarItem setAction:@selector(toolbarItemClicked:)];
    [toolbarItem setImage:[NSImage imageNamed:panelInfo[kKeyImageName]]];
    [toolbarItem setLabel:panelInfo[kKeyTitle]];
    
    // We use the tag to record the index of the corresponding tab view
    [toolbarItem setTag:[self.tabView indexOfTabViewItemWithIdentifier:identifier]];
    
    return toolbarItem;
}

- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar*)toolbar
{
    return @[];
}

- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar*)toolbar
{
    return [self.panels allKeys];
}

- (NSArray *)toolbarSelectableItemIdentifiers:(NSToolbar *)toolbar
{
    return [self.panels allKeys];
}

#pragma mark Tab view delegate methods

- (void)tabView:(NSTabView *)aTabView didSelectTabViewItem:(NSTabViewItem *)tabViewItem
{
    [self updateWindowForIdentifier:[tabViewItem identifier]];
}

#pragma mark Dynamic labels

- (NSString *)buttonLabel:(BOOL)open label:(NSString *)label
{
    if (open) {
        return [NSString stringWithFormat: NSLocalizedString(@"Open %1$@ preferences", @"1=`Input Monitoring` or `Accessibility`"), label];
    }
    else {
        return [NSString stringWithFormat: NSLocalizedString(@"Request %1$@ permission", @"1=`Input Monitoring` or `Accessibility`"), label];
    }
}

- (void)updatePermissionLabels
{
    PermissionsManager *const permissions=self.appDelegate.permissionsManager;
    NSString *const ax=NSLocalizedString(@"Accessibility", @"corresponds to Accessibility in system Privacy settings");
    NSString *const im=NSLocalizedString(@"Input Monitoring", @"corresponds to Input Monitoring in system Privacy settings");
    self.axStatusLabel.stringValue=[self statusString:permissions.accessibilityEnabled label:ax];
    self.axButton.title=[self buttonLabel:permissions.accessibilityEnabled label:ax];
    self.imStatusLabel.stringValue=[self statusString:permissions.inputMonitoringEnabled label:im];
    self.imButton.title=[self buttonLabel:permissions.inputMonitoringRequested label:im];
}

- (NSString *)statusString:(BOOL)state label:(NSString *)label
{
    return [NSString stringWithFormat:NSLocalizedString(@"%1$@ permission: %2$@", "for example: `Accessibility permission: ⛔️ required`"), label, state ?
            NSLocalizedString(@"✅ granted", nil) :
            NSLocalizedString(@"⛔️ required", nil)];
}

#pragma mark Accessors

- (AppDelegate *)appDelegate
{
    return (AppDelegate *)[[NSApplication sharedApplication] delegate];
}

#pragma mark Control helpers

static NSString *defaultsKeyPath(NSString *key)
{
    return [@"values." stringByAppendingString:key];
}

static NSDictionary *negated(void)
{
    return @{NSValueTransformerNameBindingOption: NSNegateBooleanTransformerName};
}

static NSButton *checkbox(NSString *title)
{
    NSButton *const button=[NSButton checkboxWithTitle:title target:nil action:nil];
    button.translatesAutoresizingMaskIntoConstraints=NO;
    return button;
}

// checkboxes in the scrolling pane are slightly shorter than their natural height
static NSButton *compactCheckbox(NSString *title)
{
    NSButton *const button=checkbox(title);
    [button.heightAnchor constraintEqualToConstant:14].active=YES;
    return button;
}

static NSButton *smallCheckbox(NSString *title)
{
    NSButton *const button=checkbox(title);
    button.controlSize=NSControlSizeSmall;
    button.font=[NSFont messageFontOfSize:11];
    [button setContentHuggingPriority:NSLayoutPriorityDefaultHigh forOrientation:NSLayoutConstraintOrientationHorizontal];
    [button setContentHuggingPriority:NSLayoutPriorityDefaultLow-1 forOrientation:NSLayoutConstraintOrientationVertical];
    [button setContentCompressionResistancePriority:NSLayoutPriorityRequired forOrientation:NSLayoutConstraintOrientationVertical];
    return button;
}

static NSTextField *label(NSTextField *field, NSFont *font, NSColor *color)
{
    field.translatesAutoresizingMaskIntoConstraints=NO;
    field.font=font;
    field.textColor=color;
    return field;
}

static NSFont *smallFont(void)
{
    return [NSFont systemFontOfSize:[NSFont smallSystemFontSize]];
}

static NSBox *box(NSString *title)
{
    NSBox *const box=[[NSBox alloc] init];
    box.translatesAutoresizingMaskIntoConstraints=NO;
    box.title=title;
    box.contentViewMargins=NSZeroSize;
    return box;
}

static NSStackView *stack(NSUserInterfaceLayoutOrientation orientation, NSLayoutAttribute alignment, CGFloat spacing, NSArray<NSView *> *views)
{
    NSStackView *const stack=[NSStackView stackViewWithViews:views];
    stack.translatesAutoresizingMaskIntoConstraints=NO;
    stack.orientation=orientation;
    stack.distribution=NSStackViewDistributionFill;
    stack.alignment=alignment;
    stack.spacing=spacing;
    stack.detachesHiddenViews=YES;
    return stack;
}

#pragma mark Scrolling pane

- (NSView *)makeScrollingSettings
{
    AppDelegate *const appDelegate=self.appDelegate;
    PermissionsManager *const permissions=appDelegate.permissionsManager;
    NSUserDefaultsController *const defaults=[NSUserDefaultsController sharedUserDefaultsController];

    // master switch
    NSButton *const enableCheckbox=compactCheckbox([NSString stringWithFormat:NSLocalizedString(@"Enable %1$@", @"1=name of app e.g. `Enable Scroll Reverser`"), appDelegate.appName]);
    [enableCheckbox bind:NSValueBinding toObject:appDelegate withKeyPath:@"enabled" options:@{NSValidatesImmediatelyBindingOption: @YES}];
    [enableCheckbox bind:NSHiddenBinding toObject:permissions withKeyPath:PermissionsManagerKeyHasAllRequiredPermissions options:negated()];

    // axes and devices, side by side
    NSBox *const axesBox=[self boxWithTitle:NSLocalizedString(@"Scrolling Axes", @"Prefs section title")
                                 checkboxes:@[@[NSLocalizedString(@"Reverse Vertical", @"Prefs check box"), PrefsReverseVertical],
                                              @[NSLocalizedString(@"Reverse Horizontal", @"Prefs check box"), PrefsReverseHorizontal]]];
    NSBox *const devicesBox=[self boxWithTitle:NSLocalizedString(@"Scrolling Devices", @"Prefs section title")
                                    checkboxes:@[@[NSLocalizedString(@"Reverse Trackpad", @"Prefs check box"), PrefsReverseTrackpad],
                                                 @[NSLocalizedString(@"Reverse Mouse", @"Prefs check box"), PrefsReverseMouse]]];
    NSStackView *const axesAndDevices=stack(NSUserInterfaceLayoutOrientationHorizontal, NSLayoutAttributeTop, 8, @[axesBox, devicesBox]);
    [axesAndDevices setHuggingPriority:NSLayoutPriorityDefaultHigh forOrientation:NSLayoutConstraintOrientationVertical];
    [axesAndDevices bind:NSHiddenBinding toObject:permissions withKeyPath:PermissionsManagerKeyHasAllRequiredPermissions options:negated()];

    // discrete scroll step size, shown once non-continuous scrolling has been seen
    NSView *const scrollWheelBox=[self makeScrollWheelBox];
    [scrollWheelBox bind:NSHiddenBinding toObject:permissions withKeyPath:PermissionsManagerKeyHasAllRequiredPermissions options:negated()];
    [scrollWheelBox bind:@"hidden2" toObject:defaults withKeyPath:defaultsKeyPath(PrefsShowDiscreteScrollOptions) options:negated()];

    // permissions, shown only while something is missing
    NSView *const permissionsBox=[self makePermissionsBox];
    [permissionsBox bind:NSHiddenBinding toObject:permissions withKeyPath:PermissionsManagerKeyHasAllRequiredPermissions options:nil];

    NSStackView *const pane=stack(NSUserInterfaceLayoutOrientationVertical, NSLayoutAttributeCenterX, 17, @[enableCheckbox, axesAndDevices, scrollWheelBox, permissionsBox]);
    // hug the content more strongly than the window keeps its size, so the window fits the pane as sections show and hide
    [pane setHuggingPriority:NSLayoutPriorityDefaultHigh forOrientation:NSLayoutConstraintOrientationVertical];
    NSView *const view=[[NSView alloc] init];
    [view addSubview:pane];
    NSLayoutConstraint *const bottom=[view.bottomAnchor constraintEqualToAnchor:pane.bottomAnchor constant:20];
    bottom.priority=NSLayoutPriorityDefaultHigh;
    [NSLayoutConstraint activateConstraints:@[
        [pane.topAnchor constraintEqualToAnchor:view.topAnchor constant:20],
        [pane.leadingAnchor constraintEqualToAnchor:view.leadingAnchor constant:20],
        [view.trailingAnchor constraintEqualToAnchor:pane.trailingAnchor constant:20],
        bottom,
        [axesAndDevices.leadingAnchor constraintEqualToAnchor:pane.leadingAnchor],
        [axesAndDevices.trailingAnchor constraintEqualToAnchor:pane.trailingAnchor],
        [devicesBox.widthAnchor constraintEqualToAnchor:axesBox.widthAnchor],
        [scrollWheelBox.leadingAnchor constraintEqualToAnchor:pane.leadingAnchor],
        [scrollWheelBox.trailingAnchor constraintEqualToAnchor:pane.trailingAnchor],
        [permissionsBox.leadingAnchor constraintEqualToAnchor:pane.leadingAnchor],
        [permissionsBox.trailingAnchor constraintEqualToAnchor:pane.trailingAnchor],
    ]];
    return view;
}

// a box of two checkboxes, each given as @[title, defaults key], enabled only while reversing is on
- (NSBox *)boxWithTitle:(NSString *)title checkboxes:(NSArray<NSArray<NSString *> *> *)definitions
{
    NSBox *const result=box(title);
    NSButton *previous=nil;
    for (NSArray<NSString *> *definition in definitions) {
        NSButton *const button=compactCheckbox(definition[0]);
        [button bind:NSEnabledBinding toObject:self.appDelegate withKeyPath:@"enabled" options:nil];
        [button bind:NSValueBinding toObject:[NSUserDefaultsController sharedUserDefaultsController] withKeyPath:defaultsKeyPath(definition[1]) options:nil];
        [result.contentView addSubview:button];
        [NSLayoutConstraint activateConstraints:@[
            previous ? [button.topAnchor constraintEqualToAnchor:previous.bottomAnchor constant:6] : [button.topAnchor constraintEqualToAnchor:result.topAnchor constant:26],
            [button.leadingAnchor constraintEqualToAnchor:result.leadingAnchor constant:16],
            [result.trailingAnchor constraintGreaterThanOrEqualToAnchor:button.trailingAnchor constant:16],
        ]];
        previous=button;
    }
    [result.contentView.bottomAnchor constraintEqualToAnchor:previous.bottomAnchor constant:11].active=YES;
    return result;
}

- (NSView *)makeScrollWheelBox
{
    NSBox *const result=box(NSLocalizedString(@"Scroll Wheel", @"Prefs section header"));
    NSGridView *const grid=[NSGridView gridViewWithViews:@[
        [self stepSizeRowWithTitle:NSLocalizedString(@"Vertical step size:", @"Prefs check box, followed by a number of lines to scroll for each step of the mouse scroll wheel")
                        enabledKey:PrefsDiscreteScrollStepSizeEnabled
                           sizeKey:PrefsDiscreteScrollStepSize],
    ]];
    grid.translatesAutoresizingMaskIntoConstraints=NO;
    grid.rowAlignment=NSGridRowAlignmentFirstBaseline;
    grid.columnSpacing=2;
    grid.rowSpacing=6;
    [grid columnAtIndex:0].trailingPadding=6;
    [grid columnAtIndex:2].trailingPadding=4;
    // steppers have no baseline
    for (NSInteger i=0; i<grid.numberOfRows; i++) {
        NSGridCell *const cell=[grid cellAtColumnIndex:2 rowIndex:i];
        cell.rowAlignment=NSGridRowAlignmentNone;
        cell.yPlacement=NSGridCellPlacementCenter;
    }
    [result.contentView addSubview:grid];
    [NSLayoutConstraint activateConstraints:@[
        [grid.topAnchor constraintEqualToAnchor:result.topAnchor constant:26],
        [grid.leadingAnchor constraintEqualToAnchor:result.leadingAnchor constant:16],
        [result.trailingAnchor constraintGreaterThanOrEqualToAnchor:grid.trailingAnchor constant:16],
        [result.contentView.bottomAnchor constraintEqualToAnchor:grid.bottomAnchor constant:11],
    ]];
    return result;
}

// checkbox, number field, stepper and unit label for one axis's step size
- (NSArray<NSView *> *)stepSizeRowWithTitle:(NSString *)title enabledKey:(NSString *)enabledKey sizeKey:(NSString *)sizeKey
{
    NSUserDefaultsController *const defaults=[NSUserDefaultsController sharedUserDefaultsController];
    const NSInteger maxStepSize=30;

    NSButton *const checkbox=compactCheckbox(title);
    [checkbox bind:NSEnabledBinding toObject:self.appDelegate withKeyPath:@"enabled" options:nil];
    [checkbox bind:NSValueBinding toObject:defaults withKeyPath:defaultsKeyPath(enabledKey) options:nil];

    NSNumberFormatter *const formatter=[[NSNumberFormatter alloc] init];
    formatter.allowsFloats=NO;
    formatter.minimum=@(1);
    formatter.maximum=@(maxStepSize);

    NSTextField *const field=[NSTextField textFieldWithString:@""];
    field.translatesAutoresizingMaskIntoConstraints=NO;
    field.formatter=formatter;
    field.alignment=NSTextAlignmentRight;
    [field.widthAnchor constraintEqualToConstant:36].active=YES;

    NSStepper *const stepper=[[NSStepper alloc] init];
    stepper.translatesAutoresizingMaskIntoConstraints=NO;
    stepper.minValue=1;
    stepper.maxValue=maxStepSize;
    stepper.increment=1;
    stepper.valueWraps=NO;

    NSTextField *const unitLabel=label([DimmingLabel labelWithString:NSLocalizedString(@"lines", @"Unit for scroll wheel step size, shown after the number")], [NSFont systemFontOfSize:0], [NSColor labelColor]);

    // enabled only while both reversing and this step size are on
    for (NSControl *control in @[field, stepper, unitLabel]) {
        [control bind:NSEnabledBinding toObject:self.appDelegate withKeyPath:@"enabled" options:nil];
        [control bind:@"enabled2" toObject:defaults withKeyPath:defaultsKeyPath(enabledKey) options:nil];
    }
    for (NSControl *control in @[field, stepper]) {
        [control bind:NSValueBinding toObject:defaults withKeyPath:defaultsKeyPath(sizeKey) options:@{NSValidatesImmediatelyBindingOption: @YES}];
    }

    return @[checkbox, field, stepper, unitLabel];
}

- (NSView *)makePermissionsBox
{
    PermissionsManager *const permissions=self.appDelegate.permissionsManager;

    self.axStatusLabel=[self permissionStatusLabel];
    self.axButton=[NSButton buttonWithTitle:@"" target:self action:@selector(buttonAXClicked:)];
    NSView *const axView=[self permissionViewWithDescription:NSLocalizedString(@"Scroll Reverser needs Accessibility permission to modify your scrolling.", nil)
                                                 statusLabel:self.axStatusLabel
                                                      button:self.axButton
                                            descriptionInset:0];
    [self.axButton bind:NSEnabledBinding toObject:permissions withKeyPath:PermissionsManagerKeyAccessibilityEnabled options:negated()];
    [axView bind:NSHiddenBinding toObject:permissions withKeyPath:@"accessibilityRequired" options:negated()];

    self.imStatusLabel=[self permissionStatusLabel];
    self.imButton=[NSButton buttonWithTitle:@"" target:self action:@selector(buttonIMClicked:)];
    NSView *const imView=[self permissionViewWithDescription:NSLocalizedString(@"Scroll Reverser needs Input Monitoring permission to detect whether your fingers are touching the trackpad.", nil)
                                                 statusLabel:self.imStatusLabel
                                                      button:self.imButton
                                            descriptionInset:8];
    [self.imButton bind:NSEnabledBinding toObject:permissions withKeyPath:PermissionsManagerKeyInputMonitoringEnabled options:negated()];
    [imView bind:NSHiddenBinding toObject:permissions withKeyPath:@"inputMonitoringRequired" options:negated()];

    NSStackView *const permissionStack=stack(NSUserInterfaceLayoutOrientationVertical, NSLayoutAttributeLeading, 16, @[axView, imView]);
    NSBox *const result=box(NSLocalizedString(@"Permissions", @"Section title"));
    [result setContentHuggingPriority:NSLayoutPriorityDefaultLow-1 forOrientation:NSLayoutConstraintOrientationVertical];
    NSView *const content=result.contentView;
    [content addSubview:permissionStack];
    [NSLayoutConstraint activateConstraints:@[
        [permissionStack.topAnchor constraintEqualToAnchor:content.topAnchor constant:14],
        [permissionStack.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:14],
        [content.trailingAnchor constraintEqualToAnchor:permissionStack.trailingAnchor constant:14],
        [content.bottomAnchor constraintEqualToAnchor:permissionStack.bottomAnchor constant:14],
        [axView.leadingAnchor constraintEqualToAnchor:permissionStack.leadingAnchor],
        [axView.trailingAnchor constraintEqualToAnchor:permissionStack.trailingAnchor],
        [imView.leadingAnchor constraintEqualToAnchor:permissionStack.leadingAnchor],
        [imView.trailingAnchor constraintEqualToAnchor:permissionStack.trailingAnchor],
    ]];
    return result;
}

- (NSTextField *)permissionStatusLabel
{
    NSTextField *const statusLabel=label([NSTextField labelWithString:@""], smallFont(), [NSColor labelColor]);
    statusLabel.selectable=YES;
    [statusLabel setContentHuggingPriority:NSLayoutPriorityRequired forOrientation:NSLayoutConstraintOrientationHorizontal];
    [statusLabel setContentCompressionResistancePriority:NSLayoutPriorityDefaultLow forOrientation:NSLayoutConstraintOrientationHorizontal];
    return statusLabel;
}

// description, status line and request button for one permission
- (NSView *)permissionViewWithDescription:(NSString *)description statusLabel:(NSTextField *)statusLabel button:(NSButton *)button descriptionInset:(CGFloat)inset
{
    NSTextField *const descriptionLabel=label([NSTextField wrappingLabelWithString:description], smallFont(), [NSColor secondaryLabelColor]);
    button.translatesAutoresizingMaskIntoConstraints=NO;

    NSView *const view=[[NSView alloc] init];
    view.translatesAutoresizingMaskIntoConstraints=NO;
    for (NSView *subview in @[descriptionLabel, statusLabel, button]) {
        [view addSubview:subview];
    }
    [NSLayoutConstraint activateConstraints:@[
        [descriptionLabel.topAnchor constraintEqualToAnchor:view.topAnchor],
        [descriptionLabel.leadingAnchor constraintEqualToAnchor:view.leadingAnchor],
        [view.trailingAnchor constraintEqualToAnchor:descriptionLabel.trailingAnchor constant:inset],
        [statusLabel.topAnchor constraintEqualToAnchor:descriptionLabel.bottomAnchor constant:6],
        [statusLabel.centerXAnchor constraintEqualToAnchor:view.centerXAnchor],
        [button.topAnchor constraintEqualToAnchor:statusLabel.bottomAnchor constant:6],
        [button.centerXAnchor constraintEqualToAnchor:view.centerXAnchor],
        [view.bottomAnchor constraintEqualToAnchor:button.bottomAnchor],
    ]];
    return view;
}

#pragma mark App pane

- (NSView *)makeAppSettings
{
    AppDelegate *const appDelegate=self.appDelegate;
    NSUserDefaultsController *const defaults=[NSUserDefaultsController sharedUserDefaultsController];

    // general options
    NSButton *const startAtLoginCheckbox=checkbox(NSLocalizedString(@"Start at login", @"Prefs check box"));
    [startAtLoginCheckbox bind:NSValueBinding toObject:appDelegate.loginItemController withKeyPath:@"startAtLogin" options:nil];
    NSButton *const showInMenuBarCheckbox=checkbox(NSLocalizedString(@"Show in menu bar", @"Prefs check box"));
    [showInMenuBarCheckbox bind:NSValueBinding toObject:defaults withKeyPath:defaultsKeyPath(PrefsHideIcon) options:negated()];
    [startAtLoginCheckbox setContentHuggingPriority:NSLayoutPriorityDefaultHigh-1 forOrientation:NSLayoutConstraintOrientationHorizontal];
    [showInMenuBarCheckbox setContentHuggingPriority:NSLayoutPriorityDefaultHigh forOrientation:NSLayoutConstraintOrientationHorizontal];
    for (NSButton *button in @[startAtLoginCheckbox, showInMenuBarCheckbox]) {
        [button setContentCompressionResistancePriority:NSLayoutPriorityRequired forOrientation:NSLayoutConstraintOrientationHorizontal];
    }
    NSStackView *const options=stack(NSUserInterfaceLayoutOrientationVertical, NSLayoutAttributeLeading, 6, @[startAtLoginCheckbox, showInMenuBarCheckbox]);
    [options setHuggingPriority:NSLayoutPriorityDefaultHigh forOrientation:NSLayoutConstraintOrientationHorizontal];
    [options setHuggingPriority:NSLayoutPriorityDefaultHigh forOrientation:NSLayoutConstraintOrientationVertical];

    // a separator is horizontal if it starts out wider than it is tall
    NSBox *const separator=[[NSBox alloc] initWithFrame:NSMakeRect(0, 0, 100, 1)];
    separator.translatesAutoresizingMaskIntoConstraints=NO;
    separator.boxType=NSBoxSeparator;

    // about the app
    NSFont *const infoFont=[NSFont messageFontOfSize:11];
    NSTextField *const nameLabel=label([NSTextField labelWithString:appDelegate.appName], [NSFont boldSystemFontOfSize:[NSFont smallSystemFontSize]], [NSColor labelColor]);
    NSTextField *const versionLabel=label([NSTextField labelWithString:appDelegate.appVersion], infoFont, [NSColor labelColor]);
    NSTextField *const creditLabel=label([NSTextField labelWithString:appDelegate.appCredit], infoFont, [NSColor labelColor]);
    LinkView *const linkLabel=(LinkView *)label([LinkView labelWithString:appDelegate.appDisplayLink], infoFont, [NSColor controlAccentColor]);
    linkLabel.url=appDelegate.appLink;
    // the stack stretches the labels to the widest one, so centre the text within them
    for (NSTextField *field in @[nameLabel, versionLabel, creditLabel, linkLabel]) {
        field.alignment=NSTextAlignmentCenter;
    }
    NSStackView *const info=stack(NSUserInterfaceLayoutOrientationVertical, NSLayoutAttributeCenterX, 0, @[nameLabel, versionLabel, creditLabel, linkLabel]);
    [info setHuggingPriority:NSLayoutPriorityDefaultHigh forOrientation:NSLayoutConstraintOrientationHorizontal];
    [info setHuggingPriority:NSLayoutPriorityDefaultHigh forOrientation:NSLayoutConstraintOrientationVertical];

    // updates
    SPUUpdater *const updater=self.updater;
    NSButton *const checkNowButton=[NSButton buttonWithTitle:NSLocalizedString(@"Check for updates", @"Button, when pressed, checks for updates now") target:self action:@selector(buttonCheckForUpdatesClicked:)];
    checkNowButton.translatesAutoresizingMaskIntoConstraints=NO;
    checkNowButton.controlSize=NSControlSizeSmall;
    checkNowButton.font=infoFont;
    [checkNowButton setContentHuggingPriority:NSLayoutPriorityRequired forOrientation:NSLayoutConstraintOrientationHorizontal];
    [checkNowButton setContentHuggingPriority:NSLayoutPriorityDefaultHigh+1 forOrientation:NSLayoutConstraintOrientationVertical];
    [checkNowButton bind:NSEnabledBinding toObject:updater withKeyPath:@"sessionInProgress" options:negated()];
    NSButton *const automaticCheckbox=smallCheckbox(NSLocalizedString(@"Automatically", @"Check box next to the 'Check for updates' button"));
    [automaticCheckbox bind:NSValueBinding toObject:updater withKeyPath:@"automaticallyChecksForUpdates" options:nil];
    NSButton *const betaCheckbox=smallCheckbox(NSLocalizedString(@"Include beta versions", @"Check box: Include beta versionss of the app when checking for updates"));
    [betaCheckbox bind:NSValueBinding toObject:defaults withKeyPath:defaultsKeyPath(@"BetaUpdates") options:nil];
    NSStackView *const updateOptions=stack(NSUserInterfaceLayoutOrientationVertical, NSLayoutAttributeLeading, 6, @[automaticCheckbox, betaCheckbox]);
    NSStackView *const updates=stack(NSUserInterfaceLayoutOrientationHorizontal, NSLayoutAttributeTop, 8, @[checkNowButton, updateOptions]);
    [updates setHuggingPriority:NSLayoutPriorityDefaultHigh forOrientation:NSLayoutConstraintOrientationHorizontal];
    [updates setHuggingPriority:NSLayoutPriorityDefaultHigh forOrientation:NSLayoutConstraintOrientationVertical];

    NSView *const view=[[NSView alloc] init];
    for (NSView *subview in @[options, separator, info, updates]) {
        [view addSubview:subview];
    }
    NSLayoutConstraint *const bottom=[view.bottomAnchor constraintEqualToAnchor:updates.bottomAnchor constant:20];
    bottom.priority=NSLayoutPriorityDefaultHigh;
    [NSLayoutConstraint activateConstraints:@[
        [options.topAnchor constraintEqualToAnchor:view.topAnchor constant:20],
        [options.centerXAnchor constraintEqualToAnchor:view.centerXAnchor],
        [separator.topAnchor constraintEqualToAnchor:options.bottomAnchor constant:16],
        [separator.leadingAnchor constraintEqualToAnchor:view.leadingAnchor constant:20],
        [view.trailingAnchor constraintEqualToAnchor:separator.trailingAnchor constant:20],
        [separator.heightAnchor constraintEqualToConstant:1],
        [info.topAnchor constraintEqualToAnchor:separator.bottomAnchor constant:16],
        [info.centerXAnchor constraintEqualToAnchor:view.centerXAnchor],
        [updates.topAnchor constraintEqualToAnchor:info.bottomAnchor constant:16],
        [updates.centerXAnchor constraintEqualToAnchor:view.centerXAnchor],
        bottom,
        [checkNowButton.firstBaselineAnchor constraintEqualToAnchor:automaticCheckbox.firstBaselineAnchor],
    ]];
    return view;
}

@end
