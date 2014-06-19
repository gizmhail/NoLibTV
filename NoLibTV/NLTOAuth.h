//
//  NLTOAuth.h
//  TestNoco
//
//  Created by Sébastien POIVRE on 18/06/2014.
//  Copyright (c) 2014 Sébastien Poivre. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NLTOAuthController.h"

#if ! __has_feature(objc_arc)
// ARC is Off
#error NoLibTV needs ARC support. In a non ARC project, add -fobjc-arc flag for NLT* files
#endif

#ifndef NLTAuthResponseBlockType
typedef void (^NLTAuthResponseBlock)(NSError *error);
#define NLTAuthResponseBlockType
#endif

@interface NLTOAuth : NSObject <NSURLConnectionDataDelegate>
@property (retain, nonatomic) NSString* clientId;
@property (retain, nonatomic) NSString* clientSecret;
@property (retain, nonatomic) NSString* redirectUri;
@property (retain,nonatomic) NLTOAuthController* oauthController;
@property (retain,nonatomic) NSString* oauthAccessToken;
@property (retain,nonatomic) NSString* oauthRefreshToken;
@property (retain,nonatomic) NSString* oauthTokenType;
@property (retain,nonatomic) NSDate* oauthExpirationDate;

/*
 * Main methods
 */
//Return the NLTOAuth singleton
+ (instancetype)sharedInstance;
//Initialize with credentials
- (void)configureWithClientId:(NSString*)clientId withClientSecret:(NSString*)clientsecret withRedirectUri:(NSString*)redirectUri;
//Return true if the access token should be valid
- (BOOL)isAuthenticated;

/*
 * Launch the authentification process if needed (will display a webview overlay if needed), 
 *   then executes the responseBlock when finished
 * The block error param contains  an error if one has occured, nil if the authentication has succeeded
 */
- (void)authenticate:(NLTAuthResponseBlock)responseBlock;

- (void)disconnect;

//Return nil if accessToken is not available/valid
- (NSMutableURLRequest*)requestWithAccessTokenForURL:(NSURL*)url;

/*
 * Internal usage : doesn't need to be manually called
 */
//Finish the authentification process once a auth code has been received from the NLTOAuthController
- (void)fetchAccessTokenFromAuthCode:(NSString*)code;
@end
