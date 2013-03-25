#import "NSObject+ObservePrefs.h"

@implementation NSObject (ObservePrefs)

- (void)observePrefsKey:(NSString *)key
{
	[[NSUserDefaultsController sharedUserDefaultsController] addObserver:self
															  forKeyPath:[@"values." stringByAppendingString:key]
																 options:0
																 context:nil];
}

@end
