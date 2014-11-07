#import <Foundation/Foundation.h>
#import "AppDelegate.h"

int main(int argc, const char * argv[])
{
    AppDelegate * delegate = [[AppDelegate alloc] init];
    
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
    
    NSApplication * application = [NSApplication sharedApplication];
    [application setDelegate:delegate];
    [NSApp run];
    
    [pool drain];
    
    [delegate release];
}
