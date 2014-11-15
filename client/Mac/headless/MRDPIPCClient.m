//
//  MRDPIPCClient.m
//  FreeRDP
//
//  Created by Richard Markiewicz on 2014-11-15.
//
//

#import <Foundation/Foundation.h>

#import "MRDPIPCClient.h"
#import "MRDPIPCServer.h"

@implementation MRDPIPCClient

- (id)initWithServer:(NSString *)registeredName
{
    self = [super init];
    if(self)
    {
        serverProxy = (id)[NSConnection rootProxyForConnectionWithRegisteredName:registeredName host:nil];
        [serverProxy setProtocolForProxy:@protocol(MRDPIPCServer)];
        
        if(serverProxy == nil)
        {
            NSLog(@"Failed to establish IPC connection to %@", registeredName);
            
            [self release];
            
            return nil;
        }
        
        [serverProxy clientConnected];
    }
    
    return self;
}

@end
