//
//  NLTAPI.h
//  TestNoco
//
//  Created by Sébastien POIVRE on 19/06/2014.
//  Copyright (c) 2014 Sébastien Poivre. All rights reserved.
//

#import <Foundation/Foundation.h>

#ifndef NLTDefines
typedef void (^NLTCallResponseBlock)(id result, NSError *error);
#define NOCO_ENDPOINT @"https://api.noco.tv/1.1"
#define NLTDefines
#endif


@interface NLTAPI : NSObject<NSURLConnectionDataDelegate>
+ (instancetype)sharedInstance;
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
@end
