//
//  NLTShow.m
//  TestNoco
//
//  Created by Sébastien POIVRE on 26/06/2014.
//  Copyright (c) 2014 Sébastien Poivre. All rights reserved.
//

#import "NLTShow.h"
#import "NLTAPI.h"

@implementation NLTShow

#pragma - KVO methods
- (NLTShow*)initWithDictionnary:(NSDictionary*)dictionary{
    [self setValuesForKeysWithDictionary:dictionary];
    //Date parsing
    if(self.broadcast_date_utc){
        NSDateFormatter *formater = [[NSDateFormatter alloc] init];
        [formater setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
        NSTimeZone *timeZone = [NSTimeZone timeZoneWithName:@"UTC"];
        [formater setTimeZone:timeZone];
        self.broadcastDate = [formater dateFromString:self.broadcast_date_utc];
    }
    return self;
}

-(void)setValue:(id)value forUndefinedKey:(NSString *)key{
#ifdef DEBUG
    NSLog(@"Unexpected value %@ for key %@",value, key);
#endif
}

-(void)setNilValueForKey:(NSString *)key{
    if([key compare:@"mark_read"]==NSOrderedSame){
        //Known possible null value
        self.mark_read = false;
        return;
    }
#ifdef DEBUG
    NSLog(@"Unexpected nil value for key %@",key);
#endif
}

@end
