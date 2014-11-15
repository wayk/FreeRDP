//
//  MRDPIPCClient.h
//  FreeRDP
//
//  Created by Richard Markiewicz on 2014-11-15.
//
//

#import <Foundation/Foundation.h>

@interface MRDPIPCClient : NSObject
{
    id serverProxy;
}

- (id)initWithServer:(NSString *)registeredName;

@end
