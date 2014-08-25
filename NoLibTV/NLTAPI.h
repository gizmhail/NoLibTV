//
//  NLTAPI.h
//  NoLibTV
//
//  Created by Sébastien POIVRE on 19/06/2014.
//  Copyright (c) 2014 Sébastien Poivre. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "NLTOAuth.h"
#import "NLTShow.h"
#import "NLTFamily.h"

#define NLT_SHOWS_BY_PAGE 40

#define NLT_QUEUELIST_CACHE_DURATION 60
#define NLT_USER_CACHE_DURATION 3600*10
#define NLT_PARTNERS_CACHE_DURATION 3600*24
#define NLT_SHOWS_CACHE_DURATION 60*30
#define NLT_MARKREADSHOWS_CACHE_DURATION 60*10
#define NLT_FAMILY_CACHE_DURATION 3600*24

#warning TODO Define all error codes
#define NLTAPI_ERROR_VIDEO_UNAVAILABLE_WITH_POPMESSAGE 405
#define NLTAPI_NOCO_ERROR 510

#define NLTAPI_WATCHFILTER_READONLY @"1"
#define NLTAPI_WATCHFILTER_UNREADONLY @"0"
#define NLTAPI_WATCHFILTER_ALL nil

@interface NLTAPI : NSObject<NSURLConnectionDataDelegate>
@property (retain, nonatomic)NSString* partnerKey;//Limit shows and search calls
@property (assign, nonatomic)BOOL subscribedOnly;//Limit shows calls
@property (retain,nonatomic) NSMutableDictionary* showsById; // Already fetched shows
@property (retain,nonatomic) NSMutableDictionary* familiesById; // Already fetched families
@property (retain,nonatomic) NSMutableDictionary* familiesByKey; // Already fetched families
@property (retain,nonatomic) NSMutableDictionary* partnersByKey; // Already fetched partners
@property (assign,nonatomic) BOOL handleNetworkActivityIndicator;
@property (assign,nonatomic) int networkActivityCount;
@property (retain,nonatomic) NSString* preferedQuality;//Prefered quality for video (LQ, HD_720,...)
@property (retain,nonatomic) NSString* preferedLanguage;//Prefered audio language for video (fr, ja, en, nil for original version)
@property (retain,nonatomic) NSString* preferedSubtitleLanguage;//Prefered subtitle language (none, fr, en)
@property (assign,nonatomic) BOOL autoLaunchAuthentificationView;//Calls NLTOAuth authenticate when needed if true

#pragma mark Shared singleton
+ (instancetype)sharedInstance;

#pragma mark -
#pragma mark Core methods
/*!
 @method    callAPI:withResultBlock:withKey:withCacheDuration:
 
 @abstract  Authenticate the user if needed (with OAuth webview), then call the Noco backed for the requested url
 
 @discussion    callAPI methods handle the authentification : [[NLTOAuth sharedInstance] authenticate:...] is called at their beginning, displaying the auth webview if needed
 
 @param urlPart
    Describe the call requested. It can either be a full url string (https://api.noco.tv/1.1/shows) or just the main part (/shows)
 @param block
    A NLTCallResponseBlock callback block, called when the called succeeds or fails. 
    The result argument contains the call result or nil if the call failed, and the error argument contains the error, or nil if the call has succeeded
 @param key
    A key to easily cancel a call (usefull when a call is associate to a controller that we might dismiss before call end)
 @param cacheDurationSeconds
    If greater than 0, the result of the call will be cached, and reused if the same urlPart is requested before cacheDurationSeconds seconds. 
    Cache is stored in NSUserDefault and thus is not limited to current session
*/
- (void)callAPI:(NSString*)urlPart withResultBlock:(NLTCallResponseBlock)block withKey:(id)key withCacheDuration:(double)cacheDurationSeconds;
- (void)callAPI:(NSString*)urlPart withResultBlock:(NLTCallResponseBlock)block withKey:(id)key;
- (void)callAPI:(NSString*)urlPart withResultBlock:(NLTCallResponseBlock)block;

//Cancel pending calls
- (void)cancelCallsWithKey:(id)key;
- (void)cancelAllCalls;

//Remove a cached result
- (void)invalidateCache:(NSString*)urlPart;
- (void)invalidateCacheWithPrefix:(NSString*)prefix;
- (void)invalidateAllCache;

#pragma mark - 

#pragma mark Show
- (void)showWithId:(long)showId withResultBlock:(NLTCallResponseBlock)responseBlock withKey:(id)key;
- (void)showWithId:(long)showId withResultBlock:(NLTCallResponseBlock)responseBlock withKey:(id)key noCache:(BOOL)noCache;
#pragma mark Family
- (void)familyWithId:(long)familyId withResultBlock:(NLTCallResponseBlock)responseBlock withKey:(id)key;
- (void)familyWithFamilyKey:(NSString*)familyKey withPartnerKey:(NSString*)partnerKey withResultBlock:(NLTCallResponseBlock)responseBlock withKey:(id)key;
//Conveniance method: a family merged  key is "partnerKey/familyKey"
- (void)familyWithFamilyMergedKey:(NSString*)familyMergedKey withResultBlock:(NLTCallResponseBlock)responseBlock withKey:(id)key;

#pragma mark Families list
- (void)familiesAtPage:(int)page withResultBlock:(NLTCallResponseBlock)responseBlock withKey:(id)key;

#pragma mark Shows list
//Response block  will contain an array of NLTShow objects
- (void)showsAtPage:(int)page withResultBlock:(NLTCallResponseBlock)responseBlock withKey:(id)key;
- (void)showsAtPage:(int)page withResultBlock:(NLTCallResponseBlock)responseBlock withFamilyKey:(NSString*)familyKey withKey:(id)key;
- (void)showsAtPage:(int)page withResultBlock:(NLTCallResponseBlock)responseBlock withFamilyKey:(NSString*)familyKey withWatchFilter:(NSString*)watchFilter withKey:(id)key;
//Tells how much shows/famillies we request by page in calls
- (int)resultsByPage;

#pragma mark Watchlist
- (void)isInQueueList:(NLTShow*)show withResultBlock:(NLTCallResponseBlock)responseBlock withKey:(id)key;
- (void)queueListShowIdsWithResultBlock:(NLTCallResponseBlock)responseBlock withKey:(id)key;
- (void)addToQueueList:(NLTShow*)show withResultBlock:(NLTCallResponseBlock)responseBlock withKey:(id)key;
- (void)removeFromQueueList:(NLTShow*)show withResultBlock:(NLTCallResponseBlock)responseBlock withKey:(id)key;

#pragma mark Readlist
- (void)setReadStatus:(BOOL)isRead forShow:(NLTShow*)show withResultBlock:(NLTCallResponseBlock)responseBlock withKey:(id)key;

#pragma mark Progress (resume_play)
- (void)getResumePlayForShow:(NLTShow*)show withResultBlock:(NLTCallResponseBlock)responseBlock withKey:(id)key;
- (void)setResumePlay:(long)timeInMS forShow:(NLTShow*)show withResultBlock:(NLTCallResponseBlock)responseBlock withKey:(id)key;

#pragma mark Search
- (void)search:(NSString*)query atPage:(int)page withResultBlock:(NLTCallResponseBlock)responseBlock withKey:(id)key;

#pragma mark User account
- (void)userAccountInfoWithResultBlock:(NLTCallResponseBlock)responseBlock withKey:(id)key;

#pragma mark Partners
- (void)partnersWithResultBlock:(NLTCallResponseBlock)responseBlock withKey:(id)key;
#pragma mark Video url
/*!
 @method videoUrlForShow:withPreferedQuality:withPreferedLanguage:withPreferedSubtitleLanguage:withResultBlock:withKey:(id)key
 @abstract Return the media url requested with closest criteria to prefered ones among available media
 @param preferedQuality
 Prefered quality for video (LQ, HD_720,...)
 @param preferedLanguage
 Prefered audio language for video (fr, ja, en, nil for original version)
 @param preferedSubtitleLanguage
 Prefered subtitle language (none, fr, en)
 @param block
 A NLTCallResponseBlock callback block, called when the called succeeds or fails.
 The result argument contains the call result to GET /shows/{id_show}/video/{quality_key}/{audio_lang} or nil if the call failed, and the error argument contains the error, or nil if the call has succeeded
 @param key
 A key to easily cancel a call (usefull when a call is associate to a controller that we might dismiss before call end)
 */
- (void)videoUrlForShow:(NLTShow*)show withPreferedQuality:(NSString*)preferedQuality withPreferedLanguage:(NSString*)preferedLanguage withPreferedSubtitleLanguage:(NSString*)preferedSubtitleLanguage withResultBlock:(NLTCallResponseBlock)responseBlock withKey:(id)key;
//Use NLTAPI object prefered criteria
- (void)videoUrlForShow:(NLTShow*)show withResultBlock:(NLTCallResponseBlock)responseBlock withKey:(id)key;
@end
