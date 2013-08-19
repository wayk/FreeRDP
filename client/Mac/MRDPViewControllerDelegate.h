//
//  MRDPViewControllerDelegate.h
//  FreeRDP
//
//  Created by Richard Markiewicz on 2013-07-31.
//
//

#import <Foundation/Foundation.h>

@protocol MRDPViewControllerDelegate <NSObject>
@optional

- (void)didConnectWithResult:(NSNumber *)result;
- (void)didErrorWithCode:(NSNumber *)code;

@end
