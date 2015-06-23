//
//  X509Certificate.m
//  FreeRDP
//
//  Created by Richard Markiewicz on 11/28/2013.
//
//

#import "X509Certificate.h"

@implementation X509Certificate

@synthesize data;
@synthesize hostname;
@synthesize port;

- (id)initWithData:(NSData *)newData hostname:(NSString *)newHostName andPort:(int)newPort
{
    self = [super init];
    if(self)
    {
        self.data = newData;
        self.hostname = newHostName;
        self.port = newPort;
    }
    
    return self;
}

- (void)dealloc
{
    [data release];
    [hostname release];
    
    [super dealloc];
}

@end