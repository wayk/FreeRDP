//
//  MRDPClient.h
//  FreeRDP
//
//  Created by Richard Markiewicz on 2014-11-09.
//
//

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>

#import "mfreerdp.h"
#import "MRDPClientDelegate.h"

@interface MRDPClient : NSObject
{
    mfContext* mfc;
    freerdp* instance;
    rdpContext* context;
    NSMutableArray* cursors;
    NSTimer* pasteboard_timer;
    DWORD kbdModFlags;
    
    @public
    id<MRDPClientDelegate> delegate;
    NSPasteboard* pasteboard_rd; /* for reading from clipboard */
    NSPasteboard* pasteboard_wr; /* for writing to clipboard */
    int pasteboard_changecount;
    int pasteboard_format;
}

@property(nonatomic, assign) id<MRDPClientDelegate> delegate;

- (int)rdpStart:(rdpContext*)rdp_context;
- (void)releaseResources;
- (void)pause;
- (void)resume;
- (void)onPasteboardTimerFired:(NSTimer*)timer;
- (void)keyDown:(NSEvent *)event;
- (void)keyUp:(NSEvent *)event;
- (void)flagsChanged:(NSEvent*)event;

@end

BOOL mac_pre_connect(freerdp* instance);
BOOL mac_post_connect(freerdp*	instance);
BOOL mac_authenticate(freerdp* instance, char** username, char** password, char** domain);
BOOL mac_verify_certificate(freerdp* instance, char* subject, char* issuer, char* fingerprint);
int mac_verify_x509certificate(freerdp* instance, BYTE* data, int length, const char* hostname, int port, DWORD flags);
int mac_receive_channel_data(freerdp* instance, UINT16 chan_id, BYTE* data, int size, int flags, int total_size);
BOOL mac_authenticate(freerdp* instance, char** username, char** password, char** domain);
BOOL mac_verify_certificate(freerdp* instance, char* subject, char* issuer, char* fingerprint);
int mac_verify_x509certificate(freerdp* instance, BYTE* data, int length, const char* hostname, int port, DWORD flags);
