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
#import "mfreerdp.h"

@interface MRDPViewController : NSViewController <MRDPViewDelegate>
{
    NSObject<MRDPViewControllerDelegate> *delegate;
    
    @public
	rdpContext* context;
	MRDPView* mrdpView;
}

@property(nonatomic, assign) NSObject<MRDPViewControllerDelegate> *delegate;
@property (assign) rdpContext *context;
@property (nonatomic, readonly) BOOL isConnected;

- (BOOL)configure;
- (BOOL)configure:(NSArray *)arguments;
- (void)start;
- (void)stop;
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

@end
