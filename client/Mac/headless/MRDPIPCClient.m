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

void EmbedWindowEventHandler(void* context, EmbedWindowEventArgs* e);
void ConnectionResultEventHandler(void* context, ConnectionResultEventArgs* e);
void ErrorInfoEventHandler(void* ctx, ErrorInfoEventArgs* e);

@implementation MRDPIPCClient

static NSString* const clientBaseName = @"com.devolutions.freerdp-ipc-child";

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
    }
    
    return self;
}

- (void)dealloc
{
    [self stop];
    
    [super dealloc];
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
}

- (void)start
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

- (void)keyDown:(NSEvent *)event
{
    [mrdpClient keyDown:event];
}

- (void)keyUp:(NSEvent*)event
{
    [mrdpClient keyUp:event];
}

- (void)flagsChanged:(NSEvent*)event
{
    [mrdpClient flagsChanged:event];
}

- (void)forwardMouseEvent:(NSArray *)args
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

-(void)sendCtrlAltDelete
{
    [mrdpClient sendCtrlAltDelete];
}

- (void)addServerDrive:(ServerDrive *)drive
{
    [mrdpClient addServerDrive:drive];
}

- (NSString *)getErrorInfoString:(int)code
{
    return [mrdpClient getErrorInfoString:code];
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
            if([serverProxy delegate] && [[serverProxy delegate] respondsToSelector:@selector(didConnect)])
            {
                [[serverProxy delegate] performSelectorOnMainThread:@selector(didConnect) withObject:nil waitUntilDone:true];
            }
        }
        else
        {
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

- (void)initialise:(rdpContext *)rdpContext
{
    
}

- (void)setNeedsDisplayInRect:(NSRect)newDrawRect
{
    NSValue* boxed = [NSValue valueWithRect:newDrawRect];
    
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
    
    [serverProxy cursorUpdated:cursorData hotspot:boxedHotspot];
}

- (void)preConnect:(freerdp*)rdpInstance
{
    
}

- (bool)postConnect:(freerdp*)rdpInstance;
{
    int framebufferSize = mrdpClient->frameBuffer->fbScanline * mrdpClient->frameBuffer->fbHeight;
    
    return [serverProxy pixelDataAvailable:framebufferSize];
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

