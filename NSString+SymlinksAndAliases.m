//
//  NSString+SymlinksAndAliases.m
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

#import "NSString+SymlinksAndAliases.h"
#include <sys/stat.h>

@implementation NSString (SymlinksAndAliases)

//
// stringByResolvingSymlinksAndAliases
//
// Tries to make a standardized, absolute path from the current string,
// resolving any aliases or symlinks in the path.
//
// returns the fully resolved path (if possible) or nil (if resolution fails)
//
- (NSString *)stringByResolvingSymlinksAndAliases
{
	//
	// Convert to a standardized absolute path.
	//
	NSString *path = [self stringByStandardizingPath];
	if (![path hasPrefix:@"/"])
	{
		return nil;
	}

	//
	// Break into components. First component ("/") needs no resolution, so
	// we only need to handle subsequent components.
	//
	NSArray *pathComponents = [path pathComponents];
	NSString *resolvedPath = [pathComponents objectAtIndex:0];
	pathComponents = [pathComponents
		subarrayWithRange:NSMakeRange(1, [pathComponents count] - 1)];

	//
	// Process all remaining components.
	//
	for (NSString *component in pathComponents)
	{
		resolvedPath = [resolvedPath stringByAppendingPathComponent:component];
		resolvedPath = [resolvedPath stringByIterativelyResolvingSymlinkOrAlias];
		if (!resolvedPath)
		{
			return nil;
		}
	}

	return resolvedPath;
}

//
// stringByIterativelyResolvingSymlinkOrAlias
//
// Resolves the path where the final component could be a symlink and any
// component could be an alias.
//
// returns the resolved path
//
- (NSString *)stringByIterativelyResolvingSymlinkOrAlias
{
	NSString *path = self;
	NSString *aliasTarget = nil;
	struct stat fileInfo;

	//
	// Use lstat to determine if the file is a symlink
	//
	if (lstat([[NSFileManager defaultManager]
		fileSystemRepresentationWithPath:path], &fileInfo) < 0)
	{
		return nil;
	}

	//
	// While the file is a symlink or we can resolve aliases in the path,
	// keep resolving.
	//
	while (S_ISLNK(fileInfo.st_mode) ||
		(!S_ISDIR(fileInfo.st_mode) &&
			(aliasTarget = [path stringByConditionallyResolvingAlias]) != nil))
	{
		if (S_ISLNK(fileInfo.st_mode))
		{
			//
			// Resolve the symlink final component in the path
			//
			NSString *symlinkPath = [path stringByConditionallyResolvingSymlink];
			if (!symlinkPath)
			{
				return nil;
			}
			path = symlinkPath;
		}
		else
		{
			path = aliasTarget;
		}

		//
		// Use lstat to determine if the file is a symlink
		//
		if (lstat([[NSFileManager defaultManager]
			fileSystemRepresentationWithPath:path], &fileInfo) < 0)
		{
			path = nil;
			continue;
		}
	}

	return path;
}

//
// stringByResolvingAlias
//
// Attempts to resolve the single alias at the end of the path.
//
// returns the resolved alias or self if path wasn't an alias or couldn't be
//	resolved.
//
- (NSString *)stringByResolvingAlias
{
	NSString *aliasTarget = [self stringByConditionallyResolvingAlias];
	if (aliasTarget)
	{
		return aliasTarget;
	}
	return self;
}

//
// stringByResolvingSymlink
//
// Attempts to resolve the single symlink at the end of the path.
//
// returns the resolved path or self if path wasn't a symlink or couldn't be
//	resolved.
//
- (NSString *)stringByResolvingSymlink
{
	NSString *symlinkTarget = [self stringByConditionallyResolvingSymlink];
	if (symlinkTarget)
	{
		return symlinkTarget;
	}
	return self;
}

//
// stringByConditionallyResolvingSymlink
//
// Attempt to resolve the symlink pointed to by the path.
//
// returns the resolved path (if it was a symlink and resolution is possible)
//	otherwise nil
//
- (NSString *)stringByConditionallyResolvingSymlink
{
	//
	// Resolve the symlink final component in the path
	//
	NSString *symlinkPath =
		[[NSFileManager defaultManager]
			destinationOfSymbolicLinkAtPath:self
			error:NULL];
	if (!symlinkPath)
	{
		return nil;
	}
	if (![symlinkPath hasPrefix:@"/"])
	{
		//
		// For relative path symlinks (common case), remove the
		// relative links
		//
		symlinkPath =
			[[self stringByDeletingLastPathComponent]
				stringByAppendingPathComponent:symlinkPath];
		symlinkPath = [symlinkPath stringByStandardizingPath];
	}
	return symlinkPath;
}

//
// stringByConditionallyResolvingAlias
//
// Attempt to resolve the alias pointed to by the path.
//
// returns the resolved path (if it was an alias and resolution is possible)
//	otherwise nil
//
- (NSString *)stringByConditionallyResolvingAlias
{
	NSString *resolvedPath = nil;

	CFURLRef url = CFURLCreateWithFileSystemPath
		(kCFAllocatorDefault, (CFStringRef)self, kCFURLPOSIXPathStyle, NO);
	if (url != NULL)
	{
		FSRef fsRef;
		if (CFURLGetFSRef(url, &fsRef))
		{
			Boolean targetIsFolder, wasAliased;
			OSErr err = FSResolveAliasFileWithMountFlags(
				&fsRef, false, &targetIsFolder, &wasAliased, kResolveAliasFileNoUI);
			if ((err == noErr) && wasAliased)
			{
				CFURLRef resolvedUrl = CFURLCreateFromFSRef(kCFAllocatorDefault, &fsRef);
				if (resolvedUrl != NULL)
				{
					resolvedPath =
						[(id)NSMakeCollectable(CFURLCopyFileSystemPath(resolvedUrl, kCFURLPOSIXPathStyle))
							autorelease];
					CFRelease(resolvedUrl);
				}
			}
		}
		CFRelease(url);
	}

	return resolvedPath;
}

@end
