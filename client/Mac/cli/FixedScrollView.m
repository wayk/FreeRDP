//
//  FixedScrollView.m
//  FreeRDP
//
//  Created by Richard Markiewicz on 11/14/2013.
//
//

#import "FixedScrollView.h"

@implementation FixedScrollView

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code here.
    }
    return self;
}

- (void)drawRect:(NSRect)dirtyRect
{
	[super drawRect:dirtyRect];
	
    // Drawing code here.
}

- (void)scrollWheel:(NSEvent *)theEvent
{
    // Nothing...
}

@end
