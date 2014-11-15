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

static NSString* const clientBaseName = @"com.devolutions.mrdp-ipc-client";

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
        
        NSString *serverID = [serverProxy serverId];
        NSString *clientName = [NSString stringWithFormat:@"%@.%@", clientBaseName, serverID];
        
        clientConnection = [NSConnection serviceConnectionWithName:clientName rootObject:self];
        [clientConnection runInNewThread];
        [clientConnection registerName:clientName];
        
        NSLog(@"Launched IPC server at %@", clientName);
        
        [serverProxy clientConnected:clientName];
    }
    
    return self;
}

@end
