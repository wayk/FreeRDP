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

- (id)initWithSubject:(NSString *)newSubject issuer:(NSString *)newIssuer andFingerprint:(NSString *)newFingerprint
{
    self = [super init];
    if(self)
    {
        self.subject = newSubject;
        self.issuer = newIssuer;
        self.fingerprint = newFingerprint;
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
