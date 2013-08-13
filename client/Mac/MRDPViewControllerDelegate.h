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

- (void)didConnectWithResult:(int)result;
- (void)didErrorWithCode:(uint)code message:(NSString *)message;

@end
