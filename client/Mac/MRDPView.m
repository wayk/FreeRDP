/**
 * FreeRDP: A Remote Desktop Protocol Implementation
 * MacFreeRDP
 *
 * Copyright 2012 Thomas Goddard
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#include <winpr/windows.h>

#include "mf_client.h"
#import "mfreerdp.h"
#import "MRDPView.h"
#import "MRDPCursor.h"
#import "Clipboard.h"
#import "PasswordDialog.h"
#import "MRDPViewDelegate.h"

#include <winpr/crt.h>
#include <winpr/input.h>
#include <winpr/synch.h>
#include <winpr/sysinfo.h>

#include <freerdp/constants.h>
#include <freerdp/locale/keyboard.h>

#import "freerdp/freerdp.h"
#import "freerdp/types.h"
#import "freerdp/channels/channels.h"
#import "freerdp/gdi/gdi.h"
#import "freerdp/gdi/dc.h"
#import "freerdp/gdi/region.h"
#import "freerdp/graphics.h"
#import "freerdp/client/file.h"
#import "freerdp/client/cmdline.h"
#import "freerdp/log.h"

#define TAG CLIENT_TAG("mac")

void mac_desktop_resize(rdpContext* context);

@implementation MRDPView

@synthesize is_connected;
@synthesize usesAppleKeyboard;
@synthesize delegate;



DWORD mac_client_thread(void* param)
{
	@autoreleasepool
	{
		int status;
		HANDLE events[4];
		HANDLE inputEvent;
		HANDLE inputThread;
		HANDLE updateEvent;
		HANDLE updateThread;
		HANDLE channelsEvent;
		
		DWORD nCount;
		rdpContext* context = (rdpContext*) param;
		mfContext* mfc = (mfContext*) context;
		freerdp* instance = context->instance;
		MRDPView* view = mfc->view;
		rdpSettings* settings = context->settings;
		
		status = freerdp_connect(context->instance);
        
		if (!status)
		{
			[view setIs_connected:0];
			return 0;
		}
		
		[view setIs_connected:1];
		
		nCount = 0;
		
		events[nCount++] = mfc->stopEvent;
		
		if (!settings->AsyncUpdate)
		{
			events[nCount++] = updateEvent = freerdp_get_message_queue_event_handle(instance, FREERDP_UPDATE_MESSAGE_QUEUE);
		}
		
		if (settings->AsyncInput)
		{
			inputThread = CreateThread(NULL, 0, (LPTHREAD_START_ROUTINE) mac_client_input_thread, context, 0, NULL);
		}
		else
		{
			events[nCount++] = inputEvent = freerdp_get_message_queue_event_handle(instance, FREERDP_INPUT_MESSAGE_QUEUE);
		}
		
		events[nCount++] = channelsEvent = freerdp_channels_get_event_handle(instance);
		
		while (1)
		{
			status = WaitForMultipleObjects(nCount, events, FALSE, INFINITE);
			
			if (WaitForSingleObject(mfc->stopEvent, 0) == WAIT_OBJECT_0)
			{
				freerdp_disconnect(instance);
				break;
			}
			
			if (!settings->AsyncUpdate)
			{
				if (WaitForSingleObject(updateEvent, 0) == WAIT_OBJECT_0)
				{
					update_activity_cb(instance);
				}
			}
			
			if (!settings->AsyncInput)
			{
				if (WaitForSingleObject(inputEvent, 0) == WAIT_OBJECT_0)
				{
					input_activity_cb(instance);
				}
			}
			
			if (WaitForSingleObject(channelsEvent, 0) == WAIT_OBJECT_0)
			{
				freerdp_channels_process_pending_messages(instance);
			}
		}
		
		if (settings->AsyncUpdate)
		{
			wMessageQueue* updateQueue = freerdp_get_message_queue(instance, FREERDP_UPDATE_MESSAGE_QUEUE);
			MessageQueue_PostQuit(updateQueue, 0);
			WaitForSingleObject(updateThread, INFINITE);
			CloseHandle(updateThread);
		}
		
		if (settings->AsyncInput)
		{
			wMessageQueue* inputQueue = freerdp_get_message_queue(instance, FREERDP_INPUT_MESSAGE_QUEUE);
			MessageQueue_PostQuit(inputQueue, 0);
			WaitForSingleObject(inputThread, INFINITE);
			CloseHandle(inputThread);
		}
		
		ExitThread(0);
		return 0;
	}
}

- (id)initWithFrame:(NSRect)frame
{
	self = [super initWithFrame:frame];
	
	if (self)
	{
		// Initialization code here.
        self.usesAppleKeyboard = true;
	}
	
	return self;
}

- (void)initialise:(rdpContext *)rdpContext
{
    if (!initialized)
    {
        // TODO: dispose of this properly
        self->context = rdpContext;
        self->instance = context->instance;
        
        EmbedWindowEventArgs e;
        EventArgsInit(&e, "mfreerdp");
        e.embed = TRUE;
        e.handle = (void*) self;
        PubSub_OnEmbedWindow(context->pubSub, context, &e);
    
        NSScreen* screen = [[NSScreen screens] objectAtIndex:0];
        NSRect screenFrame = [screen frame];
    
        if (context->instance->settings->Fullscreen)
        {
            context->instance->settings->DesktopWidth  = screenFrame.size.width;
            context->instance->settings->DesktopHeight = screenFrame.size.height;
        }

        // setup a mouse tracking area
        NSTrackingArea * trackingArea = [[NSTrackingArea alloc] initWithRect:[self visibleRect] options:NSTrackingMouseEnteredAndExited | NSTrackingMouseMoved | NSTrackingCursorUpdate | NSTrackingEnabledDuringMouseDrag | NSTrackingActiveWhenFirstResponder owner:self userInfo:nil];
        [self addTrackingArea:trackingArea];
        [trackingArea release];
        
        // Set the default cursor
        currentCursor = [NSCursor arrowCursor];

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationDidBecomeActive:)
                                                     name:@"NSApplicationDidBecomeActiveNotification" object:nil];
        
		initialized = YES;
	}
}

- (void)releaseResources
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"NSApplicationDidBecomeActiveNotification" object:nil];
}

- (void)applicationDidBecomeActive:(NSNotification *)notification
{
    if(self->is_connected)
    {
        NSLog(@"Releasing meta key");
        
        freerdp_input_send_keyboard_event(instance->input, 256 | KBD_FLAGS_RELEASE, 0x005B);
    }
}

- (void)setCursor:(NSCursor*) cursor
{
	self->currentCursor = cursor;
	[[self window] invalidateCursorRectsForView:self];
}

- (void)resetCursorRects
{
	[self addCursorRect:[self visibleRect] cursor:currentCursor];
}

- (void)pause
{
    // Temporarily remove tracking areas, else we will crash if the mouse
    // enters the view while restarting
    NSArray *trackingAreas = self.trackingAreas;
    for(NSTrackingArea *ta in trackingAreas)
    {
        [self removeTrackingArea:ta];
    }

}

- (void)resume
{
    NSTrackingArea * trackingArea = [[NSTrackingArea alloc] initWithRect:[self visibleRect] options:NSTrackingMouseEnteredAndExited | NSTrackingMouseMoved | NSTrackingCursorUpdate | NSTrackingEnabledDuringMouseDrag | NSTrackingActiveWhenFirstResponder owner:self userInfo:nil];
    [self addTrackingArea:trackingArea];
    [trackingArea release];

}

/*************************************************************************************************************
 * Support for SmartSizing in app
 * We want the view to grow and shrink, but never get larger than the configured desktop size
 * The implementation is not perfect because we only reconfigure the view once the resize is complete,
 * not live
 * However, I get a lot of weird bugs doing this live inside resizeWithOldSuperviewSize:(NSSize)oldBoundsSize
 ************************************************************************************************************/
- (void)viewDidEndLiveResize
{
    if(freerdp_get_param_bool(self->context->settings, FreeRDP_SmartSizing))
    {
        NSSize oldBoundsSize = self.superview.bounds.size;
        
        int newWidth = self.frame.size.width;
        int newHeight = self.frame.size.height;
        
        if(oldBoundsSize.width > freerdp_get_param_uint32(self->context->settings, FreeRDP_DesktopWidth))
        {
            self.autoresizingMask = self.autoresizingMask & ~NSViewWidthSizable;
            newWidth = freerdp_get_param_uint32(self->context->settings, FreeRDP_DesktopWidth);
        }
        else if(oldBoundsSize.width <= freerdp_get_param_uint32(self->context->settings, FreeRDP_DesktopWidth))
        {
            self.autoresizingMask = self.autoresizingMask |= NSViewWidthSizable;
            newWidth = oldBoundsSize.width;
        }
        
        if(oldBoundsSize.height > freerdp_get_param_uint32(self->context->settings, FreeRDP_DesktopHeight))
        {
            self.autoresizingMask = self.autoresizingMask & ~NSViewHeightSizable;
            newHeight = freerdp_get_param_uint32(self->context->settings, FreeRDP_DesktopHeight);
        }
        else if(oldBoundsSize.height <= freerdp_get_param_uint32(self->context->settings, FreeRDP_DesktopHeight))
        {
            self.autoresizingMask = self.autoresizingMask |= NSViewHeightSizable;
            newHeight = oldBoundsSize.height;
        }
        
        [self setFrameSize:NSMakeSize(newWidth, newHeight)];
        [self setFrameOrigin:NSMakePoint((oldBoundsSize.width - newWidth) / 2,
                                         (oldBoundsSize.height - newHeight) / 2)];
    }
}

- (void)resizeWithOldSuperviewSize:(NSSize)oldBoundsSize
{
    [super resizeWithOldSuperviewSize:oldBoundsSize];
}

/***********************************************************************
 * become first responder so we can get keyboard and mouse events
 ***********************************************************************/

- (BOOL)acceptsFirstResponder
{
	return YES;
}

- (void) mouseMoved:(NSEvent *)event
{
	[super mouseMoved:event];
	
	if (!is_connected)
		return;
	
    NSPoint loc = [self convertPoint:[event locationInWindow] fromView: nil];
    
	int x = (int) loc.x;
	int y = (int) loc.y;

	mf_scale_mouse_event(context, instance->input, PTR_FLAGS_MOVE, x, y);
}

- (void)mouseDown:(NSEvent *) event
{
	[super mouseDown:event];
	
	if (!is_connected)
		return;
	
    NSPoint loc = [self convertPoint:[event locationInWindow] fromView: nil];
	int x = (int) loc.x;
	int y = (int) loc.y;
	
	mf_scale_mouse_event(context, instance->input, PTR_FLAGS_DOWN | PTR_FLAGS_BUTTON1, x, y);
}

- (void)mouseUp:(NSEvent *) event
{
	[super mouseUp:event];
	
	if (!is_connected)
		return;
	
    NSPoint loc = [self convertPoint:[event locationInWindow] fromView: nil];
	int x = (int) loc.x;
	int y = (int) loc.y;
	
	mf_scale_mouse_event(context, instance->input, PTR_FLAGS_BUTTON1, x, y);
}

- (void)rightMouseDown:(NSEvent *)event
{
	[super rightMouseDown:event];
	
	if (!is_connected)
		return;
	
    NSPoint loc = [self convertPoint:[event locationInWindow] fromView: nil];
	int x = (int) loc.x;
	int y = (int) loc.y;
	
	mf_scale_mouse_event(context, instance->input, PTR_FLAGS_DOWN | PTR_FLAGS_BUTTON2, x, y);
}

- (void)rightMouseUp:(NSEvent *)event
{
	[super rightMouseUp:event];
	
	if (!is_connected)
		return;
	
    NSPoint loc = [self convertPoint:[event locationInWindow] fromView: nil];
	int x = (int) loc.x;
	int y = (int) loc.y;
	
	mf_scale_mouse_event(context, instance->input, PTR_FLAGS_BUTTON2, x, y);
}

- (void)otherMouseDown:(NSEvent *)event
{
	[super otherMouseDown:event];
	
	if (!is_connected)
		return;
	
    NSPoint loc = [self convertPoint:[event locationInWindow] fromView: nil];
	int x = (int) loc.x;
	int y = (int) loc.y;
	
	mf_scale_mouse_event(context, instance->input, PTR_FLAGS_DOWN | PTR_FLAGS_BUTTON3, x, y);
}

- (void)otherMouseUp:(NSEvent *)event
{
	[super otherMouseUp:event];
	
	if (!is_connected)
		return;
	
    NSPoint loc = [self convertPoint:[event locationInWindow] fromView: nil];
	int x = (int) loc.x;
	int y = (int) loc.y;
	
	mf_scale_mouse_event(context, instance->input, PTR_FLAGS_BUTTON3, x, y);
}

- (void)scrollWheel:(NSEvent *)event
{
	UINT16 flags;

	[super scrollWheel:event];

	if (!is_connected)
		return;
	
    NSPoint loc = [self convertPoint:[event locationInWindow] fromView: nil];
	int x = (int) loc.x;
	int y = (int) loc.y;
	
	flags = PTR_FLAGS_WHEEL;

	/* 1 event = 120 units */
	int units = [event deltaY] * 120;

	/* send out all accumulated rotations */
	while(units != 0)
	{
		/* limit to maximum value in WheelRotationMask (9bit signed value) */
		int step = MIN(MAX(-256, units), 255);

		mf_scale_mouse_event(context, instance->input, flags | ((UINT16)step & WheelRotationMask), x, y);
		units -= step;
	}
}

- (void)mouseDragged:(NSEvent *)event
{
	[super mouseDragged:event];
	
	if (!is_connected)
		return;
	
    NSPoint loc = [self convertPoint:[event locationInWindow] fromView: nil];
	int x = (int) loc.x;
	int y = (int) loc.y;
	
	// send mouse motion event to RDP server
	mf_scale_mouse_event(context, instance->input, PTR_FLAGS_MOVE, x, y);
}

- (void)rightMouseDragged:(NSEvent *)event
{
    [super rightMouseDragged:event];
    
    if (!is_connected)
        return;
    
    NSPoint loc = [self convertPoint:[event locationInWindow] fromView: nil];
    int x = (int) loc.x;
    int y = (int) loc.y;
    
    // send mouse motion event to RDP server
    mf_scale_mouse_event(context, instance->input, PTR_FLAGS_MOVE | PTR_FLAGS_BUTTON2, x, y);
}

- (void)otherMouseDragged:(NSEvent *)event
{
    [super otherMouseDragged:event];
    
    if (!is_connected)
        return;
    
    NSPoint loc = [self convertPoint:[event locationInWindow] fromView: nil];
    int x = (int) loc.x;
    int y = (int) loc.y;
    
    // send mouse motion event to RDP server
    mf_scale_mouse_event(context, instance->input, PTR_FLAGS_MOVE | PTR_FLAGS_BUTTON3, x, y);
}

- (void)keyDown:(NSEvent *)event
{
    mfContext* mfCtx = (mfContext*)instance->context;
    MRDPClient* client = (MRDPClient *)mfCtx->client;
    
    [client keyDown:event];
}

- (void)keyUp:(NSEvent *) event
{
    mfContext* mfCtx = (mfContext*)instance->context;
    MRDPClient* client = (MRDPClient *)mfCtx->client;
    
    [client keyUp:event];
}

- (void)flagsChanged:(NSEvent*) event
{
    mfContext* mfCtx = (mfContext*)instance->context;
    MRDPClient* client = (MRDPClient *)mfCtx->client;
    
    [client flagsChanged:event];
}

- (void)drawRect:(NSRect)rect
{
	if (!context)
		return;
	
	if (self->bitmap_context)
	{
		CGContextRef cgContext = [[NSGraphicsContext currentContext] graphicsPort];
		CGImageRef cgImage = CGBitmapContextCreateImage(self->bitmap_context);
		
		CGContextSaveGState(cgContext);
		
		CGContextClipToRect(cgContext, CGRectMake(rect.origin.x, rect.origin.y, rect.size.width, rect.size.height));

		CGContextDrawImage(cgContext, CGRectMake(0, 0, [self bounds].size.width, [self bounds].size.height), cgImage);
		
		CGContextRestoreGState(cgContext);
		
		CGImageRelease(cgImage);
	}
	else
	{
		/* Fill the screen with black */
		[[NSColor blackColor] set];
		NSRectFill(rect);
	}
}

- (void)preConnect:(freerdp*)rdpInstance;
{
    rdpInstance->update->DesktopResize = mac_desktop_resize;
}

- (void)postConnect:(freerdp*)rdpInstance;
{
    mfContext* mfCtx = (mfContext*)rdpInstance->context;
    MRDPClient* client = (MRDPClient *)mfCtx->client;
    MRDPView* view = (MRDPView*)client.delegate;

    view->bitmap_context = mac_create_bitmap_context(rdpInstance->context);
}

- (BOOL)provideServerCredentials:(ServerCredential **)credentials
{
    if(delegate && [delegate respondsToSelector:@selector(provideServerCredentials:)])
    {
        return [delegate provideServerCredentials:credentials];
    }
    
    return false;
}

- (BOOL)validateCertificate:(ServerCertificate *)certificate
{
    BOOL result = false;
    
    if(delegate && [delegate respondsToSelector:@selector(validateCertificate:)])
    {
        result = [delegate validateCertificate:certificate];
    }
    
    return result;
}

- (BOOL)validateX509Certificate:(X509Certificate *)certificate
{
    BOOL result = false;
    
    if(delegate && [delegate respondsToSelector:@selector(validateX509Certificate:)])
    {
        result = [delegate validateX509Certificate:certificate];
    }
    
    return result;
}

CGContextRef mac_create_bitmap_context(rdpContext* context)
{
    CGContextRef bitmap_context;
    rdpGdi* gdi = context->gdi;
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    
    if (gdi->bytesPerPixel == 2)
    {
        bitmap_context = CGBitmapContextCreate(gdi->primary_buffer,
                                               gdi->width, gdi->height, 5, gdi->width * gdi->bytesPerPixel,
                                               colorSpace, kCGBitmapByteOrder16Little | kCGImageAlphaNoneSkipFirst);
    }
    else
    {
        bitmap_context = CGBitmapContextCreate(gdi->primary_buffer,
                                               gdi->width, gdi->height, 8, gdi->width * gdi->bytesPerPixel,
                                               colorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaNoneSkipFirst);
    }
    
    CGColorSpaceRelease(colorSpace);
    
    return bitmap_context;
}

void mac_desktop_resize(rdpContext* context)
{
    mfContext* mfc = (mfContext*) context;
    MRDPClient* client = (MRDPClient *)mfc->client;
    MRDPView* view = (MRDPView*)client.delegate;
    rdpSettings* settings = context->settings;
    
    /**
     * TODO: Fix resizing race condition. We should probably implement a message to be
     * put on the update message queue to be able to properly flush pending updates,
     * resize, and then continue with post-resizing graphical updates.
     */
    
    CGContextRef old_context = view->bitmap_context;
    view->bitmap_context = NULL;
    CGContextRelease(old_context);
    
    mfc->width = settings->DesktopWidth;
    mfc->height = settings->DesktopHeight;
    
    gdi_resize(context->gdi, mfc->width, mfc->height);
    
    view->bitmap_context = mac_create_bitmap_context(context);
}

@end
