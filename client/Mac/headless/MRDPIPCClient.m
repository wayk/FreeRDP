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

#import "../MRDPClientNotifications.h"
#import "../MRDPCursor.h"

#define TAG CLIENT_TAG("mac")

void EmbedWindowEventHandler(void* context, EmbedWindowEventArgs* e);
void ConnectionResultEventHandler(void* context, ConnectionResultEventArgs* e);
void ErrorInfoEventHandler(void* ctx, ErrorInfoEventArgs* e);

@implementation MRDPIPCClient

static NSString* const clientBaseName = @"com.devolutions.freerdp-ipc-child";

NSMutableArray *forwardedServerDrives;

- (BOOL)isConnected
{
    return self->mrdpClient.is_connected;
}

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
        
        forwardedServerDrives = [[NSMutableArray alloc] init];
    }
    
    return self;
}

- (void)dealloc
{
    [self stop];
    
    [forwardedServerDrives release];
    
    [super dealloc];
}

- (void)configure
{
    [self performSelector:@selector(configureInternal) withObject:nil afterDelay:0.0];
}

- (void)configureInternal
{
	id delegate = [serverProxy delegate];
	if (delegate && [delegate respondsToSelector:@selector(initializeLogging)])
	{
		[delegate initializeLogging];
	}
    WLog_DBG(TAG, "configureInternal");
	
    if(context == nil)
    {
        [self createContext];
    }
    
    mfContext* mfc = (mfContext*)context;
    mfc->client = (void*)mrdpClient;
    
    PubSub_SubscribeConnectionResult(context->pubSub, ConnectionResultEventHandler);
    PubSub_SubscribeErrorInfo(context->pubSub, ErrorInfoEventHandler);
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
	
	WLog_Init();
    
    WLog_INFO(TAG, "Log initialized headless");
}

- (void)start
{
    [self performSelector:@selector(startInternal) withObject:nil afterDelay:0.0];
}

- (void)startInternal
{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(viewDidPostError:) name:MRDPClientDidPostErrorInfoNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(viewDidConnect:) name:MRDPClientDidConnectWithResultNotification object:nil];
    
    mrdpClient = [[MRDPClient alloc] init];
    mrdpClient.delegate = self;
    
    mfContext* mfc = (mfContext*)context;
    mfc->client = mrdpClient;
    
    self.frame = NSMakeRect(0, 0, context->settings->DesktopWidth, context->settings->DesktopHeight);
    
    freerdp_client_start(context);
    
    is_stopped = false;
}

- (void)stop
{
    [self performSelector:@selector(stopInternal) withObject:nil afterDelay:0.0];
}

- (void)stopInternal
{
    if(!is_stopped)
    {
        [[NSNotificationCenter defaultCenter] removeObserver:self];
        
        [mrdpClient pause];

        freerdp_client_stop(context);
        
        [mrdpClient releaseResources];
        [mrdpClient release];
        mrdpClient = nil;
        
        mfContext* mfc = (mfContext *)context;
        mfc->client = nil;
        
        PubSub_UnsubscribeConnectionResult(context->pubSub, ConnectionResultEventHandler);
        PubSub_UnsubscribeErrorInfo(context->pubSub, ErrorInfoEventHandler);
        
        [self releaseContext];
        
        is_stopped = true;
    }
}

- (void)applicationResignActive
{
    [mrdpClient performSelector:@selector(resignActive) withObject:nil afterDelay:0.0];
}

- (oneway void)keyDown:(NSEvent *)event
{
    [mrdpClient performSelector:@selector(keyDown:) withObject:event afterDelay:0.0];
}

- (oneway void)keyUp:(NSEvent*)event
{
    [mrdpClient performSelector:@selector(keyUp:) withObject:event afterDelay:0.0];
}

- (oneway void)flagsChanged:(NSEvent*)event
{
    [mrdpClient performSelector:@selector(flagsChanged:) withObject:event afterDelay:0.0];
}

- (oneway void)forwardMouseEvent:(NSArray *)args
{
    [self performSelector:@selector(forwardMouseEventInternal:) withObject:args afterDelay:0.0];
}

- (void)forwardMouseEventInternal:(NSArray *)args
{
    int eventType = (NSEventType)[args[0] integerValue];
    float xCoord = [args[1] floatValue];
    float yCoord = [args[2] floatValue];
    NSPoint coord = NSMakePoint(xCoord, yCoord);
    
    switch(eventType)
    {
        case NSLeftMouseDown:
        {
            [mrdpClient mouseDown:coord];
            break;
        }
        case NSLeftMouseUp:
        {
            [mrdpClient mouseUp:coord];
            break;
        }
        case NSRightMouseDown:
        {
            [mrdpClient rightMouseDown:coord];
            break;
        }
        case NSRightMouseUp:
        {
            [mrdpClient rightMouseUp:coord];
            break;
        }
        case NSMouseMoved:
        {
            [mrdpClient mouseMoved:coord];
            break;
        }
        case NSLeftMouseDragged:
        {
            [mrdpClient mouseDragged:coord];
            break;
        }
        case NSRightMouseDragged:
        {
            [mrdpClient rightMouseDragged:coord];
            break;
        }
        case NSOtherMouseDown:
        {
            [mrdpClient otherMouseDown:coord];
            break;
        }
        case NSOtherMouseUp:
        {
            [mrdpClient otherMouseUp:coord];
            break;
        }
        case NSOtherMouseDragged:
        {
            [mrdpClient otherMouseDragged:coord];
            break;
        }
        case NSScrollWheel:
        {
            float yDelta = [args[3] floatValue];
            [mrdpClient scrollWheelCoordinates:coord deltaY:yDelta];
        }
    }
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

- (oneway void)sendCtrlAltDelete
{
    [mrdpClient performSelector:@selector(sendCtrlAltDelete) withObject:nil afterDelay:0.0];
}

-(void)sendStart
{
    [mrdpClient performSelector:@selector(sendStart) withObject:nil afterDelay:0.0];
}

-(void)sendAppSwitch
{
    [mrdpClient performSelector:@selector(sendAppSwitch) withObject:nil afterDelay:0.0];
}

-(void)sendKey:(UINT16)key
{
    [mrdpClient performSelector:@selector(sendKey:) withObject:key];
}

-(void)sendKey:(UINT16)key withModifier:(UINT16)modifier
{
    [mrdpClient performSelector:@selector(sendKey:withModifier:) withObject:key withObject:modifier];
}

-(void)sendKeystrokes:(NSString *)keys
{
    [mrdpClient performSelector:@selector(sendKeystrokes:) withObject:keys afterDelay:0.0];
}

- (oneway void)addServerDrive:(ServerDrive *)drive
{
    [forwardedServerDrives addObject:drive];
}

- (NSString *)getErrorInfoString:(int)code
{
    return [mrdpClient getErrorInfoString:code];
}

- (BOOL)getBooleanSettingForIdentifier:(int)identifier
{
    return freerdp_get_param_bool(context->settings, identifier);
}

- (oneway void)setBooleanSettingForIdentifier:(int)identifier withValue:(BOOL)value
{
    freerdp_set_param_bool(context->settings, identifier, value);
}

- (int)getIntegerSettingForIdentifier:(int)identifier
{
    return freerdp_get_param_int(context-> settings, identifier);
}

- (oneway void)setIntegerSettingForIdentifier:(int)identifier withValue:(int)value
{
    freerdp_set_param_int(context->settings, identifier, value);
}

- (uint32)getInt32SettingForIdentifier:(int)identifier
{
    return freerdp_get_param_uint32(context-> settings, identifier);
}

- (oneway void)setInt32SettingForIdentifier:(int)identifier withValue:(uint32)value
{
    freerdp_set_param_uint32(context->settings, identifier, value);
}

- (uint64)getInt64SettingForIdentifier:(int)identifier
{
    return freerdp_get_param_uint64(context-> settings, identifier);
}

- (oneway void)setInt64SettingForIdentifier:(int)identifier withValue:(uint64)value
{
    freerdp_set_param_uint64(context->settings, identifier, value);
}

- (NSString *)getStringSettingForIdentifier:(int)identifier
{
    char* cString = freerdp_get_param_string(context-> settings, identifier);
    
    return cString ? [NSString stringWithUTF8String:cString] : nil;
}

- (oneway void)setStringSettingForIdentifier:(int)identifier withValue:(NSString *)value
{
    char* cString = (char*)[value UTF8String];
    
    freerdp_set_param_string(context->settings, identifier, cString);
}

- (void)viewDidConnect:(NSNotification *)notification
{
    rdpContext *ctx;
    
    [[[notification userInfo] valueForKey:@"context"] getValue:&ctx];
    
    if(ctx == self->context)
    {
        ConnectionResultEventArgs *e = nil;
        [[[notification userInfo] valueForKey:@"connectionArgs"] getValue:&e];
        
        if(e->result == 0)
        {
            WLog_DBG(TAG, "viewDidConnect");
            if([serverProxy delegate] && [[serverProxy delegate] respondsToSelector:@selector(didConnect)])
            {
                [[serverProxy delegate] performSelectorOnMainThread:@selector(didConnect) withObject:nil waitUntilDone:true];
            }
        }
        else
        {
            WLog_DBG(TAG, "viewDidConnect");
            if([serverProxy delegate] && [[serverProxy delegate] respondsToSelector:@selector(didFailToConnectWithError:)])
            {
                NSNumber *connectErrorCode =  [NSNumber numberWithUnsignedInt:freerdp_get_last_error(ctx)];
                
                [[serverProxy delegate] performSelectorOnMainThread:@selector(didFailToConnectWithError:) withObject:connectErrorCode waitUntilDone:true];
            }
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
        
        WLog_DBG(TAG, "viewDidPostError");
        if([serverProxy delegate] && [[serverProxy delegate] respondsToSelector:@selector(didErrorWithCode:)])
        {
            [[serverProxy delegate] performSelectorOnMainThread:@selector(didErrorWithCode:) withObject:[NSNumber numberWithInt:e->code] waitUntilDone:true];
        }
    }
}

// MRDPClientDelegate
- (bool)renderToBuffer
{
    return true;
}

- (NSString*)renderBufferName
{
    return [NSString stringWithFormat:@"/%@", [serverProxy proxyID]];
}

- (NSRect)frame
{
    // Cheating a bit because I don't want to add "viewFrame" to the interface
    NSValue* boxedFrame = (NSValue *)[[serverProxy delegate] performSelector:NSSelectorFromString(@"viewFrame")];
	return [boxedFrame rectValue];
}

- (void)setFrame:(NSRect)frame
{
    // no-op
}

- (void)setFrameSize:(NSSize)newSize
{
	[serverProxy setFrameSize:newSize];
}

- (NSArray *)getForwardedServerDrives
{
    return [NSArray arrayWithArray:forwardedServerDrives];
}

- (void)initialise:(rdpContext *)rdpContext
{
    
}

- (void)setNeedsDisplayInRect:(NSRect)newDrawRect
{	
    NSValue* boxed = [NSValue valueWithRect:newDrawRect];
    WLog_DBG(TAG, "setNeedsDisplayInRect shm: %p x:%f y:%f w:%f h:%f", self->mrdpClient->frameBuffer->fbSharedMemory,
			 newDrawRect.origin.x, newDrawRect.origin.y, newDrawRect.size.width, newDrawRect.size.height);
    [serverProxy performSelector:@selector(pixelDataUpdated:) withObject:boxed afterDelay:0.0];
}

- (void)setCursor:(MRDPCursor*) cursor
{
    NSPoint hotspot;
    NSData* cursorData = nil;
    
    if(cursor != nil)
    {
        hotspot = cursor->nsCursor.hotSpot;
        cursorData = [cursor->bmiRep TIFFRepresentation];
    }
    
    NSValue* boxedHotspot = [NSValue valueWithPoint:hotspot];
    WLog_DBG(TAG, "setCursor");
    [serverProxy cursorUpdated:cursorData hotspot:boxedHotspot];
}

- (void)preConnect:(freerdp*)rdpInstance
{
    
}

- (bool)postConnect:(freerdp*)rdpInstance;
{
    int framebufferSize = mrdpClient->frameBuffer->fbScanline * mrdpClient->frameBuffer->fbHeight;
    WLog_DBG(TAG, "postConnect");
    return [serverProxy pixelDataAvailable:framebufferSize];
}

- (void)willResizeDesktop
{
}

- (BOOL)didResizeDesktop
{
	int frameBufferSize = mrdpClient->frameBuffer->fbScanline * mrdpClient->frameBuffer->fbHeight;
    WLog_DBG(TAG, "didResizeDesktop w:%d h:%d", mrdpClient->frameBuffer->fbWidth, mrdpClient->frameBuffer->fbHeight);
	[serverProxy desktopResized:frameBufferSize];
    return TRUE;
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
    WLog_DBG(TAG, "provideServerCredentials");
    bool result = [serverProxy provideServerCredentials:[*credentials serverHostname] username:[*credentials username] password:[*credentials password] domain:[*credentials domain]];
    
    [*credentials setUsername:[[serverProxy serverCredential] username]];
    [*credentials setPassword:[[serverProxy serverCredential] password]];
    [*credentials setDomain:[[serverProxy serverCredential] domain]];
    
    return result;
}

- (BOOL)validateCertificate:(ServerCertificate *)certificate
{
    WLog_DBG(TAG, "validateCertificate");
    return [serverProxy validateCertificate:certificate.subject issuer:certificate.issuer fingerprint:certificate.fingerprint];
}

- (BOOL)validateX509Certificate:(X509Certificate *)certificate
{
    WLog_DBG(TAG, "validateX509Certificate");
    return [serverProxy validateX509Certificate:certificate.data hostname:certificate.hostname port:certificate.port];
}

- (void)setIsReadOnly:(bool)isReadOnly
{
	if ((mrdpClient == nil) && (!mrdpClient.is_connected))
		return;
	
	mrdpClient.isReadOnly = isReadOnly;
}

@end

void ConnectionResultEventHandler(void* ctx, ConnectionResultEventArgs* e)
{
    @autoreleasepool
    {
        rdpContext* context = (rdpContext*) ctx;
        
        NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:[NSValue valueWithPointer:context], @"context",
                                  [NSValue valueWithPointer:e], @"connectionArgs",
                                  [NSNumber numberWithInt:connectErrorCode], @"connectErrorCode", nil];
        
        [[NSNotificationCenter defaultCenter] postNotificationName:MRDPClientDidConnectWithResultNotification object:nil userInfo:userInfo];
    }
}

void ErrorInfoEventHandler(void* ctx, ErrorInfoEventArgs* e)
{
    @autoreleasepool
    {
        rdpContext* context = (rdpContext*) ctx;
        
        NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:[NSValue valueWithPointer:context], @"context",
                                  [NSValue valueWithPointer:e], @"errorArgs", nil];
        
        [[NSNotificationCenter defaultCenter] postNotificationName:MRDPClientDidPostErrorInfoNotification object:nil userInfo:userInfo];
    }
}

