//
//  AppDelegate.h
//  MacClient2
//
//  Created by Benoît et Kathy on 2013-05-08.
//
//

#import <Cocoa/Cocoa.h>
#import <MacFreeRDP/MRDPViewController.h>
#import <MacFreeRDP/mfreerdp.h>
#import <MacFreeRDP/MRDPViewControllerDelegate.h>

@interface AppDelegate : NSObject <NSApplicationDelegate, MRDPViewControllerDelegate>
{
@public
	NSWindow* window;
	MRDPViewController* mrdpViewController;
    NSBox *connContainer;
}

@property (assign) IBOutlet NSWindow *window;
- (IBAction)start:(id)sender;
- (IBAction)stop:(id)sender;
@property (assign) IBOutlet NSBox *connContainer;

@end
