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
