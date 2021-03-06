//
//  WelcomeViewController.h
//  Strongbox-iOS
//
//  Created by Mark on 05/06/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SafeMetaData.h"

NS_ASSUME_NONNULL_BEGIN

@interface WelcomeAddDatabaseViewController : UIViewController

@property (nonatomic, copy) void (^onDone)(BOOL addExisting, SafeMetaData* _Nullable databaseToOpen);

@end

NS_ASSUME_NONNULL_END
