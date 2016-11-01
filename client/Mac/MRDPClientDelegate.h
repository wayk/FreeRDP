//
//  MRDPClientDelegate.h
//  FreeRDP
//
//  Created by Richard Markiewicz on 2014-11-09.
//
//

#import <Foundation/Foundation.h>

#import "MRDPCursor.h"
#import "ServerCredential.h"
#import "ServerCertificate.h"
#import "X509Certificate.h"

@protocol MRDPClientDelegate <NSObject>

@required

@property (readonly) NSRect frame;
@property (readonly) bool renderToBuffer;
@property (readonly) NSString* renderBufferName;

- (NSArray *)getForwardedServerDrives;
- (void)initialise:(rdpContext *)rdpContext;
- (void)setNeedsDisplayInRect:(NSRect)newDrawRect;
- (void)setCursor:(MRDPCursor*) cursor;
- (void)preConnect:(freerdp*)rdpInstance;
- (bool)postConnect:(freerdp*)rdpInstance;
- (void)pause;
- (void)resume;
- (void)releaseResources;
- (void)willResizeDesktop;
- (BOOL)didResizeDesktop;
- (BOOL)provideServerCredentials:(ServerCredential **)credentials;
- (BOOL)provideGatewayServerCredentials:(ServerCredential **)credentials;
- (BOOL)validateCertificate:(ServerCertificate *)certificate;
- (BOOL)validateX509Certificate:(X509Certificate *)certificate;

@end
