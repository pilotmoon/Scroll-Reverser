// This file is part of Scroll Reverser <https://pilotmoon.com/scrollreverser/>
// Licensed under Apache License v2.0 <http://www.apache.org/licenses/LICENSE-2.0>

#import "PrefsWindowController.h"
#import "AppDelegate.h"
#import "LinkView.h"
#import "SourcesTableController.h"


static NSString *const kPanelScrolling=@"scrolling";
static NSString *const kPanelApp=@"app";

static NSString *const kKeyView=@"view";
static NSString *const kKeyTitle=@"title";
static NSString *const kKeyImageName=@"image";

static NSString *const kPrefsToolbarIdentifer=@"PrefsToolbar";
static NSString *const kPrefsLastUsedPanel=@"PrefsLastUsedPanel";


static void *_contextPermissions=&_contextPermissions;


typedef NS_ENUM(NSInteger, UpdateMode) {
    UpdateModeOff,
    UpdateModeNotify,
    UpdateModeInstall,
};

@interface PrefsWindowController ()
@property UpdateMode updateMode;
@property NSTabView *tabView;
@property NSToolbar *toolbar;
@property NSDictionary *panels;
@property CGFloat width;
@property NSView *scrollingSettings;
@property NSView *appSettings;
@property SourcesTableController *sourcesController;
@property NSTextField *axStatusLabel;
@property NSButton *axButton;
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

// the Automatic updates menu combines two Sparkle settings
+ (NSSet<NSString *> *)keyPathsForValuesAffectingUpdateMode
{
    return [NSSet setWithObjects:@"updater.automaticallyChecksForUpdates", @"updater.automaticallyDownloadsUpdates", nil];
}

- (UpdateMode)updateMode
{
    SPUUpdater *const updater=self.updater;
    if (!updater.automaticallyChecksForUpdates) {
        return UpdateModeOff;
    }
    return updater.automaticallyDownloadsUpdates ? UpdateModeInstall : UpdateModeNotify;
}

- (void)setUpdateMode:(UpdateMode)updateMode
{
    SPUUpdater *const updater=self.updater;
    updater.automaticallyChecksForUpdates=updateMode!=UpdateModeOff;
    updater.automaticallyDownloadsUpdates=updateMode==UpdateModeInstall;
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
        for (NSString *keyPath in @[PermissionsManagerKeyAccessibilityEnabled]) {
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
                                                              kKeyTitle: NSLocalizedString(@"Scrolling", @"Preferences pane for `Scrolling` settings; also the sources table column header for natural or classic scrolling"),
                                                              kKeyImageName: NSImageNamePreferencesGeneral},
                                           kPanelApp: @{kKeyView: self.appSettings,
                                                        kKeyTitle: NSLocalizedString(@"App", @"Preferences pane for `App` settings; also the kind of source that is an app posting scrolling of its own"),
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
        [self.sourcesController windowWillShow];
    }
    [super showWindow:sender];
    if (!wasVisible) {
        // don't start with the step size field focused
        [self.window makeFirstResponder:nil];
    }
}

- (void)windowWillClose:(NSNotification *)notification
{
    [self.sourcesController windowWillClose];
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
        return [NSString stringWithFormat: NSLocalizedString(@"Open %1$@ preferences", @"1=`Accessibility`"), label];
    }
    else {
        return [NSString stringWithFormat: NSLocalizedString(@"Request %1$@ permission", @"1=`Accessibility`"), label];
    }
}

- (void)updatePermissionLabels
{
    PermissionsManager *const permissions=self.appDelegate.permissionsManager;
    NSString *const ax=NSLocalizedString(@"Accessibility", @"corresponds to Accessibility in system Privacy settings");
    self.axStatusLabel.stringValue=[self statusString:permissions.accessibilityEnabled label:ax];
    self.axButton.title=[self buttonLabel:permissions.accessibilityEnabled label:ax];
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
    // master switch
    NSButton *const enableCheckbox=compactCheckbox([NSString stringWithFormat:NSLocalizedString(@"Enable %1$@", @"1=name of app e.g. `Enable Scroll Reverser`"), appDelegate.appName]);
    [enableCheckbox bind:NSValueBinding toObject:appDelegate withKeyPath:@"enabled" options:@{NSValidatesImmediatelyBindingOption: @YES}];
    [enableCheckbox bind:NSHiddenBinding toObject:permissions withKeyPath:PermissionsManagerKeyHasAllRequiredPermissions options:negated()];

    // a row of settings per scroll source
    self.sourcesController=[[SourcesTableController alloc] initWithSourceTable:appDelegate.sourceTable];
    [self.sourcesController bind:@"enabled" toObject:appDelegate withKeyPath:@"enabled" options:nil];
    NSView *const sources=self.sourcesController.view;
    [sources bind:NSHiddenBinding toObject:permissions withKeyPath:PermissionsManagerKeyHasAllRequiredPermissions options:negated()];

    // permissions, shown only while something is missing
    NSView *const permissionsBox=[self makePermissionsBox];
    [permissionsBox bind:NSHiddenBinding toObject:permissions withKeyPath:PermissionsManagerKeyHasAllRequiredPermissions options:nil];

    NSStackView *const pane=stack(NSUserInterfaceLayoutOrientationVertical, NSLayoutAttributeCenterX, 17, @[enableCheckbox, sources, permissionsBox]);
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
        [sources.leadingAnchor constraintEqualToAnchor:pane.leadingAnchor],
        [sources.trailingAnchor constraintEqualToAnchor:pane.trailingAnchor],
        [permissionsBox.leadingAnchor constraintEqualToAnchor:pane.leadingAnchor],
        [permissionsBox.trailingAnchor constraintEqualToAnchor:pane.trailingAnchor],
    ]];
    return view;
}

- (NSView *)makePermissionsBox
{
    PermissionsManager *const permissions=self.appDelegate.permissionsManager;

    self.axStatusLabel=[self permissionStatusLabel];
    self.axButton=[NSButton buttonWithTitle:@"" target:self action:@selector(buttonAXClicked:)];
    NSView *const axView=[self permissionViewWithDescription:NSLocalizedString(@"Scroll Reverser needs Accessibility permission to modify your scrolling.", nil)
                                                 statusLabel:self.axStatusLabel
                                                      button:self.axButton];
    [self.axButton bind:NSEnabledBinding toObject:permissions withKeyPath:PermissionsManagerKeyAccessibilityEnabled options:negated()];
    [axView bind:NSHiddenBinding toObject:permissions withKeyPath:@"accessibilityRequired" options:negated()];

    NSBox *const result=box(NSLocalizedString(@"Permissions", @"Section title"));
    [result setContentHuggingPriority:NSLayoutPriorityDefaultLow-1 forOrientation:NSLayoutConstraintOrientationVertical];
    NSView *const content=result.contentView;
    [content addSubview:axView];
    [NSLayoutConstraint activateConstraints:@[
        [axView.topAnchor constraintEqualToAnchor:content.topAnchor constant:14],
        [axView.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:14],
        [content.trailingAnchor constraintEqualToAnchor:axView.trailingAnchor constant:14],
        [content.bottomAnchor constraintEqualToAnchor:axView.bottomAnchor constant:14],
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
- (NSView *)permissionViewWithDescription:(NSString *)description statusLabel:(NSTextField *)statusLabel button:(NSButton *)button
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
        [view.trailingAnchor constraintEqualToAnchor:descriptionLabel.trailingAnchor],
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
    NSTextField *const modeLabel=label([NSTextField labelWithString:NSLocalizedString(@"Automatic updates:", @"Label before the pop-up menu that chooses how updates are handled")], infoFont, [NSColor labelColor]);
    NSPopUpButton *const modePopUp=[[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
    modePopUp.translatesAutoresizingMaskIntoConstraints=NO;
    modePopUp.controlSize=NSControlSizeSmall;
    modePopUp.font=infoFont;
    for (NSArray *item in @[@[NSLocalizedString(@"Install automatically", @"Automatic updates menu item: download and install updates without asking"), @(UpdateModeInstall)],
                            @[NSLocalizedString(@"Notify only", @"Automatic updates menu item: check for updates and ask before installing them"), @(UpdateModeNotify)],
                            @[NSLocalizedString(@"Off", @"Automatic updates menu item: don't check for updates automatically"), @(UpdateModeOff)]]) {
        [modePopUp addItemWithTitle:item[0]];
        modePopUp.lastItem.tag=[item[1] integerValue];
    }
    [modePopUp bind:NSSelectedTagBinding toObject:self withKeyPath:@"updateMode" options:nil];
    NSButton *const betaCheckbox=smallCheckbox(NSLocalizedString(@"Include beta versions", @"Check box: Include beta versionss of the app when checking for updates"));
    [betaCheckbox bind:NSValueBinding toObject:defaults withKeyPath:defaultsKeyPath(@"BetaUpdates") options:nil];
    NSGridView *const updateOptions=[NSGridView gridViewWithViews:@[@[modeLabel, modePopUp],
                                                                     @[[NSGridCell emptyContentView], betaCheckbox]]];
    updateOptions.translatesAutoresizingMaskIntoConstraints=NO;
    updateOptions.rowAlignment=NSGridRowAlignmentFirstBaseline;
    updateOptions.columnSpacing=6;
    updateOptions.rowSpacing=8;
    [updateOptions columnAtIndex:0].xPlacement=NSGridCellPlacementTrailing;
    NSButton *const checkNowButton=[NSButton buttonWithTitle:NSLocalizedString(@"Check for updates", @"Button, when pressed, checks for updates now") target:self action:@selector(buttonCheckForUpdatesClicked:)];
    checkNowButton.translatesAutoresizingMaskIntoConstraints=NO;
    checkNowButton.controlSize=NSControlSizeSmall;
    checkNowButton.font=infoFont;
    [checkNowButton setContentHuggingPriority:NSLayoutPriorityRequired forOrientation:NSLayoutConstraintOrientationHorizontal];
    [checkNowButton bind:NSEnabledBinding toObject:self.updater withKeyPath:@"sessionInProgress" options:negated()];
    NSStackView *const updates=stack(NSUserInterfaceLayoutOrientationVertical, NSLayoutAttributeCenterX, 12, @[updateOptions, checkNowButton]);
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
    ]];
    return view;
}

@end
