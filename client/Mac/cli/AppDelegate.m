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

int mac_client_start(rdpContext* context);
void mac_set_view_size(rdpContext* context, MRDPView* view);

@implementation AppDelegate

- (void)dealloc
{
	[super dealloc];
}

@synthesize window = window;

- (void) applicationDidFinishLaunching:(NSNotification*)aNotification
{
    mrdpViewController = [[MRDPViewController alloc] init];
    mrdpViewController.delegate = self;
    
    [mrdpViewController configure];
    // [controller configure:[[NSProcessInfo processInfo] arguments]];
    
    [mrdpViewController setStringSettingForIdentifier:20 withValue:@"10.211.55.5"];
    [mrdpViewController setStringSettingForIdentifier:21 withValue:@"ieuser"];
    [mrdpViewController setStringSettingForIdentifier:22 withValue:@"Passw0rd!"];
    
    [mrdpViewController start];
}

- (void)didConnect
{
   [self.window setContentView:mrdpViewController.rdpView];
}

- (void)didFailToConnectWithError:(NSNumber *)connectErrorCode
{

}

- (void)didErrorWithCode:(NSNumber *)code
{

}

//RdpClientEntry(&clientEntryPoints);
//
//clientEntryPoints.ClientStart = mac_client_start;
//
//context = freerdp_client_context_new(&clientEntryPoints);
//
//- (void) ReleaseContext
//{
//	mfContext* mfc;
//	MRDPView* view;
//	
//	mfc = (mfContext*) context;
//	view = (MRDPView*) mfc->view;
//	
//	[view releaseResources];
//	[view release];
//	 mfc->view = nil;
//	
//	freerdp_client_context_free(context);
//	context = nil;
//}

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
//	rdpContext* context = (rdpContext*) ctx;
//	
//    if (_singleDelegate)
//    {
//        mfContext* mfc = (mfContext*) context;
//        _singleDelegate->mrdpView = mfc->view;
//        
//        if (_singleDelegate->window)
//        {
//            [[_singleDelegate->window contentView] addSubview:mfc->view];
//        }
//		
//		
//		mac_set_view_size(context, mfc->view);
//    }
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender
{
	return YES;
}

//void mac_set_view_size(rdpContext* context, MRDPView* view)
//{
//	// set client area to specified dimensions
//	NSRect innerRect;
//	innerRect.origin.x = 0;
//	innerRect.origin.y = 0;
//	innerRect.size.width = context->settings->DesktopWidth;
//	innerRect.size.height = context->settings->DesktopHeight;
//	[view setFrame:innerRect];
//	
//	// calculate window of same size, but keep position
//	NSRect outerRect = [[view window] frame];
//	outerRect.size = [[view window] frameRectForContentRect:innerRect].size;
//	
//	// we are not in RemoteApp mode, disable larger than resolution
//	[[view window] setContentMaxSize:innerRect.size];
//	
//	// set window to given area
//	[[view window] setFrame:outerRect display:YES];
//	
//	
//	if(context->settings->Fullscreen)
//		[[view window] toggleFullScreen:nil];
//}

//int mac_client_start(rdpContext* context)
//{
//	mfContext* mfc;
//	MRDPView* view;
//	
//	mfc = (mfContext*) context;
//	view = [[MRDPView alloc] initWithFrame : NSMakeRect(0, 0, context->settings->DesktopWidth, context->settings->DesktopHeight)];
//	mfc->view = view;
//	
//	[view rdpStart:context];
//	mac_set_view_size(context, view);
//	
//	return 0;
//}

@end
