// This file is part of Scroll Reverser <https://pilotmoon.com/scrollreverser/>
// Licensed under Apache License v2.0 <http://www.apache.org/licenses/LICENSE-2.0>

#import "SourceRow+Display.h"

NSString *SourceDirectionModeTitle(ScrollDirectionMode mode)
{
    switch (mode) {
        case ScrollDirectionModeNatural:
            return NSLocalizedString(@"Natural", @"Scrolling direction: natural scrolling, as in System Settings");
        case ScrollDirectionModeClassic:
            return NSLocalizedString(@"Classic", @"Scrolling direction: the opposite of natural scrolling");
        case ScrollDirectionModeReversed:
            return NSLocalizedString(@"Reversed", @"Scrolling menu item: reverse the direction of scrolling posted by an app");
        case ScrollDirectionModeMatchVertical:
            return NSLocalizedString(@"Match vertical", @"Horizontal scrolling menu item: reverse horizontal scrolling whenever vertical scrolling is reversed");
        case ScrollDirectionModeUnchanged:
        default:
            return NSLocalizedString(@"Unchanged", @"Scrolling menu item: leave scrolling as the system delivers it");
    }
}

static NSString *_unidentifiedDevice(void)
{
    return NSLocalizedString(@"Unidentified device", @"Name and kind of a source of scrolling that is a device the system can't identify");
}

static NSString *_unidentifiedSource(void)
{
    return NSLocalizedString(@"Unidentified source", @"Name and kind of a source of scrolling that is neither a device nor an app");
}

@implementation SourceRow (Display)

- (NSString *)displayName
{
    return self.customName?:self.defaultName;
}

+ (NSSet *)keyPathsForValuesAffectingDisplayName
{
    return [NSSet setWithObjects:@"customName", @"reportedName", nil];
}

- (NSString *)defaultName
{
    switch (self.kind) {
        case ScrollSourceKindLocalDevice:
            return self.reportedName?:NSLocalizedString(@"Unnamed device", @"Name of a device that reports no name");
        case ScrollSourceKindRemoteDevice: {
            // Universal Control names its virtual devices "V-" and the original device's name
            NSString *name=self.reportedName;
            if ([name hasPrefix:@"V-"]&&[name length]>2) {
                name=[name substringFromIndex:2];
            }
            return [NSString stringWithFormat:NSLocalizedString(@"%1$@ (Universal Control)", @"Name of a device on another Mac, used through Universal Control. 1=the device's name"),
                    name?:NSLocalizedString(@"Unnamed device", @"Name of a device that reports no name")];
        }
        case ScrollSourceKindUnidentifiedDevice:
            return _unidentifiedDevice();
        case ScrollSourceKindApp:
            return self.reportedName?:NSLocalizedString(@"Unknown app", @"Name of an app that posted scrolling but quit before it could be identified");
        case ScrollSourceKindUnidentified:
        default:
            return _unidentifiedSource();
    }
}

- (NSImage *)icon
{
    if (self.kind==ScrollSourceKindApp&&self.path&&[[NSFileManager defaultManager] fileExistsAtPath:self.path]) {
        NSImage *const icon=[[NSWorkspace sharedWorkspace] iconForFile:self.path];
        icon.size=NSMakeSize(18, 18);
        return icon;
    }
    NSString *symbol;
    switch (self.kind) {
        case ScrollSourceKindLocalDevice:
        case ScrollSourceKindRemoteDevice:
            if (self.category==ScrollSourceCategoryTrackpad) {
                symbol=@"rectangle.and.hand.point.up.left";
            }
            else {
                // continuous scrolling from a mouse comes from a touch surface, like the Magic Mouse's
                symbol=self.continuous?@"magicmouse":@"computermouse";
            }
            break;
        case ScrollSourceKindApp:
            symbol=@"app";
            break;
        case ScrollSourceKindUnidentifiedDevice:
        case ScrollSourceKindUnidentified:
        default:
            symbol=@"questionmark.circle";
            break;
    }
    // drawn at one point size, like text, rather than scaled to fit: the trackpad symbol is much wider than the mouse
    return [[NSImage imageWithSystemSymbolName:symbol accessibilityDescription:self.kindDescription] imageWithSymbolConfiguration:[NSImageSymbolConfiguration configurationWithPointSize:13 weight:NSFontWeightRegular]];
}

- (NSString *)kindDescription
{
    const BOOL trackpad=self.category==ScrollSourceCategoryTrackpad;
    switch (self.kind) {
        case ScrollSourceKindLocalDevice:
            return trackpad?NSLocalizedString(@"Trackpad", @"Kind of source: a trackpad"):NSLocalizedString(@"Mouse", @"Kind of source: a mouse, or any other device that isn't a trackpad");
        case ScrollSourceKindRemoteDevice:
            return trackpad?NSLocalizedString(@"Trackpad (Universal Control)", @"Kind of source: a trackpad on another Mac, used through Universal Control"):
                NSLocalizedString(@"Mouse (Universal Control)", @"Kind of source: a mouse on another Mac, used through Universal Control");
        case ScrollSourceKindUnidentifiedDevice:
            return _unidentifiedDevice();
        case ScrollSourceKindApp:
            return NSLocalizedString(@"App", @"Preferences pane for `App` settings; also the kind of source that is an app posting scrolling of its own");
        case ScrollSourceKindUnidentified:
        default:
            return _unidentifiedSource();
    }
}

- (NSString *)scrollingTypeDescription
{
    return self.continuous?NSLocalizedString(@"Continuous", @"Scrolling type of a source that scrolls continuously, like a trackpad"):
        NSLocalizedString(@"Discrete", @"Scrolling type of a source that scrolls in steps, like a scroll wheel");
}

- (NSString *)systemDirectionDescription
{
    // events posted by apps never have natural scrolling applied by the system
    if (!self.hasDeviceDirection) {
        return NSLocalizedString(@"Unknown", @"System direction of scrolling posted by an app, which the system doesn't say");
    }
    // the latest, since the system setting can change
    if (self.seenNatural||self.seenClassic) {
        return SourceDirectionModeTitle(self.lastNatural?ScrollDirectionModeNatural:ScrollDirectionModeClassic);
    }
    return @"—";
}

@end
