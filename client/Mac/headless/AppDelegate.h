#import <Cocoa/Cocoa.h>

#import "MRDPIPCClient.h"

@interface AppDelegate : NSObject <NSApplicationDelegate>
{
    MRDPIPCClient *ipcClient;
    int parentProcessID;
}

@end
