//
//  MRDPIPCClient.m
//  FreeRDP
//
//  Created by Richard Markiewicz on 2014-11-15.
//
//

#import <Foundation/Foundation.h>

#import "MRDPIPCClient.h"
#import "MRDPIPCServer.h"

void EmbedWindowEventHandler(void* context, EmbedWindowEventArgs* e);
void ConnectionResultEventHandler(void* context, ConnectionResultEventArgs* e);
void ErrorInfoEventHandler(void* ctx, ErrorInfoEventArgs* e);

@implementation MRDPIPCClient

static NSString *MRDPViewDidPostErrorInfoNotification = @"MRDPViewDidPostErrorInfoNotification";
static NSString *MRDPViewDidConnectWithResultNotification = @"MRDPViewDidConnectWithResultNotification";
static NSString *MRDPViewDidPostEmbedNotification = @"MRDPViewDidPostEmbedNotification";

static NSString* const clientBaseName = @"com.devolutions.freerdp-ipc-child";

- (id)initWithServer:(NSString *)registeredName
{
    self = [super init];
    if(self)
    {
        serverProxy = (id)[NSConnection rootProxyForConnectionWithRegisteredName:registeredName host:nil];
        [serverProxy setProtocolForProxy:@protocol(MRDPIPCServer)];
        
        if(serverProxy == nil)
        {
            NSLog(@"Failed to establish IPC connection to %@\n", registeredName);
            
            [self release];
            
            return nil;
        }
        
        NSString *serverID = [serverProxy proxyID];
        NSString *clientName = [NSString stringWithFormat:@"%@.%@", clientBaseName, serverID];
        
        clientConnection = [NSConnection serviceConnectionWithName:clientName rootObject:self];
        [clientConnection runInNewThread];
        
        NSLog(@"Launched IPC server at %@\n", clientName);
        
        [serverProxy clientConnected:clientName];
    }
    
    return self;
}

- (void)configure
{
    if(context == nil)
    {
        [self createContext];
    }

    mfContext* mfc = (mfContext*)context;
    mfc->client = (void*)mrdpClient;

    PubSub_SubscribeConnectionResult(context->pubSub, ConnectionResultEventHandler);
    PubSub_SubscribeErrorInfo(context->pubSub, ErrorInfoEventHandler);
    PubSub_SubscribeEmbedWindow(context->pubSub, EmbedWindowEventHandler);
}

- (void)start
{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(viewDidPostError:) name:MRDPViewDidPostErrorInfoNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(viewDidConnect:) name:MRDPViewDidConnectWithResultNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(viewDidEmbed:) name:MRDPViewDidPostEmbedNotification object:nil];
    
    // view.usesAppleKeyboard = self.usesAppleKeyboard;
    
    mrdpClient = [[MRDPClient alloc] init];
    mrdpClient.delegate = self;
    
    mfContext* mfc = (mfContext*)context;
    mfc->client = mrdpClient;
    
    freerdp_client_start(context);
}

- (void)stop
{

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

- (void)addServerDrive:(ServerDrive *)drive
{
    char* d[] = { "drive", (char *)[drive.name UTF8String], (char *)[drive.path UTF8String] };
    freerdp_client_add_device_channel(context->settings, 3, d);
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

// MRDPClientDelegate
- (bool)renderToBuffer
{
    return true;
}

//@property (assign) int is_connected;
//@property (readonly) NSRect frame;

- (void)initialise:(rdpContext *)rdpContext
{
    
}

- (void)setNeedsDisplayInRect:(NSRect)newDrawRect
{
    
}

- (void)setCursor:(NSCursor*) cursor
{
    
}

- (void)preConnect:(freerdp*)rdpInstance
{
    
}

- (void)postConnect:(freerdp*)rdpInstance;
{
    printf("FRAMEBUFFER ID %i", mrdpClient.frameBuffer.fbSegmentId);
}

- (void)pause
{
    
}

- (void)resume
{
    
}

- (void)releaseResources
{
    
}

- (BOOL)provideServerCredentials:(ServerCredential **)credentials
{
    return false;
}

- (BOOL)validateCertificate:(ServerCertificate *)certificate
{
    return false;
}

- (BOOL)validateX509Certificate:(X509Certificate *)certificate
{
    return false;
}

@end

void EmbedWindowEventHandler(void* ctx, EmbedWindowEventArgs* e)
{
    @autoreleasepool
    {
        rdpContext* context = (rdpContext*) ctx;
        
        NSDictionary *userInfo = [NSDictionary dictionaryWithObject:[NSValue valueWithPointer:context] forKey:@"context"];
        
        [[NSNotificationCenter defaultCenter] postNotificationName:MRDPViewDidPostEmbedNotification object:nil userInfo:userInfo];
    }
}

void ConnectionResultEventHandler(void* ctx, ConnectionResultEventArgs* e)
{
    @autoreleasepool
    {
        NSLog(@"ConnectionResultEventHandler");
        
        rdpContext* context = (rdpContext*) ctx;
        
        NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:[NSValue valueWithPointer:context], @"context",
                                  [NSValue valueWithPointer:e], @"connectionArgs",
                                  [NSNumber numberWithInt:connectErrorCode], @"connectErrorCode", nil];
        
        [[NSNotificationCenter defaultCenter] postNotificationName:MRDPViewDidConnectWithResultNotification object:nil userInfo:userInfo];
    }
}

void ErrorInfoEventHandler(void* ctx, ErrorInfoEventArgs* e)
{
    @autoreleasepool
    {
        NSLog(@"ErrorInfoEventHandler");
        
        rdpContext* context = (rdpContext*) ctx;
        
        NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:[NSValue valueWithPointer:context], @"context",
                                  [NSValue valueWithPointer:e], @"errorArgs", nil];
        
        [[NSNotificationCenter defaultCenter] postNotificationName:MRDPViewDidPostErrorInfoNotification object:nil userInfo:userInfo];
    }
}

