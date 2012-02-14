//
//  PFMoveApplication.m, version 1.7.2
//  LetsMove
//
//  Created by Andy Kim at Potion Factory LLC on 9/17/09
//
//  The contents of this file are dedicated to the public domain.

#import "PFMoveApplication.h"
#import "NSString+SymlinksAndAliases.h"
#import <Security/Security.h>
#import <dlfcn.h>

// Strings
// These are macros to be able to use custom i18n tools
#define _I10NS(nsstr) NSLocalizedStringFromTable(nsstr, @"MoveApplication", nil)
#define kStrMoveApplicationCouldNotMove _I10NS(@"Could not move to Applications folder")
#define kStrMoveApplicationQuestionTitle  _I10NS(@"Move to Applications folder?")
#define kStrMoveApplicationQuestionTitleHome _I10NS(@"Move to Applications folder in your Home folder?")
#define kStrMoveApplicationQuestionMessage _I10NS(@"I can move myself to the Applications folder if you'd like.")
#define kStrMoveApplicationButtonMove _I10NS(@"Move to Applications Folder")
#define kStrMoveApplicationButtonDoNotMove _I10NS(@"Do Not Move")
#define kStrMoveApplicationQuestionInfoWillRequirePasswd _I10NS(@"Note that this will require an administrator password.")
#define kStrMoveApplicationQuestionInfoInDownloadsFolder _I10NS(@"This will keep your Downloads folder uncluttered.")

// Needs to be defined for compiling under 10.4 SDK
#ifndef NSAppKitVersionNumber10_4
	#define NSAppKitVersionNumber10_4 824
#endif
// Needs to be defined for compiling under 10.5 SDK
#ifndef NSAppKitVersionNumber10_5
	#define NSAppKitVersionNumber10_5 949
#endif

// By default, we use a small control/font for the suppression button.
// If you prefer to use the system default (to match your other alerts),
// set this to 0.
#define PFUseSmallAlertSuppressCheckbox 1


static NSString *AlertSuppressKey = @"moveToApplicationsFolderAlertSuppress";


// Helper functions
static NSString *PreferredInstallLocation(BOOL *isUserDirectory);
static BOOL IsInApplicationsFolder(NSString *path);
static BOOL IsInDownloadsFolder(NSString *path);
static BOOL IsLaunchedFromDMG();
static BOOL Trash(NSString *path);
static BOOL AuthorizedInstall(NSString *srcPath, NSString *dstPath, BOOL *canceled);
static BOOL CopyBundle(NSString *srcPath, NSString *dstPath);
static void Relaunch();

// Main worker function
void PFMoveToApplicationsFolderIfNecessary() {
	// Skip if user suppressed the alert before
	if ([[NSUserDefaults standardUserDefaults] boolForKey:AlertSuppressKey]) return;

	// Path of the bundle
	NSString *bundlePath = [[NSBundle mainBundle] bundlePath];

	// Skip if the application is already in some Applications folder
	if (IsInApplicationsFolder(bundlePath)) return;

	// File Manager
	NSFileManager *fm = [NSFileManager defaultManager];

	BOOL isLaunchedFromDMG = IsLaunchedFromDMG();

	// Since we are good to go, get the preferred installation directory.
	BOOL installToUserApplications = NO;
	NSString *applicationsDirectory = PreferredInstallLocation(&installToUserApplications);
	NSString *bundleName = [bundlePath lastPathComponent];
	NSString *destinationPath = [applicationsDirectory stringByAppendingPathComponent:bundleName];

	// Check if we need admin password to write to the Applications directory
	BOOL needAuthorization = ([fm isWritableFileAtPath:applicationsDirectory] == NO);

	// Setup the alert
	NSAlert *alert = [[[NSAlert alloc] init] autorelease];
	{
		NSString *informativeText = nil;

		[alert setMessageText:(installToUserApplications ? kStrMoveApplicationQuestionTitleHome : kStrMoveApplicationQuestionTitle)];

		informativeText = kStrMoveApplicationQuestionMessage;

		if (needAuthorization) {
			informativeText = [informativeText stringByAppendingString:@" "];
			informativeText = [informativeText stringByAppendingString:kStrMoveApplicationQuestionInfoWillRequirePasswd];
		}
		else if (IsInDownloadsFolder(bundlePath)) {
			// Don't mention this stuff if we need authentication. The informative text is long enough as it is in that case.
			informativeText = [informativeText stringByAppendingString:@" "];
			informativeText = [informativeText stringByAppendingString:kStrMoveApplicationQuestionInfoInDownloadsFolder];
		}

		[alert setInformativeText:informativeText];

		// Add accept button
		[alert addButtonWithTitle:kStrMoveApplicationButtonMove];

		// Add deny button
		NSButton *cancelButton = [alert addButtonWithTitle:kStrMoveApplicationButtonDoNotMove];
		[cancelButton setKeyEquivalent:@"\e"];

#if MAC_OS_X_VERSION_MAX_ALLOWED > MAC_OS_X_VERSION_10_4
		if (floor(NSAppKitVersionNumber) > NSAppKitVersionNumber10_4) {
			// Setup suppression button
			[alert setShowsSuppressionButton:YES];

			if (PFUseSmallAlertSuppressCheckbox) {
				[[[alert suppressionButton] cell] setControlSize:NSSmallControlSize];
				[[[alert suppressionButton] cell] setFont:[NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];
			}
		}
#endif
	}

	// Activate app -- work-around for focus issues related to "scary file from internet" OS dialog.
	if (![NSApp isActive]) {
		[NSApp activateIgnoringOtherApps:YES];
	}

	if ([alert runModal] == NSAlertFirstButtonReturn) {
		NSLog(@"INFO -- Moving myself to the Applications folder");

		// Move
		if (needAuthorization) {
			BOOL authorizationCanceled;

			if (!AuthorizedInstall(bundlePath, destinationPath, &authorizationCanceled)) {
				if (authorizationCanceled) {
					NSLog(@"INFO -- Not moving because user canceled authorization");
					return;
				}
				else {
					NSLog(@"ERROR -- Could not copy myself to /Applications with authorization");
					goto fail;
				}
			}
		}
		else {
			// If a copy already exists in the Applications folder, put it in the Trash
			if ([fm fileExistsAtPath:destinationPath]) {
				// But first, make sure that it's not running
				BOOL destinationIsRunning = NO;

				// Use the shell to determine if the app is already running on systems 10.5 or lower
				if (floor(NSAppKitVersionNumber) <= NSAppKitVersionNumber10_5) {
					NSString *script = [NSString stringWithFormat:@"ps ax -o comm | grep '%@/' | grep -v grep >/dev/null", destinationPath];
					NSTask *task = [NSTask launchedTaskWithLaunchPath:@"/bin/sh" arguments:[NSArray arrayWithObjects:@"-c", script, nil]];
					[task waitUntilExit];

					// If the task terminated with status 0, it means that the final grep produced 1 or more lines of output.
					// Which means that the app is already running
					destinationIsRunning = ([task terminationStatus] == 0);
				}
				// Use the new API on 10.6 or higher
				else {
					for (NSRunningApplication *runningApplication in [[NSWorkspace sharedWorkspace] runningApplications]) {
						NSString *executablePath = [[runningApplication executableURL] path];
						if ([executablePath hasPrefix:destinationPath]) {
							destinationIsRunning = YES;
							break;
						}
					}
				}

				if (destinationIsRunning) {
					// Give the running app focus and terminate myself
					NSLog(@"INFO -- Switching to an already running version");
					[[NSTask launchedTaskWithLaunchPath:@"/usr/bin/open" arguments:[NSArray arrayWithObject:destinationPath]] waitUntilExit];
					exit(0);
				}
				else {
					if (!Trash([applicationsDirectory stringByAppendingPathComponent:bundleName]))
						goto fail;
				}
			}

 			if (!CopyBundle(bundlePath, destinationPath)) {
				NSLog(@"ERROR -- Could not copy myself to %@", destinationPath);
				goto fail;
			}
		}

		// Trash the original app. It's okay if this fails.
		// NOTE: This final delete does not work if the source bundle is in a network mounted volume.
		//       Calling rm or file manager's delete method doesn't work either. It's unlikely to happen
		//       but it'd be great if someone could fix this.
		if (!isLaunchedFromDMG && !Trash(bundlePath)) {
			NSLog(@"WARNING -- Could not delete application after moving it to Applications folder");
		}

		// Relaunch.
		Relaunch(destinationPath);
	}
	else {
		if (floor(NSAppKitVersionNumber) > NSAppKitVersionNumber10_4) {
			// Save the alert suppress preference if checked
#if MAC_OS_X_VERSION_MAX_ALLOWED > MAC_OS_X_VERSION_10_4
			if ([[alert suppressionButton] state] == NSOnState) {
				[[NSUserDefaults standardUserDefaults] setBool:YES forKey:AlertSuppressKey];
			}
#endif
		}
		else {
			// Always suppress after the first decline on 10.4 since there is no suppression checkbox
			[[NSUserDefaults standardUserDefaults] setBool:YES forKey:AlertSuppressKey];
		}
	}

	return;

fail:
	{
		// Show failure message
		alert = [[[NSAlert alloc] init] autorelease];
		[alert setMessageText:kStrMoveApplicationCouldNotMove];
		[alert runModal];
	}
}

#pragma mark -
#pragma mark Helper Functions

static NSString *PreferredInstallLocation(BOOL *isUserDirectory) {
	// Return the preferred install location.
	// Assume that if the user has a ~/Applications folder, they'd prefer their
	// applications to go there.

	NSFileManager *fm = [NSFileManager defaultManager];

	NSArray *userApplicationsDirs = NSSearchPathForDirectoriesInDomains(NSApplicationDirectory, NSUserDomainMask, YES);

	if ([userApplicationsDirs count] > 0) {
		NSString *userApplicationsDir = [userApplicationsDirs objectAtIndex:0];
		BOOL isDirectory;

		if ([fm fileExistsAtPath:userApplicationsDir isDirectory:&isDirectory] && isDirectory) {
			// User Applications directory exists. Get the directory contents.
			NSArray *contents = [fm contentsOfDirectoryAtPath:userApplicationsDir error:NULL];

			// Check if there is at least one ".app" inside the directory.
			for (NSString *contentsPath in contents) {
				if ([[contentsPath pathExtension] isEqualToString:@"app"]) {
					if (isUserDirectory) *isUserDirectory = YES;
					return [userApplicationsDir stringByResolvingSymlinksAndAliases];
				}
			}
		}
	}

	// No user Applications directory in use. Return the machine local Applications directory
	if (isUserDirectory) *isUserDirectory = NO;
	return [[NSSearchPathForDirectoriesInDomains(NSApplicationDirectory, NSLocalDomainMask, YES) lastObject] stringByResolvingSymlinksAndAliases];
}

static BOOL IsInApplicationsFolder(NSString *path) {
	// Check all the normal Application directories
	NSEnumerator *e = [NSSearchPathForDirectoriesInDomains(NSApplicationDirectory, NSAllDomainsMask, YES) objectEnumerator];
	NSString *appDirPath = nil;

	while ((appDirPath = [e nextObject])) {
		if ([path hasPrefix:appDirPath]) return YES;
	}

	// Also, handle the case that the user has some other Application directory (perhaps on a separate data partition).
	if ([[path pathComponents] containsObject:@"Applications"]) {
		return YES;
	}

	return NO;
}

static BOOL IsInDownloadsFolder(NSString *path) {
#if MAC_OS_X_VERSION_MAX_ALLOWED > MAC_OS_X_VERSION_10_4
	// 10.5 or higher has NSDownloadsDirectory
	if (floor(NSAppKitVersionNumber) > NSAppKitVersionNumber10_4) {
		NSEnumerator *e = [NSSearchPathForDirectoriesInDomains(NSDownloadsDirectory, NSAllDomainsMask, YES) objectEnumerator];
		NSString *downloadsDirPath = nil;

		while ((downloadsDirPath = [e nextObject])) {
			if ([path hasPrefix:downloadsDirPath]) return YES;
		}

		return NO;
	}
#endif
	// 10.4
	return [[[path stringByDeletingLastPathComponent] lastPathComponent] isEqualToString:@"Downloads"];
}

static BOOL IsLaunchedFromDMG() {
	// Guess if we have launched from a disk image
	NSString *bundlePath = [[NSBundle mainBundle] bundlePath];
	NSFileManager *fm = [NSFileManager defaultManager];
	BOOL bundlePathIsWritable = [fm isWritableFileAtPath:bundlePath];

	return [bundlePath hasPrefix:@"/Volumes/"] && !bundlePathIsWritable;
}

static BOOL Trash(NSString *path) {
	if ([[NSWorkspace sharedWorkspace] performFileOperation:NSWorkspaceRecycleOperation
													 source:[path stringByDeletingLastPathComponent]
												destination:@""
													  files:[NSArray arrayWithObject:[path lastPathComponent]]
														tag:NULL]) {
		return YES;
	}
	else {
		NSLog(@"ERROR -- Could not trash '%@'", path);
		return NO;
	}
}

static BOOL AuthorizedInstall(NSString *srcPath, NSString *dstPath, BOOL *canceled) {
	if (canceled) *canceled = NO;

	// Make sure that the destination path is an app bundle. We're essentially running 'sudo rm -rf'
	// so we really don't want to fuck this up.
	if (![dstPath hasSuffix:@".app"]) return NO;

	// Do some more checks
	if ([[dstPath stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] length] == 0) return NO;
	if ([[srcPath stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] length] == 0) return NO;

	int pid, status;
	AuthorizationRef myAuthorizationRef;

	// Get the authorization
	OSStatus err = AuthorizationCreate(NULL, kAuthorizationEmptyEnvironment, kAuthorizationFlagDefaults, &myAuthorizationRef);
	if (err != errAuthorizationSuccess) return NO;

	AuthorizationItem myItems = {kAuthorizationRightExecute, 0, NULL, 0};
	AuthorizationRights myRights = {1, &myItems};
	AuthorizationFlags myFlags = kAuthorizationFlagInteractionAllowed | kAuthorizationFlagPreAuthorize | kAuthorizationFlagExtendRights;

	err = AuthorizationCopyRights(myAuthorizationRef, &myRights, NULL, myFlags, NULL);
	if (err != errAuthorizationSuccess) {
		if (err == errAuthorizationCanceled && canceled)
			*canceled = YES;
		goto fail;
	}

	static OSStatus (*security_AuthorizationExecuteWithPrivileges)(AuthorizationRef authorization, const char *pathToTool,
																   AuthorizationFlags options, char * const *arguments,
																   FILE **communicationsPipe) = NULL;
	if (!security_AuthorizationExecuteWithPrivileges) {
		// On 10.7, AuthorizationExecuteWithPrivileges is deprecated. We want to still use it since there's no
		// good alternative (without requiring code signing). We'll look up the function through dyld and fail
		// if it is no longer accessible. If Apple removes the function entirely this will fail gracefully. If
		// they keep the function and throw some sort of exception, this won't fail gracefully, but that's a
		// risk we'll have to take for now.
		security_AuthorizationExecuteWithPrivileges = dlsym(RTLD_DEFAULT, "AuthorizationExecuteWithPrivileges");
	}
	if (!security_AuthorizationExecuteWithPrivileges) {
		goto fail;
	}

	// Delete the destination
	{
		char *args[] = {"-rf", (char *)[dstPath fileSystemRepresentation], NULL};
		err = security_AuthorizationExecuteWithPrivileges(myAuthorizationRef, "/bin/rm", kAuthorizationFlagDefaults, args, NULL);
		if (err != errAuthorizationSuccess) goto fail;

		// Wait until it's done
		pid = wait(&status);
		if (pid == -1 || !WIFEXITED(status)) goto fail; // We don't care about exit status as the destination most likely does not exist
	}

	// Copy
	{
		char *args[] = {"-pR", (char *)[srcPath fileSystemRepresentation], (char *)[dstPath fileSystemRepresentation], NULL};
		err = security_AuthorizationExecuteWithPrivileges(myAuthorizationRef, "/bin/cp", kAuthorizationFlagDefaults, args, NULL);
		if (err != errAuthorizationSuccess) goto fail;

		// Wait until it's done
		pid = wait(&status);
		if (pid == -1 || !WIFEXITED(status) || WEXITSTATUS(status)) goto fail;
	}

	AuthorizationFree(myAuthorizationRef, kAuthorizationFlagDefaults);
	return YES;

fail:
	AuthorizationFree(myAuthorizationRef, kAuthorizationFlagDefaults);
	return NO;
}

static BOOL CopyBundle(NSString *srcPath, NSString *dstPath) {
	NSFileManager *fm = [NSFileManager defaultManager];

#if MAC_OS_X_VERSION_MAX_ALLOWED > MAC_OS_X_VERSION_10_4
	// 10.5 or higher
	if (floor(NSAppKitVersionNumber) > NSAppKitVersionNumber10_4) {
		NSError *error = nil;
		if ([fm copyItemAtPath:srcPath toPath:dstPath error:&error]) {
			return YES;
		}
		else {
			NSLog(@"ERROR -- Could not copy '%@' to '%@' (%@)", srcPath, dstPath, error);
		}
	}
#endif
#if MAC_OS_X_VERSION_MIN_REQUIRED <= MAC_OS_X_VERSION_10_4
	if ([fm copyPath:srcPath toPath:dstPath handler:nil]) {
		return YES;
	}
	else {
		NSLog(@"ERROR -- Could not copy '%@' to '%@'", srcPath, dstPath);
	}
#endif
	return NO;
}

static void Relaunch(NSString *destinationPath) {
	// The shell script waits until the original app process terminates.
	// This is done so that the relaunched app opens as the front-most app.
	int pid = [[NSProcessInfo processInfo] processIdentifier];

	// Command run just before running open /final/path
	NSString *preOpenCmd = @"";

	// OS X >=10.5:
	// Before we launch the new app, clear xattr:com.apple.quarantine to avoid
	// duplicate "scary file from the internet" dialog.
#if MAC_OS_X_VERSION_MAX_ALLOWED > MAC_OS_X_VERSION_10_4
	if (floor(NSAppKitVersionNumber) > NSAppKitVersionNumber10_5) {
		// Add the -r flag on 10.6
		preOpenCmd = [NSString stringWithFormat:@"/usr/bin/xattr -d -r com.apple.quarantine '%@';", destinationPath];
	}
	else if (floor(NSAppKitVersionNumber) > NSAppKitVersionNumber10_4) {
		preOpenCmd = [NSString stringWithFormat:@"/usr/bin/xattr -d com.apple.quarantine '%@';", destinationPath];
	}
#endif

	NSString *script = [NSString stringWithFormat:@"(while [ `ps -p %d | wc -l` -gt 1 ]; do sleep 0.1; done; %@ open '%@') &", pid, preOpenCmd, destinationPath];

	[NSTask launchedTaskWithLaunchPath:@"/bin/sh" arguments:[NSArray arrayWithObjects:@"-c", script, nil]];

	// Launched from within a DMG? -- unmount (if no files are open after 5 seconds,
	// otherwise leave it mounted).
	if (IsLaunchedFromDMG()) {
		script = [NSString stringWithFormat:@"(sleep 5 && hdiutil detach '%@') &", [[[NSBundle mainBundle] bundlePath] stringByDeletingLastPathComponent]];
		[NSTask launchedTaskWithLaunchPath:@"/bin/sh" arguments:[NSArray arrayWithObjects:@"-c", script, nil]];
	}

	exit(0);
}