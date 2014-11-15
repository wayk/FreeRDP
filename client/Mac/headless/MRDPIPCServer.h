//
//  MRDPIPCServer.h
//  FreeRDP
//
//  Created by Richard Markiewicz on 2014-11-15.
//
//

#import <Foundation/Foundation.h>

@protocol MRDPIPCServer <NSObject>

@required

- (NSString *)serverName;
- (NSString *)serverId;
- (void)clientConnected:(NSString *)clientName;

@end
