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
}

@property (retain) NSString* serverHostname;
@property (retain) NSString* username;
@property (retain) NSString* password;

- (id)initWithHostName:(NSString *)hostName userName:(NSString *)userName andPassword:(NSString *)password;

@end
