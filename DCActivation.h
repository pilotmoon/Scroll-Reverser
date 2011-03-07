#import <Foundation/Foundation.h>
@protocol Activation

@property (assign, getter=isActive) BOOL active;
- (void)start;
- (void)stop;

@end
