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
- (void)cursorUpdated:(NSData *)cursorData hotspot:(NSValue *)hotspot;
- (bool)pixelDataAvailable:(int)shmSize;
- (oneway void)pixelDataUpdated:(NSValue *)dirtyRect;
- (void)desktopResized:(int)shmSize;
- (void)setFrameSize:(NSSize)size;
- (ServerCredential *)serverCredential;

- (bool)validateCertificate:(NSString *)subject issuer:(NSString *)issuer fingerprint:(NSString *)fingerprint;
- (bool)validateX509Certificate:(NSData *)data hostname:(NSString *)hostname port:(int)port;
- (bool)provideServerCredentials:(NSString *)hostname username:(NSString *)username password:(NSString *)password domain:(NSString *)domain;
- (bool)provideGatewayServerCredentials:(NSString *)hostname username:(NSString *)username password:(NSString *)password domain:(NSString *)domain;

@property (nonatomic, readonly) id delegate;

@end
