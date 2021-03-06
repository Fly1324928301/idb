/**
 * Copyright (c) Facebook, Inc. and its affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import <Foundation/Foundation.h>

#import <FBControlCore/FBControlCore.h>

NS_ASSUME_NONNULL_BEGIN

/**
 Quick access to iOS targets.
 */
@interface FBiOSTargetProvider : NSObject

/**
 Provide a target with a specified identifier.

 @param udid iOS Target identifier.
 @param logger the logger to use.
 @param reporter the event reporter to report to.
 @param error an error out for any error that occurs.
 @return the target matching the specified identifier or nil on error.
 */
+ (nullable id<FBiOSTarget>)targetWithUDID:(NSString *)udid logger:(nullable id<FBControlCoreLogger>)logger reporter:(nullable id<FBEventReporter>)reporter error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
