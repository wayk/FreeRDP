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

@protocol MRDPViewControllerDelegate <NSObject, MRDPViewDelegate>
@optional
- (void)didConnect;
- (void)didFailToConnectWithError:(NSNumber *)connectErrorCode;
- (void)didErrorWithCode:(NSNumber *)code;
- (BOOL)provideServerCredentials:(ServerCredential **)credentials;
- (BOOL)validateCertificate:(ServerCertificate *)certificate;

@end
