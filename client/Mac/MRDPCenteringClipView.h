//
//  MRDPCenteringClipView.h
//  FreeRDP
//
//  Created by Richard Markiewicz on 2013-09-23.
//
//

/**************************
 * An NSClipView subclass that keeps the document view centered
 * Implementation is from // http://programerror.com/2011/04/centering-custom-views-inside-an-nsscrollview/
 *
 * Leaving this in unmanaged code for now, as porting to C# introduces problems
 * Specifically, a crash when accessing this.DocumentView inside CenterView()
 *************************/

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
