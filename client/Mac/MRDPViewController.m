//
//  MRDPViewController.m
//  FreeRDP
//
//  Created by Richard Markiewicz on 2013-07-23.
//
//

#import "MRDPViewController.h"
#import "MRDPView.h"

void EmbedWindowEventHandler(void* context, EmbedWindowEventArgs* e);
void ConnectionResultEventHandler(void* context, ConnectionResultEventArgs* e);
void ErrorInfoEventHandler(void* ctx, ErrorInfoEventArgs* e);

@interface MRDPViewController ()

@end

@implementation MRDPViewController

@synthesize context = context;
@synthesize delegate = delegate;

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

- (void)viewDidConnect:(NSNotification *)notification
{
    if(mrdpView == (MRDPView *)notification.object)
    {
        NSLog(@"viewDidConnect - %@", [notification.userInfo valueForKey:@"result"]);
        
        if(delegate && [delegate respondsToSelector:@selector(didConnectWithResult:)])
        {
            [delegate didConnectWithResult:[notification.userInfo valueForKey:@"result"]];
        }
    }
}

- (void)viewDidPostError:(NSNotification *)notification
{
    if(mrdpView == (MRDPView *)notification.object)
    {
        NSLog(@"viewDidPostError - %@", [notification.userInfo valueForKey:@"message"]);
        
        if(delegate && [delegate respondsToSelector:@selector(didErrorWithCode:message:)])
        {
            [delegate didErrorWithCode:[notification.userInfo valueForKey:@"code"] message:[notification.userInfo valueForKey:@"message"]];
        }
    }
}

- (void)viewDidEmbed:(NSNotification *)notification
{
    if(mrdpView == (MRDPView *)notification.object)
    {
        NSLog(@"viewDidEmbed");
    }
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:MRDPViewDidPostErrorInfoNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:MRDPViewDidConnectWithResultNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:
        MRDPViewDidPostEmbedNotification object:nil];
    
    [mrdpView releaseResources];
    [self releaseContext];
    
    [super dealloc];
}

- (void)loadView
{
    mrdpView = [[MRDPView alloc] initWithFrame:NSZeroRect];
    
    self.view = mrdpView;
}

- (BOOL)connect:(NSArray *)arguments
{
    int status;
    mfContext* mfc;
    
    [self createContext];
    
    status = [self parseCommandLineArguments:arguments];
    
    mfc = (mfContext*) context;
    mfc->view = (void*) mrdpView;
    
    if (status < 0)
    {
        return false;
    }
    else
    {
        PubSub_SubscribeConnectionResult(context->pubSub, ConnectionResultEventHandler);
    	PubSub_SubscribeErrorInfo(context->pubSub, ErrorInfoEventHandler);
        PubSub_SubscribeEmbedWindow(context->pubSub, EmbedWindowEventHandler);
        
        freerdp_client_start(context);
    }

    return true;
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
    mfContext* context = (mfContext*)ctx;
    [[NSNotificationCenter defaultCenter] postNotificationName:MRDPViewDidPostEmbedNotification object:context->view userInfo:nil];
}

void ConnectionResultEventHandler(void* ctx, ConnectionResultEventArgs* e)
{
	NSLog(@"ConnectionResult event result:%d\n", e->result);
    
    NSString* message = nil;
    
    if (e->result != 0)
    {
        if (connectErrorCode == AUTHENTICATIONERROR)
        {
            message = [NSString stringWithFormat:@"%@:\n%@", message, @"Authentication failure, check credentials."];
        }
    }
    
    NSDictionary *userInfo = [[NSDictionary alloc] initWithObjectsAndKeys:message, @"message", e->result, @"result", nil];
    [message release];
    
    mfContext* context = (mfContext*)ctx;
    [[NSNotificationCenter defaultCenter] postNotificationName:MRDPViewDidConnectWithResultNotification object:context->view userInfo:userInfo];
    
    [userInfo release];
}

void ErrorInfoEventHandler(void* ctx, ErrorInfoEventArgs* e)
{
	NSLog(@"ErrorInfo event code:%d\n", e->code);
    
    // Retrieve error message associated with error code
    NSString* message = nil;
    if (e->code != ERRINFO_NONE)
    {
        const char* errorMessage = freerdp_get_error_info_string(e->code);
        message = [[NSString alloc] initWithUTF8String:errorMessage];
    }
    
    NSDictionary *userInfo = [[NSDictionary alloc] initWithObjectsAndKeys:message, @"message", e->code, @"code", nil];
    [message release];
    
    mfContext* context = (mfContext*)ctx;
    [[NSNotificationCenter defaultCenter] postNotificationName:MRDPViewDidPostErrorInfoNotification object:context->view userInfo:userInfo];
    
    [userInfo release];
}
