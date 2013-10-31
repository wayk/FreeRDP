//
//  AppDelegate.m
//  MacClient2
//
//  Created by Benoît et Kathy on 2013-05-08.
//
//

#import "AppDelegate.h"
#import "MacFreeRDP/MRDPViewController.h"
#import "MacFreeRDP/mfreerdp.h"
#import "MacFreeRDP/mf_client.h"
#import "MacFreeRDP/MRDPView.h"
#include <freerdp/client/cmdline.h>

int mac_client_start(rdpContext* context);
void mac_set_view_size(rdpContext* context, MRDPView* view);

@implementation AppDelegate
@synthesize connContainer;

- (void)dealloc
{
	[super dealloc];
}

@synthesize window = window;

- (void) applicationDidFinishLaunching:(NSNotification*)aNotification
{

}

- (void)didConnect
{
    [self.connContainer setFrameSize:NSMakeSize(
        [mrdpViewController getInt32SettingForIdentifier:129],
        [mrdpViewController getInt32SettingForIdentifier:130])];
    
    [self.connContainer.contentView addSubview:mrdpViewController.rdpView];
}

- (void)didFailToConnectWithError:(NSNumber *)connectErrorCode
{

}

- (void)didErrorWithCode:(NSNumber *)code
{
    [self removeView];
}

- (BOOL)provideServerCredentials:(ServerCredential **)credentials
{
    return false;
}

- (BOOL)validateCertificate:(ServerCertificate *)certificate
{
    return true;
}

- (void) applicationWillTerminate:(NSNotification*)notification
{

}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender
{
	return YES;
}

- (IBAction)start:(id)sender
{
    mrdpViewController = [[MRDPViewController alloc] init];
    mrdpViewController.delegate = self;
    
    [mrdpViewController configure];
    // [controller configure:[[NSProcessInfo processInfo] arguments]];
    
    [mrdpViewController setStringSettingForIdentifier:20 withValue:@"10.211.55.3"];
    [mrdpViewController setStringSettingForIdentifier:21 withValue:@"richard"];
    [mrdpViewController setStringSettingForIdentifier:22 withValue:@"abc123"];
    
    [mrdpViewController start];
}

- (IBAction)stop:(id)sender
{
    [mrdpViewController stop];
    [self removeView];
    [mrdpViewController release];
}

- (void)removeView
{
    if(self.connContainer.contentView)
    {
        NSView *contentView = (NSView *)self.connContainer.contentView;
        
        if([contentView.subviews count] > 0)
        {
            NSView *firstSubView = (NSView *)[contentView.subviews objectAtIndex:0];
            
            [firstSubView removeFromSuperview];
        }
    }
}

@end
