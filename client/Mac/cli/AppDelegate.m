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
#import "MacFreeRDP/MRDPCenteringClipView.h"
#import "FixedScrollView.h"
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
    bool smartSizing = [mrdpViewController getBooleanSettingForIdentifier:1551];
    NSLog(@"Smart sizing: %i", smartSizing);
    
    if(smartSizing)
    {
        [mrdpViewController.rdpView setFrameOrigin:
         NSMakePoint((self.connContainer.bounds.size.width - mrdpViewController.rdpView.frame.size.width) / 2,
                     (self.connContainer.bounds.size.height - mrdpViewController.rdpView.frame.size.height) / 2)];
        mrdpViewController.rdpView.autoresizingMask = NSViewHeightSizable | NSViewWidthSizable |
        NSViewMaxXMargin | NSViewMaxYMargin | NSViewMinXMargin | NSViewMinYMargin;
        
        [self.connContainer.contentView addSubview:mrdpViewController.rdpView];
    }
    else
    {
        FixedScrollView *scrollView = [[FixedScrollView alloc] initWithFrame:self.connContainer.bounds];
        scrollView.autoresizingMask = NSViewHeightSizable | NSViewWidthSizable;
        
        [self.connContainer.contentView addSubview:scrollView];
        
        scrollView.documentView = mrdpViewController.rdpView;
        scrollView.scrollerStyle = NSScrollerStyleLegacy;
        scrollView.borderType = NSNoBorder;
        scrollView.hasHorizontalScroller = true;
        scrollView.hasVerticalScroller = true;
        scrollView.autohidesScrollers = true;
        
        NSView *documentView = (NSView*)scrollView.documentView;
        MRDPCenteringClipView *centeringClipView = [[MRDPCenteringClipView alloc] initWithFrame:documentView.frame];
        scrollView.contentView = centeringClipView;
        scrollView.documentView = documentView;
        [centeringClipView centerView];
    }
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
    if(mrdpViewController == nil)
    {
        mrdpViewController = [[MRDPViewController alloc] init];
        mrdpViewController.delegate = self;
        
        [mrdpViewController configure:[[NSProcessInfo processInfo] arguments]];
    }
    
    [mrdpViewController start];
}

- (IBAction)stop:(id)sender
{
    [mrdpViewController stop];
    
    [self removeView];
    [mrdpViewController release];
    
    mrdpViewController = nil;
}

- (IBAction)restart:(id)sender
{
    [mrdpViewController restart:[[NSProcessInfo processInfo] arguments]];
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