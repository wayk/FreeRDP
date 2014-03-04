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
	
	status = freerdp_client_settings_parse_command_line(context->settings, context->argc, context->argv);
	
	status = freerdp_client_settings_command_line_status_print(context->settings, status, context->argc, context->argv);
    
	return status;
    
}

- (IBAction)start:(id)sender
{
    if(mrdpViewController == nil)
    {
        mrdpViewController = [[MRDPViewController alloc] init];
        mrdpViewController.delegate = self;
        
        if(USE_CLI == true)
        {
            [mrdpViewController configure:[[NSProcessInfo processInfo] arguments]];
        }
        else
        {
            [mrdpViewController configure];
            
            [mrdpViewController setStringSettingForIdentifier:21 withValue:LOGIN_USERNAME];
            [mrdpViewController setStringSettingForIdentifier:23 withValue:LOGIN_DOMAIN];
            [mrdpViewController setStringSettingForIdentifier:20 withValue:LOGIN_ADDRESS];
            [mrdpViewController setInt32SettingForIdentifier:19 withValue:LOGIN_PORT];
            [mrdpViewController setBooleanSettingForIdentifier:4800 withValue:true]; // Clipboard
        }
        
        [mrdpViewController setBooleanSettingForIdentifier:1415 withValue:true]; // ExternalCertificateManagement
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
