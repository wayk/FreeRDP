#ifndef MRDPVIEW_H
#define MRDPVIEW_H

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

#import <Cocoa/Cocoa.h>

#import "mfreerdp.h"
#import "mf_client.h"
#import "Keyboard.h"

#import "MRDPViewDelegate.h"

@interface MRDPView : NSView
{
	mfContext* mfc;
	NSBitmapImageRep* bmiRep;
	NSMutableArray* cursors;
	NSMutableArray* windows;
	NSTimer* pasteboard_timer;
	NSCursor* currentCursor;
	NSRect prevWinPosition;
	freerdp* instance;
	rdpContext* context;
	CGContextRef bitmap_context;
	char* pixel_data;
	int argc;
	char** argv;
	DWORD kbdModFlags;
	BOOL initialized;
	NSPoint savedDragLocation;
	BOOL firstCreateWindow;
	BOOL isMoveSizeInProgress;
	BOOL skipResizeOnce;
	BOOL saveInitialDragLoc;
	BOOL skipMoveWindowOnce;
	
@public
	NSPasteboard* pasteboard_rd;
	NSPasteboard* pasteboard_wr;
	int pasteboard_changecount;
	int pasteboard_format;
	int is_connected;
    BOOL usesAppleKeyboard;
    
    NSObject<MRDPViewDelegate> *delegate;
}

- (int)  rdpStart :(rdpContext*) rdp_context;
- (void) setCursor: (NSCursor*) cursor;
- (void) setScrollOffset:(int)xOffset y:(int)yOffset w:(int)width h:(int)height;

- (void) onPasteboardTimerFired :(NSTimer *) timer;
- (void) pause;
- (void) resume;
- (void) releaseResources;

@property (assign) int is_connected;
@property (assign) BOOL usesAppleKeyboard;
@property(nonatomic, assign) NSObject<MRDPViewDelegate> *delegate;

@end

/* Pointer Flags */
#define PTR_FLAGS_WHEEL                 0x0200
#define PTR_FLAGS_WHEEL_NEGATIVE        0x0100
#define PTR_FLAGS_MOVE                  0x0800
#define PTR_FLAGS_DOWN                  0x8000
#define PTR_FLAGS_BUTTON1               0x1000
#define PTR_FLAGS_BUTTON2               0x2000
#define PTR_FLAGS_BUTTON3               0x4000
#define WheelRotationMask               0x01FF

BOOL mac_pre_connect(freerdp* instance);
BOOL mac_post_connect(freerdp*	instance);
BOOL mac_authenticate(freerdp* instance, char** username, char** password, char** domain);
BOOL mac_verify_certificate(freerdp* instance, char* subject, char* issuer, char* fingerprint);
int mac_verify_x509certificate(freerdp* instance, BYTE* data, int length, const char* hostname, int port, DWORD flags);
int mac_receive_channel_data(freerdp* instance, int chan_id, BYTE* data, int size, int flags, int total_size);
DWORD mac_client_thread(void* param);

#endif // MRDPVIEW_H
