#import "LoginItemsController.h"

// Login items change callback.
static void _loginItemsChanged(LSSharedFileListRef listRef, void *context)
{
    LoginItemsController *controller=(__bridge LoginItemsController *)(context);
    [controller willChangeValueForKey:@"startAtLogin"];
    [controller didChangeValueForKey:@"startAtLogin"];
}

@implementation LoginItemsController

- (id)init
{
    self = [super init];
    if (self) {
        loginItems=LSSharedFileListCreate(NULL, kLSSharedFileListSessionLoginItems, NULL);
        
        // Add an observer so we can update the UI if changed externally.
        LSSharedFileListAddObserver(loginItems,
                                    CFRunLoopGetMain(),
                                    kCFRunLoopCommonModes,
                                    _loginItemsChanged,
                                    (__bridge void *)(self));
        
        // Add cleanup routine for application termination.
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(cleanup)
                                                     name:NSApplicationWillTerminateNotification
                                                   object:nil];
    }
    return self;
}

- (void)cleanup
{
	LSSharedFileListRemoveObserver(loginItems,
								   CFRunLoopGetMain(),
								   kCFRunLoopCommonModes,
								   _loginItemsChanged,
								   (__bridge void *)(self));
}

- (BOOL)startAtLoginWithURL:(NSURL *)itemURL;
{
	Boolean foundIt=false;
	UInt32 seed = 0U;
	NSArray *currentLoginItems = (NSArray *)CFBridgingRelease(LSSharedFileListCopySnapshot(loginItems, &seed));

	for (unsigned i=0; i<[currentLoginItems count]; i++) {
		id itemObject=currentLoginItems[i];
		LSSharedFileListItemRef item = (__bridge LSSharedFileListItemRef)itemObject;
		
		UInt32 resolutionFlags = kLSSharedFileListNoUserInteraction | kLSSharedFileListDoNotMountVolumes;
		CFURLRef URL = NULL;
		OSStatus err = LSSharedFileListItemResolve(item, resolutionFlags, &URL, /*outRef*/ NULL);
		if (err == noErr) {
			foundIt = CFEqual(URL, (__bridge CFTypeRef)(itemURL));
			CFRelease(URL);
			
			if (foundIt)
				break;
		}
	}
	return (BOOL)foundIt;
}

- (void)setStartAtLogin:(BOOL)enabled withURL:(NSURL *)itemURL;
{
	[self willChangeValueForKey:@"startAtLogin"];
	LSSharedFileListItemRef existingItem = NULL;

	UInt32 seed = 0U;
	NSArray *currentLoginItems = (NSArray *)CFBridgingRelease(LSSharedFileListCopySnapshot(loginItems, &seed));
	for (unsigned i=0; i<[currentLoginItems count]; i++) {
		id itemObject=currentLoginItems[i];

		LSSharedFileListItemRef item = (__bridge LSSharedFileListItemRef)itemObject;
		
		UInt32 resolutionFlags = kLSSharedFileListNoUserInteraction | kLSSharedFileListDoNotMountVolumes;
		CFURLRef URL = NULL;
		OSStatus err = LSSharedFileListItemResolve(item, resolutionFlags, &URL, /*outRef*/ NULL);
		if (err == noErr) {
			Boolean foundIt = CFEqual(URL, (__bridge CFTypeRef)(itemURL));
			CFRelease(URL);
			
			if (foundIt) {
				existingItem = item;
				break;
			}
		}
	}
	
	if (enabled && (existingItem == NULL)) {
		LSSharedFileListInsertItemURL(loginItems, kLSSharedFileListItemBeforeFirst,
									  NULL, NULL, (__bridge CFURLRef)itemURL, NULL, NULL);
	
	} else if (!enabled && (existingItem != NULL)) {
		LSSharedFileListItemRemove(loginItems, existingItem);
	}
	[self didChangeValueForKey:@"startAtLogin"];
}

- (BOOL)startAtLogin
{
	return [self startAtLoginWithURL:[NSURL fileURLWithPath:[[NSBundle mainBundle] bundlePath]]];
}

- (void)setStartAtLogin:(BOOL)enabled 
{
	[self setStartAtLogin:enabled withURL:[NSURL fileURLWithPath:[[NSBundle mainBundle] bundlePath]]];
}

@end
