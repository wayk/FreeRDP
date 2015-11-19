//
//  MRDPViewController.h
//  FreeRDP
//
//  Created by Richard Markiewicz on 2013-07-23.
//
//

#import <Cocoa/Cocoa.h>
#import "MRDPView.h"
#import "MRDPViewControllerDelegate.h"
#import "ServerDrive.h"
#import "mfreerdp.h"

@interface MRDPViewController : NSObject <MRDPViewDelegate>
{
    NSObject<MRDPViewControllerDelegate> *delegate;
    NSView *rdpView;
	NSMutableArray *forwardedServerDrives;
    
    @public
	rdpContext* context;
    MRDPClient* mrdpClient;
}

@property(nonatomic, assign) NSObject<MRDPViewControllerDelegate> *delegate;
@property (assign) rdpContext *context;
@property (nonatomic, readonly) BOOL isConnected;
@property (nonatomic, assign) MRDPClient *mrdpClient;
@property (nonatomic, readonly) NSView *rdpView;

- (BOOL)configure;
- (BOOL)configure:(NSArray *)arguments;
- (void)start;
- (void)stop;
- (void)restart;
- (void)restart:(NSArray *)arguments;
- (void)addServerDrive:(ServerDrive *)drive;
- (BOOL)getBooleanSettingForIdentifier:(int)identifier;
- (int)setBooleanSettingForIdentifier:(int)identifier withValue:(BOOL)value;
- (int)getIntegerSettingForIdentifier:(int)identifier;
- (int)setIntegerSettingForIdentifier:(int)identifier withValue:(int)value;
- (uint32)getInt32SettingForIdentifier:(int)identifier;
- (int)setInt32SettingForIdentifier:(int)identifier withValue:(uint32)value;
- (uint64)getInt64SettingForIdentifier:(int)identifier;
- (int)setInt64SettingForIdentifier:(int)identifier withValue:(uint64)value;
- (NSString *)getStringSettingForIdentifier:(int)identifier;
- (int)setStringSettingForIdentifier:(int)identifier withValue:(NSString *)value;
- (NSString *)getErrorInfoString:(int)code;
- (void)sendCtrlAltDelete;
- (void)sendStart;
- (void)sendAppSwitch;
- (void)sendKey:(UINT16)key;
- (void)sendKey:(UINT16)key withModifier:(UINT16)modifier;
- (void)sendKeystrokes:(NSString *)keys;
- (void)initLoggingWithFilter:(NSString *)filter filePath:(NSString *)filePath fileName:(NSString *)fileName;
- (void)setIsReadOnly:(bool)isReadOnly;

@end
