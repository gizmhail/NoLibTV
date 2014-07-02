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

#pragma mark - Formating

- (NSString*)durationString{
    NSString* durationStr = nil;
    if(self.duration_ms){
        int seconds = self.duration_ms / 1000;
        int hours = seconds/3600;
        seconds -= hours*3600;
        int min = seconds/60;
        seconds -= min*60;
        if(hours>0){
            durationStr = [NSString stringWithFormat:@"%ih%i",hours,min];
        }else if(min>5){
            durationStr = [NSString stringWithFormat:@"%imin",min];
        }else if(min>0){
            durationStr = [NSString stringWithFormat:@"%imin%i",min,seconds];
        }else{
            durationStr = [NSString stringWithFormat:@"%isec",seconds];
        }
    }
    return durationStr;
}
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

-(void)setValue:(id)value forKey:(NSString *)key{
    //The API can return String instead of arrays if it contains only one value
    if([@[@"qualities", @"qualities_languages", @"languages", @"audio_languages", @"video_languages",@"full_audio_languages",@"full_video_Langagues"] containsObject:key]){
        if(![value isKindOfClass:[NSArray class]]){
            if([value isKindOfClass:[NSString class]]){
                value = [NSArray arrayWithObject:value];
            }else{
                value = nil;
            }
        }
    }
    [super setValue:value forKey:key];
}
-(void)setValue:(id)value forUndefinedKey:(NSString *)key{
    if([@[@"qualities", @"qualities_languages", @"languages", @"audio_languages", @"video_languages",@"full_audio_languages",@"full_video_Langagues"] containsObject:key]){
        if([value isKindOfClass:[NSNull class]]){
            [self setValue:nil forKey:key];
        }
    }else{
#ifdef DEBUG
        NSLog(@"Unexpected value %@ for key %@",value, key);
#endif
    }
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
