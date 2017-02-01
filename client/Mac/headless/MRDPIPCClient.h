//
//  MRDPIPCClient.h
//  FreeRDP
//
//  Created by Richard Markiewicz on 2014-11-15.
//
//

#import <Foundation/Foundation.h>

#import "../MRDPClient.h"
#import "../MRDPClientDelegate.h"
#import "../ServerCertificate.h"
#import "../X509Certificate.h"
#import "../ServerCredential.h"

@interface MRDPIPCClient : NSObject<MRDPClientDelegate>
{
    NSConnection *clientConnection;
    id serverProxy;
    rdpContext* context;
    MRDPClient* mrdpClient;
    bool is_stopped;
    NSRect frame;
    bool invertHungarianCharacter;
    NSEventModifierFlags shiftKeyMask;
    NSEventModifierFlags controlKeyMask;
    NSEventModifierFlags alternateKeyMask;
    NSEventModifierFlags commandKeyMask;
    NSArray* mappedShortcuts;
}

@property (assign) NSRect frame;
@property (assign) bool invertHungarianCharacter;
@property (assign) NSEventModifierFlags shiftKeyMask;
@property (assign) NSEventModifierFlags controlKeyMask;
@property (assign) NSEventModifierFlags alternateKeyMask;
@property (assign) NSEventModifierFlags commandKeyMask;
@property (copy) NSArray* mappedShortcuts;

- (id)initWithServer:(NSString *)registeredName;
- (void)configure;
- (void)initLoggingWithFilter:(NSString *)filter filePath:(NSString *)filePath fileName:(NSString *)fileName;
- (void)setIsReadOnly:(bool)isReadOnly;

@end
