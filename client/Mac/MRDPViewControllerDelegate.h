//
//  MRDPViewControllerDelegate.h
//  FreeRDP
//
//  Created by Richard Markiewicz on 2013-07-31.
//
//

#import <Foundation/Foundation.h>

#import "ServerCredential.h"
#import "ServerCertificate.h"
#import "X509Certificate.h"

@protocol MRDPViewControllerDelegate <NSObject, MRDPViewDelegate>
@optional
- (void)willReconnect;
- (void)didConnect;
- (void)didFailToConnectWithError:(NSNumber *)connectErrorCode;
- (void)didErrorWithCode:(NSNumber *)code;

- (BOOL)provideGatewayServerCredentials:(ServerCredential **)credentials;
- (BOOL)provideServerCredentials:(ServerCredential **)credentials;
- (BOOL)validateCertificate:(ServerCertificate *)certificate;
- (BOOL)validateX509Certificate:(X509Certificate *)certificate;
- (void)initializeLogging;

@end
