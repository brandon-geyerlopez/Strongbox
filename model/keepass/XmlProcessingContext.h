//
//  XmlParsingContext.h
//  Strongbox
//
//  Created by Mark on 06/11/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface XmlProcessingContext : NSObject

+ (instancetype)standardV3Context;
+ (instancetype)standardV4Context;

@property (nonatomic) BOOL v4Format;

@end

NS_ASSUME_NONNULL_END
