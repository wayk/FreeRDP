//
//  ServerCertificate.m
//  FreeRDP
//
//  Created by Richard Markiewicz on 2013-09-26.
//
//

#import "ServerCertificate.h"

@implementation ServerCertificate

@synthesize subject;
@synthesize issuer;
@synthesize fingerprint;

- (id)initWithSubject:(NSString *)subject issuer:(NSString *)issuer andFingerprint:(NSString *)fingerprint
{
    self = [super init];
    if(self)
    {
        self.subject = subject;
        self.issuer = issuer;
        self.fingerprint = fingerprint;
    }
    
    return self;
}

- (void)dealloc
{
    [subject release];
    [issuer release];
    [fingerprint release];
    
    [super dealloc];
}

@end
