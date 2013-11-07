//
//  ServerCredential.h
//  FreeRDP
//
//  Created by Richard Markiewicz on 2013-09-13.
//
//

#import <Foundation/Foundation.h>

@interface ServerCredential : NSObject
{
@public
    NSString* serverHostname;
    NSString* username;
    NSString* password;
    NSString* domain;
}

@property (retain) NSString* serverHostname;
@property (retain) NSString* username;
@property (retain) NSString* password;
@property (retain) NSString* domain;

- (id)initWithHostName:(NSString *)hostName domain:(NSString*)domain userName:(NSString *)userName andPassword:(NSString *)password;

@end
