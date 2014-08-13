//
//  NLTOAuth.m
//  NoLibTV
//
//  Created by Sébastien POIVRE on 18/06/2014.
//  Copyright (c) 2014 Sébastien Poivre. All rights reserved.
//

#import "NLTOAuth.h"
#import "Base64.h"

@interface NLTOAuth ()
@property (retain,nonatomic) NSString* oauthCode;
@property (copy,nonatomic) NLTAuthResponseBlock authResponseBlock;
@property (retain,nonatomic) NSURLConnection* connection;
@property (retain,nonatomic) NSMutableData* data;

@end

@implementation NLTOAuth

+ (instancetype)sharedInstance{
    static NLTOAuth* _sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        if(!_sharedInstance){
            _sharedInstance = [[self alloc] init];
        }
    });
    return _sharedInstance;
}

- (void)configureWithClientId:(NSString*)clientId withClientSecret:(NSString*)clientsecret withRedirectUri:(NSString*)redirectUri{
    self.clientId = clientId;
    self.clientSecret = clientsecret;
    self.redirectUri = redirectUri;
}

- (instancetype)init{
    if(self = [super init]){
        [self loadOauthInfo];
    }
    return self;
}

#pragma mark - Calls

- (NSMutableURLRequest*)requestWithAccessTokenForURL:(NSURL*)url{
    if(![self isAuthenticated]){
        return nil;
    }
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:url];
    NSString* loginString = [NSString stringWithFormat:@"%@ %@", self.oauthTokenType, self.oauthAccessToken];
    [request setValue:loginString forHTTPHeaderField:@"Authorization"];
    return request;
    
}

#pragma mark - OAuth

- (void)checkCredentials{
    if(!self.clientId||!self.clientSecret||!self.redirectUri){
        NSLog(@"Error: you need to set your credentials with:\n[[NLTOAuth sharedInstance] configureWithClientId:nolibtv_client_id withClientSecret:nolibtv_client_secret withRedirectUri:nolibtv_redirect_uri];\nbefore using NLOAuth");
#ifdef DEBUG
        exit(0);
#endif
    }
}

- (BOOL)isAuthenticated{
    [self checkCredentials];
    if(self.oauthAccessToken && self.oauthTokenType && self.oauthExpirationDate && [[NSDate date] compare:self.oauthExpirationDate] == NSOrderedAscending){
        return TRUE;
    }else if(self.oauthAccessToken){
        self.oauthAccessToken = nil;
        self.oauthExpirationDate = nil;
    }
    return FALSE;
}


- (void)isAuthenticatedAfterRefreshTokenUse:(void (^)(BOOL authenticated, NSError* error)) responseBlock{
    if([self isAuthenticated]){
        //Return proper auth
        if(responseBlock){
            responseBlock(TRUE, nil);
        }
    }else{
        //Checking if a refresh token might hel us here
        if(self.oauthRefreshToken){
            __weak NLTOAuth* weakSelf = self;
            NLTAuthResponseBlock previousblock = nil;
            if(self.authResponseBlock){
                previousblock = self.authResponseBlock;
            }
            self.authResponseBlock = ^(NSError *error) {
                if(previousblock){
                    previousblock(error);
                }
                //Return error
                if(error){
                    if(responseBlock){
                        responseBlock(FALSE, error);
                    }
                }else if([weakSelf isAuthenticated]){
                    //Return proper auth
                    if(responseBlock){
                        responseBlock(TRUE, nil);
                    }
                }else{
                    //Was tring to use a refresh token which was probably outdated
                    responseBlock(FALSE, nil);
                }
            };
            [self fetchAccessTokenFromRefreshToken];
        }else{
            if(responseBlock){
                responseBlock(FALSE, nil);
            }
        }
    }
}


- (void)disconnect{
    self.oauthCode = nil;
    self.oauthAccessToken = nil;
    self.oauthRefreshToken = nil;
    self.oauthExpirationDate = nil;
    self.oauthTokenType = nil;
    [self saveOAuthInfo];
}

- (void)authenticate:(NLTAuthResponseBlock)responseBlock{
    [self checkCredentials];
    if([self isAuthenticated]){
        if(responseBlock){
            responseBlock(nil);
        }
    }else{
        __weak NLTOAuth* weakSelf = self;
        NLTAuthResponseBlock previousblock = nil;
        BOOL authAlreadyPending = FALSE;
        if(self.authResponseBlock){
#ifdef DEBUG
            NSLog(@"Auth call already pending");
#endif
            previousblock = self.authResponseBlock;
            authAlreadyPending = TRUE;
        }
        self.authResponseBlock = ^(NSError *error) {
#ifdef DEBUG
            NSLog(@"Auth call finished");
#endif
            if(previousblock){
                previousblock(error);
            }
            //Return error
#warning TODO Check if we should handle differently when error is due to being offline
            if(error){
                if(responseBlock){
                    responseBlock(error);
                }
            }else if([weakSelf isAuthenticated]){
                //Return proper auth
                if(responseBlock){
                    responseBlock(nil);
                }
            }else{
                //Was tring to use a refresh token which was probably outdated. Switch to normal login with webview
                [weakSelf displayOAuthControllerOverlay];
            }
        };
        if(!authAlreadyPending){
            if(self.oauthRefreshToken){
                [self fetchAccessTokenFromRefreshToken];
            }else{
                [self displayOAuthControllerOverlay];
            }
        }
    }
}

- (void)displayOAuthControllerOverlay{
    self.oauthController = [[NLTOAuthController alloc] init];
    UIViewController* controller = [[[UIApplication sharedApplication] keyWindow] rootViewController];
    //Handle already present modal view
    if(controller.presentedViewController){
        controller = controller.presentedViewController;
    }
    [self requestAccessTokenWebviewFrom:controller];
}

- (void)requestAccessTokenWebviewFrom:(UIViewController*)controller{
    self.oauthController = [[NLTOAuthController alloc] init];
    [controller presentViewController:self.oauthController animated:YES completion:^{
        
    }];
}

- (void)errorDuringNLTOAuthControllerDisplay:(NSError*)error{
    [self.oauthController dismissViewControllerAnimated:YES completion:^{
        if(self.authResponseBlock){
            self.authResponseBlock(error);
            self.authResponseBlock = nil;
        }
    }];
    self.oauthController = nil;
}

- (void)fetchAccessTokenFromAuthCode:(NSString*)code{
#ifdef DEBUG
    NSLog(@"fetchAccessTokenFromAuthCode");
#endif
    //OAuthController can be dismissed
    [self.oauthController dismissViewControllerAnimated:YES completion:nil];
    self.oauthController = nil;
    
    self.oauthCode = code;
    self.oauthAccessToken = nil;
    self.oauthRefreshToken = nil;
    self.oauthExpirationDate = nil;
    self.oauthTokenType = nil;
    [self fetchAccessToken];
}

- (void)fetchAccessTokenFromRefreshToken{
#ifdef DEBUG
    NSLog(@"fetchAccessTokenFromRefreshToken");
#endif
    self.oauthCode = nil;
    self.oauthAccessToken = nil;
    self.oauthExpirationDate = nil;
    self.oauthTokenType = nil;
    [self fetchAccessToken];
}


- (void)fetchAccessToken{
    NSString* dataStr = nil;
    if(!dataStr&&self.oauthRefreshToken){
        dataStr = [NSString stringWithFormat:@"grant_type=refresh_token&refresh_token=%@",self.oauthRefreshToken];
    }
    if(!dataStr&&self.oauthCode){
        dataStr = [NSString stringWithFormat:@"grant_type=authorization_code&code=%@",self.oauthCode];
    }
    if(!dataStr){
#warning Return error
    }
    
    NSString* urlStr = [NSString stringWithFormat:@"%@/OAuth2/token.php", NOCO_ENDPOINT];
    NSURL *url = [NSURL URLWithString:urlStr];
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:url];
    NSString *loginString = [NSString stringWithFormat:@"%@:%@",self.clientId,self.clientSecret];
    //When limiting to iOS7 only, remove Base64 and use this :
    //loginString = [[loginString dataUsingEncoding:NSUTF8StringEncoding] base64EncodedStringWithOptions:0];
    loginString = [loginString base64EncodedString];
    
    loginString = [@"Basic " stringByAppendingFormat:@"%@", loginString];
    [request setValue:loginString forHTTPHeaderField:@"Authorization"];
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
    
    [request setHTTPBody:[dataStr dataUsingEncoding:NSUTF8StringEncoding]];
    [request setValue:[NSString stringWithFormat:@"%d", [[dataStr dataUsingEncoding:NSUTF8StringEncoding] length]] forHTTPHeaderField:@"Content-Length"];
    
    
    NSURLConnection* connection = [NSURLConnection connectionWithRequest:request delegate:self];
    if(connection){
        [connection start];
    }else{
        if(self.authResponseBlock){
            NSError* error = [NSError errorWithDomain:@"NLTErrorDomain" code:500 userInfo:@{@"oauthError":@"Unknown error"}];
            self.authResponseBlock(error);
            self.authResponseBlock = nil;
        }
    }
}

- (void)saveOAuthInfo{
    NSUserDefaults* settings = [NSUserDefaults standardUserDefaults];
    if(self.oauthAccessToken){
        [settings setObject:self.oauthAccessToken forKey:@"NLTOAuth_oauthAccessToken"];
    }else{
        [settings removeObjectForKey:@"NLTOAuth_oauthAccessToken"];
    }
    if(self.oauthRefreshToken) {
        [settings setObject:self.oauthRefreshToken forKey:@"NLTOAuth_oauthRefreshToken"];
    }else{
        [settings removeObjectForKey:@"NLTOAuth_oauthRefreshToken"];
    }
    if(self.oauthExpirationDate) {
        [settings setObject:self.oauthExpirationDate forKey:@"NLTOAuth_oauthExpirationDate"];
    }else{
        [settings removeObjectForKey:@"NLTOAuth_oauthExpirationDate"];
    }
    if(self.oauthTokenType) {
        [settings setObject:self.oauthTokenType forKey:@"NLTOAuth_oauthTokenType"];
    }else{
        [settings removeObjectForKey:@"NLTOAuth_oauthTokenType"];
    }
    [settings synchronize];
}

- (void)loadOauthInfo{
    NSUserDefaults* settings = [NSUserDefaults standardUserDefaults];
    self.oauthAccessToken = [settings objectForKey:@"NLTOAuth_oauthAccessToken"];
    self.oauthRefreshToken = [settings objectForKey:@"NLTOAuth_oauthRefreshToken"];
    self.oauthExpirationDate = [settings objectForKey:@"NLTOAuth_oauthExpirationDate"];
    self.oauthTokenType = [settings objectForKey:@"NLTOAuth_oauthTokenType"];
#ifdef DEBUG
    //Debug to test refresh token
    //self.oauthExpirationDate = [NSDate dateWithTimeIntervalSinceNow:10];
#endif
}

#pragma mark NSURLConnectionDataDelegate

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response{
   self.data = [NSMutableData data];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data{
    [self.data appendData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection{
    NSError *jsonError;
    BOOL refreshTokenTry = self.oauthRefreshToken != nil;
    NSDictionary* answer = nil;
    if(self.data){
        answer = [NSJSONSerialization JSONObjectWithData:self.data options:NSJSONReadingAllowFragments error:&jsonError];
    }
    if(!jsonError&&[answer isKindOfClass:[NSDictionary class]]){
        self.oauthAccessToken = [answer objectForKey:@"access_token"];
        self.oauthRefreshToken = [answer objectForKey:@"refresh_token"];
        self.oauthTokenType = [answer objectForKey:@"token_type"];
        long expiresIn = [[answer objectForKey:@"expires_in"] integerValue];
        self.oauthExpirationDate = [[NSDate date] dateByAddingTimeInterval:expiresIn];
        [self saveOAuthInfo];
    }
    //Callback, error handling
    if(self.oauthAccessToken){
#ifdef DEBUG
        NSLog(@"fetchAccessToken sucess");
#endif
        //Success
        if(self.authResponseBlock){
            self.authResponseBlock(nil);
            self.authResponseBlock = nil;
        }
    }else{
#ifdef DEBUG
        NSLog(@"fetchAccessToken failure %@", answer);
#endif
        //Failure
        if(refreshTokenTry){
            //Was tring to use a refresh token - was probably outdated. The problem will be handled in the authResponseBlock (either switch to normal login with webview, or handle differently)
            if(self.authResponseBlock){
                self.authResponseBlock(nil);
                self.authResponseBlock = nil;
            }
        }else{
            //Unable to login
            if(self.authResponseBlock){
                NSError* error = nil;
                if(jsonError){
                    error = jsonError;
                }else{
#warning Add more explicit error, make it available in .h, with proper error codes, ...
                    error = [NSError errorWithDomain:@"NLTErrorDomain" code:500 userInfo:@{@"oauthError":@"Unknown error"}];
                }
                self.authResponseBlock(error);
                self.authResponseBlock = nil;
            }
        }
    }
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error{
    if(self.authResponseBlock){
        self.authResponseBlock(error);
        self.authResponseBlock = nil;
    }
}

@end
