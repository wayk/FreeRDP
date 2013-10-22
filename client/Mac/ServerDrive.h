//
//  ServerDrive.h
//  FreeRDP
//
//  Created by Richard Markiewicz on 2013-10-21.
//
//

#import <Foundation/Foundation.h>

@interface ServerDrive : NSObject
{
@public
    NSString* name;
    NSString* path;
}

@property (retain) NSString* name;
@property (retain) NSString* path;

- (id)initWithName:(NSString *)name andPath:(NSString *)path;

@end