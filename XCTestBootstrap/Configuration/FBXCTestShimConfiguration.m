/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBXCTestShimConfiguration.h"

#import <FBControlCore/FBControlCore.h>
#import <XCTestBootstrap/XCTestBootstrap.h>

static NSString *const iOSXCToolShimFileName = @"otest-shim-ios.dylib";
static NSString *const macOSXCToolShimFileName = @"otest-shim-osx.dylib";
static NSString *const macOSXCToolQueryShimFileName = @"otest-query-lib-osx.dylib";
static NSString *const ConfirmShimsAreSignedEnv = @"FBXCTEST_CONFIRM_SIGNED_SHIMS";

@implementation FBXCTestShimConfiguration

#pragma mark Initializers

+ (NSDictionary<NSString *, NSNumber *> *)shimFilenamesToCodesigningRequired
{
  NSMutableDictionary<NSString *, NSNumber *> *shims = [NSMutableDictionary dictionaryWithDictionary:@{
    iOSXCToolShimFileName : @NO,
    macOSXCToolShimFileName : @NO,
    macOSXCToolQueryShimFileName : @NO,
  }];
  if (NSProcessInfo.processInfo.environment[ConfirmShimsAreSignedEnv].boolValue && FBControlCoreGlobalConfiguration.isXcode8OrGreater) {
    shims[iOSXCToolShimFileName] = @YES;
  }
  return [shims copy];
}

+ (nullable NSString *)findShimDirectoryWithError:(NSError **)error
{
  // If an environment variable is provided, use it
  NSString *environmentDefinedDirectory = NSProcessInfo.processInfo.environment[@"TEST_SHIMS_DIRECTORY"];
  if (environmentDefinedDirectory) {
    return [self confirmExistenceOfRequiredShimsInDirectory:environmentDefinedDirectory error:error];
  }

  // Otherwise, expect it to be relative to the location of the current executable.
  NSString *libPath = [self.fbxctestInstallationRoot stringByAppendingPathComponent:@"lib"];
  return [self confirmExistenceOfRequiredShimsInDirectory:libPath error:error];
}

+ (nullable NSString *)confirmExistenceOfRequiredShimsInDirectory:(NSString *)directory error:(NSError **)error
{
  if (![NSFileManager.defaultManager fileExistsAtPath:directory]) {
    return [[FBXCTestError
      describeFormat:@"A shim directory was expected at '%@', but it was not there", directory]
      fail:error];
  }

  NSDictionary<NSString *, NSNumber *> *shims = self.shimFilenamesToCodesigningRequired;

  id<FBCodesignProvider> codesign = FBCodesignProvider.codeSignCommandWithAdHocIdentity;
  for (NSString *filename in shims) {
    NSString *shimPath = [directory stringByAppendingPathComponent:iOSXCToolShimFileName];
    if (![NSFileManager.defaultManager fileExistsAtPath:shimPath]) {
      return [[FBXCTestError
        describeFormat:@"The iOS xctest Simulator Shim was expected at the location '%@', but it was not there", shimPath]
        fail:error];
    }
    if (!shims[filename].boolValue) {
      continue;
    }
    NSError *innerError = nil;
    if (![codesign cdHashForBundleAtPath:shimPath error:&innerError]) {
      return [[[FBXCTestError
        describeFormat:@"Shim at path %@ was required to be signed, but it was not", shimPath]
        causedBy:innerError]
        fail:error];
    }
  }
  return directory;
}

+ (nullable instancetype)defaultShimConfigurationWithError:(NSError **)error
{
  NSError *innerError = nil;
  NSString *shimDirectory = [self findShimDirectoryWithError:&innerError];
  if (!shimDirectory) {
    return [FBXCTestError failWithError:innerError errorOut:error];
  }
  return [self shimConfigurationWithDirectory:shimDirectory error:error];
}

+ (nullable instancetype)shimConfigurationWithDirectory:(NSString *)directory error:(NSError **)error
{
  NSError *innerError = nil;
  NSString *shimDirectory = [self confirmExistenceOfRequiredShimsInDirectory:directory error:error];
  if (!shimDirectory) {
    return [FBXCTestError failWithError:innerError errorOut:error];
  }
  NSString *iOSTestShimPath = [shimDirectory stringByAppendingPathComponent:iOSXCToolShimFileName];
  NSString *macTestShimPath = [shimDirectory stringByAppendingPathComponent:macOSXCToolShimFileName];
  NSString *macOSQueryShimPath = [shimDirectory stringByAppendingPathComponent:macOSXCToolQueryShimFileName];

  return [[self alloc] initWithiOSSimulatorTestShimPath:iOSTestShimPath macOSTestShimPath:macTestShimPath macOSQueryShimPath:macOSQueryShimPath];
}

+ (NSString *)fbxctestInstallationRoot
{
  NSString *executablePath = NSProcessInfo.processInfo.arguments[0];
  if (!executablePath.isAbsolutePath) {
    executablePath = [NSFileManager.defaultManager.currentDirectoryPath stringByAppendingString:executablePath];
  }
  executablePath = [executablePath stringByStandardizingPath];
  NSString *path = [[executablePath
    stringByDeletingLastPathComponent]
    stringByDeletingLastPathComponent];
  return [NSFileManager.defaultManager fileExistsAtPath:path] ? path : nil;
}

- (instancetype)initWithiOSSimulatorTestShimPath:(NSString *)iosSimulatorTestShim macOSTestShimPath:(NSString *)macOSTestShimPath macOSQueryShimPath:(NSString *)macOSQueryShimPath
{
  NSParameterAssert(iosSimulatorTestShim);
  NSParameterAssert(macOSTestShimPath);
  NSParameterAssert(macOSQueryShimPath);

  self = [super init];
  if (!self) {
    return nil;
  }

  _iOSSimulatorTestShimPath = iosSimulatorTestShim;
  _macOSTestShimPath = macOSTestShimPath;
  _macOSQueryShimPath = macOSQueryShimPath;

  return self;
}

#pragma mark NSCopying

- (instancetype)copyWithZone:(NSZone *)zone
{
  return self;
}

#pragma mark NSObject

- (BOOL)isEqual:(FBXCTestShimConfiguration *)object
{
  if (![object isKindOfClass:self.class]) {
    return NO;
  }
  return [self.iOSSimulatorTestShimPath isEqualToString:object.iOSSimulatorTestShimPath]
      && [self.macOSTestShimPath isEqualToString:object.macOSTestShimPath]
      && [self.macOSQueryShimPath isEqualToString:object.macOSQueryShimPath];
}

- (NSUInteger)hash
{
  return self.iOSSimulatorTestShimPath.hash ^ self.macOSTestShimPath.hash ^ self.macOSQueryShimPath.hash;
}

#pragma mark JSON

static NSString *const KeySimulatorTestShim = @"ios_simulator_test_shim";
static NSString *const KeyMacTestShim = @"mac_test_shim";
static NSString *const KeyMacQueryShim = @"mac_query_shim";

+ (nullable instancetype)inflateFromJSON:(NSDictionary<NSString *, NSString *> *)json error:(NSError **)error
{
  if (![FBCollectionInformation isDictionaryHeterogeneous:json keyClass:NSString.class valueClass:NSString.class]) {
    return [[FBXCTestError
      describeFormat:@"%@ is not a Dictionary<String, String>", json]
      fail:error];
  }
  NSString *simulatorTestShim = json[KeySimulatorTestShim];
  if (![simulatorTestShim isKindOfClass:NSString.class]) {
    return [[FBXCTestError
      describeFormat:@"%@ is not a String for %@", simulatorTestShim, KeySimulatorTestShim]
      fail:error];
  }
  NSString *macTestShim = json[KeyMacTestShim];
  if (![macTestShim isKindOfClass:NSString.class]) {
    return [[FBXCTestError
      describeFormat:@"%@ is not a String for %@", macTestShim, KeyMacTestShim]
      fail:error];
  }
  NSString *macOSQueryShimPath = json[KeyMacQueryShim];
  if (![macOSQueryShimPath isKindOfClass:NSString.class]) {
    return [[FBXCTestError
      describeFormat:@"%@ is not a String for %@", macOSQueryShimPath, KeyMacQueryShim]
      fail:error];
  }
  return [[FBXCTestShimConfiguration alloc] initWithiOSSimulatorTestShimPath:simulatorTestShim macOSTestShimPath:macTestShim macOSQueryShimPath:macOSQueryShimPath];
}

- (id)jsonSerializableRepresentation
{
  return @{
    KeySimulatorTestShim: self.iOSSimulatorTestShimPath,
    KeyMacTestShim: self.macOSTestShimPath,
    KeyMacQueryShim: self.macOSQueryShimPath,
  };
}

@end
