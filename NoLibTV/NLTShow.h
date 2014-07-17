//
//  NLTShow.h
//  TestNoco
//
//  Created by Sébastien POIVRE on 26/06/2014.
//  Copyright (c) 2014 Sébastien Poivre. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NLTShow : NSObject

@property (retain, nonatomic) NSDate* broadcastDate;

@property (assign, nonatomic) NSDictionary* rawShow;

//Raw field, generated from API
@property (assign, nonatomic) BOOL mark_read;
@property (retain, nonatomic) NSString* template_1l;
@property (retain, nonatomic) NSString* template_2l;
@property (retain, nonatomic) NSString* template_module;
@property (retain, nonatomic) NSString* progress;
@property (assign, nonatomic) int resume_play;
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
@property (retain, nonatomic) NSString* logo_player;
@property (assign, nonatomic) double logo_area_height;
@property (assign, nonatomic) double logo_area_width;
@property (retain, nonatomic) NSString* geoloc;
@property (assign, nonatomic) int id_family;
@property (retain, nonatomic) NSString* family_key;
@property (assign, nonatomic) int id_show;
@property (retain, nonatomic) NSString* show_key;
@property (assign, nonatomic) int hq_master;
@property (assign, nonatomic) int hd_master;
@property (retain, nonatomic) NSString* online_date_start_utc;
@property (retain, nonatomic) NSString* online_date_end_utc;
@property (retain, nonatomic) NSString* sorting_date_utc;
@property (retain, nonatomic) NSString* broadcast_date_utc;
@property (assign, nonatomic) int season_number;
@property (assign, nonatomic) int episode_number;
@property (retain, nonatomic) NSString* episode_reference;
@property (assign, nonatomic) BOOL is_subtitled;
@property (assign, nonatomic) BOOL is_karaoke;
@property (assign, nonatomic) BOOL is_dubbed;
@property (retain, nonatomic) NSString* original_lang;
@property (assign, nonatomic) int duration_ms;
@property (retain, nonatomic) NSString* rating_fr;
@property (assign, nonatomic) int display_rating;
@property (retain, nonatomic) NSString* show_OT;
@property (retain, nonatomic) NSString* show_OT_lang;
@property (retain, nonatomic) NSString* family_OT;
@property (retain, nonatomic) NSString* family_OT_lang;
@property (retain, nonatomic) NSString* show_TT;
@property (retain, nonatomic) NSString* family_TT;
@property (retain, nonatomic) NSString* show_resume; // type unknown by generator
@property (retain, nonatomic) NSString* family_resume;
@property (retain, nonatomic) NSString* cross_partner_key; // type unknown by generator
@property (retain, nonatomic) NSString* cross_partner_name; // type unknown by generator
@property (assign, nonatomic) int quotafr_free;
@property (assign, nonatomic) int user_free;
@property (retain, nonatomic) NSString* user_free_start_utc;
@property (retain, nonatomic) NSString* user_free_end_utc;
@property (assign, nonatomic) int guest_free;
@property (retain, nonatomic) NSString* guest_free_start_utc;
@property (retain, nonatomic) NSString* guest_free_end_utc;
@property (retain, nonatomic) NSString* banner_family;
@property (retain, nonatomic) NSString* screenshot_128x72;
@property (retain, nonatomic) NSString* screenshot_256x144;
@property (retain, nonatomic) NSString* screenshot_512x288;
@property (retain, nonatomic) NSString* screenshot_960x540;
@property (retain, nonatomic) NSString* screenshot_1024x576;
@property (retain, nonatomic) NSString* mosaique;
@property (assign, nonatomic) int access_show;
@property (retain, nonatomic) NSString* access_type;
@property (retain, nonatomic) NSArray* qualities;
@property (retain, nonatomic) NSArray* qualities_languages;
@property (retain, nonatomic) NSArray* languages;
@property (retain, nonatomic) NSArray* audio_languages;
@property (retain, nonatomic) NSArray* full_audio_languages; // type unsure (no value seen)
@property (retain, nonatomic) NSArray* full_video_languages; // type unsure (no value seen)
@property (retain, nonatomic) NSString* access_error;

- (NLTShow*)initWithDictionnary:(NSDictionary*)dictionary;

- (NSString*)durationString;

@end
