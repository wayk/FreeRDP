//
//  ServerCertificate.h
//  FreeRDP
//
//  Created by Richard Markiewicz on 2013-09-26.
//
//

#import <Foundation/Foundation.h>

@interface ServerCertificate : NSObject
{
@public
    NSString* subject;
    NSString* issuer;
    NSString* fingerprint;
}

@property (retain) NSString* subject;
@property (retain) NSString* issuer;
@property (retain) NSString* fingerprint;

- (id)initWithSubject:(NSString *)subject issuer:(NSString *)issuer andFingerprint:(NSString *)fingerprint;

@end