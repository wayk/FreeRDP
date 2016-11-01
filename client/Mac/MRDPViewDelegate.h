//
//  MRDPViewDelegate.h
//  FreeRDP
//
//  Created by Richard Markiewicz on 2013-09-13.
//
//

#import <Foundation/Foundation.h>

#import "ServerCredential.h"
#import "ServerCertificate.h"
#import "X509Certificate.h"

@protocol MRDPViewDelegate <NSObject>

- (BOOL)provideGatewayServerCredentials:(ServerCredential **)credentials;
- (BOOL)provideServerCredentials:(ServerCredential **)credentials;
- (BOOL)validateCertificate:(ServerCertificate *)certificate;
- (BOOL)validateX509Certificate:(X509Certificate *)certificate;
- (NSArray *)getForwardedServerDrives;

@end
