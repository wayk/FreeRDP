#import "AppDelegate.h"

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification*)aNotification
{
    NSString *bundleDescription = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleLongVersionString"];
    NSLog(@"%@", bundleDescription);
    
    NSString *server = nil;
    NSArray *args = [[NSProcessInfo processInfo] arguments];
    
    if([args count] > 1)
    {
        server = args[1];
    }
    
    if([server length] > 0)
    {
        ipcClient = [[MRDPIPCClient alloc] initWithServer:server];
    }
    
    if(ipcClient == nil)
    {
        [NSApp terminate:nil];
    }
}

- (void)applicationWillTerminate:(NSNotification*)notification
{

}

@end

