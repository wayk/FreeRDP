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

@protocol MRDPViewDelegate <NSObject>

- (BOOL)provideServerCredentials:(ServerCredential **)credentials;
- (BOOL)validateCertificate:(ServerCertificate *)certificate;

@end
