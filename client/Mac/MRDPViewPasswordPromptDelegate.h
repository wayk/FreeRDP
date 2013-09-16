//
//  MRDPViewPasswordPromptDelegate.h
//  FreeRDP
//
//  Created by Richard Markiewicz on 2013-09-13.
//
//

#import <Foundation/Foundation.h>

#import "ServerCredential.h"

@protocol MRDPViewPasswordPromptDelegate <NSObject>

- (BOOL)provideServerCredentials:(ServerCredential **)credentials;

@end
