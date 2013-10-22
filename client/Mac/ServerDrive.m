//
//  ServerDrive.m
//  FreeRDP
//
//  Created by Richard Markiewicz on 2013-10-21.
//
//

#import "ServerDrive.h"

@implementation ServerDrive

@synthesize name;
@synthesize path;

- (id)initWithName:(NSString *)name andPath:(NSString *)path
{
    self = [super init];
    if(self)
    {
        self.name = name;
        self.path = path;
    }
    
    return self;
}

- (void) dealloc
{
    [name release];
    [path release];
    
    [super dealloc];
}

@end
