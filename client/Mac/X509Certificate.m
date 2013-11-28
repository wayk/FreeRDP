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

- (id)initWithData:(NSData *)data hostname:(NSString *)hostname andPort:(int)port
{
    self = [super init];
    if(self)
    {
        self.data = data;
        self.hostname = hostname;
        self.port = port;
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