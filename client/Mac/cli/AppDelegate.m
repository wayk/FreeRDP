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
    mrdpViewController = [[MRDPViewController alloc] init];
    mrdpViewController.delegate = self;
    
    [mrdpViewController configure];
    // [controller configure:[[NSProcessInfo processInfo] arguments]];
    
    [mrdpViewController setStringSettingForIdentifier:20 withValue:@"10.211.55.3"];
    [mrdpViewController setStringSettingForIdentifier:21 withValue:@"richard"];
    [mrdpViewController setStringSettingForIdentifier:22 withValue:@"M1crosoft"];
    
    //
    //RedirectDrives = 4288,
    //RedirectHomeDrive = 4289,
    [mrdpViewController setBooleanSettingForIdentifier:4288 withValue:false];
    [mrdpViewController setBooleanSettingForIdentifier:4289 withValue:false];
    //    [mrdpViewController setBooleanSettingForIdentifier:707 withValue:true];
    //    [mrdpViewController setStringSettingForIdentifier:23 withValue:@"lab"];
    
//    char* a3[] = { "drive", "test", "/Applications" };
//    freerdp_client_add_device_channel(mrdpViewController.context->settings, 3, a3);
//    
//    char* a4[] = { "drive", "test", "/Applications" };
//    freerdp_client_add_device_channel(mrdpViewController.context->settings, 3, a4);
//    
//    char* a5[] = { "drive", "test2", "/somebunchofcrap" };
//    freerdp_client_add_device_channel(mrdpViewController.context->settings, 3, a5);
//    
//    char* a6[] = { "drive", "test", "/Library" };
//    freerdp_client_add_device_channel(mrdpViewController.context->settings, 3, a6);
//    
//    char* a7[] = { "drive", "test3", "/" };
//    freerdp_client_add_device_channel(mrdpViewController.context->settings, 3, a7);

    /*
     char** p;
     int count;
     
     p = freerdp_command_line_parse_comma_separated_values_offset(arg->Value, &count);
     p[0] = "drive";
     
     freerdp_client_add_device_channel(settings, count, p);
     
     free(p);
     
    */
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
    [mrdpViewController start];
}

- (IBAction)stop:(id)sender
{
    [mrdpViewController stop];
}

@end
