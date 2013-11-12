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
    
    [mrdpViewController configure:[[NSProcessInfo processInfo] arguments]];
    
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

void AppDelegate_ConnectionResultEventHandler(void* ctx, ConnectionResultEventArgs* e)
{
	NSLog(@"ConnectionResult event result:%d\n", e->result);
	if (_singleDelegate)
	{
		if (e->result != 0)
		{
			NSString* message = nil;
			if (connectErrorCode == AUTHENTICATIONERROR)
			{
				message = [NSString stringWithFormat:@"%@:\n%@", message, @"Authentication failure, check credentials."];
			}
			
			
			// Making sure this should be invoked on the main UI thread.
			[_singleDelegate performSelectorOnMainThread:@selector(rdpConnectError:) withObject:message waitUntilDone:FALSE];
		}
	}
}

void AppDelegate_ErrorInfoEventHandler(void* ctx, ErrorInfoEventArgs* e)
{
	NSLog(@"ErrorInfo event code:%d\n", e->code);
	if (_singleDelegate)
	{
		// Retrieve error message associated with error code
		NSString* message = nil;
		if (e->code != ERRINFO_NONE)
		{
			const char* errorMessage = freerdp_get_error_info_string(e->code);
			message = [[NSString alloc] initWithUTF8String:errorMessage];
		}
		
		// Making sure this should be invoked on the main UI thread.
		[_singleDelegate performSelectorOnMainThread:@selector(rdpConnectError:) withObject:message waitUntilDone:TRUE];
		[message release];
	}
}


void mac_set_view_size(rdpContext* context, MRDPView* view)
{
	// set client area to specified dimensions
	NSRect innerRect;
	innerRect.origin.x = 0;
	innerRect.origin.y = 0;
	innerRect.size.width = context->settings->DesktopWidth;
	innerRect.size.height = context->settings->DesktopHeight;
	[view setFrame:innerRect];
	
	// calculate window of same size, but keep position
	NSRect outerRect = [[view window] frame];
	outerRect.size = [[view window] frameRectForContentRect:innerRect].size;
	
	// we are not in RemoteApp mode, disable larger than resolution
	[[view window] setContentMaxSize:innerRect.size];
	
	// set window to given area
	[[view window] setFrame:outerRect display:YES];
	
	
	if(context->settings->Fullscreen)
		[[view window] toggleFullScreen:nil];
}

int mac_client_start(rdpContext* context)
{
	mfContext* mfc;
	MRDPView* view;
	
	mfc = (mfContext*) context;
	view = [[MRDPView alloc] initWithFrame : NSMakeRect(0, 0, context->settings->DesktopWidth, context->settings->DesktopHeight)];
	mfc->view = view;
	
	[view rdpStart:context];
	mac_set_view_size(context, view);
	
	return 0;
}
