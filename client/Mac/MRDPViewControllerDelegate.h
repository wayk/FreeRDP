//
//  MRDPViewControllerDelegate.h
//  FreeRDP
//
//  Created by Richard Markiewicz on 2013-07-31.
//
//

#import <Foundation/Foundation.h>

#import "ServerCredential.h"

@protocol MRDPViewControllerDelegate <NSObject, MRDPViewPasswordPromptDelegate>
@optional
- (void)didConnectWithResult:(NSNumber *)result;
- (void)didErrorWithCode:(NSNumber *)code;

@end
