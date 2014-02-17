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
    
    @public
	rdpContext* context;
	MRDPView* mrdpView;
    BOOL usesAppleKeyboard;
}

@property(nonatomic, assign) NSObject<MRDPViewControllerDelegate> *delegate;
@property (assign) rdpContext *context;
@property (nonatomic, readonly) BOOL isConnected;
@property (assign) BOOL usesAppleKeyboard;
@property (nonatomic, assign) NSView *rdpView;

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
- (double)getDoubleSettingForIdentifier:(int)identifier;
- (int)setDoubleSettingForIdentifier:(int)identifier withValue:(double)value;
- (NSString *)getErrorInfoString:(int)code;
- (void)sendCtrlAltDelete;

@end
