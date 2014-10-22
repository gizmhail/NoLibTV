//
//  GroupSettingsManager.m
//
//  Created by Sébastien POIVRE on 05/10/2014.
//  Copyright (c) 2014 Sébastien Poivre. All rights reserved.
//

#import "GroupSettingsManager.h"

#pragma clang diagnostic ignored "-Wincomplete-implementation"
@implementation GroupSettingsManager

+ (instancetype)sharedInstance{
    static GroupSettingsManager* _sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        if(!_sharedInstance){
            _sharedInstance = [[self alloc] init];
        }
    });
    return _sharedInstance;
}

- (id)init{
    if(self = [super init]){
    }
    return self;
}

- (BOOL) groupSupport:(NSString*)suiteName{
    BOOL groupSupport = false;
    if(self.defaultSuiteName){
        if([[[UIDevice currentDevice] systemVersion] floatValue] >= 7.0){
            groupSupport = true;
        }
    }
    return groupSupport;
}

#pragma mark - NSUserDefault proxy
//Ideas found in this article: https://www.mikeash.com/pyblog/friday-qa-2009-03-27-objective-c-message-forwarding.html

-(id)forwardingTargetForSelector:(SEL)aSelector{
    return self;
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)sel{
    NSMethodSignature *sig = [super methodSignatureForSelector:sel];
    if(!sig){
        sig = [[NSUserDefaults standardUserDefaults] methodSignatureForSelector:sel];
    }
    return sig;
}

- (void)forwardInvocation:(NSInvocation *)inv{
    NSString* selectorName = NSStringFromSelector(inv.selector);
    if([selectorName rangeOfString:@"set"].location==0){
        //set method
        NSUserDefaults* localDefaults = [NSUserDefaults standardUserDefaults];
        [inv invokeWithTarget:localDefaults];
        if([self groupSupport:self.defaultSuiteName]){
            NSUserDefaults* suiteDefaults = [[NSUserDefaults alloc] initWithSuiteName:self.defaultSuiteName];
            [inv invokeWithTarget:suiteDefaults];
        }
        
        //Add date storage
        NSString* key = nil;
        [inv getArgument:&key atIndex:3];
        [inv invokeWithTarget:[self userDefaultsStoring:key withSuiteName:nil]];
        if(key){
            NSString* updateKey = [NSString stringWithFormat:@"%@%@",key,GSM_SETTINGS_UPDATE_SUFFIX];
            NSDate* now = [NSDate date];
            [localDefaults setObject:now forKey:updateKey];
            if([self groupSupport:self.defaultSuiteName]){
                NSUserDefaults* suiteDefaults = [[NSUserDefaults alloc] initWithSuiteName:self.defaultSuiteName];
                [suiteDefaults setObject:now forKey:updateKey];
            }

        }
    }else{
        //get method
        NSString* key = nil;
        if([selectorName rangeOfString:@":"].location!=NSNotFound){
            //Selector expect at least one argument
            [inv getArgument:&key atIndex:2];
            [inv invokeWithTarget:[self userDefaultsStoring:key withSuiteName:nil]];
        }
    }
}

#pragma mark - Read

- (NSUserDefaults*)userDefaultsStoring:(NSString*)key withSuiteName:(NSString*)suiteName{
    if(!suiteName){
        suiteName = self.defaultSuiteName;
    }
#ifdef DEBUG
    if(suiteName == nil){
        NSLog(@"Trying to use group settings without a suiteName: might be an error");
    }
#endif
    BOOL useLocalSettings = true;
    NSUserDefaults* defaults = nil;
    NSUserDefaults* localDefaults = [NSUserDefaults standardUserDefaults];
    if([self groupSupport:suiteName]){
        NSUserDefaults* suiteDefaults = [[NSUserDefaults alloc] initWithSuiteName:suiteName];
        if(suiteDefaults){
            NSString* updateKey = [NSString stringWithFormat:@"%@%@",key,GSM_SETTINGS_UPDATE_SUFFIX];
            
            id localObject = [localDefaults objectForKey:key];
            NSDate* localObjectUpdateDate = [localDefaults objectForKey:updateKey];
            id suiteObject = [suiteDefaults objectForKey:updateKey];
            NSDate* suiteObjectUpdateDate = [suiteDefaults objectForKey:updateKey];

            defaults = localDefaults;
            if(!localObject){
                //NSLog(@"No local settings, using suiteName %@",suiteName);
                defaults = suiteDefaults;
                useLocalSettings = false;
            }else{
                if(suiteObject&&localObjectUpdateDate&&suiteObjectUpdateDate){
                    if([suiteObjectUpdateDate compare:localObjectUpdateDate]==NSOrderedDescending){
                        //NSLog(@"Group settings for suiteName %@ are more recent",suiteName);
                        defaults = suiteDefaults;
                        useLocalSettings = false;
                    }else{
                        //NSLog(@"Group settings for suiteName %@ are older",suiteName);
                    }
                }else{
                    //NSLog(@"Not all data to compare with suiteName %@, usiong local settings",suiteName);
                }
            }
        }else{
            //NSLog(@"No group settings for suitname %@",suiteName);
            defaults = localDefaults;
        }
    }else{
        //NSLog(@"No group support for suitName %@",suiteName);
        defaults = localDefaults;
    }
    
    if(self.debugKeys&&[self.debugKeys containsObject:key]){
        NSMutableDictionary* debugInfo = [NSMutableDictionary dictionary];
        NSString* updateKey = [NSString stringWithFormat:@"%@%@",key,GSM_SETTINGS_UPDATE_SUFFIX];
        NSUserDefaults* suiteDefaults = nil;
        if([self groupSupport:suiteName]){
            suiteDefaults = [[NSUserDefaults alloc] initWithSuiteName:suiteName];
        }
        if([defaults objectForKey:key]){
            [debugInfo setObject:[defaults objectForKey:key] forKey:@"selected"];
        }
        if([localDefaults objectForKey:key]){
            [debugInfo setObject:[defaults objectForKey:key] forKey:@"local"];
        }
        if([localDefaults objectForKey:updateKey]){
            [debugInfo setObject:[defaults objectForKey:updateKey] forKey:@"localDate"];
        }
        if([suiteDefaults objectForKey:key]){
            [debugInfo setObject:[defaults objectForKey:key] forKey:@"group"];
        }
        if([suiteDefaults objectForKey:updateKey]){
            [debugInfo setObject:[defaults objectForKey:updateKey] forKey:@"groupDate"];
        }
        
        if(useLocalSettings){
            //NSLog(@"Fetching object from local settings with key %@",key);
            NSString* event = [NSString stringWithFormat:@"LocalSourceFor%@",key];
            [self logEvent:event withUserInfo:debugInfo];
        }else{
            //NSLog(@"Fetching object from %@ settings with key %@",suiteName,key);
            NSString* event = [NSString stringWithFormat:@"GroupSourceFor%@",key];
            [self logEvent:event withUserInfo:debugInfo];
        }
    }
    return defaults;
}

- (id)objectForKey:(NSString*)key{
    return [self objectForKey:key withSuiteName:nil];
}

- (id)objectForKey:(NSString*)key withSuiteName:(NSString*)suiteName{
    NSUserDefaults* defaults = [self userDefaultsStoring:key withSuiteName:suiteName];
    return [defaults objectForKey:key];
}

#pragma mark - Write

- (void)setObject:(id)object forKey:(NSString*)key{
    [self setObject:object forKey:key withSuiteName:nil];
}

- (void)setObject:(id)object forKey:(NSString*)key withSuiteName:(NSString*)suiteName{
    NSDate* now = [NSDate date];
    NSString* updateKey = [NSString stringWithFormat:@"%@%@",key,GSM_SETTINGS_UPDATE_SUFFIX];
    NSUserDefaults* localDefaults = [NSUserDefaults standardUserDefaults];
    [localDefaults setObject:object forKey:key];
    [localDefaults setObject:now forKey:updateKey];
    
    if(self.debugKeys&&[self.debugKeys containsObject:key]){
        NSString* event = [NSString stringWithFormat:@"LocalSetFor%@",key];
        [self logEvent:event withUserInfo:@{@"value":object}];
    }

    //NSLog(@"Set local settings ; Key %@ ",key);
    if(!suiteName){
        suiteName = self.defaultSuiteName;
    }
    if([self groupSupport:suiteName]){
        if(self.debugKeys&&[self.debugKeys containsObject:key]){
            NSString* event = [NSString stringWithFormat:@"GroupSetFor%@",key];
            [self logEvent:event withUserInfo:@{@"value":object}];
        }
        
        NSUserDefaults* suiteDefaults = [[NSUserDefaults alloc] initWithSuiteName:suiteName];
        //NSLog(@"Set %@ settings ; Key %@ ",suiteName,key);
        [suiteDefaults setObject:object forKey:key];
        [suiteDefaults setObject:now forKey:updateKey];
    }
}

- (void)removeObjectForKey:(NSString *)key{
    [self removeObjectForKey:key withSuiteName:nil];
}

- (void)removeObjectForKey:(NSString *)key withSuiteName:(NSString*)suiteName{
    NSUserDefaults* localDefaults = [NSUserDefaults standardUserDefaults];
    [localDefaults removeObjectForKey:key];
    if(!suiteName){
        suiteName = self.defaultSuiteName;
    }
    if([self groupSupport:suiteName]){
        NSUserDefaults* suiteDefaults = [[NSUserDefaults alloc] initWithSuiteName:suiteName];
        [suiteDefaults removeObjectForKey:key];
    }
}

- (void)synchronize{
    [self synchronizeWithSuiteName:nil];
}
- (void)synchronizeWithSuiteName:(NSString*)suiteName{
    NSUserDefaults* localDefaults = [NSUserDefaults standardUserDefaults];
    [localDefaults synchronize];
    if(!suiteName){
        suiteName = self.defaultSuiteName;
    }
    if([self groupSupport:suiteName]){
        NSUserDefaults* suiteDefaults = [[NSUserDefaults alloc] initWithSuiteName:suiteName];
        [suiteDefaults synchronize];
    }
}

#pragma mark - Migration

- (void)copyIfNeededFromLocalKeys:(NSArray*)keys{
    [self copyIfNeededFromLocalKeys:keys toSuitName:nil];
}

- (void)copyIfNeededFromLocalKeys:(NSArray*)keys toSuitName:(NSString*)suiteName{
    if(!suiteName){
        suiteName = self.defaultSuiteName;
    }
    if(keys&&[self groupSupport:suiteName]){
        NSUserDefaults* suiteDefaults = [[NSUserDefaults alloc] initWithSuiteName:suiteName];
        NSUserDefaults* localDefaults = [NSUserDefaults standardUserDefaults];
        for (NSString*key in keys) {
            if(![suiteDefaults objectForKey:key]){
                id localObject = [localDefaults objectForKey:key];
                if(localObject){
                    [suiteDefaults setObject:localObject forKey:key];
                }
            }
        }
    }
}

#pragma mark Log

- (NSMutableArray*)logs{
    NSMutableArray* logs = nil;
    if([self objectForKey:@"GSM_Logs"]){
        NSArray* logsSaved = [NSKeyedUnarchiver unarchiveObjectWithData:[self objectForKey:@"GSM_Logs"]];

        logs = [NSMutableArray arrayWithArray:logsSaved ];
    }else{
        logs = [NSMutableArray array];
    }
    return logs;
}

- (void)logEvent:(NSString*)event withUserInfo:(NSDictionary*)userInfo{
    NSString* bundleIdentifier = [[NSBundle mainBundle] bundleIdentifier];
    NSDate* date = [NSDate date];
    NSMutableArray* logs = [self logs];
    NSMutableDictionary* log = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                event,@"event",
                                bundleIdentifier,@"bundleId",
                                date,@"date",
                                nil];
    if(userInfo){
        [log setObject:userInfo forKey:@"userInfo"];
    }
    [logs addObject:log];
    if([logs count]>200){
        [logs removeObjectsInRange:NSMakeRange(0, 150)];
    }
    NSData* logsData = [NSKeyedArchiver archivedDataWithRootObject:logs ];

    [self setObject:logsData forKey:@"GSM_Logs"];
    [self synchronize];
    NSLog(@"Logging %@",log);
}

@end
