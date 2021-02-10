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


static void *_contextRefresh=&_contextRefresh;

@interface PrefsWindowController ()
@property NSTabView *tabView;
@property NSToolbar *toolbar;
@property NSDictionary *panels;
@property CGFloat width;
@end

@implementation PrefsWindowController

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

- (void)windowDidLoad
{
    [super windowDidLoad];
    
    NSArray *const toolbarDefinition=@[kPanelScrolling, kPanelApp];
    NSDictionary *const panelsDefinition=@{kPanelScrolling: @{kKeyView: self.scrollingSettings,
                                                              kKeyTitle: self.menuStringScrollingSettings,
                                                              kKeyImageName: NSImageNamePreferencesGeneral},
                                           kPanelApp: @{kKeyView: self.appSettings,
                                                        kKeyTitle: self.menuStringAppSettings,
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
    
    // other set-up
    self.linkView.url=self.appDelegate.appLink;

    [self.appDelegate.permissionsManager addObserver:self forKeyPath:@"accessibilityEnabled" options:0 context:_contextRefresh];
    [self.appDelegate.permissionsManager addObserver:self forKeyPath:@"inputMonitoringEnabled" options:0 context:_contextRefresh];

    // select the initial pane
    [self.tabView selectTabViewItemWithIdentifier:startingIdentifier];
    [self.toolbar setSelectedItemIdentifier:startingIdentifier];
    [self updateWindowForIdentifier:startingIdentifier];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context
{
    if (context==_contextRefresh) {
        NSLog(@"refresh observe");
    }
}

- (void)showWindow:(id)sender
{
    self.window.delegate=self;
    self.window.level=NSNormalWindowLevel;
    if (![NSApp isActive]) {
        [NSApp activateIgnoringOtherApps:YES];
    }
    if (self.window.visible) {
        [self callAttention];
    }
    else {
        [self.window center];
    }
    [super showWindow:sender];
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
    // we simply set the width to out pre-stored width. autolayout will deal with the height.
    NSRect contentRect=[NSWindow contentRectForFrameRect:[self.window frame]
                                               styleMask:[self.window styleMask]];
    contentRect.size.width=self.width;
    [self.window setFrame:[NSWindow frameRectForContentRect:contentRect
                                                  styleMask:[self.window styleMask]]
                  display:YES
                  animate:NO];
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

+ (NSSet *)keyPathsForValuesAffectingMenuStringAXButtonLabel
{
    return [NSSet setWithObject:@"appDelegate.permissionsManager.accessibilityEnabled"];
}

- (NSString *)menuStringAXButtonLabel
{
    return [self buttonLabel:self.appDelegate.permissionsManager.accessibilityEnabled label:self.menuStringPermissionsAX];
}

+ (NSSet *)keyPathsForValuesAffectingMenuStringIMButtonLabel
{
    return [NSSet setWithObject:@"appDelegate.permissionsManager.inputMonitoringRequested"];
}

- (NSString *)menuStringIMButtonLabel
{
    return [self buttonLabel:self.appDelegate.permissionsManager.inputMonitoringRequested label:self.menuStringPermissionsIM];
}

+ (NSSet *)keyPathsForValuesAffectingMenuStringAXStatus
{
    return [NSSet setWithObject:@"appDelegate.permissionsManager.accessibilityEnabled"];
}

- (NSString *)menuStringAXStatus
{
    return [self statusString:self.appDelegate.permissionsManager.accessibilityEnabled label:self.menuStringPermissionsAX];
}

+ (NSSet *)keyPathsForValuesAffectingMenuStringIMStatus
{
    return [NSSet setWithObject:@"appDelegate.permissionsManager.inputMonitoringEnabled"];
}

- (NSString *)menuStringIMStatus
{
    return [self statusString:self.appDelegate.permissionsManager.inputMonitoringEnabled label:self.menuStringPermissionsIM];
}

- (NSString *)statusString:(BOOL)state label:(NSString *)label
{
    return [NSString stringWithFormat:NSLocalizedString(@"%1$@ permission: %2$@", "for example: `Accessibility permission: ⛔️ required`"), label, state ?
            NSLocalizedString(@"✅ granted", nil) :
            NSLocalizedString(@"⛔️ required", nil)];
}

#pragma mark Bindings
// I'm sure there's a better way of doing this 😂

- (AppDelegate *)appDelegate
{
    return (AppDelegate *)[[NSApplication sharedApplication] delegate];
}

- (NSString *)menuStringReverseScrolling
{
    return self.appDelegate.menuStringReverseScrolling;
}

- (NSString *)menuStringPreferencesTitle
{
    return self.appDelegate.appName;
}

- (NSString *)menuStringAppSettings {
    return NSLocalizedString(@"App", @"Preferences pane for `App` settings");
}

- (NSString *)menuStringScrollingSettings {
    return NSLocalizedString(@"Scrolling", @"Preferences pane for `Scrolling` serttings");
}

- (NSString *)menuStringScrollingAxes {
    return NSLocalizedString(@"Scrolling Axes", @"Prefs section title");
}

- (NSString *)menuStringScrollingDevices {
    return NSLocalizedString(@"Scrolling Devices", @"Prefs section title");
}

- (NSString *)menuStringHorizontal {
    return NSLocalizedString(@"Reverse Horizontal", @"Prefs check box");
}

- (NSString *)menuStringVertical {
    return NSLocalizedString(@"Reverse Vertical", @"Prefs check box");
}

- (NSString *)menuStringTrackpad {
    return NSLocalizedString(@"Reverse Trackpad", @"Prefs check box");
}

- (NSString *)menuStringMouse {
    return NSLocalizedString(@"Reverse Mouse", @"Prefs check box");
}

- (NSString *)menuStringStartAtLogin {
    return NSLocalizedString(@"Start at login", @"Prefs check box");
}

- (NSString *)menuStringShowInMenuBar {
    return NSLocalizedString(@"Show in menu bar", @"Prefs check box");
}

- (NSString *)menuStringCheckNow {
    return NSLocalizedString(@"Check for updates", @"Button, when pressed, checks for updates now");
}

- (NSString *)menuStringCheckForUpdates {
    return NSLocalizedString(@"Automatically", @"Check box next to the 'Check for updates' button");
}

- (NSString *)menuStringBetaUpdates {
    return NSLocalizedString(@"Include beta versions", @"Check box: Include beta versionss of the app when checking for updates");
}

- (NSString *)menuStringPermissionsHeader {
    return NSLocalizedString(@"Permissions", @"Section title");
}

- (NSString *)menuStringPermissionsAXDescription {
    return NSLocalizedString(@"Scroll Reverser needs Accessibility permission to modify your scrolling.", nil);
}

- (NSString *)menuStringPermissionsIMDescription {
    return NSLocalizedString(@"Scroll Reverser needs Input Monitoring permission to detect whether your fingers are touching the trackpad.", nil);
}

- (NSString *)menuStringPermissionsAX {
    return NSLocalizedString(@"Accessibility", @"corresponds to Accessibility in system Privacy settings");
}

- (NSString *)menuStringPermissionsIM {
    return NSLocalizedString(@"Input Monitoring", @"corresponds to Input Monitoring in system Privacy settings");
}

- (NSString *)menuStringMouseWheelHeader {
    return NSLocalizedString(@"Mouse Wheel Step Size", @"Prefs section header");
}

- (NSString *)menuStringMouseWheelLevel0 {
    return NSLocalizedString(@"Default", @"System default step size (small)");
}

- (NSString *)menuStringMouseWheelLevel1 {
    return NSLocalizedString(@"Medium", @"Medium step size");
}

- (NSString *)menuStringMouseWheelLevel2 {
    return NSLocalizedString(@"Large", @"Large step size");
}

- (NSString *)menuStringMouseWheelLevel3 {
    return NSLocalizedString(@"X-Large", @"Extra large step size");
}

@end
