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
}

@property (assign) IBOutlet NSWindow *window;

@end
