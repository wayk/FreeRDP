//
//  ServerCredential.m
//  FreeRDP
//
//  Created by Richard Markiewicz on 2013-09-13.
//
//

#import "ServerCredential.h"

@implementation ServerCredential

@synthesize serverHostname;
@synthesize username;
@synthesize password;
@synthesize domain;

- (id)initWithHostName:(NSString *)hostName domain:(NSString*)domain userName:(NSString *)userName andPassword:(NSString *)password;
{
    self = [super init];
    if(self)
    {
        self.serverHostname = hostName;
        self.username = userName;
        self.password = password;
        self.domain = domain;
    }
    
    return self;
}

- (void) dealloc
{
    [serverHostname release];
    [username release];
    [password release];
    [domain release];
    
    [super dealloc];
}

@end
