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

@interface MRDPView : NSView<MRDPClientDelegate>
{
    NSMutableArray* windows;
	NSCursor* currentCursor;
	freerdp* instance;
	rdpContext* context;
	CGContextRef bitmap_context;
	BOOL initialized;
	
@public
	int is_connected;
    BOOL usesAppleKeyboard;
    NSObject<MRDPViewDelegate> *delegate;
}

- (void)setCursor:(NSCursor*) cursor;
- (void)releaseResources;
- (void)preConnect:(freerdp*)rdpInstance;
- (void)postConnect:(freerdp*)rdpInstance;
- (BOOL)provideServerCredentials:(ServerCredential **)credentials;
- (BOOL)validateCertificate:(ServerCertificate *)certificate;
- (BOOL)validateX509Certificate:(X509Certificate *)certificate;

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

#endif // MRDPVIEW_H
