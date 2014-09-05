//
//  NLTOAuthController.m
//  NoLibTV
//
//  Created by Sébastien POIVRE on 18/06/2014.
//  Copyright (c) 2014 Sébastien Poivre. All rights reserved.
//

#import "NLTOAuthController.h"
#import "NLTOAuth.h"

@interface NLTOAuthController ()
@property (retain,nonatomic) UIWebView* webview;
@property (retain,nonatomic) UIActivityIndicatorView* activity;
@end

@implementation NLTOAuthController


- (void)viewDidLoad
{
    [super viewDidLoad];
    self.webview = [[UIWebView alloc] initWithFrame:self.view.bounds];
    self.edgesForExtendedLayout = UIRectEdgeNone;
    self.webview.delegate = self;
    self.webview.autoresizingMask = UIViewAutoresizingFlexibleHeight|UIViewAutoresizingFlexibleWidth;
    self.activity = [[UIActivityIndicatorView alloc] initWithFrame:self.view.bounds];
    self.activity.hidesWhenStopped = TRUE;
    self.activity.activityIndicatorViewStyle = UIActivityIndicatorViewStyleGray;
    self.activity.autoresizingMask = UIViewAutoresizingFlexibleHeight|UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:self.webview];
    [self.view addSubview:self.activity];
    [self.activity startAnimating];
}

-(void)viewDidAppear:(BOOL)animated{
    NSString* urlStr = [NSString stringWithFormat:@"%@/OAuth2/authorize.php?response_type=code&client_id=%@&state=STATE",NOCO_ENDPOINT,[NLTOAuth sharedInstance].clientId];
    [self.webview loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:urlStr]]];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(void)dealloc{
    self.webview.delegate = nil;
}

#pragma mark -  UIWebviewDelegate

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType{
    NSLog(@"%@",request);
    if([[request.URL absoluteString] rangeOfString:[NLTOAuth sharedInstance].redirectUri].location!=NSNotFound){
        //Redirect URL for our client
        NSArray* rawParams = [[request.URL query] componentsSeparatedByString:@"&"];
        NSMutableDictionary* params = [NSMutableDictionary dictionary];
        for (NSString* rawParam in rawParams) {
            NSArray* rawParamParts = [rawParam componentsSeparatedByString:@"="];
            if([rawParamParts count]==2){
                NSString * key = [[rawParamParts objectAtIndex:0] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
                NSString * value = [[rawParamParts objectAtIndex:1] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
                [params setObject:value forKey:key];
            }
        }
        if([params objectForKey:@"code"]){
            //fetchAccessTokenFromAuthCode also handles dismissing the controller
            [[NLTOAuth sharedInstance] fetchAccessTokenFromAuthCode:[params objectForKey:@"code"]];
        }else{
            NSError* error = [NSError errorWithDomain:@"NLTErrorDomain" code:600 userInfo:@{@"oauthError":@"Unexpected response", @"returnUrl":[request.URL absoluteString]}];
            [[NLTOAuth sharedInstance] errorDuringNLTOAuthControllerDisplay:error];

        }
        return NO;
    }
    return TRUE;
}

-(void)webViewDidFinishLoad:(UIWebView *)webView{
    [self.activity stopAnimating];
#ifdef HACK_AUTH_WEBPAGE_REMOVE_ACCOUNT_CREATION
    [self.webview stringByEvaluatingJavaScriptFromString:@"\
     var els = document.getElementsByTagName('a');\
     for (var i = 0, l = els.length; i < l; i++) {\
         var el = els[i];\
         if (el.href.indexOf('#two') > -1 ) {\
             el.parentNode.removeChild(el);\
             break;\
         }\
     }"];
#endif
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error{
    [self.activity stopAnimating];
    BOOL normalInterruption = FALSE;
    if(error.userInfo && [error.userInfo objectForKey:@"NSErrorFailingURLKey"]){
        NSString* failingURLKey =  [error.userInfo objectForKey:@"NSErrorFailingURLKey"];
        if([failingURLKey isKindOfClass:[NSURL class]]){
            failingURLKey = [(NSURL*)failingURLKey absoluteString];
        }
        if([failingURLKey rangeOfString:[NLTOAuth sharedInstance].redirectUri].location!=NSNotFound){
            normalInterruption = TRUE;
        }
    }
    if(!normalInterruption){
        NSLog(@"%@ : %@ %@",NSStringFromSelector(_cmd), error, error.userInfo);
        [[NLTOAuth sharedInstance] errorDuringNLTOAuthControllerDisplay:error];

    }
}
@end
