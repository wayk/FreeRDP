//
//  MRDPScrollView.m
//  FreeRDP
//
//  Created by Richard Markiewicz on 2013-09-23.
//
//

#import "MRDPScrollView.h"

// Replacement for NSScrollView that ignores scroll from the mouse wheel
@implementation MRDPScrollView

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code here.
    }
    
    return self;
}

- (void)scrollWheel:(NSEvent *)theEvent
{
    // Disable scrolling with the mousewheel
}

@end
