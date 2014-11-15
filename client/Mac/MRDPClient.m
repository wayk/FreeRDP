//
//  MRDPClient.m
//  FreeRDP
//
//  Created by Richard Markiewicz on 2014-11-09.
//
//

#import "MRDPClient.h"
#import "MRDPCursor.h"

#include "mf_client.h"

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
#import "freerdp/utils/event.h"
#import "freerdp/client/cliprdr.h"
#import "freerdp/client/file.h"
#import "freerdp/client/cmdline.h"
#import "freerdp/log.h"

#define TAG CLIENT_TAG("mac")

static void update_activity_cb(freerdp* instance);
static void input_activity_cb(freerdp* instance);
static void channel_activity_cb(freerdp* instance);

DWORD mac_client_thread(void* param);

void mf_Pointer_New(rdpContext* context, rdpPointer* pointer);
void mf_Pointer_Free(rdpContext* context, rdpPointer* pointer);
void mf_Pointer_Set(rdpContext* context, rdpPointer* pointer);
void mf_Pointer_SetNull(rdpContext* context);
void mf_Pointer_SetDefault(rdpContext* context);

void mac_begin_paint(rdpContext* context);
void mac_end_paint(rdpContext* context);

int process_plugin_args(rdpSettings* settings, const char* name, RDP_PLUGIN_DATA* plugin_data, void* user_data);
int receive_channel_data(freerdp* instance, int chan_id, BYTE* data, int size, int flags, int total_size);

void process_cliprdr_event(freerdp* instance, wMessage* event);
void cliprdr_process_cb_format_list_event(freerdp* instance, RDP_CB_FORMAT_LIST_EVENT* event);
void cliprdr_send_data_request(freerdp* instance, UINT32 format);
void cliprdr_process_cb_monitor_ready_event(freerdp* inst);
void cliprdr_process_cb_data_response_event(freerdp* instance, RDP_CB_DATA_RESPONSE_EVENT* event);
void cliprdr_process_text(freerdp* instance, BYTE* data, int len);
void cliprdr_send_supported_format_list(freerdp* instance);
int register_channel_fds(int* fds, int count, freerdp* instance);

@implementation MRDPClient

@synthesize delegate;

- (id)init
{
    self = [super init];
    if(self)
    {
        cursors = [[NSMutableArray alloc] initWithCapacity:10];
    }
    
    return self;
}

- (void)dealloc
{
    self.delegate = nil;
    
    [super dealloc];
}

- (int)rdpStart:(rdpContext*)rdp_context
{
    context = rdp_context;
    mfc = (mfContext*) rdp_context;
    instance = context->instance;

    [delegate initialise:context];
    
    mfc->client_height = instance->settings->DesktopHeight;
    mfc->client_width = instance->settings->DesktopWidth;
    
    mfc->thread = CreateThread(NULL, 0, mac_client_thread, (void*) context, 0, &mfc->mainThreadId);
    
    return 0;
}

- (void)releaseResources
{
    if (!self.delegate.is_connected)
        return;
    
    [delegate releaseResources];
    
    gdi_free(context->instance);
}

- (void)pause
{
    // Invalidate the timer on the thread it was created on
    dispatch_async(dispatch_get_main_queue(), ^{
        [self->pasteboard_timer invalidate];
    });
    
    [delegate pause];
}

- (void)resume
{
    dispatch_async(dispatch_get_main_queue(), ^{
        self->pasteboard_timer = [NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector(onPasteboardTimerFired:) userInfo:nil repeats:YES];
    });

    [delegate resume];
}

- (void)onPasteboardTimerFired:(NSTimer*)timer
{
    int i;
    NSArray* types;
    
    i = (int) [pasteboard_rd changeCount];
    
    if (i != pasteboard_changecount)
    {
        pasteboard_changecount = i;
        types = [NSArray arrayWithObject:NSStringPboardType];
        NSString *str = [pasteboard_rd availableTypeFromArray:types];
        if (str != nil)
        {
            cliprdr_send_supported_format_list(instance);
        }
    }
    
    //pasteboard_changecount = (int) [pasteboard_rd changeCount];
}

- (void)mouseMoved:(NSPoint)coord
{
    mf_scale_mouse_event(context, instance->input, PTR_FLAGS_MOVE, coord.x, coord.y);
}

- (void)mouseDown:(NSPoint)coord
{
    mf_scale_mouse_event(context, instance->input, PTR_FLAGS_DOWN | PTR_FLAGS_BUTTON1, coord.x, coord.y);
}

- (void)mouseUp:(NSPoint)coord
{
    mf_scale_mouse_event(context, instance->input, PTR_FLAGS_BUTTON1, coord.x, coord.y);
}

- (void)rightMouseDown:(NSPoint)coord
{
    mf_scale_mouse_event(context, instance->input, PTR_FLAGS_DOWN | PTR_FLAGS_BUTTON2, coord.x, coord.y);
}

- (void)rightMouseUp:(NSPoint)coord
{
    mf_scale_mouse_event(context, instance->input, PTR_FLAGS_BUTTON2, coord.x, coord.y);
}

- (void)otherMouseDown:(NSPoint)coord
{
    mf_scale_mouse_event(context, instance->input, PTR_FLAGS_DOWN | PTR_FLAGS_BUTTON3, coord.x, coord.y);
}

- (void)otherMouseUp:(NSPoint)coord
{
    mf_scale_mouse_event(context, instance->input, PTR_FLAGS_BUTTON3, coord.x, coord.y);
}

- (void)scrollWheelCoordinates:(NSPoint)coord deltaY:(CGFloat)deltaY
{
    UINT16 flags = PTR_FLAGS_WHEEL;
    
    /* 1 event = 120 units */
    int units = deltaY * 120;
    
    /* send out all accumulated rotations */
    while(units != 0)
    {
        /* limit to maximum value in WheelRotationMask (9bit signed value) */
        int step = MIN(MAX(-256, units), 255);
        
        mf_scale_mouse_event(context, instance->input, flags | ((UINT16)step & WheelRotationMask), coord.x, coord.y);
        units -= step;
    }
}

- (void)mouseDragged:(NSPoint)coord
{
    mf_scale_mouse_event(context, instance->input, PTR_FLAGS_MOVE, coord.x, coord.y);
}

- (void)rightMouseDragged:(NSPoint)coord
{
    mf_scale_mouse_event(context, instance->input, PTR_FLAGS_MOVE | PTR_FLAGS_BUTTON2, coord.x, coord.y);
}

- (void)otherMouseDragged:(NSPoint)coord
{
    mf_scale_mouse_event(context, instance->input, PTR_FLAGS_MOVE | PTR_FLAGS_BUTTON3, coord.x, coord.y);
}

- (void)keyDown:(NSEvent *)event
{
    DWORD keyCode;
    DWORD keyFlags;
    DWORD vkcode;
    DWORD scancode;
    unichar keyChar;
    NSString* characters;
    NSUInteger modifierFlags;
    bool releaseKey = false;
    
    if (!delegate.is_connected)
        return;
    
    keyFlags = KBD_FLAGS_DOWN;
    keyCode = [event keyCode];
    modifierFlags = [event modifierFlags];
    
    characters = [event charactersIgnoringModifiers];
    
    if ([characters length] > 0)
    {
        keyChar = [characters characterAtIndex:0];
        keyCode = fixKeyCode(keyCode, keyChar, mfc->appleKeyboardType);
    }
    
    vkcode = GetVirtualKeyCodeFromKeycode(keyCode + 8, KEYCODE_TYPE_APPLE);
    scancode = GetVirtualScanCodeFromVirtualKeyCode(vkcode, 4);
    keyFlags |= (scancode & KBDEXT) ? KBDEXT : 0;
    scancode &= 0xFF;
    vkcode &= 0xFF;
    
    // For VK_A, VK_C, VK_V or VK_X
    if ((vkcode == 0x43 || vkcode == 0x56 || vkcode == 0x41 || vkcode == 0x58) && modifierFlags & NSCommandKeyMask)
    {
        releaseKey = true;
        freerdp_input_send_keyboard_event(context->input, KBD_FLAGS_RELEASE, 0x5B); /* VK_LWIN, RELEASE */
        freerdp_input_send_keyboard_event(context->input, KBD_FLAGS_RELEASE, 0x5C); /* VK_RWIN, RELEASE */
        freerdp_input_send_keyboard_event(context->input, KBD_FLAGS_DOWN, 0x1D); /* VK_LCONTROL, DOWN */
    }
    
#if 0
    WLog_ERR(TAG,  "keyDown: keyCode: 0x%04X scancode: 0x%04X vkcode: 0x%04X keyFlags: %d name: %s",
             keyCode, scancode, vkcode, keyFlags, GetVirtualKeyName(vkcode));
#endif
    
    freerdp_input_send_keyboard_event(instance->input, keyFlags, scancode);
    
    if (releaseKey)
    {
        //For some reasons, keyUp isn't called when Command is held down.
        freerdp_input_send_keyboard_event(context->input, KBD_FLAGS_RELEASE, 0x1D); /* VK_LCONTROL, RELEASE */
    }
}

- (void)keyUp:(NSEvent *)event
{
    DWORD keyCode;
    DWORD keyFlags;
    DWORD vkcode;
    DWORD scancode;
    unichar keyChar;
    NSString* characters;
    
    if (!delegate.is_connected)
        return;
    
    keyFlags = KBD_FLAGS_RELEASE;
    keyCode = [event keyCode];
    
    characters = [event charactersIgnoringModifiers];
    
    if ([characters length] > 0)
    {
        keyChar = [characters characterAtIndex:0];
        keyCode = fixKeyCode(keyCode, keyChar, mfc->appleKeyboardType);
    }
    
    vkcode = GetVirtualKeyCodeFromKeycode(keyCode + 8, KEYCODE_TYPE_APPLE);
    scancode = GetVirtualScanCodeFromVirtualKeyCode(vkcode, 4);
    keyFlags |= (scancode & KBDEXT) ? KBDEXT : 0;
    scancode &= 0xFF;
    vkcode &= 0xFF;
    
#if 0
    WLog_DBG(TAG,  "keyUp: key: 0x%04X scancode: 0x%04X vkcode: 0x%04X keyFlags: %d name: %s",
             keyCode, scancode, vkcode, keyFlags, GetVirtualKeyName(vkcode));
#endif
    
    freerdp_input_send_keyboard_event(instance->input, keyFlags, scancode);
}

- (void)flagsChanged:(NSEvent*)event
{
    int key;
    DWORD keyFlags;
    DWORD vkcode;
    DWORD scancode;
    DWORD modFlags;
    
    if (!delegate.is_connected)
        return;
    
    keyFlags = 0;
    key = [event keyCode] + 8;
    modFlags = [event modifierFlags] & NSDeviceIndependentModifierFlagsMask;
    
    vkcode = GetVirtualKeyCodeFromKeycode(key, KEYCODE_TYPE_APPLE);
    scancode = GetVirtualScanCodeFromVirtualKeyCode(vkcode, 4);
    keyFlags |= (scancode & KBDEXT) ? KBDEXT : 0;
    scancode &= 0xFF;
    vkcode &= 0xFF;
    
#if 0
    fprintf(stderr, "flagsChanged: key: 0x%04X scancode: 0x%04lX vkcode: 0x%04lX extended: %lu name: %s modFlags: 0x%04lX\n", key - 8, scancode, vkcode, keyFlags, GetVirtualKeyName(vkcode), modFlags);
    
    if (modFlags & NSAlphaShiftKeyMask)
        fprintf( "NSAlphaShiftKeyMask\n");
    
    if (modFlags & NSShiftKeyMask)
        fprintf( "NSShiftKeyMask\n");
    
    if (modFlags & NSControlKeyMask)
        fprintf( "NSControlKeyMask\n");
    
    if (modFlags & NSAlternateKeyMask)
        fprintf( "NSAlternateKeyMask\n");
    
    if (modFlags & NSCommandKeyMask)
        fprintf( "NSCommandKeyMask\n");
    
    if (modFlags & NSNumericPadKeyMask)
        fprintf( "NSNumericPadKeyMask\n");
    
    if (modFlags & NSHelpKeyMask)
        fprintf( "NSHelpKeyMask\n");
#endif
    
    if ((modFlags & NSAlphaShiftKeyMask) && !(kbdModFlags & NSAlphaShiftKeyMask))
        freerdp_input_send_keyboard_event(instance->input, keyFlags | KBD_FLAGS_DOWN, scancode);
    else if (!(modFlags & NSAlphaShiftKeyMask) && (kbdModFlags & NSAlphaShiftKeyMask))
        freerdp_input_send_keyboard_event(instance->input, keyFlags | KBD_FLAGS_RELEASE, scancode);
    
    if ((modFlags & NSShiftKeyMask) && !(kbdModFlags & NSShiftKeyMask))
        freerdp_input_send_keyboard_event(instance->input, keyFlags | KBD_FLAGS_DOWN, scancode);
    else if (!(modFlags & NSShiftKeyMask) && (kbdModFlags & NSShiftKeyMask))
        freerdp_input_send_keyboard_event(instance->input, keyFlags | KBD_FLAGS_RELEASE, scancode);
    
    if ((modFlags & NSControlKeyMask) && !(kbdModFlags & NSControlKeyMask))
        freerdp_input_send_keyboard_event(instance->input, keyFlags | KBD_FLAGS_DOWN, scancode);
    else if (!(modFlags & NSControlKeyMask) && (kbdModFlags & NSControlKeyMask))
        freerdp_input_send_keyboard_event(instance->input, keyFlags | KBD_FLAGS_RELEASE, scancode);
    
    if ((modFlags & NSAlternateKeyMask) && !(kbdModFlags & NSAlternateKeyMask))
        freerdp_input_send_keyboard_event(instance->input, keyFlags | KBD_FLAGS_DOWN, scancode);
    else if (!(modFlags & NSAlternateKeyMask) && (kbdModFlags & NSAlternateKeyMask))
        freerdp_input_send_keyboard_event(instance->input, keyFlags | KBD_FLAGS_RELEASE, scancode);
    
    if(context->settings->EnableWindowsKey)
    {
        if ((modFlags & NSCommandKeyMask) && !(kbdModFlags & NSCommandKeyMask))
            freerdp_input_send_keyboard_event(instance->input, keyFlags | KBD_FLAGS_DOWN, scancode);
        else if (!(modFlags & NSCommandKeyMask) && (kbdModFlags & NSCommandKeyMask))
            freerdp_input_send_keyboard_event(instance->input, keyFlags | KBD_FLAGS_RELEASE, scancode);
    }
    
    if ((modFlags & NSNumericPadKeyMask) && !(kbdModFlags & NSNumericPadKeyMask))
        freerdp_input_send_keyboard_event(instance->input, keyFlags | KBD_FLAGS_DOWN, scancode);
    else if (!(modFlags & NSNumericPadKeyMask) && (kbdModFlags & NSNumericPadKeyMask))
        freerdp_input_send_keyboard_event(instance->input, keyFlags | KBD_FLAGS_RELEASE, scancode);
    
    if ((modFlags & NSHelpKeyMask) && !(kbdModFlags & NSHelpKeyMask))
        freerdp_input_send_keyboard_event(instance->input, keyFlags | KBD_FLAGS_DOWN, scancode);
    else if (!(modFlags & NSHelpKeyMask) && (kbdModFlags & NSHelpKeyMask))
        freerdp_input_send_keyboard_event(instance->input, keyFlags | KBD_FLAGS_RELEASE, scancode);
    
    kbdModFlags = modFlags;
}

DWORD fixKeyCode(DWORD keyCode, unichar keyChar, enum APPLE_KEYBOARD_TYPE type)
{
    /**
     * In 99% of cases, the given key code is truly keyboard independent.
     * This function handles the remaining 1% of edge cases.
     *
     * Hungarian Keyboard: This is 'QWERTZ' and not 'QWERTY'.
     * The '0' key is on the left of the '1' key, where '~' is on a US keyboard.
     * A special 'i' letter key with acute is found on the right of the left shift key.
     * On the hungarian keyboard, the 'i' key is at the left of the 'Y' key
     * Some international keyboards have a corresponding key which would be at
     * the left of the 'Z' key when using a QWERTY layout.
     *
     * The Apple Hungarian keyboard sends inverted key codes for the '0' and 'i' keys.
     * When using the US keyboard layout, key codes are left as-is (inverted).
     * When using the Hungarian keyboard layout, key codes are swapped (non-inverted).
     * This means that when using the Hungarian keyboard layout with a US keyboard,
     * the keys corresponding to '0' and 'i' will effectively be inverted.
     *
     * To fix the '0' and 'i' key inversion, we use the corresponding output character
     * provided by OS X and check for a character to key code mismatch: for instance,
     * when the output character is '0' for the key code corresponding to the 'i' key.
     */
    
#if 0
    switch (keyChar)
    {
        case '0':
        case 0x00A7: /* section sign */
            if (keyCode == APPLE_VK_ISO_Section)
                keyCode = APPLE_VK_ANSI_Grave;
            break;
            
        case 0x00ED: /* latin small letter i with acute */
        case 0x00CD: /* latin capital letter i with acute */
            if (keyCode == APPLE_VK_ANSI_Grave)
                keyCode = APPLE_VK_ISO_Section;
            break;
    }
#endif
    
    /* Perform keycode correction for all ISO keyboards */
    
    if (type == APPLE_KEYBOARD_TYPE_ISO)
    {
        if (keyCode == APPLE_VK_ANSI_Grave)
            keyCode = APPLE_VK_ISO_Section;
        else if (keyCode == APPLE_VK_ISO_Section)
            keyCode = APPLE_VK_ANSI_Grave;
    }
    
    return keyCode;
}

DWORD mac_client_input_thread(void* param)
{
    int status;
    wMessage message;
    wMessageQueue* queue;
    rdpContext* context = (rdpContext*) param;
    
    status = 1;
    queue = freerdp_get_message_queue(context->instance, FREERDP_INPUT_MESSAGE_QUEUE);
    
    while (MessageQueue_Wait(queue))
    {
        while (MessageQueue_Peek(queue, &message, TRUE))
        {
            status = freerdp_message_queue_process_message(context->instance, FREERDP_INPUT_MESSAGE_QUEUE, &message);
            
            if (!status)
                break;
        }
        
        if (!status)
            break;
    }
    
    ExitThread(0);
    return 0;
}

DWORD mac_client_channels_thread(void* param)
{
    int status;
    wMessage* event;
    HANDLE channelsEvent;
    rdpChannels* channels;
    rdpContext* context = (rdpContext*) param;
    
    channels = context->channels;
    channelsEvent = freerdp_channels_get_event_handle(context->instance);
    
    while (WaitForSingleObject(channelsEvent, INFINITE) == WAIT_OBJECT_0)
    {
        status = freerdp_channels_process_pending_messages(context->instance);
        
        if (!status)
            break;
        
        event = freerdp_channels_pop_event(context->channels);
        
        if (event)
        {
            switch (GetMessageClass(event->id))
            {
                case CliprdrChannel_Class:
                    process_cliprdr_event(context->instance, event);
                    break;
            }
            
            freerdp_event_free(event);
        }
    }
    
    ExitThread(0);
    return 0;
}

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
        MRDPClient* client = mfc->client;
        rdpSettings* settings = context->settings;
        
        status = freerdp_connect(context->instance);
        
        if (!status)
        {
            [client->delegate setIs_connected:0];
            return 0;
        }
        
        [client->delegate setIs_connected:1];
        
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

BOOL mac_pre_connect(freerdp* instance)
{
    rdpSettings* settings;
 
    mfContext* mfc = (mfContext*) instance->context;
    
    MRDPClient* client = (MRDPClient *)mfc->client;
    id<MRDPClientDelegate> view = (id<MRDPClientDelegate>)client.delegate;
    
    instance->update->BeginPaint = mac_begin_paint;
    instance->update->EndPaint = mac_end_paint;
    
    [view preConnect:instance];
    
    settings = instance->settings;
    
    if (!settings->ServerHostname)
    {
        fprintf(stderr, "error: server hostname was not specified with /v:<server>[:port]\n");
        return -1;
    }
    
    settings->SoftwareGdi = TRUE;
    
    settings->OsMajorType = OSMAJORTYPE_MACINTOSH;
    settings->OsMinorType = OSMINORTYPE_MACINTOSH;
    
    ZeroMemory(settings->OrderSupport, 32);
    settings->OrderSupport[NEG_DSTBLT_INDEX] = TRUE;
    settings->OrderSupport[NEG_PATBLT_INDEX] = TRUE;
    settings->OrderSupport[NEG_SCRBLT_INDEX] = TRUE;
    settings->OrderSupport[NEG_OPAQUE_RECT_INDEX] = TRUE;
    settings->OrderSupport[NEG_DRAWNINEGRID_INDEX] = FALSE;
    settings->OrderSupport[NEG_MULTIDSTBLT_INDEX] = FALSE;
    settings->OrderSupport[NEG_MULTIPATBLT_INDEX] = FALSE;
    settings->OrderSupport[NEG_MULTISCRBLT_INDEX] = FALSE;
    settings->OrderSupport[NEG_MULTIOPAQUERECT_INDEX] = TRUE;
    settings->OrderSupport[NEG_MULTI_DRAWNINEGRID_INDEX] = FALSE;
    settings->OrderSupport[NEG_LINETO_INDEX] = TRUE;
    settings->OrderSupport[NEG_POLYLINE_INDEX] = TRUE;
    settings->OrderSupport[NEG_MEMBLT_INDEX] = settings->BitmapCacheEnabled;
    settings->OrderSupport[NEG_MEM3BLT_INDEX] = (settings->SoftwareGdi) ? TRUE : FALSE;
    settings->OrderSupport[NEG_MEMBLT_V2_INDEX] = settings->BitmapCacheEnabled;
    settings->OrderSupport[NEG_MEM3BLT_V2_INDEX] = FALSE;
    settings->OrderSupport[NEG_SAVEBITMAP_INDEX] = FALSE;
    settings->OrderSupport[NEG_GLYPH_INDEX_INDEX] = TRUE;
    settings->OrderSupport[NEG_FAST_INDEX_INDEX] = TRUE;
    settings->OrderSupport[NEG_FAST_GLYPH_INDEX] = TRUE;
    settings->OrderSupport[NEG_POLYGON_SC_INDEX] = FALSE;
    settings->OrderSupport[NEG_POLYGON_CB_INDEX] = FALSE;
    settings->OrderSupport[NEG_ELLIPSE_SC_INDEX] = FALSE;
    settings->OrderSupport[NEG_ELLIPSE_CB_INDEX] = FALSE;
    
    PubSub_SubscribeChannelConnected(instance->context->pubSub,
                                     (pChannelConnectedEventHandler) mac_OnChannelConnectedEventHandler);
    
    PubSub_SubscribeChannelDisconnected(instance->context->pubSub,
                                        (pChannelDisconnectedEventHandler) mac_OnChannelDisconnectedEventHandler);
    
    freerdp_client_load_addins(instance->context->channels, instance->settings);
    
    freerdp_channels_pre_connect(instance->context->channels, instance);
    
    return TRUE;
}

BOOL mac_post_connect(freerdp* instance)
{
    rdpGdi* gdi;
    UINT32 flags;
    rdpSettings* settings;
    rdpPointer rdp_pointer;
    mfContext* mfc = (mfContext*) instance->context;
    
    MRDPClient* client = (MRDPClient *)mfc->client;
    id<MRDPClientDelegate> view = (id<MRDPClientDelegate>)client.delegate;
    
    ZeroMemory(&rdp_pointer, sizeof(rdpPointer));
    rdp_pointer.size = sizeof(rdpPointer);
    rdp_pointer.New = mf_Pointer_New;
    rdp_pointer.Free = mf_Pointer_Free;
    rdp_pointer.Set = mf_Pointer_Set;
    rdp_pointer.SetNull = mf_Pointer_SetNull;
    rdp_pointer.SetDefault = mf_Pointer_SetDefault;
    
    settings = instance->settings;
    
    flags = CLRCONV_ALPHA | CLRCONV_RGB555;
    
    //if (settings->ColorDepth > 16)
    flags |= CLRBUF_32BPP;
    //else
    //	flags |= CLRBUF_16BPP;
    
    gdi_init(instance, flags, NULL);
    gdi = instance->context->gdi;
    
    [view postConnect:instance];
    
    pointer_cache_register_callbacks(instance->update);
    graphics_register_pointer(instance->context->graphics, &rdp_pointer);
    
    freerdp_channels_post_connect(instance->context->channels, instance);
    
    /* setup pasteboard (aka clipboard) for copy operations (write only) */
    client->pasteboard_wr = [NSPasteboard generalPasteboard];
    
    /* setup pasteboard for read operations */
    dispatch_async(dispatch_get_main_queue(), ^{
        client->pasteboard_rd = [NSPasteboard generalPasteboard];
        client->pasteboard_changecount = -1;
        client->pasteboard_timer = [NSTimer scheduledTimerWithTimeInterval:0.5 target:client selector:@selector(onPasteboardTimerFired:) userInfo:nil repeats:YES];
    });
    
    mfc->appleKeyboardType = mac_detect_keyboard_type();
    
    return TRUE;
}

void mac_begin_paint(rdpContext* context)
{
    rdpGdi* gdi = context->gdi;
    
    if (!gdi)
        return;
    
    gdi->primary->hdc->hwnd->invalid->null = 1;
}

void mac_end_paint(rdpContext* context)
{
    rdpGdi* gdi;
    HGDI_RGN invalid;
    NSRect newDrawRect;
    int ww, wh, dw, dh;
    mfContext* mfc = (mfContext*) context;
    MRDPClient* client = (MRDPClient *)mfc->client;
    id<MRDPClientDelegate> view = (id<MRDPClientDelegate>)client.delegate;
    
    gdi = context->gdi;
    
    if (!gdi)
        return;
    
    ww = view.frame.size.width;
    wh = view.frame.size.height;
    dw = mfc->context.settings->DesktopWidth;
    dh = mfc->context.settings->DesktopHeight;
    
    if ((!context) || (!context->gdi))
        return;
    
    if (context->gdi->primary->hdc->hwnd->invalid->null)
        return;
    
    invalid = gdi->primary->hdc->hwnd->invalid;
    
    newDrawRect.origin.x = invalid->x;
    newDrawRect.origin.y = invalid->y;
    newDrawRect.size.width = invalid->w;
    newDrawRect.size.height = invalid->h;
    
    if (mfc->context.settings->SmartSizing && (ww != dw || wh != dh))
    {
        newDrawRect.origin.y = newDrawRect.origin.y * wh / dh - 1;
        newDrawRect.size.height = newDrawRect.size.height * wh / dh + 1;
        newDrawRect.origin.x = newDrawRect.origin.x * ww / dw - 1;
        newDrawRect.size.width = newDrawRect.size.width * ww / dw + 1;
    }
    else
    {
        newDrawRect.origin.y = newDrawRect.origin.y - 1;
        newDrawRect.size.height = newDrawRect.size.height + 1;
        newDrawRect.origin.x = newDrawRect.origin.x - 1;
        newDrawRect.size.width = newDrawRect.size.width + 1;
    }
    
    windows_to_apple_cords(view, &newDrawRect);
    
    [view setNeedsDisplayInRect:newDrawRect];
    
    gdi->primary->hdc->hwnd->ninvalid = 0;
}

/**
 * given a rect with 0,0 at the top left (windows cords)
 * convert it to a rect with 0,0 at the bottom left (apple cords)
 *
 * Note: the formula works for conversions in both directions.
 *
 */
void windows_to_apple_cords(id<MRDPClientDelegate> view, NSRect* r)
{
    r->origin.y = [view frame].size.height - (r->origin.y + r->size.height);
}

void mac_OnChannelConnectedEventHandler(rdpContext* context, ChannelConnectedEventArgs* e)
{
    rdpSettings* settings = context->settings;
    
    if (strcmp(e->name, RDPEI_DVC_CHANNEL_NAME) == 0)
    {
        
    }
    else if (strcmp(e->name, RDPGFX_DVC_CHANNEL_NAME) == 0)
    {
        if (settings->SoftwareGdi)
            gdi_graphics_pipeline_init(context->gdi, (RdpgfxClientContext*) e->pInterface);
    }
    else if (strcmp(e->name, ENCOMSP_SVC_CHANNEL_NAME) == 0)
    {
        
    }
}

void mac_OnChannelDisconnectedEventHandler(rdpContext* context, ChannelDisconnectedEventArgs* e)
{
    rdpSettings* settings = context->settings;
    
    if (strcmp(e->name, RDPEI_DVC_CHANNEL_NAME) == 0)
    {
        
    }
    else if (strcmp(e->name, RDPGFX_DVC_CHANNEL_NAME) == 0)
    {
        if (settings->SoftwareGdi)
            gdi_graphics_pipeline_uninit(context->gdi, (RdpgfxClientContext*) e->pInterface);
    }
    else if (strcmp(e->name, ENCOMSP_SVC_CHANNEL_NAME) == 0)
    {
        
    }
}

void mf_Pointer_New(rdpContext* context, rdpPointer* pointer)
{
    NSRect rect;
    NSImage* image;
    NSPoint hotSpot;
    NSCursor* cursor;
    BYTE* cursor_data;
    NSMutableArray* ma;
    NSBitmapImageRep* bmiRep;
    MRDPCursor* mrdpCursor = [[MRDPCursor alloc] init];
    mfContext* mfc = (mfContext*) context;
    MRDPClient* client = (MRDPClient *)mfc->client;
    
    rect.size.width = pointer->width;
    rect.size.height = pointer->height;
    rect.origin.x = pointer->xPos;
    rect.origin.y = pointer->yPos;
    
    cursor_data = (BYTE*) malloc(rect.size.width * rect.size.height * 4);
    mrdpCursor->cursor_data = cursor_data;
    
    freerdp_image_copy_from_pointer_data(cursor_data, PIXEL_FORMAT_ARGB32,
                                         pointer->width * 4, 0, 0, pointer->width, pointer->height,
                                         pointer->xorMaskData, pointer->andMaskData, pointer->xorBpp, NULL);
    
    /* store cursor bitmap image in representation - required by NSImage */
    bmiRep = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:(unsigned char **) &cursor_data
                                                     pixelsWide:rect.size.width
                                                     pixelsHigh:rect.size.height
                                                  bitsPerSample:8
                                                samplesPerPixel:4
                                                       hasAlpha:YES
                                                       isPlanar:NO
                                                 colorSpaceName:NSDeviceRGBColorSpace
                                                   bitmapFormat:0
                                                    bytesPerRow:rect.size.width * 4
                                                   bitsPerPixel:0];
    mrdpCursor->bmiRep = bmiRep;
    
    /* create an image using above representation */
    image = [[NSImage alloc] initWithSize:[bmiRep size]];
    [image addRepresentation: bmiRep];
    [image setFlipped:NO];
    mrdpCursor->nsImage = image;
    
    /* need hotspot to create cursor */
    hotSpot.x = pointer->xPos;
    hotSpot.y = pointer->yPos;
    
    cursor = [[NSCursor alloc] initWithImage: image hotSpot:hotSpot];
    mrdpCursor->nsCursor = cursor;
    mrdpCursor->pointer = pointer;
    
    /* save cursor for later use in mf_Pointer_Set() */
    ma = client->cursors;
    [ma addObject:mrdpCursor];
    
    [mrdpCursor release];
}

void mf_Pointer_Free(rdpContext* context, rdpPointer* pointer)
{
    mfContext* mfc = (mfContext*) context;
    MRDPClient* client = (MRDPClient *)mfc->client;
    NSMutableArray* ma = client->cursors;
    
    for (MRDPCursor* cursor in ma)
    {
        if (cursor->pointer == pointer)
        {
            cursor->nsImage = nil;
            cursor->nsCursor = nil;
            cursor->bmiRep = nil;
            free(cursor->cursor_data);
            [ma removeObject:cursor];
            return;
        }
    }
}

void mf_Pointer_Set(rdpContext* context, rdpPointer* pointer)
{
    mfContext* mfc = (mfContext*) context;
    MRDPClient* client = (MRDPClient *)mfc->client;
    id<MRDPClientDelegate> view = (id<MRDPClientDelegate>)client.delegate;
    
    NSMutableArray* ma = client->cursors;
    
    for (MRDPCursor* cursor in ma)
    {
        if (cursor->pointer == pointer)
        {
            [view setCursor:cursor->nsCursor];
            return;
        }
    }
    
    NSLog(@"Cursor not found");
}

void mf_Pointer_SetNull(rdpContext* context)
{
    
}

void mf_Pointer_SetDefault(rdpContext* context)
{
    mfContext* mfc = (mfContext*) context;
    MRDPClient* client = (MRDPClient *)mfc->client;
    id<MRDPClientDelegate> view = (id<MRDPClientDelegate>)client.delegate;
    [view setCursor:[NSCursor arrowCursor]];
}

/***********************************************************************
 * called when channel data is available
 ***********************************************************************/

int mac_receive_channel_data(freerdp* instance, UINT16 chan_id, BYTE* data, int size, int flags, int total_size)
{
    return freerdp_channels_data(instance, chan_id, data, size, flags, total_size);
}

int process_plugin_args(rdpSettings* settings, const char* name, RDP_PLUGIN_DATA* plugin_data, void* user_data)
{
    rdpChannels* channels = (rdpChannels*) user_data;
    
    freerdp_channels_load_plugin(channels, settings, name, plugin_data);
    
    return 1;
}

static void update_activity_cb(freerdp* instance)
{
    int status;
    wMessage message;
    wMessageQueue* queue;
    
    status = 1;
    queue = freerdp_get_message_queue(instance, FREERDP_UPDATE_MESSAGE_QUEUE);
    
    if (queue)
    {
        while (MessageQueue_Peek(queue, &message, TRUE))
        {
            status = freerdp_message_queue_process_message(instance, FREERDP_UPDATE_MESSAGE_QUEUE, &message);
            
            if (!status)
                break;
        }
    }
    else
    {
        WLog_ERR(TAG,  "update_activity_cb: No queue!");
    }
}

static void input_activity_cb(freerdp* instance)
{
    int status;
    wMessage message;
    wMessageQueue* queue;
    
    status = 1;
    queue = freerdp_get_message_queue(instance, FREERDP_INPUT_MESSAGE_QUEUE);
    
    if (queue)
    {
        while (MessageQueue_Peek(queue, &message, TRUE))
        {
            status = freerdp_message_queue_process_message(instance, FREERDP_INPUT_MESSAGE_QUEUE, &message);
            
            if (!status)
                break;
        }
    }
    else
    {
        WLog_ERR(TAG,  "input_activity_cb: No queue!");
    }
}

static void channel_activity_cb(freerdp* instance)
{
    wMessage* event;
    
    freerdp_channels_process_pending_messages(instance);
    event = freerdp_channels_pop_event(instance->context->channels);
    
    if (event)
    {
        WLog_DBG(TAG,  "channel_activity_cb: message %d", event->id);
        
        switch (GetMessageClass(event->id))
        {
            case CliprdrChannel_Class:
                process_cliprdr_event(instance, event);
                break;
        }
        
        freerdp_event_free(event);
    }
}

/*
 * stuff related to clipboard redirection
 */

void cliprdr_process_cb_data_request_event(freerdp* instance)
{
    NSLog(@"cliprdr_process_cb_data_request_event");
    
    int len;
    NSArray* types;
    RDP_CB_DATA_RESPONSE_EVENT* event;
    mfContext* mfc = (mfContext*) instance->context;
    MRDPClient* client = (MRDPClient *)mfc->client;
    
    event = (RDP_CB_DATA_RESPONSE_EVENT*) freerdp_event_new(CliprdrChannel_Class, CliprdrChannel_DataResponse, NULL, NULL);
    
    types = [NSArray arrayWithObject:NSStringPboardType];
    NSString* str = [client->pasteboard_rd availableTypeFromArray:types];
    
    if (str == nil)
    {
        event->data = NULL;
        event->size = 0;
    }
    else
    {
        NSString* data = [client->pasteboard_rd stringForType:NSStringPboardType];
        len = (int) ([data length] * 2 + 2);
        event->data = malloc(len);
        [data getCString:(char *) event->data maxLength:len encoding:NSUnicodeStringEncoding];
        event->size = len;
    }
    
    freerdp_channels_send_event(instance->context->channels, (wMessage*) event);
}

void cliprdr_send_data_request(freerdp* instance, UINT32 format)
{
    NSLog(@"cliprdr_send_data_request");
    
    RDP_CB_DATA_REQUEST_EVENT* event;
    
    event = (RDP_CB_DATA_REQUEST_EVENT*) freerdp_event_new(CliprdrChannel_Class, CliprdrChannel_DataRequest, NULL, NULL);
    
    event->format = format;
    freerdp_channels_send_event(instance->context->channels, (wMessage*) event);
}

/**
 * at the moment, only the following formats are supported
 *    CF_TEXT
 *    CF_UNICODETEXT
 */

void cliprdr_process_cb_data_response_event(freerdp* instance, RDP_CB_DATA_RESPONSE_EVENT* event)
{
    NSLog(@"cliprdr_process_cb_data_response_event");
    
    NSString* str;
    NSArray* types;
    mfContext* mfc = (mfContext*) instance->context;
    MRDPClient* client = (MRDPClient *)mfc->client;
    
    if (event->size == 0)
        return;
    
    if (client->pasteboard_format == CF_TEXT || client->pasteboard_format == CF_UNICODETEXT)
    {
        str = [[NSString alloc] initWithCharacters:(unichar *) event->data length:event->size / 2];
        types = [[NSArray alloc] initWithObjects:NSStringPboardType, nil];
        [client->pasteboard_wr declareTypes:types owner:mfc->client];
        [client->pasteboard_wr setString:str forType:NSStringPboardType];
    }
}

void cliprdr_process_cb_monitor_ready_event(freerdp* instance)
{
    NSLog(@"cliprdr_process_cb_monitor_ready_event");
    
    wMessage* event;
    RDP_CB_FORMAT_LIST_EVENT* format_list_event;
    
    event = freerdp_event_new(CliprdrChannel_Class, CliprdrChannel_FormatList, NULL, NULL);
    
    format_list_event = (RDP_CB_FORMAT_LIST_EVENT*) event;
    format_list_event->num_formats = 0;
    
    freerdp_channels_send_event(instance->context->channels, event);
    
    cliprdr_send_supported_format_list(instance);
}

/**
 * list of supported clipboard formats; currently only the following are supported
 *    CF_TEXT
 *    CF_UNICODETEXT
 */

void cliprdr_process_cb_format_list_event(freerdp* instance, RDP_CB_FORMAT_LIST_EVENT* event)
{
    NSLog(@"cliprdr_process_cb_format_list_event");
    
    int i;
    mfContext* mfc = (mfContext*) instance->context;
    MRDPClient* client = (MRDPClient *)mfc->client;
    
    if (event->num_formats == 0)
        return;
    
    for (i = 0; i < event->num_formats; i++)
    {
        switch (event->formats[i])
        {
            case CF_TEXT:
            case CF_UNICODETEXT:
                client->pasteboard_format = CF_UNICODETEXT;
                cliprdr_send_data_request(instance, CF_UNICODETEXT);
                return;
                break;
        }
    }
}

void process_cliprdr_event(freerdp* instance, wMessage* event)
{
    NSLog(@"process_cliprdr_event");
    
    int i;
    NSArray* types;
    mfContext* mfc = (mfContext*) instance->context;
    
    MRDPClient* client = (MRDPClient *)mfc->client;
    NSPasteboard* pasteboard_rd = (NSPasteboard*)client->pasteboard_rd;
    
    i = (int) [pasteboard_rd changeCount];
    if (i != client->pasteboard_changecount)
    {
        client->pasteboard_changecount = i;
        types = [NSArray arrayWithObject:NSStringPboardType];
        NSString *str = [pasteboard_rd availableTypeFromArray:types];
        if (str != nil)
        {
            cliprdr_send_supported_format_list(instance);
        }
    }
    
    if (event)
    {
        switch (GetMessageType(event->id))
        {
                /*
                 * Monitor Ready PDU is sent by server to indicate that it has been
                 * initialized and is ready. This PDU is transmitted by the server after it has sent
                 * Clipboard Capabilities PDU
                 */
            case CliprdrChannel_MonitorReady:
                cliprdr_process_cb_monitor_ready_event(instance);
                break;
                
                /*
                 * The Format List PDU is sent either by the client or the server when its
                 * local system clipboard is updated with new clipboard data. This PDU
                 * contains the Clipboard Format ID and name pairs of the new Clipboard
                 * Formats on the clipboard
                 */
            case CliprdrChannel_FormatList:
                cliprdr_process_cb_format_list_event(instance, (RDP_CB_FORMAT_LIST_EVENT*) event);
                break;
                
                /*
                 * The Format Data Request PDU is sent by the receipient of the Format List PDU.
                 * It is used to request the data for one of the formats that was listed in the
                 * Format List PDU
                 */
            case CliprdrChannel_DataRequest:
                cliprdr_process_cb_data_request_event(instance);
                break;
                
                /*
                 * The Format Data Response PDU is sent as a reply to the Format Data Request PDU.
                 * It is used to indicate whether processing of the Format Data Request PDU
                 * was successful. If the processing was successful, the Format Data Response PDU
                 * includes the contents of the requested clipboard data
                 */
            case CliprdrChannel_DataResponse:
                cliprdr_process_cb_data_response_event(instance, (RDP_CB_DATA_RESPONSE_EVENT*) event);
                break;
                
            default:
                WLog_ERR(TAG, "process_cliprdr_event: unknown event type %d", GetMessageType(event->id));
                break;
        }
    }
}

void cliprdr_send_supported_format_list(freerdp* instance)
{
    NSLog(@"cliprdr_send_supported_format_list");
    
    RDP_CB_FORMAT_LIST_EVENT* event;
    
    event = (RDP_CB_FORMAT_LIST_EVENT*) freerdp_event_new(CliprdrChannel_Class, CliprdrChannel_FormatList, NULL, NULL);
    
    event->formats = (UINT32*) malloc(sizeof(UINT32) * 1);
    event->num_formats = 1;
    event->formats[0] = CF_UNICODETEXT;
    
    freerdp_channels_send_event(instance->context->channels, (wMessage*) event);
}

BOOL mac_authenticate(freerdp* instance, char** username, char** password, char** domain)
{
    mfContext *mfc = (mfContext *)instance->context;
    MRDPClient* client = (MRDPClient *)mfc->client;
    id<MRDPClientDelegate> view = (id<MRDPClientDelegate>)client.delegate;
    
    NSString *hostName = [NSString stringWithCString:instance->settings->ServerHostname encoding:NSUTF8StringEncoding];
    NSString *userName = nil;
    NSString *userPass = nil;
    NSString *userDomain = nil;
    
    if(*username)
    {
        userName = [NSString stringWithCString:*username encoding:NSUTF8StringEncoding];
    }
    
    if(*password)
    {
        userPass = [NSString stringWithCString:*password encoding:NSUTF8StringEncoding];
    }
    
    if(*domain)
    {
        userDomain = [NSString stringWithCString:*domain encoding:NSUTF8StringEncoding];
    }
    
    ServerCredential *credential = [[ServerCredential alloc] initWithHostName:hostName
                                                                       domain:userDomain
                                                                     userName:userName
                                                                  andPassword:userPass];
    
    if([view provideServerCredentials:&credential] == TRUE)
    {
        const char* submittedUsername = [credential.username cStringUsingEncoding:NSUTF8StringEncoding];
        *username = malloc((strlen(submittedUsername) + 1) * sizeof(char));
        strcpy(*username, submittedUsername);
        
        const char* submittedPassword = [credential.password cStringUsingEncoding:NSUTF8StringEncoding];
        *password = malloc((strlen(submittedPassword) + 1) * sizeof(char));
        strcpy(*password, submittedPassword);
        
        const char* submittedDomain = [credential.domain cStringUsingEncoding:NSUTF8StringEncoding];
        *domain = malloc((strlen(submittedDomain) + 1) * sizeof(char));
        strcpy(*domain, submittedDomain);
    }
    
    [credential release];
    
    return TRUE;
}

BOOL mac_verify_certificate(freerdp* instance, char* subject, char* issuer, char* fingerprint)
{
    mfContext *mfc = (mfContext *)instance->context;
    MRDPClient* client = (MRDPClient *)mfc->client;
    id<MRDPClientDelegate> view = (id<MRDPClientDelegate>)client.delegate;
    
    NSString *certSubject = nil;
    NSString *certIssuer = nil;
    NSString *certFingerprint = nil;
    
    if(*subject)
    {
        certSubject = [NSString stringWithUTF8String:subject];
    }
    
    if(*issuer)
    {
        certIssuer = [NSString stringWithUTF8String:issuer];
    }
    
    if(*fingerprint)
    {
        certFingerprint = [NSString stringWithUTF8String:fingerprint];
    }
    
    ServerCertificate *certificate = [[ServerCertificate alloc] initWithSubject:certSubject issuer:certIssuer andFingerprint:certFingerprint];
    
    bool result = [view validateCertificate:certificate];
    
    [certificate release];
    
    return result;
}

int mac_verify_x509certificate(freerdp* instance, BYTE* data, int length, const char* hostname, int port, DWORD flags)
{
    mfContext *mfc = (mfContext *)instance->context;
    MRDPClient* client = (MRDPClient *)mfc->client;
    id<MRDPClientDelegate> view = (id<MRDPClientDelegate>)client.delegate;
    
    BOOL result = false;
    
    if(length > 0 && *hostname)
    {
        NSData *certificateData = [NSData dataWithBytes:data length:length];
        NSString *certificateHostname = [NSString stringWithUTF8String:hostname];
        
        X509Certificate *x509 = [[X509Certificate alloc] initWithData:certificateData hostname:certificateHostname andPort:port];
        
        result = [view validateX509Certificate:x509];
        
        [x509 release];
    }
    
    return result ? 1 : -1;
}

@end
