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
#import "MacFreeRDP/ServerCredential.h"

static AppDelegate* _singleDelegate = nil;
void AppDelegate_ConnectionResultEventHandler(void* context, ConnectionResultEventArgs* e);
void AppDelegate_ErrorInfoEventHandler(void* ctx, ErrorInfoEventArgs* e);
void AppDelegate_EmbedWindowEventHandler(void* context, EmbedWindowEventArgs* e);
void AppDelegate_ResizeWindowEventHandler(void* context, ResizeWindowEventArgs* e);
void mac_set_view_size(rdpContext* context, MRDPView* view);

@implementation AppDelegate

@synthesize connContainer;

#define USE_CLI true
#define LOGIN_USERNAME @""
#define LOGIN_DOMAIN @""
#define LOGIN_PASSWORD @""
#define LOGIN_PORT 6003
#define LOGIN_ADDRESS @""

BOOL reconnecting = false;

- (void)dealloc
{
	[super dealloc];
}

@synthesize window = window;
@synthesize context = context;

- (void) applicationDidFinishLaunching:(NSNotification*)aNotification
{

}

- (void)didConnect
{
    if(!reconnecting)
    {
        bool smartSizing = [mrdpViewController getBooleanSettingForIdentifier:1551];
        NSLog(@"Smart sizing: %i", smartSizing);
        
        [mrdpViewController setBooleanSettingForIdentifier:707 withValue:true]; // EnableWindowsKey
        [mrdpViewController setBooleanSettingForIdentifier:707 withValue:true]; // EnableWinKeyCutPaste
        
        if(smartSizing)
        {
            [mrdpViewController.rdpView setFrameOrigin:
             NSMakePoint((self.connContainer.bounds.size.width - mrdpViewController.rdpView.frame.size.width) / 2,
                         (self.connContainer.bounds.size.height - mrdpViewController.rdpView.frame.size.height) / 2)];
            mrdpViewController.rdpView.autoresizingMask = NSViewHeightSizable | NSViewWidthSizable;
            
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
    
    reconnecting = false;
}

- (void)didFailToConnectWithError:(NSNumber *)connectErrorCode
{

}

- (void)didErrorWithCode:(NSNumber *)code
{
    [self removeView];
}

- (void)willReconnect
{
    reconnecting = true;
    
    if(!USE_CLI)
    {
        [mrdpViewController setStringSettingForIdentifier:21 withValue:LOGIN_USERNAME];
        [mrdpViewController setStringSettingForIdentifier:23 withValue:LOGIN_DOMAIN];
        [mrdpViewController setStringSettingForIdentifier:20 withValue:LOGIN_ADDRESS];
        [mrdpViewController setInt32SettingForIdentifier:19 withValue:LOGIN_PORT];
    }
}

- (BOOL)provideServerCredentials:(ServerCredential **)credentials
{
    if(!USE_CLI)
    {
        *credentials = [[ServerCredential alloc] initWithHostName:LOGIN_ADDRESS domain:LOGIN_DOMAIN userName:LOGIN_USERNAME andPassword:LOGIN_PASSWORD];
        
        return true;
    }
    
    return false;
}

- (BOOL)validateCertificate:(ServerCertificate *)certificate
{

    return true;
}

- (BOOL)validateX509Certificate:(X509Certificate *)certificate
{
    return true;
}

- (void) applicationWillTerminate:(NSNotification*)notification
{
    if (mrdpViewController) {
        [self stop:self];
    }
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender
{
	return YES;
}

- (int) ParseCommandLineArguments
{
	int i;
	int length;
	int status;
	char* cptr;
    
	NSArray* args = [[NSProcessInfo processInfo] arguments];
    
	context->argc = (int) [args count];
	context->argv = malloc(sizeof(char*) * context->argc);
	
	i = 0;
	
	for (NSString* str in args)
	{
		/* filter out some arguments added by XCode */
		
		if ([str isEqualToString:@"YES"])
			continue;
		
		if ([str isEqualToString:@"-NSDocumentRevisionsDebugMode"])
			continue;
		
		length = (int) ([str length] + 1);
		cptr = (char*) malloc(length);
		strcpy(cptr, [str UTF8String]);
		context->argv[i++] = cptr;
	}
	
	context->argc = i;
	
	status = freerdp_client_settings_parse_command_line(context->settings, context->argc, context->argv, FALSE);
	
	status = freerdp_client_settings_command_line_status_print(context->settings, status, context->argc, context->argv);
    
	return status;
}

- (void) CreateContext
{
	RDP_CLIENT_ENTRY_POINTS clientEntryPoints;
    
	ZeroMemory(&clientEntryPoints, sizeof(RDP_CLIENT_ENTRY_POINTS));
	clientEntryPoints.Size = sizeof(RDP_CLIENT_ENTRY_POINTS);
	clientEntryPoints.Version = RDP_CLIENT_INTERFACE_VERSION;
    
	RdpClientEntry(&clientEntryPoints);
    
	context = freerdp_client_context_new(&clientEntryPoints);
}

- (void) ReleaseContext
{
	mfContext* mfc;
	MRDPClient* client;
    
	mfc = (mfContext *) context;
	client = (MRDPClient *) mfc->client;
    
	[client releaseResources];
	[client release];
	mfc->client = nil;
    
	freerdp_client_context_free(context);
	context = nil;
}


/** *********************************************************************
 * called when we fail to connect to a RDP server - Make sure this is called from the main thread.
 ***********************************************************************/

- (void) rdpConnectError : (NSString*) withMessage
{
	mfContext* mfc;
	MRDPView* view;

	mfc = (mfContext*) context;
	view = (MRDPView*) mfc->client;

	[view exitFullScreenModeWithOptions:nil];

	NSString* message = withMessage ? withMessage : @"Error connecting to server";
    
	NSAlert *alert = [[NSAlert alloc] init];
	[alert setMessageText:message];
	[alert beginSheetModalForWindow:[self window]
					  modalDelegate:self
					 didEndSelector:@selector(alertDidEnd:returnCode:contextInfo:)
						contextInfo:nil];
}


/** *********************************************************************
 * just a terminate selector for above call
 ***********************************************************************/

- (void) alertDidEnd:(NSAlert *)a returnCode:(NSInteger)rc contextInfo:(void *)ci
{
	[NSApp terminate:nil];
}

/** *********************************************************************
 * On connection error, display message and quit application
 ***********************************************************************/

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
				message = [NSString stringWithFormat:@"%@", @"Authentication failure, check credentials."];
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

void AppDelegate_EmbedWindowEventHandler(void* ctx, EmbedWindowEventArgs* e)
{
	rdpContext* context = (rdpContext*) ctx;
	
	if (_singleDelegate)
	{
		mfContext* mfc = (mfContext*) context;
		_singleDelegate->mrdpClient = mfc->client;
		
		if (_singleDelegate->window)
		{
			[[_singleDelegate->window contentView] addSubview:mfc->client];
		}
		
		mac_set_view_size(context, mfc->client);
	}
}

void AppDelegate_ResizeWindowEventHandler(void* ctx, ResizeWindowEventArgs* e)
{
	rdpContext* context = (rdpContext*) ctx;
	
	fprintf(stderr, "ResizeWindowEventHandler: %d %d\n", e->width, e->height);
	
	if (_singleDelegate)
	{
		mfContext* mfc = (mfContext*) context;
		mac_set_view_size(context, mfc->client);
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
    
	if (context->settings->Fullscreen)
		[[view window] toggleFullScreen:nil];
}

- (IBAction)start:(id)sender
{
    if(mrdpViewController == nil)
    {
        mrdpViewController = [[MRDPViewController alloc] init];
        mrdpViewController.delegate = self;
        
        bool result = false;
        
        if(USE_CLI == true)
        {
            result = [mrdpViewController configure:[[NSProcessInfo processInfo] arguments]];
        }
        else
        {
            result = [mrdpViewController configure];
            
            [mrdpViewController setStringSettingForIdentifier:21 withValue:LOGIN_USERNAME];
            [mrdpViewController setStringSettingForIdentifier:23 withValue:LOGIN_DOMAIN];
            [mrdpViewController setStringSettingForIdentifier:20 withValue:LOGIN_ADDRESS];
            [mrdpViewController setInt32SettingForIdentifier:19 withValue:LOGIN_PORT];
            [mrdpViewController setBooleanSettingForIdentifier:4800 withValue:true]; // Clipboard
        }
        
        [mrdpViewController setBooleanSettingForIdentifier:1415 withValue:true]; // ExternalCertificateManagement
		[mrdpViewController setBooleanSettingForIdentifier:FreeRDP_CompressionEnabled withValue:TRUE];
		[mrdpViewController setInt32SettingForIdentifier:FreeRDP_CompressionLevel withValue:2];
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
    if(USE_CLI)
    {
        [mrdpViewController restart:[[NSProcessInfo processInfo] arguments]];
    }
    else
    {
        [mrdpViewController restart];
    }
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
