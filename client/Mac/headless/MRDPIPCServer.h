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

- (NSString *)proxyName;
- (NSString *)proxyID;
- (void)clientConnected:(NSString *)clientName;
- (void)pixelDataAvailable:(int)shmId size:(int)shmSize;
- (void)pixelDataUpdated:(NSValue *)dirtyRect;

@property (nonatomic, readonly) id delegate;

@end
