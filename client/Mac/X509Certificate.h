//
//  X509Certificate.h
//  FreeRDP
//
//  Created by Richard Markiewicz on 11/28/2013.
//
//

#import <Foundation/Foundation.h>

@interface X509Certificate : NSObject
{
@public
    NSData* data;
    NSString* hostname;
    int port;
}

@property (retain) NSData* data;
@property (retain) NSString* hostname;
@property (nonatomic) int port;

- (id)initWithData:(NSData *)data hostname:(NSString *)hostname andPort:(int)port;

@end
