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
/*
 * Call API methods handle the authentification : [[NLTOAuth sharedInstance] authenticate:...] is called at their beginning, displaying the auth webview if needed
 */
- (void)callAPI:(NSString*)urlPart withResultBlock:(NLTCallResponseBlock)block withKey:(id)key withCacheDuration:(double)cacheDurationSeconds;
- (void)callAPI:(NSString*)urlPart withResultBlock:(NLTCallResponseBlock)block withKey:(id)key;
- (void)callAPI:(NSString*)urlPart withResultBlock:(NLTCallResponseBlock)block;

- (void)cancelCallsWithKey:(id)key;
- (void)cancelAllCAlls;

- (void)invalidateCache:(NSString*)urlPart;
@end
