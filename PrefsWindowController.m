//
//  PrefsWindowController.m
//  ScrollInverter
//
//  Created by Nicholas Moore on 08/12/2014.
//
//

#import "PrefsWindowController.h"
#import "AppDelegate.h"
#import "LinkView.h"

static NSString *const kPanelScrolling=@"scrolling";
static NSString *const kPanelApp=@"app";

static NSString *const kKeyView=@"view";
static NSString *const kKeyViewHeight=@"viewHeight";
static NSString *const kKeyTitle=@"title";
static NSString *const kKeyImageName=@"image";

static NSString *const kPrefsToolbarIdentifer=@"PrefsToolbar";
static NSString *const kPrefsLastUsedPanel=@"PrefsLastUsedPanel";

@interface PrefsWindowController ()
@property NSTabView *tabView;
@property NSToolbar *toolbar;
@property NSDictionary *panels;
@property CGFloat width;
@end

@implementation PrefsWindowController

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
        panelData[kKeyViewHeight] = @([view frame].size.height);
        const NSSize size=[view fittingSize];
        self.width=MAX(self.width, size.width);
        //NSLog(@"fs %@", NSStringFromSize(size));
        //NSLog(@" s %@", NSStringFromSize([view frame].size));
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
    [self updateHeightForIdentifier:startingIdentifier];
    
    // other set-up
    self.linkView.url=self.appDelegate.appLink;
}

- (void)showWindow:(id)sender
{
    [[self window] setLevel:NSFloatingWindowLevel];
    [[self window] center];
    [NSApp activateIgnoringOtherApps:YES];
    // small delay to prevent flash of window drawing (better way?)
    dispatch_after(0.05, dispatch_get_main_queue(), ^{
        [super showWindow:sender];
    });
}

#pragma mark Private methods

- (void)setPane:(NSString *)identifier
{
    // select the appropriate tab view item
    [self.tabView selectTabViewItemWithIdentifier:identifier];
    
    // save this as the last used panel
    [[NSUserDefaults standardUserDefaults] setObject:identifier forKey:kPrefsLastUsedPanel];
}

// Futz about with the geometry to get the height right
- (void)setWindowContentHeight:(CGFloat)height
{
    // get the current content rect
    NSRect contentRect=[NSWindow contentRectForFrameRect:[self.window frame]
                                               styleMask:[self.window styleMask]];
    
    
    // calculate new content rect
    const CGFloat toolbarHeight=NSHeight(contentRect)-NSHeight([(NSView *)[[self window] contentView] frame]);
    const CGFloat diff=height+toolbarHeight-contentRect.size.height;
    contentRect.size.height+=diff;
    contentRect.origin.y-=diff;
    contentRect.size.width=self.width;
    
    // set window to new size
    [self.window setFrame:[NSWindow frameRectForContentRect:contentRect
                                                  styleMask:[self.window styleMask]]
                  display:YES
                  animate:NO];
}

// Set the window to the previously stored height for the selected panel
- (void)updateHeightForIdentifier:(NSString *)identifier
{
    [self setWindowContentHeight:[self.panels[identifier][kKeyViewHeight] floatValue]];
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
    [self updateHeightForIdentifier:[tabViewItem identifier]];
}

#pragma mark Bindings

- (AppDelegate *)appDelegate
{
    return [[NSApplication sharedApplication] delegate];
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
    return NSLocalizedString(@"App", nil);
}

- (NSString *)menuStringScrollingSettings {
    return NSLocalizedString(@"Scrolling", nil);
}

- (NSString *)menuStringScrollingAxes {
    return NSLocalizedString(@"Scrolling Axes", nil);
}

- (NSString *)menuStringScrollingDevices {
    return NSLocalizedString(@"Scrolling Devices", nil);
}

- (NSString *)menuStringHorizontal {
    return NSLocalizedString(@"Reverse Horizontal", nil);
}

- (NSString *)menuStringVertical {
    return NSLocalizedString(@"Reverse Vertical", nil);
}

- (NSString *)menuStringTrackpad {
    return NSLocalizedString(@"Reverse Trackpad", nil);
}

- (NSString *)menuStringMouse {
    return NSLocalizedString(@"Reverse Mouse", nil);
}

- (NSString *)menuStringTablet {
    return NSLocalizedString(@"Reverse Tablet", nil);
}

- (NSString *)menuStringStartAtLogin {
    return NSLocalizedString(@"Start at login", nil);
}

- (NSString *)menuStringShowInMenuBar {
    return NSLocalizedString(@"Show in menu bar", nil);
}

- (NSString *)menuStringCheckNow {
    return NSLocalizedString(@"Check for updates", nil);
}

- (NSString *)menuStringCheckForUpdates {
    return NSLocalizedString(@"Automatically", @"check box next to the 'Check for updates' button");
}

@end
