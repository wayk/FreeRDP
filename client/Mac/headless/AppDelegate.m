#import "AppDelegate.h"

#include <sys/types.h>
#include <sys/sysctl.h>

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification*)aNotification
{
    // Trying to programmatically managed SHMMAX
//    // shmall
//    // Now: 1024 (1024 * 4096 = 4194304)
//    // To: 10240
//    uint64_t memA;
//    size_t lenA = sizeof(memA);
//    
//    uint64_t newMemA = 10240;
//    size_t newLenA = sizeof(newMemA);
//    
//    int resultone = sysctlbyname("kern.sysv.shmall", &memA, &lenA, nil, 0);
//    
//    NSLog(@"Failed: %s (%d)", strerror(errno), errno);
//    
//    // SHMMAX
//    // Now: 4194304
//    // To: 41943040
//    uint64_t mem;
//    size_t len = sizeof(mem);
//    
//    uint64_t newMem = 41943040;
//    size_t newLen = sizeof(newMem);
//    
//    int resulttwo = sysctlbyname("kern.sysv.shmmax", &mem, &len, nil, 0);
//
//    NSLog(@"Failed: %s (%d)", strerror(errno), errno);
    
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

