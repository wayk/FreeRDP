//
//  MRDPViewController.m
//  FreeRDP
//
//  Created by Richard Markiewicz on 2013-07-23.
//
//

#import "MRDPViewController.h"
#import "MRDPView.h"
#import "MRDPScrollView.h"
#import "MRDPCenteringClipView.h"

#include <freerdp/addin.h>
#include <freerdp/client/channels.h>

void EmbedWindowEventHandler(void* context, EmbedWindowEventArgs* e);
void ConnectionResultEventHandler(void* context, ConnectionResultEventArgs* e);
void ErrorInfoEventHandler(void* ctx, ErrorInfoEventArgs* e);

@interface MRDPViewController ()

@end

@implementation MRDPViewController

@synthesize context;
@synthesize delegate;

static NSString *MRDPViewDidPostErrorInfoNotification = @"MRDPViewDidPostErrorInfoNotification";
static NSString *MRDPViewDidConnectWithResultNotification = @"MRDPViewDidConnectWithResultNotification";
static NSString *MRDPViewDidPostEmbedNotification = @"MRDPViewDidPostEmbedNotification";

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self)
    {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(viewDidPostError:) name:MRDPViewDidPostErrorInfoNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(viewDidConnect:) name:MRDPViewDidConnectWithResultNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(viewDidEmbed:) name:MRDPViewDidPostEmbedNotification object:nil];
    }
    
    return self;
}

- (BOOL)isConnected
{
    return self->mrdpView.is_connected;
}

- (void)viewDidConnect:(NSNotification *)notification
{
    rdpContext *ctx;
    [[[notification userInfo] valueForKey:@"context"] getValue:&ctx];
    
    if(ctx == self->context)
    {
        ConnectionResultEventArgs *e = nil;
        [[[notification userInfo] valueForKey:@"connectionArgs"] getValue:&e];
        
        if(delegate && [delegate respondsToSelector:@selector(didConnectWithResult:)])
        {
            [delegate performSelectorOnMainThread:@selector(didConnectWithResult:) withObject:[NSNumber numberWithInt:e->result] waitUntilDone:false];
        }
    }
}

- (void)viewDidPostError:(NSNotification *)notification
{
    rdpContext *ctx;
    [[[notification userInfo] valueForKey:@"context"] getValue:&ctx];
    
    if(ctx == self->context)
    {
        ErrorInfoEventArgs *e = nil;
        [[[notification userInfo] valueForKey:@"errorArgs"] getValue:&e];
        
        if(delegate && [delegate respondsToSelector:@selector(didErrorWithCode:)])
        {
            [delegate performSelectorOnMainThread:@selector(didErrorWithCode:) withObject:[NSNumber numberWithInt:e->code] waitUntilDone:false];
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
        
        self->mrdpView = mfc->view;
        
        if([self getBooleanSettingForIdentifier:FreeRDP_SmartSizing])
        {
            [mrdpView setFrameOrigin:NSMakePoint(
                                                 (NSWidth([self.view bounds]) - NSWidth([mrdpView frame])) / 2,
                                                 (NSHeight([self.view bounds]) - NSHeight([mrdpView frame])) / 2
                                                 )];
            [mrdpView setAutoresizingMask:NSViewMinXMargin | NSViewMaxXMargin | NSViewMinYMargin | NSViewMaxYMargin | NSViewWidthSizable | NSViewHeightSizable];
            [self.view addSubview:mrdpView];
        }
        else
        {
            // TODO leaked...
            MRDPScrollView *scroller = [[MRDPScrollView alloc] init];
            [scroller setFrame:self.view.frame];
            [scroller setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
            [self.view addSubview:scroller];
            
            [scroller setDocumentView:mrdpView];
            
            [scroller setScrollerStyle:NSScrollerStyleLegacy];
            [scroller setBorderType:NSBorderlessWindowMask];
            [scroller setHasHorizontalScroller:TRUE];
            [scroller setHasVerticalScroller:TRUE];
            
            // Replace NSClipView of scrollView with a CenteringClipView
            id docView = [scroller documentView];
            NSClipView* clipView = [[MRDPCenteringClipView alloc] initWithFrame:[docView frame]];
            [scroller setContentView:clipView];
            [scroller setDocumentView:docView];
        }
    }
}

- (void)dealloc
{
    NSLog(@"dealloc");
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:MRDPViewDidPostErrorInfoNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:MRDPViewDidConnectWithResultNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:MRDPViewDidPostEmbedNotification object:nil];

    self->mrdpView.delegate = nil;
    self.delegate = nil;
    
    // Done inside freerdp_client_stop(context);
    // [mrdpView releaseResources];
    
    // Wayk client doesn't do this...
    // [self releaseContext];
    
    [super dealloc];
}

- (void)loadView
{
    // TODO leaked...
    self.view = [[NSView alloc] init];
}

- (BOOL)configure
{
    return [self configure:[NSArray array]];
}

- (BOOL)configure:(NSArray *)arguments
{
    NSLog(@"configure");
    
    int status;
    mfContext* mfc;
    
    [self createContext];
    
    if(arguments && [arguments count] > 0)
    {
        status = [self parseCommandLineArguments:arguments];
    }
    else
    {
        // Workaround bug when not using the command line parser
        freerdp_register_addin_provider(freerdp_channels_load_static_addin_entry, 0);
        
        status = 0;
    }
    
    mfc = (mfContext*)context;
    mfc->view = (void*)mrdpView;
    
    if (status < 0)
    {
        return false;
    }
    else
    {
        PubSub_SubscribeConnectionResult(context->pubSub, ConnectionResultEventHandler);
    	PubSub_SubscribeErrorInfo(context->pubSub, ErrorInfoEventHandler);
        PubSub_SubscribeEmbedWindow(context->pubSub, EmbedWindowEventHandler);
    }

    return true;
}

- (void)start
{
    NSLog(@"start");
    
    freerdp_client_start(context);
    
    // Is this a race condition? Probably a slight hack at least to do this here
    // We need to provide a password prompt delegate to the view, but we can only do that once it's been created
    mfContext* mfc = (mfContext*)context;
    MRDPView* view = (MRDPView*)mfc->view;
    view.delegate = self;
}

- (void)stop
{
    NSLog(@"stop");
    
    freerdp_client_stop(context);
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

- (double)getDoubleSettingForIdentifier:(int)identifier
{
    return freerdp_get_param_double(context-> settings, identifier);    
}

- (int)setDoubleSettingForIdentifier:(int)identifier withValue:(double)value
{
    return freerdp_set_param_double(context->settings, identifier, value);
}

- (BOOL)provideServerCredentials:(ServerCredential **)credentials
{
//  Implemented like this:
//
//  PasswordDialog* dialog = [[PasswordDialog alloc] initWithWindowNibName:@"PasswordDialog"];
//  ServerCredential* c = *credentials;
//    
//	dialog.serverHostname = c.serverHostname;
//    
//	if (c.username)
//		dialog.username = c.username;
//    
//	if (c.password)
//		dialog.password = c.password;
//    
//    if([NSApp runModalForWindow:dialog.window] == TRUE)
//    {
//        c.username = dialog.username;
//        c.password = dialog.password;
//        
//        return TRUE;
//    }
//
    
    if(delegate && [delegate respondsToSelector:@selector(provideServerCredentials:)])
    {
        return [delegate provideServerCredentials:credentials];
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
		len = (int) ([str length] + 1);
		cptr = (char*) malloc(len);
		strcpy(cptr, [str UTF8String]);
		argv[i++] = cptr;
	}
	
	status = freerdp_client_parse_command_line(context, argc, argv);
    
	return status;
}

@end

void EmbedWindowEventHandler(void* ctx, EmbedWindowEventArgs* e)
{
    rdpContext* context = (rdpContext*) ctx;
    
    NSDictionary *userInfo = [NSDictionary dictionaryWithObject:[NSValue valueWithPointer:context] forKey:@"context"];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:MRDPViewDidPostEmbedNotification object:nil userInfo:userInfo];
}

void ConnectionResultEventHandler(void* ctx, ConnectionResultEventArgs* e)
{
	NSLog(@"ConnectionResult event result:%d\n", e->result);
    
    rdpContext* context = (rdpContext*) ctx;
    
    NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:[NSValue valueWithPointer:context], @"context",
                              [NSValue valueWithPointer:e], @"connectionArgs", nil];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:MRDPViewDidConnectWithResultNotification object:nil userInfo:userInfo];
}

void ErrorInfoEventHandler(void* ctx, ErrorInfoEventArgs* e)
{
	NSLog(@"ErrorInfo event code:%d\n", e->code);
    
    rdpContext* context = (rdpContext*) ctx;
    
    NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:[NSValue valueWithPointer:context], @"context",
                              [NSValue valueWithPointer:e], @"errorArgs", nil];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:MRDPViewDidPostErrorInfoNotification object:nil userInfo:userInfo];
}
