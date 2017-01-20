//
//  MRDPViewController.m
//  FreeRDP
//
//  Created by Richard Markiewicz on 2013-07-23.
//
//

#import "MRDPViewController.h"
#import "MRDPView.h"
#import "MRDPCenteringClipView.h"
#import "MRDPClientNotifications.h"

#include <freerdp/addin.h>
#include <freerdp/client/channels.h>
#include <freerdp/client/cmdline.h>

#include <winpr/environment.h>

#include <pthread.h>

#define TAG CLIENT_TAG("mac")

void MRDPViewController_EmbedWindowEventHandler(void* context, EmbedWindowEventArgs* e);
void MRDPViewController_ConnectionResultEventHandler(void* context, ConnectionResultEventArgs* e);
void MRDPViewController_ErrorInfoEventHandler(void* ctx, ErrorInfoEventArgs* e);
void MRDPViewController_ResizeWindowEventHandler(void* context, ResizeWindowEventArgs* e);

@interface MRDPViewController ()

@end

@implementation MRDPViewController

@synthesize context;
@synthesize delegate;
@synthesize mrdpClient;
@synthesize invertHungarianCharacter;
@synthesize shiftKeyMask;
@synthesize controlKeyMask;
@synthesize alternateKeyMask;
@synthesize commandKeyMask;

- (BOOL)isConnected
{
	return self->mrdpClient.is_connected;
}

- (NSView *)rdpView
{
	return (NSView *)self->mrdpClient->delegate;
}

- (NSArray *)getForwardedServerDrives
{
	return [NSArray arrayWithArray:forwardedServerDrives];
}

- (void)viewDidConnect:(NSNotification *)notification
{
	WLog_DBG(TAG, "viewDidConnect");
	rdpContext *ctx;

	[[[notification userInfo] valueForKey:@"context"] getValue:&ctx];
    
	if(ctx == self->context)
	{
		NSLog(@"viewDidConnect:");
        
		ConnectionResultEventArgs *e = nil;
		[[[notification userInfo] valueForKey:@"connectionArgs"] getValue:&e];
        
		if(e->result == 0)
		{
			if(delegate && [delegate respondsToSelector:@selector(didConnect)])
			{
				// Better to replace this (and others in this class) with dispatch_async(dispatch_get_main_queue(), ^{ ... }) ?
				// It doesn't care about run loop modes...
				[delegate performSelectorOnMainThread:@selector(didConnect) withObject:nil waitUntilDone:true];
			}
		}
		else
		{
			if(delegate && [delegate respondsToSelector:@selector(didFailToConnectWithError:)])
			{
				NSNumber *connectErrorCode =  [NSNumber numberWithUnsignedInt:freerdp_get_last_error(ctx)];
				[delegate performSelectorOnMainThread:@selector(didFailToConnectWithError:) withObject:connectErrorCode waitUntilDone:true];
			}
		}
	}
    
    if(freerdp_get_param_bool(self->context->settings, FreeRDP_SmartSizing) && [[self rdpView] respondsToSelector:@selector(smartResize)])
    {
        [[self rdpView] performSelector:@selector(smartResize)];
    }
}

- (void)viewDidPostError:(NSNotification *)notification
{
	WLog_DBG(TAG, "viewDidPostError");
	rdpContext *ctx;
	[[[notification userInfo] valueForKey:@"context"] getValue:&ctx];
    
	if(ctx == self->context)
	{
		ErrorInfoEventArgs *e = nil;
		[[[notification userInfo] valueForKey:@"errorArgs"] getValue:&e];
		NSLog(@"viewDidPostError: %d", e->code);
		if(delegate && [delegate respondsToSelector:@selector(didErrorWithCode:)])
		{
			[delegate performSelectorOnMainThread:@selector(didErrorWithCode:) withObject:[NSNumber numberWithInt:e->code] waitUntilDone:true];
		}
	}
}

- (void)viewDidEmbed:(NSNotification *)notification
{
	rdpContext *ctx;
	[[[notification userInfo] valueForKey:@"context"] getValue:&ctx];
    
	if(ctx == self->context)
	{
		mfContext* mfc = (mfContext*)context;
		self->mrdpClient = mfc->client;
	}
}

- (void)viewDidResize:(NSNotification *)notification
{
	
}

- (void)dealloc
{
    NSLog(@"dealloc");

    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    [forwardedServerDrives release];
    
    MRDPView *view = (MRDPView *)self.mrdpClient.delegate;
    view.delegate = nil;
	
    self.delegate = nil;
    
    freerdp_client_stop(context);
    
    mfContext* mfc = (mfContext *)context;
    
    MRDPClient* client = (MRDPClient *)mfc->client;
    [client releaseResources];
    [client release];
	// the view is the delegate for the client it needs to be released after the client
	[view release];
    mfc->client = nil;
    
    [self releaseContext];
    
    [super dealloc];
}

- (BOOL)configure
{
	return [self configure:[NSArray array]];
}

- (BOOL)configure:(NSArray *)arguments
{
	NSLog(@"configure");
    
	if (delegate && [delegate respondsToSelector:@selector(initializeLogging)])
	{
		[delegate initializeLogging];
	}
	
	forwardedServerDrives = [[NSMutableArray alloc] init];
	mrdpClient.invertHungarianCharacter = invertHungarianCharacter;
    
    mrdpClient.alternateKeyMask = alternateKeyMask;
    mrdpClient.commandKeyMask = commandKeyMask;
    mrdpClient.controlKeyMask = controlKeyMask;
    mrdpClient.shiftKeyMask = shiftKeyMask;
    
	int status;
	mfContext* mfc;
    
	if(self.context == nil)
	{
		[self createContext];
	}
    
	if(arguments && [arguments count] > 0)
	{
		status = [self parseCommandLineArguments:arguments];
	}
	else
	{
		status = 0;
	}
    
	mfc = (mfContext*)context;
	mfc->client = (void*)mrdpClient;
    
	if (status < 0)
	{
		return false;
	}
	else
	{
		PubSub_SubscribeConnectionResult(context->pubSub, MRDPViewController_ConnectionResultEventHandler);
		PubSub_SubscribeErrorInfo(context->pubSub, MRDPViewController_ErrorInfoEventHandler);
		PubSub_SubscribeEmbedWindow(context->pubSub, MRDPViewController_EmbedWindowEventHandler);
		PubSub_SubscribeResizeWindow(context->pubSub, MRDPViewController_ResizeWindowEventHandler);
	}

	return true;
}

- (void)start
{
	NSLog(@"start");
    
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(viewDidPostError:) name:MRDPClientDidPostErrorInfoNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(viewDidConnect:) name:MRDPClientDidConnectWithResultNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(viewDidEmbed:) name:MRDPClientDidPostEmbedNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(viewDidResize:) name:MRDPClientDidResizeNotification object:nil];
    
	MRDPView *view = [[MRDPView alloc] initWithFrame : NSMakeRect(0, 0, context->settings->DesktopWidth, context->settings->DesktopHeight)];
	view.delegate = self;
    
	MRDPClient *client = [[MRDPClient alloc] init];
	client.delegate = view;
    
	mfContext* mfc = (mfContext*)context;
	mfc->client = client;
    
	freerdp_client_start(context);
}

- (void)stop
{
	NSLog(@"stop");
    
	[[NSNotificationCenter defaultCenter] removeObserver:self];
    
	[mrdpClient pause];
    
	freerdp_client_stop(context);
    
	PubSub_UnsubscribeConnectionResult(context->pubSub, MRDPViewController_ConnectionResultEventHandler);
	PubSub_UnsubscribeErrorInfo(context->pubSub, MRDPViewController_ErrorInfoEventHandler);
	PubSub_UnsubscribeEmbedWindow(context->pubSub, MRDPViewController_EmbedWindowEventHandler);
	PubSub_UnsubscribeResizeWindow(context->pubSub, MRDPViewController_ResizeWindowEventHandler);
}

- (void)restart
{
	[self restart:[NSArray array]];
}

- (void)restart:(NSArray *)arguments
{
	NSLog(@"restart");
    
	// Prevent any notifications from firing
	[[NSNotificationCenter defaultCenter] removeObserver:self name:MRDPClientDidPostErrorInfoNotification object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:MRDPClientDidConnectWithResultNotification object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:MRDPClientDidPostEmbedNotification object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:MRDPClientDidResizeNotification object:nil];

	[mrdpClient pause];
    
	// Tear down the context
	freerdp_client_stop(context);
    
	PubSub_UnsubscribeConnectionResult(context->pubSub, MRDPViewController_ConnectionResultEventHandler);
	PubSub_UnsubscribeErrorInfo(context->pubSub, MRDPViewController_ErrorInfoEventHandler);
	PubSub_UnsubscribeEmbedWindow(context->pubSub, MRDPViewController_EmbedWindowEventHandler);
	PubSub_UnsubscribeResizeWindow(context->pubSub, MRDPViewController_ResizeWindowEventHandler);
    
	freerdp_client_context_free(context);
	context = nil;
    
	[self createContext];
    
	// Let the delegate change the configuration
	if(delegate && [delegate respondsToSelector:@selector(willReconnect)])
	{
		[delegate performSelectorOnMainThread:@selector(willReconnect) withObject:nil waitUntilDone:true];
	}
    
	// Recreate the context
	[self configure:arguments];
    
	// Don't resubscribe the view embedded event, we're already embedded
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(viewDidPostError:) name:MRDPClientDidPostErrorInfoNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(viewDidConnect:) name:MRDPClientDidConnectWithResultNotification object:nil];
	
	// Reassign the view back to the context
	mfContext* mfc = (mfContext*)context;
	mfc->client = mrdpClient;
    
	freerdp_client_start(context);

	[mrdpClient resume];
}

-(void)sendCtrlAltDelete
{
    [mrdpClient sendCtrlAltDelete];
}

-(void)sendStart
{
    [mrdpClient sendStart];
}

-(void)sendAppSwitch
{
    [mrdpClient sendAppSwitch];
}

-(void)sendKey:(UINT16)key
{
    [mrdpClient sendKey:key];
}

-(void)sendKey:(UINT16)key withModifier:(UINT16)modifier
{
    [mrdpClient sendKey:key withModifier:modifier];
}

-(void)sendKeystrokes:(NSString *)keys
{
    [mrdpClient sendKeystrokes:keys];
}

- (void)addServerDrive:(ServerDrive *)drive
{
    [forwardedServerDrives addObject:drive];
}

- (BOOL)getBooleanSettingForIdentifier:(int)identifier
{
    return freerdp_get_param_bool(context->settings, identifier);
}

- (int)setBooleanSettingForIdentifier:(int)identifier withValue:(BOOL)value
{
    return freerdp_set_param_bool(context->settings, identifier, value);
}

- (int)getIntegerSettingForIdentifier:(int)identifier
{
    return freerdp_get_param_int(context-> settings, identifier);
}

- (int)setIntegerSettingForIdentifier:(int)identifier withValue:(int)value
{
    return freerdp_set_param_int(context->settings, identifier, value);
}

- (uint32)getInt32SettingForIdentifier:(int)identifier
{
    return freerdp_get_param_uint32(context-> settings, identifier);
}

- (int)setInt32SettingForIdentifier:(int)identifier withValue:(uint32)value
{
    return freerdp_set_param_uint32(context->settings, identifier, value);
}

- (uint64)getInt64SettingForIdentifier:(int)identifier
{
    return freerdp_get_param_uint64(context-> settings, identifier);    
}

- (int)setInt64SettingForIdentifier:(int)identifier withValue:(uint64)value
{
    return freerdp_set_param_uint64(context->settings, identifier, value);
}

- (NSString *)getStringSettingForIdentifier:(int)identifier
{
    char* cString = freerdp_get_param_string(context-> settings, identifier);
    
    return cString ? [NSString stringWithUTF8String:cString] : nil;
}

- (int)setStringSettingForIdentifier:(int)identifier withValue:(NSString *)value
{
    char* cString = (char*)[value UTF8String];
    
    return freerdp_set_param_string(context->settings, identifier, cString);
}

- (NSString *)getErrorInfoString:(int)code
{
    return [mrdpClient getErrorInfoString:code];
}

- (BOOL)provideGatewayServerCredentials:(ServerCredential **)credentials
{
	if(delegate && [delegate respondsToSelector:@selector(provideGatewayServerCredentials:)])
	{
		return [delegate provideGatewayServerCredentials:credentials];
	}
	
	return FALSE;
}

- (BOOL)provideServerCredentials:(ServerCredential **)credentials
{
    if(delegate && [delegate respondsToSelector:@selector(provideServerCredentials:)])
    {
        return [delegate provideServerCredentials:credentials];
    }
    
    return FALSE;
}

- (BOOL)validateCertificate:(ServerCertificate *)certificate
{
    if(delegate && [delegate respondsToSelector:@selector(validateCertificate:)])
    {
        return [delegate validateCertificate:certificate];
    }
    
    return FALSE;
}

- (BOOL)validateX509Certificate:(X509Certificate *)certificate
{
    if(delegate && [delegate respondsToSelector:@selector(validateX509Certificate:)])
    {
        return [delegate validateX509Certificate:certificate];
    }
    
    return FALSE;
}

- (void)createContext
{
	RDP_CLIENT_ENTRY_POINTS clientEntryPoints;
    
	ZeroMemory(&clientEntryPoints, sizeof(RDP_CLIENT_ENTRY_POINTS));
	clientEntryPoints.Size = sizeof(RDP_CLIENT_ENTRY_POINTS);
	clientEntryPoints.Version = RDP_CLIENT_INTERFACE_VERSION;
    
	RdpClientEntry(&clientEntryPoints);
    
	context = freerdp_client_context_new(&clientEntryPoints);
}

- (void)releaseContext
{
	freerdp_client_context_free(context);
	context = nil;
}

- (int)parseCommandLineArguments:(NSArray *)args
{
	int i;
	int len;
	int status;
	char* cptr;
	int argc;
	char** argv = nil;
    
	argc = (int) [args count];
	argv = malloc(sizeof(char*) * argc);
	
	i = 0;
	
	for (NSString* str in args)
	{
        /* filter out some arguments added by XCode */
        
        if ([str isEqualToString:@"YES"])
        {
            argc--;
            continue;
        }
        
        if ([str isEqualToString:@"-NSDocumentRevisionsDebugMode"])
        {
            argc--;
            continue;
        }
        
		len = (int) ([str length] + 1);
		cptr = (char*) malloc(len);
		strcpy(cptr, [str UTF8String]);
		argv[i++] = cptr;
	}
	
	status = freerdp_client_settings_parse_command_line(context->settings, argc, argv, FALSE);
    
	return status;
}

- (void) initLoggingWithFilter:(NSString *)filter filePath:(NSString *)filePath fileName:(NSString *)fileName
{
	if(([filter length] == 0) || ([filePath length] == 0) || ([fileName length] == 0))
		return;
	
	SetEnvironmentVariableA("WLOG_APPENDER", "FILE");
	SetEnvironmentVariableA("WLOG_FILEAPPENDER_OUTPUT_FILE_PATH", filePath.UTF8String);
	SetEnvironmentVariableA("WLOG_FILEAPPENDER_OUTPUT_FILE_NAME", fileName.UTF8String);
	SetEnvironmentVariableA("WLOG_FILTER", filter.UTF8String);
	SetEnvironmentVariableA("WLOG_PREFIX", "[%hr:%mi:%se:%ml] [%pid:%tid] [%lv][%mn] %fn %ln - ");
	
	//Make sure our settings are used
	WLog_Uninit();
	WLog_Init();
	WLog_INFO(TAG, "Log initialized inline File: %s/%s Filter: %s", filePath.UTF8String, fileName.UTF8String, filter.UTF8String);
}

- (void) setIsReadOnly:(bool)isReadOnly
{
	if ((mrdpClient == nil) && (!mrdpClient.is_connected))
		return;
		
	mrdpClient.isReadOnly = isReadOnly;
}

@end

void MRDPViewController_EmbedWindowEventHandler(void* ctx, EmbedWindowEventArgs* e)
{
    @autoreleasepool
    {
        rdpContext* context = (rdpContext*) ctx;
        
        NSDictionary *userInfo = [NSDictionary dictionaryWithObject:[NSValue valueWithPointer:context] forKey:@"context"];
        
        [[NSNotificationCenter defaultCenter] postNotificationName:MRDPClientDidPostEmbedNotification object:nil userInfo:userInfo];
    }
}

void MRDPViewController_ConnectionResultEventHandler(void* ctx, ConnectionResultEventArgs* e)
{
    @autoreleasepool
    {
        NSLog(@"ConnectionResultEventHandler");
        
        rdpContext* context = (rdpContext*) ctx;
        
        NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:[NSValue valueWithPointer:context], @"context",
                                  [NSValue valueWithPointer:e], @"connectionArgs",
                                  [NSNumber numberWithInt:connectErrorCode], @"connectErrorCode", nil];
        
        [[NSNotificationCenter defaultCenter] postNotificationName:MRDPClientDidConnectWithResultNotification object:nil userInfo:userInfo];
    }
}

void MRDPViewController_ErrorInfoEventHandler(void* ctx, ErrorInfoEventArgs* e)
{
    @autoreleasepool
    {
        NSLog(@"ErrorInfoEventHandler");
        
        rdpContext* context = (rdpContext*) ctx;

        NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:[NSValue valueWithPointer:context], @"context",
                                  [NSValue valueWithPointer:e], @"errorArgs", nil];

        [[NSNotificationCenter defaultCenter] postNotificationName:MRDPClientDidPostErrorInfoNotification object:nil userInfo:userInfo];
    }
}

void MRDPViewController_ResizeWindowEventHandler(void* ctx, ResizeWindowEventArgs* e)
{
	@autoreleasepool
	{
		NSLog(@"ErrorInfoEventHandler");
		
		rdpContext* context = (rdpContext*) ctx;
		
		NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:[NSValue valueWithPointer:context], @"context",
								  [NSValue valueWithPointer:e], @"resizeArgs", nil];
		
		[[NSNotificationCenter defaultCenter] postNotificationName:MRDPClientDidResizeNotification object:nil userInfo:userInfo];
	}
}
