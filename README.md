NoLibTV
=======

NolifeTV API iOS library

This library allows to use http://noco.tv API (https://api.noco.tv/1.1/documentation/) easily, by handling the OAuth2 authentification
#Usage
##Main calls
First you have to configure the NLTOAuth singleton with your credential
```objective-c
[[NLTOAuth sharedInstance] configureWithClientId:nolibtv_client_id withClientSecret:nolibtv_client_secret withRedirectUri:nolibtv_redirect_uri];
```
*Note: please read this topic to know how to request credentials http://forum.nolife-tv.com/showthread.php?t=25535*

If you simply what to make an API call then, you can use any flavor of callAPI on the NLTAPI singleton:

```objective-c
[[NLTAPI sharedInstance] callAPI:@"/shows" withResultBlock:^(id result, NSError *error) {
	if(error){
		NSLog(@"Error: %@",error);
        }else{
		NSLog(@"Answer: %@",result);
	}
}];
```
These calls will automatically handle the login by displaying an authentication webview to the user.
Another callAPI flavor allows to set a cache duration for the call result.

##Detailed authentification calls
You can check if you're authenticated with isAuthenticated 
```objective-c
BOOL authenticated = [[NLTOAuth sharedInstance] isAuthenticated];
```

You can request an authentification will NLTOAuth authenticate, which will display the OAuth login page in an popup webview

```objective-c
[[NLTOAuth sharedInstance] authenticate:^(NSError *error) {
	if(error){
		//Authentification failure
	}else{
		//Properly authenticated
	}
}];
```

# Open source components

## Base64
Base64, Copyright (C) 2012 Charcoal Design
https://github.com/nicklockwood/Base64

#Changelog 
0.6
0.5:
- handle already presented modal view controller when trying to present OAuth webview
- added isAuthenticatedAfterRefreshTokenUse: to include refresh token check (asyn response using blocks)
- simultaneous calls to the same API now wait for first call result instead of calling the same API


