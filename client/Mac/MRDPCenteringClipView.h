//
//  MRDPCenteringClipView.h
//  FreeRDP
//
//  Created by Richard Markiewicz on 2013-09-23.
//
//

#import <Cocoa/Cocoa.h>

@interface MRDPCenteringClipView : NSClipView
{
    NSPoint viewPoint;
}

- (id)initWithFrame:(NSRect)frame;
- (void)centerView;
// NSClipView Method Overrides
- (NSPoint)constrainScrollPoint:(NSPoint)proposedNewOrigin;
- (void)viewBoundsChanged:(NSNotification*)notification;
- (void)viewFrameChanged:(NSNotification*)notification;
- (void)setFrame:(NSRect)frameRect;
- (void)setFrameOrigin:(NSPoint)newOrigin;
- (void)setFrameSize:(NSSize)newSize;
- (void)setFrameRotation:(CGFloat)angle;

@end
