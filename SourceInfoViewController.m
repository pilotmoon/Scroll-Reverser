// This file is part of Scroll Reverser <https://pilotmoon.com/scrollreverser/>
// Licensed under Apache License v2.0 <http://www.apache.org/licenses/LICENSE-2.0>

#import "SourceInfoViewController.h"
#import "SourceRow+Display.h"

static NSFont *_font(void)
{
    return [NSFont systemFontOfSize:[NSFont smallSystemFontSize]];
}

static NSTextField *_title(NSString *string)
{
    NSTextField *const field=[NSTextField labelWithString:string];
    field.font=_font();
    field.textColor=[NSColor secondaryLabelColor];
    return field;
}

static NSTextField *_value(NSString *string)
{
    NSTextField *const field=[NSTextField wrappingLabelWithString:string?:@"—"];
    field.selectable=YES;
    field.font=_font();
    [field.widthAnchor constraintLessThanOrEqualToConstant:320].active=YES;
    return field;
}

@interface SourceInfoViewController ()
@property SourceRow *row;
@property BOOL editable;
@end

@implementation SourceInfoViewController

- (instancetype)initWithRow:(SourceRow *)row editable:(BOOL)editable
{
    self=[super initWithNibName:nil bundle:nil];
    if (self) {
        self.row=row;
        self.editable=editable;
    }
    return self;
}

- (void)loadView
{
    SourceRow *const row=self.row;

    // empty for the default name, which shows as the placeholder (the binding's, since it replaces the field's own)
    NSTextField *const nameField=[NSTextField textFieldWithString:@""];
    [nameField.widthAnchor constraintEqualToConstant:240].active=YES;
    [nameField bind:NSValueBinding toObject:row withKeyPath:@"customName" options:@{NSContinuouslyUpdatesValueBindingOption: @YES,
                                                                                   NSNullPlaceholderBindingOption: row.defaultName}];

    NSPopUpButton *const horizontalPopUp=[[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
    horizontalPopUp.controlSize=NSControlSizeSmall;
    horizontalPopUp.font=_font();
    for (NSNumber *mode in @[@(ScrollDirectionModeReversed), @(ScrollDirectionModeUnchanged)]) {
        [horizontalPopUp addItemWithTitle:SourceDirectionModeTitle([mode integerValue])];
        horizontalPopUp.lastItem.tag=[mode integerValue];
    }
    [horizontalPopUp bind:NSSelectedTagBinding toObject:row withKeyPath:@"horizontalMode" options:nil];

    nameField.enabled=self.editable;
    horizontalPopUp.enabled=self.editable;

    NSDateFormatter *const dateFormatter=[[NSDateFormatter alloc] init];
    dateFormatter.dateStyle=NSDateFormatterMediumStyle;
    dateFormatter.timeStyle=NSDateFormatterShortStyle;
    // the unit is in the label, so the value needs no plural forms
    NSString *const scrolled=[NSNumberFormatter localizedStringFromNumber:@(round(row.scrollTotal)) numberStyle:NSNumberFormatterDecimalStyle];

    NSMutableArray<NSArray<NSView *> *> *const rows=[NSMutableArray arrayWithArray:@[
        @[_title(NSLocalizedString(@"Name:", @"Source info: label before the source's name field")), nameField],
        @[_title(NSLocalizedString(@"Horizontal scrolling:", @"Source info: label before the horizontal scrolling menu")), horizontalPopUp],
        @[_title(NSLocalizedString(@"Kind:", @"Source info: label before the kind of source, such as Mouse or App")), _value(row.kindDescription)],
        @[_title(NSLocalizedString(@"Reported name:", @"Source info: label before the name the device or app reports")), _value(row.reportedName)],
        @[_title(NSLocalizedString(@"Identifier:", @"Source info: label before the identifier of the source's settings")), _value(row.key)],
    ]];
    if (row.path) {
        [rows addObject:@[_title(NSLocalizedString(@"Path:", @"Source info: label before the location of an app")), _value(row.path)]];
    }
    [rows addObjectsFromArray:@[
        @[_title(NSLocalizedString(@"Scrolling type:", @"Source info: label before Continuous or Discrete")), _value(row.scrollingTypeDescription)],
        @[_title(NSLocalizedString(@"System direction:", @"Source info: label before the direction the system delivers the source's scrolling in, such as Natural")), _value(row.systemDirectionDescription)],
        @[_title(NSLocalizedString(@"First seen:", @"Source info: label before the date the source first scrolled")), _value([dateFormatter stringFromDate:row.firstSeen])],
        @[_title(NSLocalizedString(@"Points scrolled:", @"Source info: label before the total distance the source has scrolled, as a number of points (the unit of distance on screen)")), _value(scrolled)],
    ]];

    NSGridView *const grid=[NSGridView gridViewWithViews:rows];
    grid.translatesAutoresizingMaskIntoConstraints=NO;
    grid.rowAlignment=NSGridRowAlignmentFirstBaseline;
    grid.rowSpacing=6;
    grid.columnSpacing=6;
    [grid columnAtIndex:0].xPlacement=NSGridCellPlacementTrailing;

    NSView *const view=[[NSView alloc] init];
    [view addSubview:grid];
    [NSLayoutConstraint activateConstraints:@[
        [grid.topAnchor constraintEqualToAnchor:view.topAnchor constant:14],
        [grid.leadingAnchor constraintEqualToAnchor:view.leadingAnchor constant:14],
        [view.trailingAnchor constraintEqualToAnchor:grid.trailingAnchor constant:14],
        [view.bottomAnchor constraintEqualToAnchor:grid.bottomAnchor constant:14],
    ]];
    self.view=view;
}

@end
