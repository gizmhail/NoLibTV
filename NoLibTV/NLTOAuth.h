//
//  NLTOAuth.h
//  NoLibTV
//
//  Created by Sébastien POIVRE on 18/06/2014.
//  Copyright (c) 2014 Sébastien Poivre. All rights reserved.
//

#import <Foundation/Foundation.h>
#ifndef NLTOAUTH_NO_LOGINCONTROLLER
#import "NLTOAuthController.h"
#endif

#if ! __has_feature(objc_arc)
// ARC is Off
#error NoLibTV needs ARC support. In a non ARC project, add -fobjc-arc flag for NLT* files
#endif

#ifndef NLTDefines
typedef void (^NLTAuthResponseBlock)(NSError *error);
typedef void (^NLTCallResponseBlock)(id result, NSError *error);
#define NOCO_ENDPOINT @"https://api.noco.tv/1.1"
#define NLTDefines
#endif

@interface NLTOAuth : NSObject <NSURLConnectionDataDelegate>
@property (retain, nonatomic) NSString* clientId;
@property (retain, nonatomic) NSString* clientSecret;
@property (retain, nonatomic) NSString* redirectUri;
@property (retain,nonatomic) NSString* oauthAccessToken;
@property (retain,nonatomic) NSString* oauthRefreshToken;
@property (retain,nonatomic) NSString* oauthTokenType;
@property (retain,nonatomic) NSDate* oauthExpirationDate;
#ifndef NLTOAUTH_NO_LOGINCONTROLLER
@property (retain,nonatomic) NLTOAuthController* oauthController;
#endif


//Return the NLTOAuth singleton
+ (instancetype)sharedInstance;
//Initialize the singleton with Noco dev credentials
- (void)configureWithClientId:(NSString*)clientId withClientSecret:(NSString*)clientsecret withRedirectUri:(NSString*)redirectUri;

//Return true if the access token is currently valid (won't use refresh token availability, but will procur immediate response)
- (BOOL)isAuthenticated;

//Return true in the block either if access token is valid directly or after using a refresh token first
- (void)isAuthenticatedAfterRefreshTokenUse:(void (^)(BOOL authenticated, NSError* error)) responseBlock;

/*
 * Launch the authentification process if needed (will display a webview overlay if needed), 
 *   then executes the responseBlock when finished
 * The block error param contains  an error if one has occured, nil if the authentication has succeeded
 */
- (void)authenticate:(NLTAuthResponseBlock)responseBlock;

- (void)disconnect;

//Build a request with oauthAccess token (if authenticated). Return nil if accessToken is not available/valid
- (NSMutableURLRequest*)requestWithAccessTokenForURL:(NSURL*)url;

#pragma mark - Internal tools
/*
 * Finish the authentification process once a auth code has been received from the NLTOAuthController
 * Internal usage : doesn't need to be manually called
 */
- (void)fetchAccessTokenFromAuthCode:(NSString*)code;
/*
 * Problem while invoking the NLTOAuthController
 * Internal usage : doesn't need to be manually called
 */
- (void)errorDuringNLTOAuthControllerDisplay:(NSError*)error;

/**
 * Load info stored in settings
 */
- (void)loadOauthInfo;
@end
