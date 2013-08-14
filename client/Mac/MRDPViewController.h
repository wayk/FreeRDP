//
//  MRDPViewController.h
//  FreeRDP
//
//  Created by Richard Markiewicz on 2013-07-23.
//
//

#import <Cocoa/Cocoa.h>
#import "MRDPView.h"
#import "MRDPViewControllerDelegate.h"
#import "mfreerdp.h"

@interface MRDPViewController : NSViewController
{
    id<MRDPViewControllerDelegate> delegate;
    
    @public
	rdpContext* context;
	MRDPView* mrdpView;
}

@property(readwrite , assign) id<MRDPViewControllerDelegate> delegate;
@property (assign) rdpContext *context;

- (BOOL)connect:(NSArray *)arguments;
- (void)releaseResources;

@end
