//
//  NLTFamily.m
//  TestNoco
//
//  Created by Sébastien POIVRE on 01/07/2014.
//  Copyright (c) 2014 Sébastien Poivre. All rights reserved.
//

#import "NLTFamily.h"

@implementation NLTFamily

#pragma - KVO methods
- (NLTFamily*)initWithDictionnary:(NSDictionary*)dictionary{
    [self setValuesForKeysWithDictionary:dictionary];
    return self;
}

-(void)setValue:(id)value forUndefinedKey:(NSString *)key{
#ifdef DEBUG
    NSLog(@"Unexpected value %@ for key %@",value, key);
#endif
}


-(void)setValue:(id)value forKey:(NSString *)key{
    NSMethodSignature* methodSignature = [[NLTFamily class] instanceMethodSignatureForSelector:NSSelectorFromString(key)];
    if(methodSignature){
        if(strcmp([methodSignature methodReturnType], "@")==0){
            //Object expected
            if(value && [value isKindOfClass:[NSNumber class]]){
                //...but number received : adaptating
                value = [NSString stringWithFormat:@"%@", value];
            }
        }
    }
    // "@" is not garanteed to save us from NSNumber received instead of NSString (this value can change, according to the documentaiton), so we add a final security

    if([@[@"family_TT", @"family_OT", @"partner_name", @"partner_shortname"] containsObject:key]){
        if(value && ![value isKindOfClass:[NSString class]]){
            value = [NSString stringWithFormat:@"%@", value];
        }
    }
    [super setValue:value forKey:key];
}

-(void)setNilValueForKey:(NSString *)key{
    if([key compare:@"id_show_autopromo"]==NSOrderedSame){
        //Known possible null value
        self.id_show_autopromo = -1;
        return;
    }
#ifdef DEBUG
    NSLog(@"Unexpected nil value for key %@",key);
#endif
}
@end
