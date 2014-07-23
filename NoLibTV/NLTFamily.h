//
//  NLTFamily.h
//  TestNoco
//
//  Created by Sébastien POIVRE on 01/07/2014.
//  Copyright (c) 2014 Sébastien Poivre. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NLTFamily : NSObject

@property (assign, nonatomic) int id_family;
@property (assign, nonatomic) int id_type;
@property (retain, nonatomic) NSString* type_name;
@property (retain, nonatomic) NSString* type_key;
@property (assign, nonatomic) int id_theme;
@property (retain, nonatomic) NSString* theme_name;
@property (retain, nonatomic) NSString* theme_key;
@property (assign, nonatomic) int id_partner;
@property (retain, nonatomic) NSString* partner_name;
@property (retain, nonatomic) NSString* partner_shortname;
@property (retain, nonatomic) NSString* partner_key;
@property (retain, nonatomic) NSString* geoloc;
@property (retain, nonatomic) NSString* family_key;
@property (assign, nonatomic) int is_star;
@property (assign, nonatomic) int id_show_autopromo; //Set to -1 if no autopromo available
@property (assign, nonatomic) int nb_shows;
@property (retain, nonatomic) NSString* family_OT;
@property (retain, nonatomic) NSString* OT_lang;
@property (retain, nonatomic) NSString* family_TT;
@property (retain, nonatomic) NSString* family_resume;
@property (retain, nonatomic) NSString* partner_geoloc;
@property (retain, nonatomic) NSString* banner_family;
@property (retain, nonatomic) NSString* icon_128x72;
@property (retain, nonatomic) NSString* icon_256x144;
@property (retain, nonatomic) NSString* icon_512x288;
@property (retain, nonatomic) NSString* icon_960x540;
@property (retain, nonatomic) NSString* icon_1024x576;

@property (retain, nonatomic) NSDate* cachingDate;

- (NLTFamily*)initWithDictionnary:(NSDictionary*)dictionary;

@end
