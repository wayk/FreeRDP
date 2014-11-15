//
//  MRDPClientDelegate.h
//  FreeRDP
//
//  Created by Richard Markiewicz on 2014-11-09.
//
//

#import <Foundation/Foundation.h>

#import "ServerCredential.h"
#import "ServerCertificate.h"
#import "X509Certificate.h"

@protocol MRDPClientDelegate <NSObject>

@required

// TODO: Move is_connected up to the client
@property (assign) int is_connected;
@property (readonly) NSRect frame;

- (void)initialise:(rdpContext *)rdpContext;
- (void)setNeedsDisplayInRect:(NSRect)newDrawRect;
- (void)setCursor:(NSCursor*) cursor;
- (void)preConnect:(freerdp*)rdpInstance;
- (void)postConnect:(freerdp*)rdpInstance;
- (void)pause;
- (void)resume;
- (void)releaseResources;
- (BOOL)provideServerCredentials:(ServerCredential **)credentials;
- (BOOL)validateCertificate:(ServerCertificate *)certificate;
- (BOOL)validateX509Certificate:(X509Certificate *)certificate;

@end
