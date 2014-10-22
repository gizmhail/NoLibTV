//
//  GroupSettingsManager.h
//
//  Created by Sébastien POIVRE on 05/10/2014.
//  Copyright (c) 2014 Sébastien Poivre. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

#ifndef GROUP_SETTINGS_MANAGER_h
#define GROUP_SETTINGS_MANAGER_h
#define GSM_SETTINGS_UPDATE_SUFFIX @"_lastUpdate"
#endif
@interface GroupSettingsManager : NSObject

@property(retain,nonatomic) NSString* defaultSuiteName;
//Array of keys that need deep debugging with logs
@property(retain,nonatomic) NSArray*debugKeys;

#pragma mark - Real  methods

+ (instancetype)sharedInstance;
#pragma mark
- (void)synchronize;
- (void)synchronizeWithSuiteName:(NSString*)suiteName;

#pragma mark Read methods: will read the value in the most recently used storage between standardUserSettings and suiteName settings
- (id)objectForKey:(NSString*)key;
- (id)objectForKey:(NSString*)key withSuiteName:(NSString*)suiteName;

#pragma mark Set methods: will write the value in both standardUserSettings and suiteName settings

- (void)setObject:(id)object forKey:(NSString*)key;
- (void)setObject:(id)object forKey:(NSString*)key withSuiteName:(NSString*)suiteName;

- (void)removeObjectForKey:(NSString *)key;
- (void)removeObjectForKey:(NSString *)key withSuiteName:(NSString*)suiteName;

#pragma mark Migration methods (to fill suitName NSUserDefaults with local values
- (void)copyIfNeededFromLocalKeys:(NSArray*)keys;
- (void)copyIfNeededFromLocalKeys:(NSArray*)keys toSuitName:(NSString*)suiteName;

#pragma mark Debugging methods (will use shared NSUserSettings through GroupSettingsManager to store the logs - synchronize call not needed, as it is handled in logEvent)
- (void)logEvent:(NSString*)event withUserInfo:(NSDictionary*)userInfo;
- (NSMutableArray*)logs;

#pragma mark - Proxified methods (towards proper NSUserdefaults, either standardUserDefaults or defaultSuiteName one)
- (NSString *)stringForKey:(NSString *)defaultName;
- (NSArray *)arrayForKey:(NSString *)defaultName;
- (NSDictionary *)dictionaryForKey:(NSString *)defaultName;
- (NSData *)dataForKey:(NSString *)defaultName;
- (NSArray *)stringArrayForKey:(NSString *)defaultName;
- (NSInteger)integerForKey:(NSString *)defaultName;
- (float)floatForKey:(NSString *)defaultName;
- (double)doubleForKey:(NSString *)defaultName;
- (BOOL)boolForKey:(NSString *)defaultName;
- (NSURL *)URLForKey:(NSString *)defaultName;

- (void)setInteger:(NSInteger)value forKey:(NSString *)defaultName;
- (void)setFloat:(float)value forKey:(NSString *)defaultName;
- (void)setDouble:(double)value forKey:(NSString *)defaultName;
- (void)setBool:(BOOL)value forKey:(NSString *)defaultName;
- (void)setURL:(NSURL *)url forKey:(NSString *)defaultName;

@end
