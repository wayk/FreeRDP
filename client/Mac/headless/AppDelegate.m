#import "AppDelegate.h"

#include <sys/types.h>
#include <sys/sysctl.h>

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification*)aNotification
{
    NSString *bundleDescription = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleLongVersionString"];
    NSLog(@"%@\n", bundleDescription);
    
    NSString *server = nil;
    parentProcessID = 0;
    NSArray *args = [[NSProcessInfo processInfo] arguments];
    
    if([args count] > 1)
    {
        server = args[1];
        parentProcessID = [args[2] intValue];
    }
    
    if([server length] > 0)
    {
        ipcClient = [[MRDPIPCClient alloc] initWithServer:server];
    }
    
    if(ipcClient == nil)
    {
        [NSApp terminate:nil];
    }
    
    [self setupDeadManSwitch];
}

- (void)setupDeadManSwitch
{
    NSNotificationCenter* center = [[NSWorkspace sharedWorkspace] notificationCenter];
    [center addObserver:self
               selector:@selector(appTerminated:)
                   name:NSWorkspaceDidTerminateApplicationNotification 
                 object:nil];
}

- (void)appTerminated:(NSNotification *)note
{
    int processID = [[[note userInfo] objectForKey:@"NSApplicationProcessIdentifier"] intValue];
    
    if(processID == parentProcessID)
    {
        [NSApp terminate:nil];
    }
}

- (void)applicationWillTerminate:(NSNotification*)notification
{

}

@end

