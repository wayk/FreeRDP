//
//  AppDelegate.m
//  MacClient2
//
//  Created by Benoît et Kathy on 2013-05-08.
//
//

#import "AppDelegate.h"
#import "MacFreeRDP/MRDPViewController.h"

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

@end