//
//  NSString+SymlinksAndAliases.h
//  ResolvePath
//
//  Created by Matt Gallagher on 2010/02/22.
//  Copyright 2010 Matt Gallagher. All rights reserved.
//
//  Permission is given to use this source code file, free of charge, in any
//  project, commercial or otherwise, entirely at your risk, with the condition
//  that any redistribution (in part or whole) of source code must retain
//  this copyright and permission notice. Attribution in compiled projects is
//  appreciated but not required.
//

#import <Cocoa/Cocoa.h>

@interface NSString (SymlinksAndAliases)

- (NSString *)stringByResolvingSymlinksAndAliases;
- (NSString *)stringByIterativelyResolvingSymlinkOrAlias;

- (NSString *)stringByResolvingSymlink;
- (NSString *)stringByConditionallyResolvingSymlink;

- (NSString *)stringByResolvingAlias;
- (NSString *)stringByConditionallyResolvingAlias;

@end
